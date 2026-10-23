# Four-player greybox with an optional ghost; full match flow is added in Phase 5.
extends Node3D

# --- Resources and display state ---
const MOVER_SCENE := preload("res://actors/Mover.tscn")
const GHOST_SCENE := preload("res://actors/GhostWisp.tscn")
const CAMERA_SCENE := preload("res://actors/PartyCamera.tscn")
const ARENA_SCENE := preload("res://arenas/Mansion.tscn")
var status_label := Label.new()
var ghost_panel := PanelContainer.new()
var ghost_label := Label.new()
var ghost_bar := ProgressBar.new()
var arena: Node3D
var movers: Array[CharacterBody3D] = []
var ghost: Node3D
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
		mover.position = _spawn_point(slot)
		add_child(mover)
		movers.append(mover)
	Net.players_changed.connect(_start_ready_controllers)
	_build_connection_text()
	_start_ready_controllers()
	print("Phase 4: ghost greybox ready. Press G to pass the ghost role; the piano needs two movers.")


# --- Test feedback ---
func _process(delta: float) -> void:
	status_label.text = "GHOSTED MOVERS · BANKED %s\nHold GRAB to carry · release in the green truck zone · THROW light items · the piano needs two\nG passes the ghost role · ghost keys: Q possess · F action · Z shake · X slime\n%s" % [Loot.rupees(arena.truck.banked_value), connection_text]
	# Until match flow exists, one active mover counts as the lone mover of a 2-player match.
	Loot.lone_mover = _active_mover_count() <= 1
	_update_ghost_panel()
	hud_elapsed += delta
	if hud_elapsed >= 1.0 / Balance.HUD_RATE:
		hud_elapsed = fmod(hud_elapsed, 1.0 / Balance.HUD_RATE)
		_send_hud()


func _build_connection_text() -> void:
	if Net.listen_error != OK:
		connection_text = "PORT %d BUSY — close the other game instance, then restart." % Balance.SOCKET_PORT
	else:
		var addresses: PackedStringArray = []
		for address: String in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
				addresses.append("http://%s:%d" % [address, Balance.WEB_PORT])
		connection_text = "Phones: " + " · ".join(addresses)


func _send_hud() -> void:
	for mover: CharacterBody3D in movers:
		var player := Net.player_for_slot(mover.slot)
		if player.is_empty():
			continue
		if is_ghost_slot(mover.slot):
			Net.send_to_player(player, ghost.hud())
			continue
		var item: Carryable = mover.held_item
		var has_item: bool = is_instance_valid(item) and not item.finished
		var value: Variant = null # Items without a price, like the flashlight, show their name only.
		if has_item and item is Loot:
			value = item.value
		Net.send_to_player(player, {"type": "hud", "held": item.item_name if has_item else "", "value": value, "t": 0})


func _update_ghost_panel() -> void:
	# Everyone sees the ghost's energy: it is a tell.
	ghost_panel.visible = is_instance_valid(ghost)
	if ghost_panel.visible:
		ghost_bar.value = ghost.energy
		ghost_label.text = "GHOST ENERGY %d" % floori(ghost.energy)


# --- Roles ---
func _unhandled_input(event: InputEvent) -> void:
	# Host key G passes the ghost role along until Phase 5's role rotation exists.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		cycle_ghost()


func cycle_ghost() -> void:
	# The next active slot after the current ghost; after the last one, back to no ghost.
	var current: int = ghost.slot if is_instance_valid(ghost) else -1
	var next_slot: int = -1
	for slot: int in _active_slots():
		if slot > current:
			next_slot = slot
			break
	set_ghost_slot(next_slot)


func set_ghost_slot(slot: int) -> void:
	if is_instance_valid(ghost):
		var old_slot: int = ghost.slot
		remove_child(ghost) # Hands back any possessed prop straight away.
		ghost.queue_free()
		ghost = null
		var mover: CharacterBody3D = movers[old_slot]
		mover.position = _spawn_point(old_slot)
		mover.set_in_play(true)
		Net.set_role(old_slot, "mover", arena.ARENA_NAME)
	if slot < 0:
		print("No ghost")
		return
	movers[slot].set_in_play(false)
	ghost = GHOST_SCENE.instantiate()
	ghost.slot = slot
	ghost.signature_haunting = arena.SIGNATURE_HAUNTING
	ghost.position = arena.ghost_spawn()
	add_child(ghost)
	Net.set_role(slot, "ghost", arena.ARENA_NAME)
	print("Player %d is the ghost" % (slot + 1))


func is_ghost_slot(slot: int) -> bool:
	return is_instance_valid(ghost) and ghost.slot == slot


func _active_slots() -> Array[int]:
	# Slots driven by a connected phone, plus the keyboard's slot when no phone has it.
	var slots: Array[int] = []
	for slot: int in range(Balance.MAX_PLAYERS):
		var player := Net.player_for_slot(slot)
		var phone_connected: bool = not player.is_empty() and player.socket != null
		if phone_connected or slot == InputRouter.selected_slot:
			slots.append(slot)
	return slots


func _active_mover_count() -> int:
	# The ghost's slot is not a mover: a 2-player match is one mover against the ghost.
	var count: int = 0
	for slot: int in _active_slots():
		if not is_ghost_slot(slot):
			count += 1
	return count


func _start_ready_controllers() -> void:
	# This harness gives ready phones mover controls; real roles belong to Game in Phase 5.
	for player: Dictionary in Net.players:
		if player.ready and player.role.is_empty():
			Net.set_role(player.slot, "mover", arena.ARENA_NAME)


# --- Scene helpers ---
func _spawn_point(slot: int) -> Vector3:
	return Vector3((slot - (Balance.MAX_PLAYERS - 1) / 2.0) * Balance.SPAWN_SPACING, Balance.CAPSULE_HEIGHT / 2.0, Balance.MOVER_SPAWN_Z)


func _build_camera() -> void:
	add_child(CAMERA_SCENE.instantiate())
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

	# Top right: the ghost's energy bar, shown while someone is the ghost.
	canvas.add_child(ghost_panel)
	var rows := VBoxContainer.new()
	ghost_panel.add_child(rows)
	ghost_label.add_theme_font_size_override("font_size", Balance.HUD_FONT_SIZE)
	rows.add_child(ghost_label)
	ghost_bar.max_value = Balance.ENERGY_MAX
	ghost_bar.show_percentage = false
	ghost_bar.custom_minimum_size = Vector2(Balance.GHOST_PANEL_WIDTH, Balance.HUD_FONT_SIZE)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Balance.POSSESS_COLOUR
	ghost_bar.add_theme_stylebox_override("fill", fill)
	rows.add_child(ghost_bar)
	ghost_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ghost_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, int(Balance.OVERLAY_MARGIN))
	ghost_panel.hide()
