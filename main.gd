# Runs the match world: Game drives the phases and calls setup_match_round() for each seeded round.
# With match_mode off it is the Phase 4 greybox harness (G passes the ghost), kept for the physics checks.
extends Node3D

@export var match_mode: bool = true
var arena_scene: PackedScene # A check may choose the arena; otherwise matches use the Mansion and the harness the greybox.

# --- Resources and display state ---
const MOVER_SCENE := preload("res://actors/Mover.tscn")
const GHOST_SCENE := preload("res://actors/GhostWisp.tscn")
const CAMERA_SCENE := preload("res://actors/PartyCamera.tscn")
const MANSION_SCENE := preload("res://arenas/Mansion.tscn")
const GREYBOX_SCENE := preload("res://arenas/Greybox.tscn")
const WINDOW_KEYS := preload("res://core/window_keys.gd")
const WIPE_PHASES: Array[String] = ["lobby", "intro", "reveal", "result", "final"]
const SCREEN_SCENES: Array[PackedScene] = [
	preload("res://screens/HUD.tscn"), preload("res://screens/Lobby.tscn"), preload("res://screens/RoleReveal.tscn"),
	preload("res://screens/RoundEnd.tscn"), preload("res://screens/Results.tscn"),
	preload("res://screens/Cutscene.tscn"),
]
var camera: Camera3D
var status_label: Label # Harness overlay only; the match uses the screens instead.
var ghost_panel: PanelContainer
var ghost_label: Label
var ghost_bar: ProgressBar
var arena: Node3D
var movers: Array[CharacterBody3D] = []
var ghost: Node3D
var connection_text: String = ""
var hud_elapsed: float = 0.0
var shown_phase: String = "lobby" # The match phase on screen, so the wipe plays once per change.

# --- Setup ---
func _ready() -> void:
	arena = _arena_scene().instantiate()
	add_child(arena)
	_build_camera()
	_build_overlay()
	for slot: int in range(Balance.MAX_PLAYERS):
		var mover := MOVER_SCENE.instantiate()
		mover.slot = slot
		mover.position = _spawn_point(slot)
		add_child(mover)
		movers.append(mover)
	_apply_arena_bounds()
	Net.players_changed.connect(_start_ready_controllers)
	_build_connection_text()
	_start_ready_controllers()
	add_child(WINDOW_KEYS.new())
	if match_mode:
		# The shared screen plays fullscreen; F11 gives the window back.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_build_match_screens()
		Game.attach(self)
		print("Match lobby ready: phones join, tap Ready, then press Enter to start.")
	else:
		print("Phase 4: ghost greybox ready. Press G to pass the ghost role; the piano needs two movers.")


# --- Test feedback ---
func _process(delta: float) -> void:
	if not match_mode:
		_update_harness_overlay()
	# A 2-player match is one mover against the ghost; in the harness, count the active movers.
	Loot.lone_mover = Game.participants.size() == 2 if match_mode else _active_mover_count() <= 1
	hud_elapsed += delta
	if hud_elapsed >= 1.0 / Balance.HUD_RATE:
		hud_elapsed = fmod(hud_elapsed, 1.0 / Balance.HUD_RATE)
		_send_hud()


func _update_harness_overlay() -> void:
	status_label.text = "GHOSTED MOVERS · BANKED %s\nHold GRAB to carry · release in the green truck zone · THROW light items · the piano needs two\nG passes the ghost role · ghost keys: Q possess · F action · Z shake · X slime\n%s" % [Loot.rupees(arena.truck.banked_value), connection_text]
	_update_ghost_panel()


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
	var generator: Node = arena.get("generator")
	var task: Dictionary = {}
	if is_instance_valid(generator):
		task = {"delivered": generator.delivered, "total": Balance.BATTERY_COUNT, "powered": generator.powered}
	for mover: CharacterBody3D in movers:
		var player := Net.player_for_slot(mover.slot)
		if player.is_empty():
			continue
		if is_ghost_slot(mover.slot):
			var message: Dictionary = ghost.hud()
			message.generator = task
			Net.send_to_player(player, message)
			continue
		# A carried item that just shattered is already freed; check before taking a typed reference.
		var has_item: bool = is_instance_valid(mover.held_item) and not mover.held_item.finished
		var item: Carryable = mover.held_item if has_item else null
		var value: Variant = null # Items without a price show their name only.
		if has_item and item is Loot:
			value = item.value
		var cursed: float = item.curse_left if has_item and item is Loot else 0.0
		Net.send_to_player(player, {"type": "hud", "held": item.item_name if has_item else "", "value": value, "cursed": ceili(cursed), "t": ceili(Game.seconds_left) if match_mode else 0, "generator": task})


func _update_ghost_panel() -> void:
	# Everyone sees the ghost's energy: it is a tell.
	ghost_panel.visible = is_instance_valid(ghost)
	if ghost_panel.visible:
		ghost_bar.value = ghost.energy
		ghost_label.text = "GHOST ENERGY %d" % floori(ghost.energy)


# --- Roles ---
func _unhandled_input(event: InputEvent) -> void:
	if match_mode:
		return # The match screens own the host keys.
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
	ghost.demo_rules = match_mode
	ghost.mover_count = maxi(1, Game.participants.size() - 1)
	ghost.slot = slot
	ghost.signature_haunting = arena.SIGNATURE_HAUNTING
	ghost.avatar_script = arena.GHOST_AVATAR
	ghost.arena = arena
	ghost.position = arena.ghost_spawn()
	ghost.bounds = arena.ghost_bounds()
	add_child(ghost)
	Net.set_role(slot, "ghost", arena.ARENA_NAME)
	print("Player %d is the ghost" % (slot + 1))


# --- Match rounds, called by Game ---
func setup_match_round(round_seed: int, participants: Array[int], ghost_slot: int) -> void:
	# A fresh seeded arena, every mover back at its spawn, and the ghost at the arena's ghost spawn.
	_remove_ghost()
	for mover: CharacterBody3D in movers:
		mover.reset_for_round(_spawn_point(mover.slot), mover.slot in participants and mover.slot != ghost_slot)
	remove_child(arena)
	arena.free() # Freed now, so Game counts only the new round's loot.
	arena = _arena_scene().instantiate()
	arena.demo_mode = true
	arena.player_count = participants.size()
	arena.spawn_seed = round_seed
	add_child(arena)
	_apply_arena_bounds()
	for mover: CharacterBody3D in movers:
		mover.position = _spawn_point(mover.slot)
	Loot.lone_mover = participants.size() == 2

	ghost = GHOST_SCENE.instantiate()
	ghost.demo_rules = true
	ghost.mover_count = participants.size() - 1
	ghost.slot = ghost_slot
	ghost.signature_haunting = arena.SIGNATURE_HAUNTING
	ghost.avatar_script = arena.GHOST_AVATAR
	ghost.arena = arena
	ghost.position = arena.ghost_spawn()
	ghost.bounds = arena.ghost_bounds()
	add_child(ghost)
	for slot: int in participants:
		Net.set_role(slot, "ghost" if slot == ghost_slot else "mover", arena.ARENA_NAME)
	camera.snap()
	print("Round set up: seed %d, ghost is player %d" % [round_seed, ghost_slot + 1])


func reset_for_lobby() -> void:
	# Between matches: no ghost and no movers on the board; players appear when a round starts.
	_remove_ghost()
	for mover: CharacterBody3D in movers:
		mover.reset_for_round(_spawn_point(mover.slot), false)
	camera.snap()


func _remove_ghost() -> void:
	if is_instance_valid(ghost):
		remove_child(ghost) # Hands back any possessed prop straight away.
		ghost.free()
	ghost = null


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
	if match_mode:
		return
	# This harness gives ready phones mover controls; real roles belong to Game in Phase 5.
	for player: Dictionary in Net.players:
		if player.ready and player.role.is_empty():
			Net.set_role(player.slot, "mover", arena.ARENA_NAME)


# --- Scene helpers ---
func _spawn_point(slot: int) -> Vector3:
	return arena.mover_spawn(slot)


func _arena_scene() -> PackedScene:
	if arena_scene != null:
		return arena_scene
	return load(Game.selected_arena) if match_mode else GREYBOX_SCENE


func _apply_arena_bounds() -> void:
	# The camera, movers and ghost stay within the current arena's limits.
	camera.bounds = arena.camera_bounds()
	camera.arena_yaw = Balance.SHIP_CAMERA_YAW if arena.ARENA_NAME == "Ghost Ship" else Balance.CAMERA_YAW
	camera.limit_overview = arena.ARENA_NAME == "Ghost Ship"
	for mover: CharacterBody3D in movers:
		mover.bounds = arena.mover_bounds()
	if is_instance_valid(ghost):
		ghost.bounds = arena.ghost_bounds()


func _build_camera() -> void:
	camera = CAMERA_SCENE.instantiate()
	camera.follow_movers = match_mode
	add_child(camera)
	if arena.has_node("WorldEnvironment") or arena.find_child("WorldEnvironment", true, false) != null:
		return # The arena brings its own lighting and mood.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Balance.LIGHT_ROTATION
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("162a2b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.glow_enabled = true # Bloom on the ghost's glow, as the art direction asks.
	add_child(environment)


func _build_match_screens() -> void:
	_build_light_grade()
	# The screens keep running while the world is paused between rounds.
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	for scene: PackedScene in SCREEN_SCENES:
		canvas.add_child(scene.instantiate())
	Game.changed.connect(_wipe_on_new_screen)


func _build_light_grade() -> void:
	# STYLE.md's code light grade: a vignette into the night colour and a warm wash at the centre, over the 3D
	# world but under every screen (the screens' layer is 1).
	var grade := CanvasLayer.new()
	grade.layer = 0
	add_child(grade)
	for warm: bool in [false, true]:
		var cover := ColorRect.new()
		cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shade := ShaderMaterial.new()
		shade.shader = preload("res://assets/shaders/light_grade.gdshader")
		shade.set_shader_parameter("warm", warm)
		shade.set_shader_parameter("colour", Balance.GRADE_WARM if warm else Balance.UI_NIGHT)
		shade.set_shader_parameter("strength", Balance.GRADE_WARM_STRENGTH if warm else Balance.GRADE_VIGNETTE)
		shade.set_shader_parameter("inner", Balance.GRADE_VIGNETTE_INNER)
		shade.set_shader_parameter("centre", Balance.GRADE_CENTRE)
		cover.material = shade
		grade.add_child(cover)


func _wipe_on_new_screen() -> void:
	# A wipe across the screen whenever the match moves to a new full screen (not into live play).
	if Game.phase != shown_phase and Game.phase in WIPE_PHASES:
		UiMotion.flash()
	shown_phase = Game.phase


func _build_overlay() -> void:
	if match_mode:
		return
	status_label = Label.new()
	ghost_panel = PanelContainer.new()
	ghost_label = Label.new()
	ghost_bar = ProgressBar.new()
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
