# Produces one input snapshot per slot; connected phones take priority over keyboard, except the developer mode
# stand-in the keyboard has picked.
extends Node

# --- Input definitions ---
const SLOT_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
const BUTTON_KEYS: Dictionary = {
	KEY_SPACE: "grab", KEY_E: "throw", KEY_SHIFT: "brace",
	KEY_Q: "possess", KEY_F: "action", KEY_Z: "haunt1", KEY_X: "haunt2", KEY_C: "haunt3",
}

class PlayerInput:
	var direction := Vector2.ZERO
	var buttons: Dictionary = {}
	var pressed: Dictionary = {}
	var released: Dictionary = {}

# --- Input state ---
var selected_slot: int = 0
var snapshots: Array[PlayerInput] = []
var keyboard_buttons: Dictionary = {}
var keyboard_pressed: Dictionary = {}
var keyboard_released: Dictionary = {}
var has_focus: bool = true
var input_enabled: bool = true

# --- Setup and event collection ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100 # Sample before the actors consume their input.
	for slot: int in range(Balance.MAX_PLAYERS):
		snapshots.append(PlayerInput.new())


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	if event.pressed and event.physical_keycode in SLOT_KEYS and not event.ctrl_pressed: # Ctrl+number is developer mode's.
		selected_slot = SLOT_KEYS.find(event.physical_keycode)
		_clear_keyboard()
		print("Keyboard selected slot %d" % (selected_slot + 1))
	if event.physical_keycode in BUTTON_KEYS:
		var button: String = BUTTON_KEYS[event.physical_keycode]
		keyboard_buttons[button] = event.pressed
		if event.pressed:
			keyboard_pressed[button] = true
		else:
			keyboard_released[button] = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		has_focus = false
		_clear_keyboard()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		has_focus = true


# --- Physics input snapshots ---
func _physics_process(_delta: float) -> void:
	for slot: int in range(Balance.MAX_PLAYERS):
		_sample_slot(slot)
	keyboard_pressed.clear()
	keyboard_released.clear()


func for_slot(slot: int) -> PlayerInput:
	return snapshots[slot]


func _sample_slot(slot: int) -> void:
	var snapshot: PlayerInput = snapshots[slot]
	var previous_buttons: Dictionary = snapshot.buttons.duplicate()
	snapshot.direction = Vector2.ZERO
	snapshot.buttons = {}
	snapshot.pressed = {}
	snapshot.released = {}
	if not input_enabled:
		return
	var player := Net.player_for_slot(slot)
	# Developer mode's stand-ins are played by bots, except the one the keyboard has picked.
	var keyboard_slot: bool = slot == selected_slot and player.get("stand_in", false)
	if not player.is_empty() and player.socket != null and not keyboard_slot:
		snapshot.direction = stick_to_world(player.direction)
		snapshot.buttons = player.buttons.duplicate()
		snapshot.pressed = player.pressed.duplicate()
		snapshot.released = player.released.duplicate()
	elif slot == selected_slot and has_focus:
		snapshot.direction = stick_to_world(_keyboard_direction())
		snapshot.buttons = keyboard_buttons.duplicate()
		snapshot.pressed = keyboard_pressed.duplicate()
		snapshot.released = keyboard_released.duplicate()
	if not player.is_empty():
		player.pressed.clear()
		player.released.clear()
	for button: String in Net.BUTTONS:
		var held_before: bool = previous_buttons.get(button, false)
		var held_now: bool = snapshot.buttons.get(button, false)
		if held_now and not held_before:
			snapshot.pressed[button] = true
		if held_before and not held_now:
			snapshot.released[button] = true


# --- Screen to world ---
func stick_to_world(stick: Vector2) -> Vector2:
	# Phones and keys give a screen direction (up is up on the big screen); movers, the ghost and possessed props move
	# in the world's x and z. The camera looks in at an angle, so the stick turns with it (decision 124).
	var axes: Array[Vector2] = _screen_axes()
	return axes[0] * stick.x + axes[1] * stick.y


func world_to_stick(direction: Vector2) -> Vector2:
	# The reverse, for bots and checks that steer toward a point in the world.
	var axes: Array[Vector2] = _screen_axes()
	return Vector2(direction.dot(axes[0]), direction.dot(axes[1]))


func _screen_axes() -> Array[Vector2]:
	# The screen's right and down as flat world directions, from the camera now showing the play; none, the world's.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return [Vector2.RIGHT, Vector2.DOWN]
	var right := Vector2(camera.global_basis.x.x, camera.global_basis.x.z)
	var down := Vector2(camera.global_basis.z.x, camera.global_basis.z.z) # The camera's back, flattened.
	if right.length() < 0.01 or down.length() < 0.01:
		return [Vector2.RIGHT, Vector2.DOWN] # Looking straight down or along the ground: keep the world's axes.
	return [right.normalized(), down.normalized()]


# --- Keyboard helpers ---
func _keyboard_direction() -> Vector2:
	var left: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right: bool = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	return Vector2(float(right) - float(left), float(down) - float(up)).limit_length()


func _clear_keyboard() -> void:
	keyboard_buttons.clear()
	keyboard_pressed.clear()
	keyboard_released.clear()
