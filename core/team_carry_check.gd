# Runs real Jolt physics and two simulated phones for two-person carry, tumbling and the flashlight.
# This script compiles before the autoloads exist, so props are loaded at runtime and never named by class.
extends SceneTree

# --- Test settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const VASE_KIND: int = 0
const TV_KIND: int = 1
const PIANO_KIND: int = 3
const SETTLE_SECONDS: float = 0.6
const INPUT_SECONDS: float = 0.12
const MOVER_HEIGHT: float = 0.8 # Mover centre above the floor, metres.
const SPEED_TOLERANCE: float = 0.3 # Metres per second.
const DIRECTION_TOLERANCE: float = 20.0 # Degrees.
const DOORWAY_TIMEOUT: float = 8.0 # Seconds allowed to steer the piano through the parlour door.
const DOOR_STEER_GAIN: float = 2.0 # Stick per metre each holder steers their end toward the door's centre line.
const TARGET_SCRIPT := "extends Node3D\nvar possessed: bool = true\nvar exorcisms: int = 0\nfunc is_possessed() -> bool:\n\treturn possessed\nfunc exorcise() -> void:\n\tpossessed = false\n\texorcisms += 1\n"

# --- Test state ---
var loot_scene: PackedScene
var flashlight_scene: PackedScene
var playground: Node3D
var mover_a: CharacterBody3D
var mover_b: CharacterBody3D
var router: Node
var net: Node
var failures: int = 0
var clients: Array[WebSocketPeer] = []
var inboxes: Array[Array] = []
var sticks: Array[Vector2] = []
var next_heartbeat: int = 0

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting team_carry_check.gd")
		quit(1)
		return

	# Stop early if the props cannot load; otherwise every check below would compare empty values.
	loot_scene = load("res://props/Loot.tscn")
	flashlight_scene = load("res://props/Flashlight.tscn")
	var props_loaded: bool = true
	for path: String in ["res://props/carryable.gd", "res://props/loot.gd", "res://props/flashlight.gd"]:
		var script: Script = load(path)
		props_loaded = props_loaded and script != null and script.can_instantiate()
	_check(props_loaded, "Carryable, loot and flashlight scripts compile")
	if not props_loaded:
		quit(1)
		return

	playground = load("res://Main.tscn").instantiate()
	playground.match_mode = false # The greybox harness, not the match flow.
	root.add_child(playground)
	_check_greybox_contents()
	# The ghost's furniture has its own check (with the parlour door in place); this one carries in an empty room.
	for prop: Node in get_nodes_in_group("furniture"):
		prop.queue_free()
	await _wait(INPUT_SECONDS)
	for index: int in range(2):
		await _connect_phone("Team %d" % (index + 1))
	_check(_welcome_slot(0) == 0 and _welcome_slot(1) == 1, "Two phones control movers 1 and 2")
	net.accept_new_players = false # Real phones left open on the network must not join the test.
	mover_a = playground.movers[0]
	mover_b = playground.movers[1]
	router.selected_slot = 0 # The keyboard shares phone A's slot, so it never drives another mover.
	for other: CharacterBody3D in playground.movers:
		if other != mover_a and other != mover_b:
			_place(other, Vector3(-6.0 + other.slot * 2.0, MOVER_HEIGHT, 8.0), Vector3.FORWARD)

	await _check_team_carry()
	await _check_team_conditions()
	await _check_drag()
	await _check_doorway()
	await _check_tumbling()
	await _check_flashlight()
	await _check_lone_drag()
	for client: WebSocketPeer in clients:
		client.close()
	await _wait(INPUT_SECONDS)
	print("TEAM CARRY CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _check_greybox_contents() -> void:
	var pianos: Array = get_nodes_in_group("loot").filter(func(item: Node) -> bool: return item.weight_class == SETTINGS.TWO_PERSON)
	_check(pianos.size() == 1 and pianos[0].global_position.z < SETTINGS.PARLOUR_WALL_Z, "The greybox has one piano, in the parlour")
	_check(get_nodes_in_group("flashlights").size() == 1, "The greybox has one flashlight")


# --- Two-person carry ---
func _check_team_carry() -> void:
	var piano := await _setup_piano(Vector2(2.0, -6.0), true)
	_check(piano.holder_count() == 2 and mover_a.held_item == piano and mover_b.held_item == piano, "Both movers take a handle each")
	var lift_target: float = SETTINGS.CARRY_CLEARANCE + SETTINGS.LOOT_SIZES[PIANO_KIND].y / 2.0
	_check(absf(piano.global_position.y - lift_target) < 0.1, "Two holders lift the piano to carry height (%.2f m)" % piano.global_position.y)
	_check(piano.value == piano.initial_value, "Picking up the piano does not damage it")

	# Both push the same way: 70% of walking speed.
	var team_speed: float = SETTINGS.MOVER_SPEED * SETTINGS.CARRY_SPEEDS[SETTINGS.TWO_PERSON]
	_set_stick(0, Vector2(0.0, 1.0))
	_set_stick(1, Vector2(0.0, 1.0))
	var straight: Dictionary = await _measure(piano, 0.5, 0.4)
	_check(absf(straight.speed - team_speed) < SPEED_TOLERANCE, "Both pushing carries the piano at 70%% speed (%.2f m/s)" % straight.speed)
	_check(straight.peak < team_speed + SPEED_TOLERANCE, "The piano never outruns 70%% speed (peak %.2f m/s)" % straight.peak)
	await _stop_sticks()

	# Different sticks: the piano follows their average.
	_set_stick(0, Vector2(0.0, 1.0))
	_set_stick(1, Vector2(1.0, 0.0))
	var steer: Dictionary = await _measure(piano, 0.3, 0.3)
	var steer_angle: float = rad_to_deg(steer.direction.angle_to(Vector3(1.0, 0.0, 1.0).normalized()))
	_check(steer_angle < DIRECTION_TOLERANCE, "The piano moves along the average of both sticks (%.0f° off)" % steer_angle)
	await _stop_sticks()

	# Opposite sticks: the piano turns on the spot.
	piano = await _setup_piano(Vector2(2.0, -5.0), true)
	var start_yaw: float = _yaw(piano)
	var start_position: Vector3 = piano.global_position
	_set_stick(0, Vector2(0.0, 1.0))
	_set_stick(1, Vector2(0.0, -1.0))
	await _wait(0.8)
	var turned: float = rad_to_deg(absf(angle_difference(start_yaw, _yaw(piano))))
	var drift: float = _flat(piano.global_position - start_position).length()
	_check(turned > 60.0 and drift < 0.6, "Opposite pulls turn the piano (%.0f°, centre moved %.2f m)" % [turned, drift])
	_check(piano.holder_count() == 2, "Both holders keep hold through the turn")
	await _stop_sticks()

	# THROW does nothing to a two-person item, and the phone shows what is held.
	inboxes[0].clear()
	_press(0, "throw", true)
	await _wait(INPUT_SECONDS)
	_press(0, "throw", false)
	await _wait(SETTLE_SECONDS)
	_check(piano.holder_count() == 2 and piano.linear_velocity.length() < 1.0, "THROW cannot launch the piano")
	_check(_hud_shows(0, "Grand piano", piano.value), "Phone shows the piano and its value")


func _check_team_conditions() -> void:
	# Dragged too far from the handle: the holder lets go.
	var piano := await _setup_piano(Vector2(2.0, -5.0), true)
	_place(mover_b, Vector3(5.5, MOVER_HEIGHT, -2.0), Vector3.FORWARD)
	await _wait(INPUT_SECONDS)
	_check(mover_b.held_item == null and piano.holder_count() == 1, "A holder pulled off their spot lets go")

	# A tumble mid-carry leaves the partner dragging.
	piano = await _setup_piano(Vector2(2.0, -5.0), true)
	mover_b.tumble(Vector3.RIGHT)
	await _wait(INPUT_SECONDS)
	_check(mover_b.is_tumbling() and mover_b.held_item == null and piano.holder_count() == 1, "A tumble drops the handle; the partner keeps the other")
	await _wait(SETTINGS.TUMBLE_DURATION)


func _check_drag() -> void:
	var piano := await _setup_piano(Vector2(2.0, -5.0), false)
	_check(piano.holder_count() == 1, "One mover can take a single handle")
	_set_stick(0, Vector2(-1.0, 0.0))
	await _wait(0.6)
	var start_value: int = piano.value
	var drag: Dictionary = await _measure(piano, 0.0, 1.2)
	var drag_speed: float = SETTINGS.MOVER_SPEED * SETTINGS.DRAG_SPEED
	_check(absf(drag.speed - drag_speed) < SPEED_TOLERANCE, "One handle drags the piano at 25%% speed (%.2f m/s)" % drag.speed)
	_check(piano.global_position.y < SETTINGS.LOOT_SIZES[PIANO_KIND].y / 2.0 + 0.1, "A dragged piano stays on the floor")
	var expected_loss: float = start_value * SETTINGS.SCRAPE_RATE * drag.distance
	var loss: int = start_value - piano.value
	_check(loss > expected_loss * 0.6 and loss < expected_loss * 1.4 + 1.0, "Dragging scrapes 1.5%% per metre (−₹%d over %.2f m, expected about ₹%d)" % [loss, drag.distance, roundi(expected_loss)])
	await _stop_sticks()

	# Lifted then set down: the drop from carry height is free.
	piano = await _setup_piano(Vector2(2.0, -5.0), true)
	var lifted_value: int = piano.value
	_press(0, "grab", false)
	_press(1, "grab", false)
	await _wait(SETTLE_SECONDS * 2.0)
	_check(piano.holder_count() == 0 and piano.value == lifted_value, "Setting the piano down does not damage it")


func _check_doorway() -> void:
	# Turn the piano lengthwise in the parlour, then steer it through the 2 m door.
	var piano := await _setup_piano(Vector2(0.0, -9.75), true)
	var start_value: int = piano.value
	_set_stick(0, Vector2(0.0, 1.0))
	_set_stick(1, Vector2(0.0, -1.0))
	await _wait(1.0)
	var axis: Vector3 = _flat(piano.global_basis.x).normalized()
	_check(absf(axis.z) > 0.9, "Opposite pulls swing the piano lengthwise toward the door")

	var elapsed: float = 0.0
	while elapsed < DOORWAY_TIMEOUT and piano.global_position.z < SETTINGS.PARLOUR_WALL_Z + SETTINGS.LOOT_SIZES[PIANO_KIND].x:
		# Each holder steers their own end toward the door's centre line while both push forward.
		for index: int in range(2):
			var handle: int = piano.handle_holders.find(mover_a if index == 0 else mover_b)
			var handle_x: float = piano.handle_position(handle).x
			_set_stick(index, Vector2(clampf(-handle_x * DOOR_STEER_GAIN, -1.0, 1.0), 1.0).limit_length())
		await _wait(INPUT_SECONDS)
		elapsed += INPUT_SECONDS
	var through: bool = piano.global_position.z > SETTINGS.PARLOUR_WALL_Z + SETTINGS.LOOT_SIZES[PIANO_KIND].x / 2.0
	_check(through and piano.holder_count() == 2, "Two movers carry the piano through the parlour door (%.1f s)" % elapsed)
	print("INFO: the doorway cost the piano %s of %s" % [piano.rupees(start_value - piano.value), piano.rupees(start_value)])
	await _stop_sticks()


# --- Tumbling ---
func _check_tumbling() -> void:
	# Phone A throws a vase at phone B, who is carrying a TV.
	await _release_all()
	await _clear_carryables()
	_place(mover_a, Vector3(-2.0, MOVER_HEIGHT, -5.0), Vector3.RIGHT)
	_place(mover_b, Vector3(0.5, MOVER_HEIGHT, -5.0), Vector3.RIGHT)
	var vase := _spawn_loot(VASE_KIND, Vector3(-2.0 + SETTINGS.HOLD_DISTANCE, _rest_height(VASE_KIND), -5.0))
	var tv := _spawn_loot(TV_KIND, Vector3(0.5 + SETTINGS.HOLD_DISTANCE, _rest_height(TV_KIND), -5.0))
	await _wait(SETTLE_SECONDS)
	_press(0, "grab", true)
	_press(1, "grab", true)
	await _wait(SETTLE_SECONDS)
	_check(mover_a.held_item == vase and mover_b.held_item == tv, "Thrower holds a vase and the target holds a TV")
	inboxes[1].clear()
	_press(0, "throw", true)
	await _wait(INPUT_SECONDS)
	_press(0, "throw", false)
	await _wait(INPUT_SECONDS * 2.0)
	_check(mover_b.is_tumbling(), "A thrown vase above 4 m/s knocks a mover over")
	_check(mover_b.held_item == null and not tv.is_held(), "The tumbling mover drops what they carry")
	_check(_received(1, "buzz"), "The tumbled mover's phone buzzes")

	_set_stick(1, Vector2(0.0, 1.0))
	await _wait(0.5)
	_check(_flat(mover_b.velocity).length() < 0.1, "A tumbled mover ignores the joystick")
	await _wait(SETTINGS.TUMBLE_DURATION - 0.5 + SETTINGS.TUMBLE_FALL_TIME)
	_check(not mover_b.is_tumbling() and _flat(mover_b.velocity).length() > 1.0, "The mover stands up after 1.5 s and can move again")
	_check(mover_b.held_item == null, "Getting up while still holding GRAB does not re-grab")
	await _stop_sticks()

	# Slow or unthrown hits do not tumble.
	await _release_all()
	await _clear_carryables()
	_place(mover_b, Vector3(0.5, MOVER_HEIGHT, -5.0), Vector3.RIGHT)
	# Spawned just short of the mover, so each one really hits (the vase's damage proves contact).
	var slow := _spawn_loot(VASE_KIND, Vector3(-0.3, _rest_height(VASE_KIND), -5.0))
	await _wait(SETTLE_SECONDS)
	slow.thrown = true
	slow.sleeping = false
	slow.linear_velocity = Vector3.RIGHT * 3.8
	await _wait(SETTLE_SECONDS)
	_check(slow.value < slow.initial_value and not mover_b.is_tumbling(), "A thrown item hitting slower than 4 m/s does not tumble anyone")
	await _clear_carryables()
	var pushed := _spawn_loot(VASE_KIND, Vector3(-1.5, _rest_height(VASE_KIND), -5.0))
	await _wait(SETTLE_SECONDS)
	pushed.sleeping = false
	pushed.linear_velocity = Vector3.RIGHT * 7.0
	await _wait(SETTLE_SECONDS)
	_check(_value_of(pushed) < SETTINGS.LOOT_VALUES[VASE_KIND] and not mover_b.is_tumbling(), "A fast item that was not thrown does not tumble anyone")
	# The vase arrives at about 5.4 m/s; being shoved aside must not shrink the hit below 4.5 m/s.
	var min_loss: float = 4.5 * SETTINGS.LOOT_FRAGILITIES[VASE_KIND] * SETTINGS.DAMAGE_MULTIPLIER
	_check(_value_of(pushed) < SETTINGS.LOOT_VALUES[VASE_KIND] * (1.0 - min_loss), "A hit on a mover counts the item's full speed (₹%d left)" % _value_of(pushed))


# --- Flashlight ---
func _check_flashlight() -> void:
	await _release_all()
	await _clear_carryables()
	_place(mover_a, Vector3(0.0, MOVER_HEIGHT, -4.0), Vector3.RIGHT)
	_place(mover_b, Vector3(-5.0, MOVER_HEIGHT, 0.0), Vector3.FORWARD)
	var torch := _spawn_flashlight(Vector3(SETTINGS.HOLD_DISTANCE, _torch_height(), -4.0))
	await _wait(SETTLE_SECONDS)
	inboxes[0].clear()
	_press(0, "grab", true)
	await _wait(SETTLE_SECONDS)
	_check(mover_a.held_item == torch, "GRAB picks up the flashlight")
	_check(_hud_shows(0, "Flashlight", null), "Phone shows the flashlight without a price")
	_spawn_loot(VASE_KIND, Vector3(1.2, _rest_height(VASE_KIND), -3.0))
	await _wait(SETTLE_SECONDS)
	_check(mover_a.held_item == torch, "Carrying the flashlight means not carrying loot")

	# The beam follows the holder's facing.
	_set_stick(0, Vector2(0.0, 1.0))
	await _wait(INPUT_SECONDS)
	_set_stick(0, Vector2.ZERO)
	await _wait(SETTLE_SECONDS)
	var beam_forward: Vector3 = -torch.beam.global_basis.z
	_check(beam_forward.dot(mover_a.facing) > cos(deg_to_rad(5.0)), "The beam points where the holder faces")
	var body_forward: Vector3 = _flat(-torch.global_basis.z).normalized()
	_check(body_forward.dot(mover_a.facing) > cos(deg_to_rad(25.0)), "The torch body turns to match the beam")

	# A possessed stand-in 4 m down the beam is exorcised once after 1.5 s.
	var target := _spawn_target(mover_a.global_position + mover_a.facing * 4.0)
	await _wait(SETTINGS.EXORCISE_TIME - 0.5)
	_check(target.exorcisms == 0, "Less than 1.5 s in the beam does not exorcise")
	await _wait(0.8)
	_check(target.exorcisms == 1 and not target.possessed, "1.5 s in the beam exorcises the possessed target")
	await _wait(1.5)
	_check(target.exorcisms == 1, "An exorcised target is not exorcised again")

	# Out of the cone, behind a wall, or with a loose torch: no exorcism.
	target.possessed = true
	target.global_position = mover_a.global_position - mover_a.facing * 4.0
	await _wait(SETTINGS.EXORCISE_TIME + 0.5)
	_check(target.exorcisms == 1, "A target outside the beam cone is not exorcised")

	# Facing the parlour partition (a solid section, away from the door) with the target behind it.
	target.global_position = Vector3(3.0, 0.5, -10.0)
	_place(mover_a, Vector3(3.0, MOVER_HEIGHT, -5.5), Vector3.FORWARD)
	await _wait(SETTLE_SECONDS * 2.0 + SETTINGS.EXORCISE_TIME + 0.5)
	_check(mover_a.held_item == torch and target.exorcisms == 1, "Walls block the beam")

	# Back in open space, drop the torch and put the target in its beam.
	_place(mover_a, Vector3(0.0, MOVER_HEIGHT, -3.0), Vector3.RIGHT)
	await _wait(SETTLE_SECONDS * 2.0)
	_press(0, "grab", false)
	await _wait(SETTLE_SECONDS)
	target.global_position = torch.global_position + torch.beam_direction() * 3.0
	await _wait(SETTINGS.EXORCISE_TIME + 0.5)
	_check(target.exorcisms == 1, "A flashlight lying on the floor does not exorcise")
	target.queue_free()

	# Thrown like any light item; released in the truck it stays in play.
	await _clear_carryables()
	_place(mover_a, Vector3(0.0, MOVER_HEIGHT, -4.0), Vector3.RIGHT)
	torch = _spawn_flashlight(Vector3(SETTINGS.HOLD_DISTANCE, _torch_height(), -4.0))
	await _wait(SETTLE_SECONDS)
	_press(0, "grab", true)
	await _wait(SETTLE_SECONDS)
	_press(0, "throw", true)
	await _wait(INPUT_SECONDS)
	_press(0, "throw", false)
	_check(mover_a.held_item == null and torch.linear_velocity.x > 3.0, "THROW launches the flashlight")
	await _release_all()
	await _clear_carryables()
	var truck: Area3D = playground.arena.truck
	var banked_before: int = truck.banked_items
	_place(mover_a, Vector3(5.0, MOVER_HEIGHT, 6.5), Vector3.FORWARD)
	torch = _spawn_flashlight(Vector3(5.0, _torch_height(), 6.5 - SETTINGS.HOLD_DISTANCE))
	await _wait(SETTLE_SECONDS)
	_press(0, "grab", true)
	await _wait(SETTLE_SECONDS)
	_press(0, "grab", false)
	await _wait(SETTLE_SECONDS)
	_check(is_instance_valid(torch) and not torch.finished and truck.banked_items == banked_before, "A flashlight released in the truck does not bank")


# --- Lone mover ---
func _check_lone_drag() -> void:
	# With phone B gone, only one player is active, so the lone mover drags at 40%.
	await _release_all()
	clients[1].close()
	await _wait(SETTLE_SECONDS)
	_check(_lone_mover(), "One active player turns on the lone-mover rule")
	var piano := await _setup_piano(Vector2(2.0, -5.0), false)
	_set_stick(0, Vector2(-1.0, 0.0))
	await _wait(0.6)
	var start_value: int = piano.value
	var drag: Dictionary = await _measure(piano, 0.0, 1.0)
	var lone_speed: float = SETTINGS.MOVER_SPEED * SETTINGS.LONE_DRAG_SPEED
	_check(absf(drag.speed - lone_speed) < SPEED_TOLERANCE, "The lone mover drags at 40%% speed (%.2f m/s)" % drag.speed)
	_check(piano.value < start_value, "The lone mover's drag still scrapes value")
	await _stop_sticks()


# --- Scenario helpers ---
func _setup_piano(centre: Vector2, both_hands: bool) -> RigidBody3D:
	# A fresh piano lying along x, with phone A at its west handle and phone B at its east handle.
	await _release_all()
	await _clear_carryables()
	var piano := _spawn_loot(PIANO_KIND, Vector3(centre.x, _rest_height(PIANO_KIND), centre.y))
	var stand_offset: float = SETTINGS.LOOT_SIZES[PIANO_KIND].x / 2.0 + SETTINGS.TEAM_STAND_DISTANCE
	_place(mover_a, Vector3(centre.x - stand_offset, MOVER_HEIGHT, centre.y), Vector3.RIGHT)
	_place(mover_b, Vector3(centre.x + stand_offset, MOVER_HEIGHT, centre.y), Vector3.LEFT)
	await _wait(SETTLE_SECONDS)
	_press(0, "grab", true)
	if both_hands:
		_press(1, "grab", true)
	await _wait(SETTLE_SECONDS)
	return piano


func _measure(item: RigidBody3D, lead_seconds: float, window_seconds: float) -> Dictionary:
	# Average horizontal velocity over a window after a lead-in, plus the peak speed throughout.
	var record: Dictionary = {"speed": 0.0, "peak": 0.0, "direction": Vector3.ZERO, "distance": 0.0}
	var lead_end: int = Time.get_ticks_msec() + int(lead_seconds * 1000.0)
	while Time.get_ticks_msec() < lead_end:
		record.peak = maxf(record.peak, _flat(item.linear_velocity).length())
		await _frame()
	var start: Vector3 = item.global_position
	var start_time: int = Time.get_ticks_msec()
	var previous: Vector3 = start
	var window_end: int = start_time + int(window_seconds * 1000.0)
	while Time.get_ticks_msec() < window_end:
		record.peak = maxf(record.peak, _flat(item.linear_velocity).length())
		record.distance += _flat(item.global_position - previous).length()
		previous = item.global_position
		await _frame()
	var moved: Vector3 = _flat(item.global_position - start)
	record.speed = moved.length() / ((Time.get_ticks_msec() - start_time) / 1000.0)
	record.direction = moved.normalized()
	return record


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


func _spawn_flashlight(location: Vector3) -> RigidBody3D:
	var torch: RigidBody3D = flashlight_scene.instantiate()
	torch.position = location
	playground.add_child(torch)
	return torch


func _spawn_target(location: Vector3) -> Node3D:
	var script := GDScript.new()
	script.source_code = TARGET_SCRIPT
	script.reload()
	var target := Node3D.new()
	target.set_script(script)
	target.name = "StandInProp"
	playground.add_child(target)
	target.global_position = Vector3(location.x, 0.5, location.z)
	target.add_to_group("possessables")
	return target


func _clear_carryables() -> void:
	for item: Node in get_nodes_in_group("carryables"):
		item.queue_free()
	await _wait(INPUT_SECONDS)


func _place(target: CharacterBody3D, location: Vector3, direction: Vector3) -> void:
	target.position = location
	target.velocity = Vector3.ZERO
	target.facing = direction
	target._update_hold_point()


func _rest_height(kind: int) -> float:
	return SETTINGS.LOOT_SIZES[kind].y / 2.0 + SETTINGS.LOOT_SPAWN_CLEARANCE


func _torch_height() -> float:
	return SETTINGS.FLASHLIGHT_SIZE.y / 2.0 + SETTINGS.LOOT_SPAWN_CLEARANCE


func _yaw(item: Node3D) -> float:
	var axis: Vector3 = item.global_basis.x
	return atan2(axis.x, axis.z)


func _value_of(item: RigidBody3D) -> int:
	# A shattered item has been freed; report it as worthless.
	return item.value if is_instance_valid(item) else 0


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _lone_mover() -> bool:
	# The flag is a static variable on the Loot script.
	var loot_script: Script = load("res://props/loot.gd")
	return loot_script.lone_mover


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


func _set_stick(index: int, direction: Vector2) -> void:
	sticks[index] = direction
	_send(index, {"type": "in", "x": direction.x, "y": direction.y})


func _press(index: int, button: String, down: bool) -> void:
	_send(index, {"type": "btn", "b": button, "down": down})


func _received(index: int, message_type: String) -> bool:
	for message: Dictionary in inboxes[index]:
		if message.get("type") == message_type:
			return true
	return false


func _hud_shows(index: int, held: String, value: Variant) -> bool:
	for message: Dictionary in inboxes[index]:
		if message.get("type") == "hud" and message.get("held") == held and message.get("value") == value:
			return true
	return false


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await _frame()


func _frame() -> void:
	# Every frame: read host messages and keep each phone's heartbeat (its current stick) flowing.
	var send_heartbeat: bool = Time.get_ticks_msec() >= next_heartbeat
	for index: int in range(clients.size()):
		var client: WebSocketPeer = clients[index]
		client.poll()
		while client.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(client.get_packet().get_string_from_utf8())
			if message is Dictionary:
				inboxes[index].append(message)
		if send_heartbeat:
			_send(index, {"type": "in", "x": sticks[index].x, "y": sticks[index].y})
	if send_heartbeat:
		next_heartbeat = Time.get_ticks_msec() + int(1000.0 / SETTINGS.INPUT_RATE)
	await process_frame


func _send(index: int, message: Dictionary) -> void:
	if clients[index].get_ready_state() == WebSocketPeer.STATE_OPEN:
		clients[index].send_text(JSON.stringify(message))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
