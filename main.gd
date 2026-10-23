# Four-player carrying greybox; full match flow is added in Phase 5.
extends Node3D

# --- Resources and display state ---
const MOVER_SCENE := preload("res://actors/Mover.tscn")
const ARENA_SCENE := preload("res://arenas/Mansion.tscn")
var status_label := Label.new()
var arena: Node3D
var movers: Array[CharacterBody3D] = []
var connection_text: String = ""
var hud_elapsed: float = 0.0

# --- Setup ---
func _ready() -> void:
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	_build_camera()
	_build_overlay()
	for slot: int in range(Balance.MAX_PLAYERS):
		var mover := MOVER_SCENE.instantiate()
		mover.slot = slot
		mover.position = Vector3((slot - (Balance.MAX_PLAYERS - 1) / 2.0) * Balance.SPAWN_SPACING, Balance.CAPSULE_HEIGHT / 2.0, Balance.MOVER_SPAWN_Z)
		add_child(mover)
		movers.append(mover)
	Net.players_changed.connect(_start_ready_controllers)
	_build_connection_text()
	_start_ready_controllers()
	print("Phase 3: carrying greybox ready. The piano needs two movers; the flashlight is by the front door.")


# --- Test feedback ---
func _process(delta: float) -> void:
	status_label.text = "GHOSTED MOVERS · BANKED %s\nHold GRAB to carry · release in the green truck zone · THROW light items · the piano needs two\n%s" % [Loot.rupees(arena.truck.banked_value), connection_text]
	# Until match flow exists, one active player counts as the lone mover of a 2-player match.
	Loot.lone_mover = _active_player_count() <= 1
	hud_elapsed += delta
	if hud_elapsed >= 1.0 / Balance.HUD_RATE:
		hud_elapsed = fmod(hud_elapsed, 1.0 / Balance.HUD_RATE)
		_send_held_hud()


func _build_connection_text() -> void:
	if Net.listen_error != OK:
		connection_text = "PORT %d BUSY — close the other game instance, then restart." % Balance.SOCKET_PORT
	else:
		var addresses: PackedStringArray = []
		for address: String in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
				addresses.append("http://%s:%d" % [address, Balance.WEB_PORT])
		connection_text = "Phones: " + " · ".join(addresses)


func _send_held_hud() -> void:
	for mover: CharacterBody3D in movers:
		var player := Net.player_for_slot(mover.slot)
		if player.is_empty():
			continue
		var item: Carryable = mover.held_item
		var has_item: bool = is_instance_valid(item) and not item.finished
		var value: Variant = null # Items without a price, like the flashlight, show their name only.
		if has_item and item is Loot:
			value = item.value
		Net.send_to_player(player, {"type": "hud", "held": item.item_name if has_item else "", "value": value, "t": 0})


func _active_player_count() -> int:
	# Slots driven by a connected phone, plus the keyboard's slot when no phone has it.
	var count: int = 0
	for slot: int in range(Balance.MAX_PLAYERS):
		var player := Net.player_for_slot(slot)
		var phone_connected: bool = not player.is_empty() and player.socket != null
		if phone_connected or slot == InputRouter.selected_slot:
			count += 1
	return count


func _start_ready_controllers() -> void:
	# This harness assigns mover controls only; real roles belong to Game in Phase 5.
	for player: Dictionary in Net.players:
		if player.ready and player.role.is_empty():
			Net.set_role(player.slot, "mover", "Carrying test")


# --- Scene helpers ---
func _build_camera() -> void:
	var camera := Camera3D.new()
	var angle: float = deg_to_rad(Balance.CAMERA_ANGLE)
	camera.position = Balance.CAMERA_TARGET + Vector3(0.0, sin(angle), cos(angle)) * Balance.CAMERA_DISTANCE
	add_child(camera)
	camera.look_at(Balance.CAMERA_TARGET)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Balance.LIGHT_ROTATION
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("162a2b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	add_child(environment)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2.ONE * Balance.OVERLAY_MARGIN
	canvas.add_child(panel)
	status_label.add_theme_font_size_override("font_size", Balance.HUD_SMALL_FONT_SIZE)
	panel.add_child(status_label)
