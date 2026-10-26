# Runs real Jolt physics with two simulated phones, a mover and the ghost: the wisp, possession rules, all five prop
# actions, energy, exorcism, House Shake, Ecto Slime, the ghost's phone screen and its keyboard keys.
# This script compiles before the autoloads exist, so props and the ghost are loaded at runtime and never named by class.
extends SceneTree

# --- Test settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const SCRIPTS: Array[String] = [
	"res://props/carryable.gd", "res://props/loot.gd", "res://props/Possessable.gd",
	"res://props/furniture.gd", "res://props/door.gd", "res://props/chandelier.gd", "res://props/rug.gd",
	"res://actors/ghost_wisp.gd", "res://actors/party_camera.gd", "res://hauntings/Haunting.gd",
	"res://hauntings/HouseShake.gd", "res://hauntings/EctoSlime.gd",
]
const VASE_KIND: int = 0
const PIANO_KIND: int = 3
const SLIDER: int = 0 # Possessable kinds.
const DOOR: int = 1
const DROPPER: int = 2
const HOPPER: int = 3
const RUG: int = 4
const DOOR_OPEN: int = 0 # Door states.
const DOOR_LOCKED: int = 2
const CREAKING: int = 1 # Chandelier states.
const FALLING: int = 2
const DOWN: int = 3
const IDLE: int = 0 # Haunting phases.
const WARNING: int = 1
const RUNNING: int = 2
const MOVER_PHONE: int = 0 # Phone 0 drives mover 1; phone 1 is the ghost.
const GHOST_PHONE: int = 1
const SETTLE_SECONDS: float = 0.6
const INPUT_SECONDS: float = 0.12
const MOVER_HEIGHT: float = 0.8 # Mover centre above the floor, metres.
const SPEED_TOLERANCE: float = 0.35 # Metres per second.
const ENERGY_TOLERANCE: float = 1.5
const DOORWAY_TIMEOUT: float = 8.0 # Seconds allowed to steer a mover or the piano through the parlour door.
const DOOR_STEER_GAIN: float = 2.0 # Stick per metre of offset from the door's centre line.
const DROP_TIMEOUT: float = 3.0 # Seconds allowed for the creak and physical landing.

# --- Test state ---
var loot_scene: PackedScene
var chandelier_scene: PackedScene
var playground: Node3D
var ghost: Node3D
var mover_a: CharacterBody3D
var mover_b: CharacterBody3D
var mover_c: CharacterBody3D
var mover_d: CharacterBody3D
var crate_p: Node3D # The arena's Possessable components, one per furniture type.
var door_p: Node3D
var chandelier_p: Node3D
var armour_p: Node3D
var rug_p: Node3D
var router: Node
var net: Node
var failures: int = 0
var clients: Array[WebSocketPeer] = []
var inboxes: Array[Array] = []
var sticks: Array[Vector2] = []
var next_heartbeat: int = 0
var ghost_actions: Dictionary = {} # Every ACTION label the ghost's phone has been shown.
var ghost_huds: int = 0
var ghost_hud_complete: bool = true

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting ghost_check.gd")
		quit(1)
		return

	# Stop early if any script cannot load; otherwise every check below would compare empty values.
	var scripts_loaded: bool = true
	for path: String in SCRIPTS:
		var script: Script = load(path)
		scripts_loaded = scripts_loaded and script != null and script.can_instantiate()
	_check(scripts_loaded, "Ghost, possessable, furniture and haunting scripts compile")
	if not scripts_loaded:
		quit(1)
		return
	loot_scene = load("res://props/Loot.tscn")
	chandelier_scene = load("res://props/furniture/Chandelier.tscn")

	playground = load("res://Main.tscn").instantiate()
	playground.match_mode = false # The greybox harness, not the match flow.
	root.add_child(playground)
	await _wait(INPUT_SECONDS)
	_check_greybox_contents()
	for player_name: String in ["Mover", "Ghost"]:
		await _connect_phone(player_name)
	_check(_welcome_slot(MOVER_PHONE) == 0 and _welcome_slot(GHOST_PHONE) == 1, "Two phones control slots 1 and 2")
	net.accept_new_players = false # Real phones left open on the network must not join the test.
	router.selected_slot = 0 # The keyboard shares phone 1's slot, so it never drives another player.
	mover_a = playground.movers[0]
	mover_b = playground.movers[1]
	mover_c = playground.movers[2]
	mover_d = playground.movers[3]
	_park(mover_c)
	_park(mover_d)

	await _check_doorway_with_door()
	await _check_ghost_role()
	await _check_wisp()
	await _check_energy()
	await _check_possession_rules()
	await _check_slider()
	await _check_door()
	await _check_dropper()
	await _check_hopper()
	await _check_rug()
	await _check_exorcism()
	await _check_house_shake()
	await _check_slime()
	await _check_hud()
	await _check_keyboard()
	for client: WebSocketPeer in clients:
		client.close()
	await _wait(INPUT_SECONDS)
	print("GHOST CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _check_greybox_contents() -> void:
	var kinds: Array = []
	var loot_sliders: int = 0
	for node: Node in get_nodes_in_group("possessables"):
		var prop: Node = node.get_parent()
		if prop.is_in_group("furniture"):
			kinds.append(node.kind)
			match node.kind:
				SLIDER: crate_p = node
				DOOR: door_p = node
				DROPPER: chandelier_p = node
				HOPPER: armour_p = node
				RUG: rug_p = node
		elif prop.is_in_group("loot") and node.kind == SLIDER:
			loot_sliders += 1
	kinds.sort()
	_check(kinds == [SLIDER, DOOR, DROPPER, HOPPER, RUG], "The greybox has one possessable prop of each type (%s)" % str(kinds))
	_check(loot_sliders > 0 and loot_sliders == get_nodes_in_group("loot").size(), "Every loot item, the piano included, is a possessable slider (%d)" % loot_sliders)
	var carryable_furniture: int = 0
	for prop: Node in get_nodes_in_group("furniture"):
		if prop.is_in_group("carryables") or prop.is_in_group("loot"):
			carryable_furniture += 1
	_check(carryable_furniture == 0, "Furniture has no value and cannot be carried")


# --- The open door and the piano route ---
func _check_doorway_with_door() -> void:
	# The Phase 3 piano route, now with the parlour door standing open beside it.
	var door: Node3D = door_p.prop
	_check(door.state == DOOR_OPEN and is_equal_approx(door.angle, SETTINGS.DOOR_OPEN_ANGLE), "The parlour door starts open")
	var piano := await _setup_piano(Vector2(0.0, -9.75))
	_check(piano.holder_count() == 2, "Both movers take a piano handle in the parlour")
	var start_value: int = piano.value
	_set_stick(0, Vector2(0.0, 1.0))
	_set_stick(1, Vector2(0.0, -1.0))
	await _wait(1.0)
	var elapsed: float = 0.0
	while elapsed < DOORWAY_TIMEOUT and piano.global_position.z < SETTINGS.PARLOUR_WALL_Z + SETTINGS.LOOT_SIZES[PIANO_KIND].x:
		for index: int in range(2):
			var handle: int = piano.handle_holders.find(mover_a if index == 0 else mover_b)
			var handle_x: float = piano.handle_position(handle).x
			_set_stick(index, Vector2(clampf(-handle_x * DOOR_STEER_GAIN, -1.0, 1.0), 1.0).limit_length())
		await _wait(INPUT_SECONDS)
		elapsed += INPUT_SECONDS
	var through: bool = piano.global_position.z > SETTINGS.PARLOUR_WALL_Z + SETTINGS.LOOT_SIZES[PIANO_KIND].x / 2.0
	_check(through and piano.holder_count() == 2, "Two movers still get the piano through the doorway past the open door (%.1f s)" % elapsed)
	_check(piano.value == start_value, "The open door costs the piano nothing (%s of %s)" % [piano.rupees(piano.value), piano.rupees(start_value)])
	await _stop_sticks()
	await _release_all()
	await _clear_carryables()


# --- Roles ---
func _check_ghost_role() -> void:
	_check(not _lone_mover(), "Two movers: the lone-mover rule is off")
	await _tap_key(KEY_G)
	_check(_ghost() != null and _ghost().slot == 0 and _role_of(MOVER_PHONE) == "ghost", "G makes the first active slot the ghost")
	await _tap_key(KEY_G)
	ghost = _ghost()
	_check(ghost != null and ghost.slot == 1, "G again passes the ghost to the next active slot")
	_check(_role_of(GHOST_PHONE) == "ghost" and _role_arena(GHOST_PHONE) == "Old Mansion" and _role_of(MOVER_PHONE) == "mover", "Phone 2 switches to the ghost screen; phone 1 is a mover again")
	var out_of_play: bool = not mover_b.visible and not mover_b.is_in_group("movers") and mover_b.collision_layer == 0
	_check(out_of_play and mover_a.in_play and mover_a.is_in_group("movers"), "The ghost's mover leaves play")
	_check(ghost != null and ghost.global_position.z < SETTINGS.PARLOUR_WALL_Z - 2.0 and is_equal_approx(ghost.energy, SETTINGS.ENERGY_MAX), "The wisp starts at the far end of the parlour with full energy")
	_check(_lone_mover(), "One mover plus the ghost: the lone-mover rule counts movers only")
	await _tap_key(KEY_G)
	var back: bool = mover_b.in_play and mover_b.visible and mover_b.is_in_group("movers") and mover_b.collision_layer == SETTINGS.MOVER_LAYER
	_check(_ghost() == null and back and not _lone_mover(), "G after the last active slot goes back to no ghost")
	playground.set_ghost_slot(1)
	await _wait(INPUT_SECONDS)
	ghost = _ghost()
	_check(ghost != null and ghost.slot == 1, "Phone 2 is the ghost for the rest of the check")


# --- The wisp ---
func _check_wisp() -> void:
	ghost.position = Vector3(3.0, SETTINGS.WISP_HEIGHT, -10.0)
	_set_stick(GHOST_PHONE, Vector2(0.0, 1.0))
	var run: Dictionary = await _measure_motion(ghost, 0.15, 0.5)
	_check(absf(run.speed - SETTINGS.WISP_SPEED) < SPEED_TOLERANCE, "The wisp flies at 7 m/s (%.2f m/s)" % run.speed)
	_check(ghost.global_position.z > SETTINGS.PARLOUR_WALL_Z + 1.0, "The wisp passes through the parlour wall")
	ghost.position = Vector3(6.0, SETTINGS.WISP_HEIGHT, -5.0)
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	await _wait(0.8)
	var x: float = ghost.global_position.x
	_check(x > SETTINGS.ROOM_WIDTH / 2.0 and x <= SETTINGS.GHOST_BOUNDS.end.x + 0.001, "The wisp passes through the side wall and stops at the bounds (x %.2f)" % x)
	_check(is_equal_approx(ghost.global_position.y, SETTINGS.WISP_HEIGHT), "The wisp flies 1.2 m up")
	_set_stick(GHOST_PHONE, Vector2.ZERO)

	# Faint: a shimmer between 25% and 45% opacity, and no shadow to give it away.
	var lowest: float = 1.0
	var highest: float = 0.0
	var deadline: int = Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < deadline:
		var alpha: float = ghost.material.albedo_color.a
		lowest = minf(lowest, alpha)
		highest = maxf(highest, alpha)
		await _frame()
	var in_range: bool = lowest >= SETTINGS.WISP_ALPHA_MIN - 0.01 and highest <= SETTINGS.WISP_ALPHA_MAX + 0.01
	_check(in_range and highest - lowest > 0.1, "The wisp shimmers between 25%% and 45%% opacity (%.2f–%.2f)" % [lowest, highest])
	_check(ghost.body_mesh.visible and ghost.body_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "The free wisp shows but casts no shadow")


func _check_energy() -> void:
	ghost.energy = 50.0
	var started: int = Time.get_ticks_msec()
	await _wait(1.0)
	var expected: float = 50.0 + SETTINGS.ENERGY_REGEN * (Time.get_ticks_msec() - started) / 1000.0
	_check(absf(ghost.energy - expected) < ENERGY_TOLERANCE, "A free wisp regains 12 energy per second (%.1f, expected %.1f)" % [ghost.energy, expected])
	ghost.energy = 99.0
	await _wait(0.5)
	_check(is_equal_approx(ghost.energy, SETTINGS.ENERGY_MAX), "Energy stops at 100")


# --- Possession rules ---
func _check_possession_rules() -> void:
	var crate: RigidBody3D = crate_p.prop
	_reset_body(crate, Vector3(-3.5, _furniture_height(0), 0.0))
	await _wait(SETTLE_SECONDS)

	# Out of reach, then within 0.6 m of the crate's footprint.
	_ghost_to(Vector3(-3.5, 0.0, 2.0))
	inboxes[GHOST_PHONE].clear()
	await _wait(0.3)
	_check(ghost.target == null and _ghost_ok("possess") == false, "1.5 m off: nothing to possess, and the phone greys POSSESS")
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == null, "POSSESS out of reach does nothing")
	_ghost_to(Vector3(-2.7, 0.0, 0.0))
	inboxes[GHOST_PHONE].clear()
	await _wait(0.3)
	_check(ghost.target == crate_p and crate_p.highlighted and _ghost_ok("possess") == true, "Within 0.6 m the crate is the wisp's target, outlined brightly")
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == crate_p and crate_p.is_possessed() and not ghost.body_mesh.visible, "POSSESS takes the crate and hides the wisp inside it")
	_check(crate_p.meshes[0].material_overlay == crate_p.glow, "The possessed crate glows")

	# Possessing drains 8 per second; leaving is free.
	ghost.energy = SETTINGS.ENERGY_MAX
	var started: int = Time.get_ticks_msec()
	await _wait(1.0)
	var expected: float = SETTINGS.ENERGY_MAX - SETTINGS.POSSESS_DRAIN * (Time.get_ticks_msec() - started) / 1000.0
	_check(absf(ghost.energy - expected) < ENERGY_TOLERANCE, "Possessing drains 8 energy per second (%.1f, expected %.1f)" % [ghost.energy, expected])
	var before: float = ghost.energy
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == null and not crate_p.is_possessed() and ghost.body_mesh.visible, "POSSESS again leaves the crate and shows the wisp")
	_check(ghost.energy > before - 1.0, "Leaving costs nothing")

	# Running out of energy pushes the ghost out, without a stun.
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == crate_p, "Setup: the ghost is back in the crate")
	ghost.energy = 1.0
	await _wait(0.4)
	_check(ghost.possessing == null and ghost.energy < 5.0 and not ghost.is_frozen() and ghost.lockout_left == 0.0, "Running out of energy pushes the ghost out, without a stun")
	ghost.energy = SETTINGS.ENERGY_MAX

	# A carried vase cannot be possessed.
	_place(mover_a, Vector3(-5.0, MOVER_HEIGHT, -4.0), Vector3.RIGHT)
	var vase := _spawn_loot(VASE_KIND, Vector3(-5.0 + SETTINGS.HOLD_DISTANCE, _rest_height(VASE_KIND), -4.0))
	var vase_p: Node3D = _possessable_of(vase)
	await _wait(SETTLE_SECONDS)
	_press(MOVER_PHONE, "grab", true)
	await _wait(SETTLE_SECONDS)
	_ghost_to(vase.global_position)
	await _wait(INPUT_SECONDS)
	var in_reach: bool = vase_p.reach_distance(ghost.global_position) < SETTINGS.POSSESS_RANGE
	_check(mover_a.held_item == vase and in_reach, "Setup: phone 1 carries a vase and the wisp is on it")
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == null and not vase_p.is_possessed(), "A carried item cannot be possessed")
	_press(MOVER_PHONE, "grab", false)
	await _wait(SETTLE_SECONDS)

	# A possessed vase cannot be grabbed until the ghost leaves.
	await _possess(vase_p)
	_place(mover_a, vase.global_position - Vector3(1.0, vase.global_position.y - MOVER_HEIGHT, 0.0), Vector3.RIGHT)
	_press(MOVER_PHONE, "grab", true)
	await _wait(SETTLE_SECONDS)
	_check(mover_a.held_item == null and not vase.is_held(), "A possessed item cannot be grabbed")
	_press(MOVER_PHONE, "grab", false)
	await _wait(INPUT_SECONDS)
	await _leave()
	_press(MOVER_PHONE, "grab", true)
	await _wait(SETTLE_SECONDS)
	_check(mover_a.held_item == vase, "Once the ghost leaves, the same vase can be grabbed")
	_press(MOVER_PHONE, "grab", false)
	await _wait(SETTLE_SECONDS)

	# Nothing inside the truck zone can be possessed.
	var truck: Area3D = playground.arena.truck
	var parked := _spawn_loot(VASE_KIND, Vector3(5.0, _rest_height(VASE_KIND), 5.0))
	await _wait(SETTLE_SECONDS)
	_ghost_to(parked.global_position)
	await _wait(INPUT_SECONDS)
	await _tap(GHOST_PHONE, "possess")
	_check(truck.contains_point(parked.global_position) and ghost.possessing == null, "Loot inside the truck zone cannot be possessed")

	# A possessed vase slid into the truck pushes the ghost out, and does not bank.
	var outside := _spawn_loot(VASE_KIND, Vector3(5.0, _rest_height(VASE_KIND), 2.6))
	await _wait(SETTLE_SECONDS)
	await _possess(_possessable_of(outside))
	var banked: int = truck.banked_items
	_set_stick(GHOST_PHONE, Vector2(0.0, 1.0))
	await _wait(1.0)
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	var reached: bool = is_instance_valid(outside) and truck.contains_point(outside.global_position)
	_check(reached and ghost.possessing == null and ghost.lockout_left == 0.0 and not ghost.is_frozen(), "Sliding a possessed vase into the truck pushes the ghost out, without a stun")
	_check(truck.banked_items == banked and reached and not outside.finished, "Loot the ghost slides into the truck does not bank")
	await _clear_carryables()


# --- Slider ---
func _check_slider() -> void:
	ghost.energy = SETTINGS.ENERGY_MAX
	var crate: RigidBody3D = crate_p.prop
	_reset_body(crate, Vector3(-3.5, _furniture_height(0), 0.0))
	await _wait(SETTLE_SECONDS)
	await _possess(crate_p)
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	var slide: Dictionary = await _measure_motion(crate, 0.4, 0.5)
	var crate_speed: float = SETTINGS.SLIDER_SPEED * SETTINGS.POSSESS_SPEED_FACTORS[SETTINGS.MEDIUM]
	_check(absf(slide.speed - crate_speed) < SPEED_TOLERANCE, "A possessed crate glides at its weight's slider speed (%.2f m/s, expected %.2f)" % [slide.speed, crate_speed])
	_check(_flat(ghost.global_position - crate_p.global_position).length() < 0.05, "The hidden wisp rides along inside the crate")
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	await _wait(SETTLE_SECONDS)
	_check(_flat(crate.linear_velocity).length() < 0.3 and crate.global_basis.y.dot(Vector3.UP) > 0.99, "Centring the stick stops the crate, upright")
	await _leave()

	# A light item glides at 2.4 m/s, and sliding into a wall breaks nothing.
	var vase := _spawn_loot(VASE_KIND, Vector3(4.5, _rest_height(VASE_KIND), -4.0))
	await _wait(SETTLE_SECONDS)
	await _possess(_possessable_of(vase))
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	var glide: Dictionary = await _measure_motion(vase, 0.25, 0.3)
	_check(absf(glide.speed - SETTINGS.SLIDER_SPEED) < SPEED_TOLERANCE, "A possessed vase glides at 2.4 m/s (%.2f m/s)" % glide.speed)
	await _wait(1.0)
	_check(vase.global_position.x > SETTINGS.ROOM_WIDTH / 2.0 - 0.6 and vase.value == vase.initial_value, "Gliding a possessed vase into a wall does no damage (%s)" % vase.rupees(vase.value))

	# SHOVE launches it into the wall.
	_set_stick(GHOST_PHONE, Vector2(-1.0, 0.0))
	await _wait(0.6)
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	var energy_before: float = ghost.energy
	_press(GHOST_PHONE, "action", true)
	var peak: float = await _peak_speed(vase, INPUT_SECONDS)
	var spent: float = energy_before - ghost.energy
	_press(GHOST_PHONE, "action", false)
	peak = maxf(peak, await _peak_speed(vase, 0.2))
	_check(absf(spent - SETTINGS.ACTION_COSTS[SLIDER]) < ENERGY_TOLERANCE, "SHOVE costs 15 energy (%.1f spent, drain included)" % spent)
	_check(absf(peak - SETTINGS.SHOVE_SPEED) < 0.6, "SHOVE launches a light item at 6 m/s (peak %.2f m/s)" % peak)
	await _wait(SETTLE_SECONDS)
	_check(_value_of(vase) < SETTINGS.LOOT_VALUES[VASE_KIND], "A shoved vase smashes into the wall (₹%d left)" % _value_of(vase))
	await _leave()
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	await _clear_carryables()

	# A shoved crate knocks over the mover it hits.
	_reset_body(crate, Vector3(-3.5, _furniture_height(0), 0.0))
	_place(mover_c, Vector3(-1.2, MOVER_HEIGHT, 0.0), Vector3.LEFT)
	await _wait(SETTLE_SECONDS)
	await _possess(crate_p)
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	await _tap(GHOST_PHONE, "action")
	await _wait(0.4)
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	_check(crate.global_position.x > -2.6 and mover_c.is_tumbling(), "A shoved crate knocks over the mover it hits")
	await _leave()
	await _wait(SETTINGS.TUMBLE_DURATION + SETTINGS.TUMBLE_FALL_TIME)

	# Gliding into a mover only pushes against them.
	_reset_body(crate, Vector3(-3.5, _furniture_height(0), 0.0))
	_place(mover_c, Vector3(-1.5, MOVER_HEIGHT, 0.0), Vector3.LEFT)
	await _wait(SETTLE_SECONDS)
	await _possess(crate_p)
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	await _wait(1.5)
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	var pressed_up: bool = absf(mover_c.global_position.x - crate.global_position.x) < 1.05
	_check(pressed_up and not mover_c.is_tumbling(), "A possessed crate gliding into a mover pushes against them, no tumble")

	# Walking into a still possessed crate trips nobody.
	_reset_body(crate, Vector3(-3.5, _furniture_height(0), 0.0))
	_park(mover_c)
	_place(mover_a, Vector3(-6.0, MOVER_HEIGHT, 0.0), Vector3.RIGHT)
	_set_stick(MOVER_PHONE, Vector2(1.0, 0.0))
	await _wait(1.0)
	_set_stick(MOVER_PHONE, Vector2.ZERO)
	_check(mover_a.global_position.x > -4.6 and not mover_a.is_tumbling(), "Walking into a still possessed crate trips nobody")

	# Too little energy: SHOVE is refused and costs nothing.
	ghost.energy = 10.0
	await _tap(GHOST_PHONE, "action")
	_check(_flat(crate.linear_velocity).length() < 0.5 and ghost.energy <= 10.0 and ghost.energy > 6.0, "SHOVE with too little energy is refused and costs nothing")
	ghost.energy = SETTINGS.ENERGY_MAX
	await _leave()


# --- Door ---
func _check_door() -> void:
	var door: Node3D = door_p.prop
	ghost.energy = SETTINGS.ENERGY_MAX
	_place(mover_a, Vector3(0.0, MOVER_HEIGHT, -6.5), Vector3.FORWARD)
	_set_stick(MOVER_PHONE, Vector2(0.0, -1.0))
	await _wait(0.8)
	_check(mover_a.global_position.z < SETTINGS.PARLOUR_WALL_Z - 0.5, "Movers walk through the open parlour door")
	_set_stick(MOVER_PHONE, Vector2.ZERO)

	# SLAM shuts it within 0.3 s and holds it for 3 s.
	_place(mover_a, Vector3(0.0, MOVER_HEIGHT, -5.0), Vector3.FORWARD)
	await _possess(door_p)
	var energy_before: float = ghost.energy
	_press(GHOST_PHONE, "action", true)
	await _wait(0.4)
	_press(GHOST_PHONE, "action", false)
	var spent: float = energy_before - ghost.energy
	_check(door.is_shut(), "SLAM shuts the door within 0.4 s")
	_check(absf(spent - SETTINGS.ACTION_COSTS[DOOR] - SETTINGS.POSSESS_DRAIN * 0.4) < ENERGY_TOLERANCE, "SLAM costs 20 energy (%.1f spent, drain included)" % spent)
	inboxes[GHOST_PHONE].clear()
	_set_stick(MOVER_PHONE, Vector2(0.0, -1.0))
	await _wait(1.4)
	var z: float = mover_a.global_position.z
	_check(door.is_shut() and z < -7.0 and z > SETTINGS.PARLOUR_WALL_Z + 0.3, "The shut door blocks a mover walking into it")
	_check(_ghost_ok("action") == false, "ACTION greys out while the door is shut")
	await _wait(SETTINGS.DOOR_LOCK_TIME + SETTINGS.DOOR_REOPEN_TIME - 1.8 + 0.6)
	_check(door.state == DOOR_OPEN, "After its 3 s lock the door swings open again, nudging the mover aside")
	# The swing pushes the mover outside the open panel. Walk around its free end before entering the doorway.
	var clear_z: float = SETTINGS.PARLOUR_WALL_Z + SETTINGS.PARLOUR_DOOR_WIDTH + SETTINGS.CAPSULE_RADIUS * 2.0
	var route: Array[Vector2] = [
		Vector2(mover_a.global_position.x, clear_z),
		Vector2(0.0, clear_z),
		Vector2(0.0, SETTINGS.PARLOUR_WALL_Z - SETTINGS.CAPSULE_RADIUS * 2.0),
	]
	var doorway_deadline: int = Time.get_ticks_msec() + int(DOORWAY_TIMEOUT * 1000.0)
	for waypoint: Vector2 in route:
		while Time.get_ticks_msec() < doorway_deadline:
			var offset: Vector2 = waypoint - Vector2(mover_a.global_position.x, mover_a.global_position.z)
			if offset.length() < SETTINGS.CAPSULE_RADIUS / 2.0:
				break
			_set_stick(MOVER_PHONE, (offset * DOOR_STEER_GAIN).limit_length())
			await _wait(INPUT_SECONDS)
	_check(mover_a.global_position.z < SETTINGS.PARLOUR_WALL_Z - 0.5, "Once it is open, the mover steers back through the doorway (position %s)" % mover_a.global_position)
	_set_stick(MOVER_PHONE, Vector2.ZERO)

	# A slam knocks over a mover in its swing.
	_place(mover_a, Vector3(-3.0, MOVER_HEIGHT, -4.0), Vector3.FORWARD)
	_place(mover_c, Vector3(0.2, MOVER_HEIGHT, -6.6), Vector3.FORWARD)
	await _wait(SETTLE_SECONDS)
	ghost.energy = SETTINGS.ENERGY_MAX
	await _tap(GHOST_PHONE, "action")
	await _wait(0.3)
	_check(mover_c.is_tumbling() and door.is_shut(), "A slam knocks over a mover in its swing and still shuts")
	await _wait(SETTINGS.DOOR_LOCK_TIME + SETTINGS.DOOR_REOPEN_TIME + 0.3)
	_check(door.state == DOOR_OPEN, "The door reopens after knocking someone over")
	_park(mover_c)

	# Loot in the swing stops the slam short and takes a hit.
	var vase := _spawn_loot(VASE_KIND, Vector3(0.0, _rest_height(VASE_KIND), -7.3))
	await _wait(SETTLE_SECONDS)
	ghost.energy = SETTINGS.ENERGY_MAX
	await _tap(GHOST_PHONE, "action")
	await _wait(0.3)
	_check(door.state == DOOR_LOCKED and door.angle > 10.0, "A vase in the swing stops the slam short (%.0f° open)" % door.angle)
	_check(_value_of(vase) < SETTINGS.LOOT_VALUES[VASE_KIND], "The vase in the way takes a hit (₹%d left)" % _value_of(vase))
	await _wait(SETTINGS.DOOR_LOCK_TIME + SETTINGS.DOOR_REOPEN_TIME + 0.3)
	_check(door.state == DOOR_OPEN, "The stopped door still reopens after its lock")
	await _clear_carryables()

	# Exorcising the possessed door ejects the ghost and locks it out.
	door_p.exorcise()
	_check(ghost.possessing == null and ghost.lockout_left > 0.0, "Exorcising the possessed door ejects the ghost")
	await _wait(SETTLE_SECONDS)


# --- Dropper ---
func _check_dropper() -> void:
	_reset_ghost()
	var chandelier: RigidBody3D = chandelier_p.prop
	var hang_height: float = chandelier.global_position.y
	_place(mover_c, Vector3(chandelier.global_position.x, MOVER_HEIGHT, chandelier.global_position.z), Vector3.FORWARD)
	await _possess(chandelier_p)
	var energy_before: float = ghost.energy
	await _tap(GHOST_PHONE, "action")
	var spent: float = energy_before - ghost.energy
	_check(absf(spent - SETTINGS.ACTION_COSTS[DROPPER] - SETTINGS.POSSESS_DRAIN * 2.0 * INPUT_SECONDS) < ENERGY_TOLERANCE, "DROP costs 30 energy (%.1f spent, drain included)" % spent)
	inboxes[GHOST_PHONE].clear()
	await _wait(0.6)
	var hanging: bool = chandelier.freeze and is_equal_approx(chandelier.global_position.y, hang_height)
	_check(hanging and chandelier.marker.visible and not mover_c.is_tumbling(), "DROP creaks first: after 0.8 s it still hangs, with a marker on the floor below")
	_check(_ghost_ok("action") == false, "ACTION greys out once the chandelier is creaking")
	await _wait(0.9)
	_check(chandelier.global_position.y < hang_height - 1.0 and mover_c.is_tumbling(), "The chandelier falls and knocks over the mover beneath")
	await _wait(1.0)
	_check(chandelier.state == DOWN and ghost.possessing == null and not ghost.is_frozen() and ghost.lockout_left == 0.0, "After it lands the ghost pops out, without a stun")
	_check(not chandelier_p.can_be_possessed() and not chandelier.marker.visible, "A dropped chandelier cannot be possessed again")
	_ghost_to(chandelier.global_position)
	await _wait(INPUT_SECONDS)
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == null, "POSSESS on the fallen chandelier is refused")
	_park(mover_c)

	# Committed once pressed: leaving during the creak does not stop the fall, and it still trips a mover.
	var spare := _spawn_chandelier(Vector3(-4.0, hang_height, -5.5))
	_place(mover_d, Vector3(-4.0, MOVER_HEIGHT, -5.5), Vector3.FORWARD)
	await _wait(INPUT_SECONDS)
	await _possess(_possessable_of(spare))
	await _tap(GHOST_PHONE, "action")
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == null and spare.state == CREAKING, "The ghost can leave a creaking chandelier")
	await _wait(1.4)
	_check(spare.global_position.y < hang_height - 1.0 and mover_d.is_tumbling(), "It still falls once the ghost has left, and still knocks over the mover beneath")
	_park(mover_d)

	# Exorcised during the creak, it still falls and smashes the vase below.
	_reset_ghost()
	var second := _spawn_chandelier(Vector3(-4.0, hang_height, -2.0))
	var vase := _spawn_loot(VASE_KIND, Vector3(-4.0, _rest_height(VASE_KIND), -2.0))
	await _wait(SETTLE_SECONDS)
	var second_p: Node3D = _possessable_of(second)
	await _possess(second_p, Vector3(-0.5, 0.0, 0.0)) # Off the vase's footprint, still under the chandelier.
	await _tap(GHOST_PHONE, "action")
	second_p.exorcise()
	_check(ghost.possessing == null and ghost.is_frozen() and second.state == CREAKING, "Exorcised during the creak, the ghost is ejected")
	# Check the physical landing, not a fixed delay that can expire just before contact with the vase.
	var drop_deadline: int = Time.get_ticks_msec() + int(DROP_TIMEOUT * 1000.0)
	while second.state != DOWN and Time.get_ticks_msec() < drop_deadline:
		await _frame()
	_check(second.state == DOWN and second.global_position.y < hang_height - 1.0 and _value_of(vase) < SETTINGS.LOOT_VALUES[VASE_KIND], "The chandelier still lands and damages the vase beneath (₹%d left)" % _value_of(vase))
	await _clear_carryables()


# --- Hopper ---
func _check_hopper() -> void:
	_reset_ghost()
	var armour: RigidBody3D = armour_p.prop
	_reset_body(armour, Vector3(3.0, _furniture_height(1), -6.8))
	await _wait(SETTLE_SECONDS)
	await _possess(armour_p)
	var start: Vector3 = armour.global_position
	var highest: float = start.y
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	var deadline: int = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		highest = maxf(highest, armour.global_position.y)
		await _frame()
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	await _wait(SETTLE_SECONDS)
	var moved: float = armour.global_position.x - start.x
	_check(moved > 1.5 and highest > start.y + 0.3, "The stick hops the armour along (%.1f m, %.2f m up)" % [moved, highest - start.y])
	_check(armour.global_basis.y.dot(Vector3.UP) > 0.95, "The possessed armour stays upright")

	# STOMP tumbles everyone within 2 m, braced or not.
	var at: Vector3 = armour.global_position
	_place(mover_a, Vector3(at.x, MOVER_HEIGHT, at.z + 1.5), Vector3.FORWARD)
	_place(mover_c, Vector3(at.x - 2.6, MOVER_HEIGHT, at.z), Vector3.RIGHT)
	_press(MOVER_PHONE, "brace", true)
	await _wait(SETTLE_SECONDS)
	var energy_before: float = ghost.energy
	await _tap(GHOST_PHONE, "action")
	var spent: float = energy_before - ghost.energy
	_check(absf(spent - SETTINGS.ACTION_COSTS[HOPPER] - SETTINGS.POSSESS_DRAIN * 2.0 * INPUT_SECONDS) < ENERGY_TOLERANCE, "STOMP costs 25 energy (%.1f spent, drain included)" % spent)
	_check(mover_a.is_tumbling() and mover_a.is_bracing(), "STOMP tumbles a braced mover 1.5 m away")
	_check(not mover_c.is_tumbling(), "STOMP spares a mover 2.6 m away")
	_press(MOVER_PHONE, "brace", false)
	await _leave()
	_park(mover_c)
	await _wait(SETTINGS.TUMBLE_DURATION + SETTINGS.TUMBLE_FALL_TIME)


# --- Rug ---
func _check_rug() -> void:
	_reset_ghost()
	var crate: RigidBody3D = crate_p.prop
	_reset_body(crate, Vector3(-3.5, _furniture_height(0), 0.0))
	var vase := _spawn_loot(VASE_KIND, Vector3(0.8, _rest_height(VASE_KIND), 0.9))
	_place(mover_a, Vector3(-0.6, MOVER_HEIGHT, 0.5), Vector3.FORWARD)
	_place(mover_c, Vector3(-2.6, MOVER_HEIGHT, 1.3), Vector3.FORWARD)
	await _wait(SETTLE_SECONDS)
	await _possess(rug_p)
	var vase_start: Vector3 = vase.global_position
	var energy_before: float = ghost.energy
	await _tap(GHOST_PHONE, "action")
	var spent: float = energy_before - ghost.energy
	_check(absf(spent - SETTINGS.ACTION_COSTS[RUG] - SETTINGS.POSSESS_DRAIN * 2.0 * INPUT_SECONDS) < ENERGY_TOLERANCE, "YANK costs 25 energy (%.1f spent, drain included)" % spent)
	_check(mover_a.is_tumbling() and not mover_c.is_tumbling(), "YANK tumbles the mover on the rug, not the one beside it")
	inboxes[GHOST_PHONE].clear()
	await _wait(0.3)
	var shift: Vector3 = vase.global_position - vase_start
	_check(shift.z < -0.3 and absf(shift.x) < 0.2, "Loose loot on the rug slides off along the yank (%.2f m)" % -shift.z)
	_check(_ghost_ok("action") == false, "ACTION greys out while the rug settles")
	await _wait(1.0)
	_check(rug_p.can_act(), "Once settled, the rug can be yanked again")
	await _leave()
	_park(mover_c)
	await _clear_carryables()
	await _wait(SETTINGS.TUMBLE_DURATION)


# --- Exorcism ---
func _check_exorcism() -> void:
	_reset_ghost()
	var crate: RigidBody3D = crate_p.prop
	_reset_body(crate, Vector3(-2.0, _furniture_height(0), 0.0))
	await _wait(SETTLE_SECONDS)
	await _possess(crate_p)
	crate_p.exorcise()
	_check(ghost.possessing == null and not crate_p.is_possessed() and ghost.body_mesh.visible, "Exorcism ejects the ghost from the crate")
	var ejected_at: Vector3 = ghost.global_position
	_check(_flat(ejected_at - crate_p.global_position).length() < 0.1, "The ejected wisp appears where the crate is")

	# Frozen for 1 s: no movement and no buttons.
	var slime: Node = ghost.hauntings[1]
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	var energy_before: float = ghost.energy
	await _tap(GHOST_PHONE, "haunt2")
	var still: bool = _flat(ghost.global_position - ejected_at).length() < 0.05
	_check(ghost.is_frozen() and still and not slime.is_active() and ghost.energy >= energy_before, "While frozen the wisp ignores the stick and its buttons")
	await _wait(ghost.freeze_left + 0.3)
	_check(not ghost.is_frozen() and _flat(ghost.global_position - ejected_at).length() > 0.5, "After 1 s the wisp moves again")
	_set_stick(GHOST_PHONE, Vector2.ZERO)

	# No possessing for 5 s.
	_ghost_to(crate_p.global_position)
	inboxes[GHOST_PHONE].clear()
	await _wait(0.3)
	await _tap(GHOST_PHONE, "possess")
	var hud: Dictionary = _latest_ghost_hud()
	_check(ghost.possessing == null and ghost.lockout_left > 0.0, "POSSESS is refused for 5 s after an exorcism")
	_check(hud.get("ok", {}).get("possess") == false and float(hud.get("cd", {}).get("possess", 0.0)) > 0.0, "The phone greys POSSESS and shows the lock's ring")
	await _wait(ghost.lockout_left + 0.2)
	await _tap(GHOST_PHONE, "possess")
	_check(ghost.possessing == crate_p, "After 5 s the ghost can possess again")
	await _leave()
	await _clear_carryables()


# --- House Shake ---
func _check_house_shake() -> void:
	_reset_ghost()
	var shake: Node = ghost.hauntings[0]
	var camera: Camera3D = get_first_node_in_group("party_camera")
	_place(mover_a, Vector3(-6.0, MOVER_HEIGHT, -4.0), Vector3.LEFT)
	_place(mover_c, Vector3(-3.0, MOVER_HEIGHT, 4.0), Vector3.FORWARD)
	_set_stick(MOVER_PHONE, Vector2(-1.0, 0.0)) # Pushing into the left wall.
	await _wait(SETTLE_SECONDS)
	_check(mover_a.is_moving() and not mover_c.is_moving(), "Setup: mover 1 pushes the stick, mover 3 stands still")
	var energy_before: float = ghost.energy
	var cast_time: int = Time.get_ticks_msec()
	_press(GHOST_PHONE, "haunt1", true)
	await _wait(INPUT_SECONDS)
	_press(GHOST_PHONE, "haunt1", false)
	_check(shake.phase == WARNING and energy_before - ghost.energy > SETTINGS.SHAKE_COST - ENERGY_TOLERANCE * 2.0, "SHAKE costs 45 energy and starts with a warning")
	await _wait(0.5)
	var warned: bool = camera.trauma > 0.2 and shake.banner.visible and shake.dust.emitting
	_check(warned and not mover_a.is_tumbling(), "The 1 s warning shakes the camera, drops dust and shows a banner, but tumbles nobody")
	var energy_mid: float = ghost.energy
	await _tap(GHOST_PHONE, "haunt1")
	_check(ghost.energy >= energy_mid and shake.cooldown_left > 0.0, "SHAKE is refused while it cools down")
	await _wait(0.4)
	_check(shake.phase == RUNNING and mover_a.is_tumbling(), "Once the house shakes, a mover pushing the stick tumbles")
	_check(not mover_c.is_tumbling(), "A mover standing still stays up")
	_check(camera.trauma > 0.5, "The camera shakes hard while the house shakes")
	inboxes[GHOST_PHONE].clear()
	await _wait(0.3)
	var hud: Dictionary = _latest_ghost_hud()
	_check(hud.get("ok", {}).get("haunt1") == false and float(hud.get("cd", {}).get("haunt1", 0.0)) > 0.5, "The phone greys SHAKE and shows its cooldown ring")
	await _wait(SETTINGS.SHAKE_WARNING + SETTINGS.SHAKE_DURATION + 0.2 - (Time.get_ticks_msec() - cast_time) / 1000.0)
	_check(shake.phase == IDLE and not shake.banner.visible and not shake.dust.emitting, "The shake ends after 2.5 s")
	await _wait(SETTINGS.TUMBLE_DURATION + SETTINGS.TUMBLE_FALL_TIME)
	_check(not mover_a.is_tumbling() and mover_a.is_moving(), "After the shake, moving is safe again")

	# BRACE protects, even with the stick pushed.
	shake.cooldown_left = 0.0 # Setup: skip the 20 s cooldown checked above.
	ghost.energy = SETTINGS.ENERGY_MAX
	_press(MOVER_PHONE, "brace", true)
	await _wait(INPUT_SECONDS)
	await _tap(GHOST_PHONE, "haunt1")
	await _wait(SETTINGS.SHAKE_WARNING + 0.8)
	_check(shake.phase == RUNNING and not mover_a.is_tumbling(), "A braced mover pushing the stick stays up through the shake")
	await _wait(SETTINGS.SHAKE_DURATION)
	_press(MOVER_PHONE, "brace", false)
	_set_stick(MOVER_PHONE, Vector2.ZERO)
	await _wait(INPUT_SECONDS)


# --- Ecto Slime ---
func _check_slime() -> void:
	_reset_ghost()
	var slime: Node = ghost.hauntings[1]
	_ghost_to(Vector3(-3.0, 0.0, -6.5))
	await _wait(INPUT_SECONDS)
	var energy_before: float = ghost.energy
	var cast_time: int = Time.get_ticks_msec()
	_press(GHOST_PHONE, "haunt2", true)
	await _wait(INPUT_SECONDS)
	_press(GHOST_PHONE, "haunt2", false)
	_check(slime.phase == RUNNING and energy_before - ghost.energy > SETTINGS.SLIME_COST - ENERGY_TOLERANCE * 2.0, "SLIME costs 25 energy and starts the trail")
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	await _wait(0.57)
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	await _wait(INPUT_SECONDS)
	var patches: Array[Node] = get_nodes_in_group("slime")
	_check(patches.size() >= 6 and patches.size() <= 10, "The wisp leaves a trail of slime patches (%d over about 4 m)" % patches.size())
	var xs: Array[float] = []
	var on_path: bool = true
	for patch: Node3D in patches:
		xs.append(patch.global_position.x)
		on_path = on_path and absf(patch.global_position.z + 6.5) < 0.05 and absf(patch.global_position.y - SETTINGS.DECAL_HEIGHT) < 0.01
	xs.sort()
	var spacing_ok: bool = true
	for index: int in range(1, xs.size()):
		var gap: float = xs[index] - xs[index - 1]
		spacing_ok = spacing_ok and gap >= SETTINGS.SLIME_PATCH_SPACING - 0.05 and gap <= SETTINGS.SLIME_PATCH_SPACING + 0.2
	_check(on_path and spacing_ok, "The patches lie on the floor along the wisp's path, about 0.6 m apart")

	# On slime a mover keeps sliding after letting go; off it they stop at once.
	_place(mover_a, Vector3(-6.0, MOVER_HEIGHT, -6.5), Vector3.RIGHT)
	_set_stick(MOVER_PHONE, Vector2(1.0, 0.0))
	var deadline: int = Time.get_ticks_msec() + 1500
	while not mover_a.on_slime() and Time.get_ticks_msec() < deadline:
		await _frame()
	await _wait(0.1)
	_set_stick(MOVER_PHONE, Vector2.ZERO)
	await _wait(0.3)
	var slide_speed: float = _flat(mover_a.velocity).length()
	_check(mover_a.on_slime() and slide_speed > 2.0, "On slime a mover keeps sliding after letting go (%.2f m/s after 0.3 s)" % slide_speed)
	_place(mover_a, Vector3(-6.0, MOVER_HEIGHT, -4.0), Vector3.RIGHT)
	_set_stick(MOVER_PHONE, Vector2(1.0, 0.0))
	await _wait(0.5)
	_set_stick(MOVER_PHONE, Vector2.ZERO)
	await _wait(0.1)
	var stop_speed: float = _flat(mover_a.velocity).length()
	_check(not mover_a.on_slime() and stop_speed < 0.1, "Off slime the same mover stops as soon as the stick is let go (%.2f m/s, on slime %s)" % [stop_speed, mover_a.on_slime()])

	# The trail ends 4 s after casting; each patch lasts 4 s.
	await _wait(SETTINGS.SLIME_TRAIL_TIME + 0.2 - (Time.get_ticks_msec() - cast_time) / 1000.0)
	var remaining: int = get_nodes_in_group("slime").size()
	_check(not slime.is_active() and remaining > 0, "The trail ends 4 s after casting, while its newest patches remain")
	_ghost_to(Vector3(-5.0, 0.0, 4.0))
	_set_stick(GHOST_PHONE, Vector2(1.0, 0.0))
	await _wait(0.4)
	_set_stick(GHOST_PHONE, Vector2.ZERO)
	_check(get_nodes_in_group("slime").size() <= remaining, "No new slime once the trail has ended")
	await _wait(SETTINGS.SLIME_TRAIL_TIME + 1.2 - (Time.get_ticks_msec() - cast_time) / 1000.0)
	_check(get_nodes_in_group("slime").is_empty(), "Every patch is gone 4 s after it was laid")


# --- The ghost's phone ---
func _check_hud() -> void:
	var labels: Array = ghost_actions.keys()
	labels.sort()
	_check(labels == ["", "DROP", "SHOVE", "SLAM", "STOMP", "YANK"], "The phone's ACTION label followed every prop type (%s)" % ", ".join(labels))
	_check(ghost_huds > 0 and ghost_hud_complete, "All %d ghost hud messages carried energy, action, costs, cd, ok and t" % ghost_huds)
	await _leave()
	ghost.energy = 10.0
	inboxes[GHOST_PHONE].clear()
	await _wait(0.3)
	var hud: Dictionary = _latest_ghost_hud()
	var costs: Dictionary = hud.get("costs", {})
	_check(int(costs.get("haunt1", 0)) == SETTINGS.SHAKE_COST and int(costs.get("haunt2", 0)) == SETTINGS.SLIME_COST, "The phone gets each haunting's cost for its label")
	_check(hud.get("ok", {}).get("haunt1") == false and hud.get("ok", {}).get("haunt2") == false, "Too little energy greys out both hauntings")
	var before: float = ghost.energy
	await _tap(GHOST_PHONE, "haunt1")
	await _tap(GHOST_PHONE, "haunt2")
	_check(ghost.energy >= before and not ghost.hauntings[0].is_active() and not ghost.hauntings[1].is_active(), "Greyed hauntings still send presses; the host refuses them for free")
	var mover_hud: bool = false
	for message: Dictionary in inboxes[MOVER_PHONE]:
		mover_hud = mover_hud or (message.get("type") == "hud" and message.has("held"))
	_check(mover_hud, "The mover's phone still gets its own hud")
	ghost.energy = SETTINGS.ENERGY_MAX


# --- Keyboard fallback ---
func _check_keyboard() -> void:
	await _leave()
	_reset_ghost()
	clients[GHOST_PHONE].close()
	await _wait(SETTLE_SECONDS)
	router.selected_slot = 1
	router.has_focus = true
	_check(_ghost() == ghost and _lone_mover(), "The ghost keeps its slot after its phone leaves")
	var crate: RigidBody3D = crate_p.prop
	_reset_body(crate, Vector3(-3.5, _furniture_height(0), 0.0))
	await _wait(SETTLE_SECONDS)
	_ghost_to(crate_p.global_position)
	await _wait(INPUT_SECONDS)
	await _tap_key(KEY_Q)
	_check(ghost.possessing == crate_p, "Q possesses")
	var before: float = ghost.energy
	_key(KEY_D, true)
	await _tap_key(KEY_F)
	_key(KEY_D, false)
	_check(before - ghost.energy > SETTINGS.ACTION_COSTS[SLIDER] - 1.0, "F uses the ACTION")
	await _wait(SETTLE_SECONDS)
	await _tap_key(KEY_Q)
	_check(ghost.possessing == null, "Q again leaves")
	await _tap_key(KEY_X)
	_check(ghost.hauntings[1].is_active(), "X casts Ecto Slime")
	await _tap_key(KEY_Z)
	_check(ghost.hauntings[0].is_active(), "Z triggers House Shake")
	var start: Vector3 = ghost.global_position
	_key(KEY_D, true)
	await _wait(0.3)
	_key(KEY_D, false)
	_check(ghost.global_position.x > start.x + 1.0, "WASD flies the wisp")
	router.selected_slot = 0
	await _wait(INPUT_SECONDS)


# --- Scenario helpers ---
func _setup_piano(centre: Vector2) -> RigidBody3D:
	# A fresh piano lying along x, with phone 1 at its west handle and phone 2 at its east handle.
	await _release_all()
	await _clear_carryables()
	var piano := _spawn_loot(PIANO_KIND, Vector3(centre.x, _rest_height(PIANO_KIND), centre.y))
	var stand_offset: float = SETTINGS.LOOT_SIZES[PIANO_KIND].x / 2.0 + SETTINGS.TEAM_STAND_DISTANCE
	_place(mover_a, Vector3(centre.x - stand_offset, MOVER_HEIGHT, centre.y), Vector3.RIGHT)
	_place(mover_b, Vector3(centre.x + stand_offset, MOVER_HEIGHT, centre.y), Vector3.LEFT)
	await _wait(SETTLE_SECONDS)
	_press(0, "grab", true)
	_press(1, "grab", true)
	await _wait(SETTLE_SECONDS)
	return piano


func _possess(target: Node3D, offset := Vector3.ZERO) -> void:
	# Fly the wisp onto the prop and press POSSESS; a setup that fails counts as a failure.
	_ghost_to(target.global_position + offset)
	await _wait(INPUT_SECONDS)
	await _tap(GHOST_PHONE, "possess")
	if ghost.possessing != target:
		_check(false, "Setup: the ghost possesses the %s" % target.prop_name())


func _leave() -> void:
	if is_instance_valid(ghost.possessing):
		await _tap(GHOST_PHONE, "possess")


func _reset_ghost() -> void:
	# Setup between scenarios: a rested ghost with full energy and no cooldowns.
	ghost.freeze_left = 0.0
	ghost.lockout_left = 0.0
	ghost.energy = SETTINGS.ENERGY_MAX
	for haunting: Node in ghost.hauntings:
		haunting.cooldown_left = 0.0


func _ghost_to(point: Vector3) -> void:
	ghost.position = Vector3(point.x, SETTINGS.WISP_HEIGHT, point.z)


func _measure_motion(node: Node3D, lead_seconds: float, window_seconds: float) -> Dictionary:
	await _wait(lead_seconds)
	var start: Vector3 = node.global_position
	var start_time: int = Time.get_ticks_msec()
	await _wait(window_seconds)
	var moved: Vector3 = _flat(node.global_position - start)
	return {"speed": moved.length() / ((Time.get_ticks_msec() - start_time) / 1000.0), "direction": moved.normalized()}


func _peak_speed(body: RigidBody3D, seconds: float) -> float:
	var peak: float = 0.0
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(body):
			peak = maxf(peak, _flat(body.linear_velocity).length())
		await _frame()
	return peak


func _release_all() -> void:
	for index: int in range(clients.size()):
		_set_stick(index, Vector2.ZERO)
		_press(index, "grab", false)
	await _wait(INPUT_SECONDS)


func _stop_sticks() -> void:
	for index: int in range(clients.size()):
		_set_stick(index, Vector2.ZERO)
	await _wait(SETTLE_SECONDS)


func _spawn_loot(kind: int, location: Vector3) -> RigidBody3D:
	var item: RigidBody3D = loot_scene.instantiate()
	item.loot_kind = kind
	item.position = location
	playground.add_child(item)
	return item


func _spawn_chandelier(location: Vector3) -> RigidBody3D:
	var chandelier: RigidBody3D = chandelier_scene.instantiate()
	chandelier.position = location
	playground.add_child(chandelier)
	return chandelier


func _clear_carryables() -> void:
	for item: Node in get_nodes_in_group("carryables"):
		item.queue_free()
	await _wait(INPUT_SECONDS)


func _reset_body(body: RigidBody3D, location: Vector3) -> void:
	body.global_transform = Transform3D(Basis(), location)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


func _place(target: CharacterBody3D, location: Vector3, direction: Vector3) -> void:
	target.position = location
	target.velocity = Vector3.ZERO
	target.facing = direction
	target._update_hold_point()


func _park(target: CharacterBody3D) -> void:
	_place(target, Vector3(-6.0 + target.slot * 2.0, MOVER_HEIGHT, 8.0), Vector3.FORWARD)


func _possessable_of(prop: Node) -> Node3D:
	for child: Node in prop.get_children():
		if child.is_in_group("possessables"):
			return child
	return null


func _ghost() -> Node3D:
	return playground.ghost if is_instance_valid(playground.ghost) else null


func _rest_height(kind: int) -> float:
	return SETTINGS.LOOT_SIZES[kind].y / 2.0 + SETTINGS.LOOT_SPAWN_CLEARANCE


func _furniture_height(kind: int) -> float:
	return SETTINGS.FURNITURE_SIZES[kind].y / 2.0 + SETTINGS.LOOT_SPAWN_CLEARANCE


func _value_of(item: RigidBody3D) -> int:
	# A shattered item has been freed; report it as worthless.
	return item.value if is_instance_valid(item) else 0


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _lone_mover() -> bool:
	# The flag is a static variable on the Loot script.
	var loot_script: Script = load("res://props/loot.gd")
	return loot_script.lone_mover


# --- Keyboard helpers ---
func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_key(key: Key) -> void:
	_key(key, true)
	await _wait(INPUT_SECONDS)
	_key(key, false)
	await _wait(INPUT_SECONDS)


# --- Phone helpers ---
func _connect_phone(player_name: String) -> void:
	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	clients.append(client)
	inboxes.append([])
	sticks.append(Vector2.ZERO)
	var index: int = clients.size() - 1
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "hello", "name": player_name, "key": net.session_key})
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "ready"})
	await _wait(INPUT_SECONDS)


func _welcome_slot(index: int) -> int:
	for message: Dictionary in inboxes[index]:
		if message.get("type") == "welcome":
			return int(message.slot)
	return -1


func _role_of(index: int) -> String:
	var role: String = ""
	for message: Dictionary in inboxes[index]:
		if message.get("type") == "role":
			role = message.get("role", "")
	return role


func _role_arena(index: int) -> String:
	var arena: String = ""
	for message: Dictionary in inboxes[index]:
		if message.get("type") == "role":
			arena = message.get("arena", "")
	return arena


func _latest_ghost_hud() -> Dictionary:
	var latest: Dictionary = {}
	for message: Dictionary in inboxes[GHOST_PHONE]:
		if message.get("type") == "hud" and message.has("energy"):
			latest = message
	return latest


func _ghost_ok(button: String) -> Variant:
	return _latest_ghost_hud().get("ok", {}).get(button)


func _set_stick(index: int, direction: Vector2) -> void:
	sticks[index] = direction
	_send(index, {"type": "in", "x": direction.x, "y": direction.y})


func _press(index: int, button: String, down: bool) -> void:
	_send(index, {"type": "btn", "b": button, "down": down})


func _tap(index: int, button: String) -> void:
	_press(index, button, true)
	await _wait(INPUT_SECONDS)
	_press(index, button, false)
	await _wait(INPUT_SECONDS)


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await _frame()


func _frame() -> void:
	# Every frame: read host messages, note the ghost's hud, and keep each phone's heartbeat flowing.
	var send_heartbeat: bool = Time.get_ticks_msec() >= next_heartbeat
	for index: int in range(clients.size()):
		var client: WebSocketPeer = clients[index]
		client.poll()
		while client.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(client.get_packet().get_string_from_utf8())
			if message is Dictionary:
				inboxes[index].append(message)
				if index == GHOST_PHONE and message.get("type") == "hud" and message.has("energy"):
					_note_ghost_hud(message)
		if send_heartbeat:
			_send(index, {"type": "in", "x": sticks[index].x, "y": sticks[index].y})
	if send_heartbeat:
		next_heartbeat = Time.get_ticks_msec() + int(1000.0 / SETTINGS.INPUT_RATE)
	await process_frame


func _note_ghost_hud(message: Dictionary) -> void:
	ghost_huds += 1
	ghost_actions[message.get("action", "")] = true
	for key: String in ["energy", "action", "costs", "cd", "ok", "t"]:
		ghost_hud_complete = ghost_hud_complete and message.has(key)
	for key: String in ["possess", "haunt1", "haunt2"]:
		ghost_hud_complete = ghost_hud_complete and message.get("cd", {}).has(key)
	for key: String in ["possess", "action", "haunt1", "haunt2"]:
		ghost_hud_complete = ghost_hud_complete and message.get("ok", {}).has(key)


func _send(index: int, message: Dictionary) -> void:
	if clients[index].get_ready_state() == WebSocketPeer.STATE_OPEN:
		clients[index].send_text(JSON.stringify(message))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
