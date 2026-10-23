# Runs real Jolt physics and input paths for pickup, impacts, throwing, banking, grab conflicts and price tags.
# This script compiles before the autoloads exist, so loot is loaded at runtime and never named by class.
extends SceneTree

# --- Test settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const SETTLE_SECONDS: float = 0.6
const INPUT_SECONDS: float = 0.12
const WALK_SECONDS: float = 1.0
const REST_SECONDS: float = 2.0
const FLOAT_TOLERANCE: float = 0.1
const MOVER_HEIGHT: float = 0.8 # Mover centre above the floor, metres.
const SETTLED_DISTANCE: float = 0.3 # Metres from the carry target once the spring has settled.
const SWING_DISTANCE: float = SETTINGS.HOLD_DISTANCE # A carried item never trails further than the mover's reach.
const LAUNCH_SPEED: float = 7.0 # Metres per second relative to the mover; faster counts as a launch.
const LAUNCH_HEIGHT: float = 2.0 # Metres; a carried item's centre must stay below this.

# --- Test state ---
var loot_scene: PackedScene
var playground: Node3D
var mover: CharacterBody3D
var router: Node
var net: Node
var failures: int = 0
var clients: Array[WebSocketPeer] = []
var inboxes: Array[Array] = []
var heartbeat: bool = false
var next_heartbeat: int = 0

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting carrying_check.gd")
		quit(1)
		return

	# Stop early if loot cannot load; otherwise every check below would compare empty values.
	loot_scene = load("res://props/Loot.tscn")
	var loot_script: Script = load("res://props/loot.gd")
	var loot_loaded: bool = loot_script != null and loot_script.can_instantiate()
	_check(loot_loaded, "Loot script compiles and loads")
	if not loot_loaded:
		quit(1)
		return

	playground = load("res://Main.tscn").instantiate()
	playground.match_mode = false # The greybox harness, not the match flow.
	root.add_child(playground)
	mover = playground.movers[0]
	_park_other_movers()
	await _clear_furniture()
	await _clear_loot()
	await _check_spring_settles()
	await _check_grab_selection()
	await _check_throwing()
	await _check_damage_math()
	await _check_wall_hits()
	await _check_resting_contact()
	await _check_banking()
	await _check_phone_release_and_hud()
	await _check_double_grab()
	await _check_price_tags()
	await _clear_loot()
	for client: WebSocketPeer in clients:
		client.close()
	print("CARRYING CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Carrying ---
func _check_spring_settles() -> void:
	for kind: int in range(3):
		await _clear_loot()
		_reset_mover(Vector3(0.0, MOVER_HEIGHT, 0.0), Vector3.FORWARD)
		var item := _spawn(kind, Vector3(0.0, _rest_height(kind), -SETTINGS.HOLD_DISTANCE))
		var label: String = item.item_name
		await _wait(SETTLE_SECONDS)
		_check(item.value == item.initial_value, "Resting %s starts undamaged" % label)

		# Pick up and let the spring settle.
		_key(KEY_SPACE, true)
		var pickup: Dictionary = await _track_carry(item, SETTLE_SECONDS)
		_check(mover.held_item == item and item.holder == mover, "GRAB picks up %s" % label)
		_check(_is_calm(pickup), "Pickup does not launch %s (%s)" % [label, _describe(pickup)])
		var settled: float = item.global_position.distance_to(item.carry_target())
		_check(settled < SETTLED_DISTANCE, "Spring settles %s at the carry target (%.2f m)" % [label, settled])
		_check(not item.try_grab(playground.movers[1], playground.movers[1].hold_point, 1), "Another player cannot claim held %s" % label)

		# Walk, brace, then turn around and walk back.
		_key(KEY_D, true)
		var walk: Dictionary = await _track_carry(item, WALK_SECONDS)
		var expected_speed: float = SETTINGS.MOVER_SPEED * SETTINGS.CARRY_SPEEDS[kind]
		_check(absf(mover.velocity.x - expected_speed) < FLOAT_TOLERANCE, "Correct movement speed carrying %s" % label)
		_key(KEY_SHIFT, true)
		await _wait(INPUT_SECONDS)
		_check(Vector2(mover.velocity.x, mover.velocity.z).length() < FLOAT_TOLERANCE, "BRACE stops movement carrying %s" % label)
		_key(KEY_SHIFT, false)
		_key(KEY_D, false)
		_key(KEY_A, true)
		var turn: Dictionary = await _track_carry(item, WALK_SECONDS)
		_key(KEY_A, false)
		_check(_is_calm(walk) and _is_calm(turn), "Walking and a 180° turn do not launch %s (%s / %s)" % [label, _describe(walk), _describe(turn)])
		_check(item.value == item.initial_value, "Carrying %s through open space causes no damage" % label)

		# Stop, then let go: a plain drop must land below the damage threshold.
		await _wait(SETTLE_SECONDS)
		_key(KEY_SPACE, false)
		await _wait(INPUT_SECONDS)
		_check(mover.held_item == null and item.holder == null, "Releasing GRAB drops %s" % label)
		await _wait(REST_SECONDS)
		_check(_value(item) == item.initial_value, "A plain drop does not damage %s (₹%d left)" % [label, _value(item)])
	await _measure_walking_drops()


func _measure_walking_drops() -> void:
	# Information only: letting go at full walking speed can tip an item over.
	for kind: int in range(3):
		await _clear_loot()
		_reset_mover(Vector3(-3.0, MOVER_HEIGHT, -4.0), Vector3.RIGHT)
		var item := _spawn(kind, Vector3(-3.0 + SETTINGS.HOLD_DISTANCE, _rest_height(kind), -4.0))
		await _wait(SETTLE_SECONDS)
		_key(KEY_SPACE, true)
		await _wait(SETTLE_SECONDS)
		_key(KEY_D, true)
		await _wait(SETTLE_SECONDS)
		_key(KEY_SPACE, false)
		await _wait(INPUT_SECONDS)
		_key(KEY_D, false)
		await _wait(REST_SECONDS)
		print("INFO: %s dropped at walking speed keeps ₹%d of ₹%d" % [item.item_name, _value(item), item.initial_value])


func _check_grab_selection() -> void:
	await _clear_loot()
	_reset_mover(Vector3(0.0, MOVER_HEIGHT, 0.0), Vector3.FORWARD)
	_spawn(0, Vector3(0.0, _rest_height(0), 1.25))
	_key(KEY_SPACE, true)
	await _wait(INPUT_SECONDS)
	_check(mover.held_item == null, "Cannot grab loot behind the mover")

	await _clear_loot()
	_reset_mover(Vector3(6.4, MOVER_HEIGHT, 0.0), Vector3.RIGHT)
	_spawn(0, Vector3(7.5, _rest_height(0), 0.0))
	_key(KEY_SPACE, true)
	await _wait(INPUT_SECONDS)
	_check(mover.held_item == null, "Cannot grab through a wall")

	await _clear_loot()
	_reset_mover(Vector3(0.0, MOVER_HEIGHT, 0.0), Vector3.FORWARD)
	var near_item := _spawn(0, Vector3(0.0, _rest_height(0), -0.9))
	_spawn(0, Vector3(0.7, _rest_height(0), -1.5))
	_key(KEY_SPACE, true)
	await _wait(INPUT_SECONDS)
	_check(mover.held_item == near_item, "Nearest available item in front wins")


# --- Throwing and damage ---
func _check_throwing() -> void:
	for kind: int in range(3):
		await _clear_loot()
		_reset_mover(Vector3(0.0, MOVER_HEIGHT, 0.0), Vector3.FORWARD)
		var item := _spawn(kind, Vector3(0.0, _rest_height(kind), -SETTINGS.HOLD_DISTANCE))
		_key(KEY_SPACE, true)
		await _wait(SETTLE_SECONDS)
		_key(KEY_E, true)
		await _wait(INPUT_SECONDS)
		_key(KEY_E, false)
		if kind == 0:
			_check(mover.held_item == null and item.linear_velocity.z < -3.0, "THROW launches light loot")
			await _wait(INPUT_SECONDS)
			_check(mover.held_item == null, "Holding GRAB does not immediately catch a thrown item")
			await _wait(WALK_SECONDS)
			_check(_value(item) < item.initial_value, "A thrown vase lands hard and takes damage")
		else:
			_check(mover.held_item == item, "THROW cannot launch medium/heavy loot")


func _check_damage_math() -> void:
	await _clear_loot()
	var item := _spawn(0, Vector3(0.0, _rest_height(0), -5.0))
	item.apply_impact(SETTINGS.DAMAGE_SPEED_THRESHOLD)
	_check(item.value == 3000, "Threshold-speed contact causes no damage")
	item.apply_impact(3.0)
	_check(item.value == 1920, "3 m/s impact removes 36% of a fragility-3 vase")
	item.apply_impact(3.0)
	_check(item.value == 1228, "Subsequent damage uses current value and rounds up")
	item.value = 1
	item.apply_impact(3.0)
	_check(item.value == 0 and item.finished, "Whole-rupee damage reaches zero and shatters")
	item.apply_impact(100.0)
	_check(item.value == 0, "Finished loot cannot lose value again")
	await _wait(INPUT_SECONDS)
	_check(not is_instance_valid(item), "Shattered body is removed")
	var formatter: RigidBody3D = _spawn(0, Vector3(0.0, _rest_height(0), -5.0))
	var formatted: Array = [formatter.rupees(0), formatter.rupees(1200), formatter.rupees(25000), formatter.rupees(120000)]
	_check(formatted == ["₹0", "₹1,200", "₹25,000", "₹1,20,000"], "Prices use Indian digit grouping (%s)" % ", ".join(formatted))


func _check_wall_hits() -> void:
	# Carried at full walking speed into the right-hand wall, then held pressed against it.
	await _clear_loot()
	_reset_mover(Vector3(3.5, MOVER_HEIGHT, -4.0), Vector3.RIGHT)
	var carried := _spawn(0, Vector3(3.5 + SETTINGS.HOLD_DISTANCE, _rest_height(0), -4.0))
	await _wait(SETTLE_SECONDS)
	_key(KEY_SPACE, true)
	await _wait(SETTLE_SECONDS)
	_check(mover.held_item == carried, "Picked up a vase for the wall test")
	_key(KEY_D, true)
	await _wait(WALK_SECONDS)
	var hit_value: int = _value(carried)
	_check(hit_value >= 0 and hit_value < carried.initial_value, "Walking a carried vase into a wall drops its value (₹%d left)" % hit_value)
	await _wait(REST_SECONDS)
	_check(_value(carried) == hit_value, "Holding a vase pressed against a wall does not drain value")
	_key(KEY_D, false)
	_key(KEY_SPACE, false)

	# Loose items sliding into a wall, below and above the threshold.
	await _clear_loot()
	_reset_mover(Vector3(-4.0, MOVER_HEIGHT, 5.0), Vector3.FORWARD)
	var slow_item := _spawn(0, Vector3(6.3, _rest_height(0), -5.0))
	await _wait(SETTLE_SECONDS)
	slow_item.linear_velocity = Vector3.RIGHT
	slow_item.sleeping = false
	await _wait(0.8)
	_check(slow_item.value == 3000, "Low-speed wall contact does not damage loot")

	await _clear_loot()
	var fast_item := _spawn(0, Vector3(5.3, _rest_height(0), -5.0))
	fast_item.rotation.y = PI / 4.0
	await _wait(SETTLE_SECONDS)
	fast_item.linear_velocity = Vector3.RIGHT * 5.0
	fast_item.sleeping = false
	await _wait(0.45)
	var fast_value: int = _value(fast_item)
	_check(fast_value >= 0 and fast_value < 3000, "Rotated-body wall impact reduces value (₹%d left)" % fast_value)

	await _clear_loot()
	var dropped := _spawn(0, Vector3(0.0, 2.5, -5.0))
	await _wait(WALK_SECONDS)
	_check(_value(dropped) < 3000, "Falling from 2.5 m onto the floor causes impact damage")


func _check_resting_contact() -> void:
	await _clear_loot()
	var items: Array[RigidBody3D] = []
	for kind: int in range(3):
		items.append(_spawn(kind, Vector3(-4.0 + kind * 3.0, _rest_height(kind), -5.0)))
	await _wait(REST_SECONDS)
	for item: RigidBody3D in items:
		_check(_value(item) == item.initial_value, "%s resting on the floor takes no damage" % item.item_name)

	# A damaged item settling against a wall must stop losing value once at rest.
	await _clear_loot()
	var bumped := _spawn(0, Vector3(5.3, _rest_height(0), -5.0))
	await _wait(SETTLE_SECONDS)
	bumped.linear_velocity = Vector3.RIGHT * 5.0
	bumped.sleeping = false
	await _wait(WALK_SECONDS)
	var settled_value: int = _value(bumped)
	await _wait(REST_SECONDS)
	_check(settled_value > 0 and _value(bumped) == settled_value, "Resting contact after an impact does not drain value")


# --- Banking ---
func _check_banking() -> void:
	await _clear_loot()
	var truck: Area3D = playground.arena.truck
	var bank_events: Array[int] = []
	truck.banked.connect(func(amount: int, _slot: int) -> void: bank_events.append(amount))

	# Real GRAB release inside the truck.
	_reset_mover(Vector3(5.0, MOVER_HEIGHT, 6.5), Vector3.FORWARD)
	var item := _spawn(0, Vector3(5.0, _rest_height(0), 6.5 - SETTINGS.HOLD_DISTANCE))
	_key(KEY_SPACE, true)
	await _wait(SETTLE_SECONDS)
	_check(mover.held_item == item and truck.banked_value == 0, "Held loot inside the truck is not banked")
	item.apply_impact(3.0)
	var expected: int = item.value
	_key(KEY_SPACE, false)
	await _wait(INPUT_SECONDS)
	_check(truck.banked_value == expected and truck.banked_items == 1 and bank_events.size() == 1, "Releasing GRAB in the truck banks the damaged value exactly once")
	_check(not is_instance_valid(item), "Banked loot despawns")

	# Repeated release and bank calls in the same frame must not double-count.
	_key(KEY_SPACE, true)
	var second := _spawn(0, Vector3(5.0, _rest_height(0), 6.5 - SETTINGS.HOLD_DISTANCE))
	await _wait(SETTLE_SECONDS)
	_check(mover.held_item == second, "Picked up a second vase in the truck")
	second.release()
	second.release()
	var repeat_bank: bool = truck.try_bank(second)
	_check(not repeat_bank and truck.banked_value == expected + 3000 and truck.banked_items == 2 and bank_events.size() == 2, "Repeated release and bank requests cannot double-count")
	_key(KEY_SPACE, false)
	await _wait(INPUT_SECONDS)
	_check(truck.banked_items == 2 and bank_events.size() == 2, "Banking stays at two items after the frame ends")

	# Loose loot sliding into the truck is not banked.
	await _clear_loot()
	var loose := _spawn(0, Vector3(4.0, _rest_height(0), 5.0))
	await _wait(SETTLE_SECONDS)
	loose.linear_velocity = Vector3.RIGHT * 2.0
	loose.sleeping = false
	await _wait(WALK_SECONDS)
	_check(truck.contains_point(loose.global_position) and truck.banked_items == 2, "Loose loot entering the truck is not automatically banked")


# --- Phone integration ---
func _check_phone_release_and_hud() -> void:
	await _clear_loot()
	var index: int = await _connect_phone("Carry test")
	_check(_welcome_slot(index) == 0, "First phone controls mover 1")
	_reset_mover(Vector3(0.0, MOVER_HEIGHT, 0.0), Vector3.FORWARD)
	var item := _spawn(0, Vector3(0.0, _rest_height(0), -SETTINGS.HOLD_DISTANCE))
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "btn", "b": "grab", "down": true})
	inboxes[index].clear()
	await _wait(SETTLE_SECONDS)
	_check(mover.held_item == item, "Phone GRAB reaches the real carrying controller")
	var held_huds: int = 0
	for message: Dictionary in inboxes[index]:
		if message.get("type") == "hud" and message.get("held") == "Antique vase" and message.get("value") == item.value:
			held_huds += 1
	_check(held_huds >= 3 and held_huds <= 6, "Phone receives held name/value at the HUD cadence (%d messages)" % held_huds)

	heartbeat = false
	await _wait(SETTINGS.INPUT_TIMEOUT_MS / 1000.0 + INPUT_SECONDS)
	_check(mover.held_item == null and item.holder == null, "Heartbeat timeout drops carried loot")

	await _clear_loot()
	heartbeat = true
	_reset_mover(Vector3(0.0, MOVER_HEIGHT, 0.0), Vector3.FORWARD)
	item = _spawn(0, Vector3(0.0, _rest_height(0), -SETTINGS.HOLD_DISTANCE))
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "btn", "b": "grab", "down": true})
	await _wait(INPUT_SECONDS)
	_check(mover.held_item == item, "Fresh heartbeat allows grabbing again")
	clients[index].close()
	await _wait(INPUT_SECONDS)
	_check(mover.held_item == null and item.holder == null, "Detected disconnect drops carried loot")


func _check_double_grab() -> void:
	await _clear_loot()
	var first: int = await _connect_phone("Grab A")
	var second: int = await _connect_phone("Grab B")
	var mover_a: CharacterBody3D = playground.movers[_welcome_slot(first)]
	var mover_b: CharacterBody3D = playground.movers[_welcome_slot(second)]
	_check(mover_a != mover_b, "Two phones control two different movers")

	# Both movers face the same vase from opposite sides, within grab range.
	var item := _spawn(0, Vector3(2.0, _rest_height(0), -4.5))
	_place(mover_a, Vector3(2.0, MOVER_HEIGHT, -4.5 + SETTINGS.HOLD_DISTANCE), Vector3.FORWARD)
	_place(mover_b, Vector3(2.0, MOVER_HEIGHT, -4.5 - SETTINGS.HOLD_DISTANCE), Vector3.BACK)
	await _wait(SETTLE_SECONDS)

	# Apply both GRAB messages through Net's own handler in one frame, so they land in the same physics tick.
	var player_a: Dictionary = net.player_for_slot(mover_a.slot)
	var player_b: Dictionary = net.player_for_slot(mover_b.slot)
	net._set_button(player_a, {"type": "btn", "b": "grab", "down": true})
	net._set_button(player_b, {"type": "btn", "b": "grab", "down": true})
	await _wait(SETTLE_SECONDS)
	var holders: int = int(mover_a.held_item == item) + int(mover_b.held_item == item)
	_check(holders == 1 and (item.holder == mover_a or item.holder == mover_b), "Simultaneous GRAB: exactly one mover gets the vase")
	_check(mover_a.held_item == null or mover_b.held_item == null, "The other mover is left empty-handed")
	_send(first, {"type": "btn", "b": "grab", "down": false})
	_send(second, {"type": "btn", "b": "grab", "down": false})
	await _wait(INPUT_SECONDS)


# --- Price tags ---
func _check_price_tags() -> void:
	# A tag stays hidden until a mover comes within PRICE_SHOW_DISTANCE, then fades in.
	await _clear_loot()
	_park_other_movers()
	_reset_mover(Vector3(0.0, MOVER_HEIGHT, 3.0), Vector3.FORWARD)
	var item := _spawn(0, Vector3(4.0, _rest_height(0), -4.0))
	await _wait(SETTLE_SECONDS)
	_check(not item.price_label.visible, "A price tag is hidden while nobody is near")
	_reset_mover(Vector3(4.0, MOVER_HEIGHT, -2.5), Vector3.FORWARD)
	await _wait(SETTINGS.PRICE_FADE_TIME + 0.2)
	_check(item.price_label.visible and item.price_label.modulate.a > SETTINGS.PRICE_OPACITY - 0.05, "A mover walking up to an item reveals its price tag")
	_reset_mover(Vector3(0.0, MOVER_HEIGHT, 3.0), Vector3.FORWARD)
	await _wait(SETTINGS.PRICE_FADE_TIME + 0.2)
	_check(not item.price_label.visible, "The tag fades away again once the mover leaves")


# --- Test helpers ---
func _spawn(kind: int, location: Vector3) -> RigidBody3D:
	var item: RigidBody3D = loot_scene.instantiate()
	item.loot_kind = kind
	item.position = location
	playground.add_child(item)
	return item


func _rest_height(kind: int) -> float:
	return SETTINGS.LOOT_SIZES[kind].y / 2.0 + SETTINGS.LOOT_SPAWN_CLEARANCE


func _value(item: RigidBody3D) -> int:
	# A shattered or banked item has been freed; report it as worthless.
	return item.value if is_instance_valid(item) else 0


func _track_carry(item: RigidBody3D, seconds: float) -> Dictionary:
	# Records the worst speed, height and distance from the carry target over real physics ticks.
	var record: Dictionary = {"speed": 0.0, "height": 0.0, "distance": 0.0}
	for tick: int in range(int(seconds * Engine.physics_ticks_per_second)):
		await physics_frame
		if not is_instance_valid(item):
			return record
		record.speed = maxf(record.speed, (item.linear_velocity - mover.velocity).length())
		record.height = maxf(record.height, item.global_position.y)
		if item.holder != null:
			record.distance = maxf(record.distance, item.global_position.distance_to(item.carry_target()))
	return record


func _is_calm(record: Dictionary) -> bool:
	return record.speed < LAUNCH_SPEED and record.height < LAUNCH_HEIGHT and record.distance < SWING_DISTANCE


func _describe(record: Dictionary) -> String:
	return "peak %.2f m/s relative, top %.2f m, off target %.2f m" % [record.speed, record.height, record.distance]


func _reset_mover(location: Vector3, direction: Vector3) -> void:
	_place(mover, location, direction)
	router.selected_slot = 0
	router.has_focus = true


func _place(target: CharacterBody3D, location: Vector3, direction: Vector3) -> void:
	target.position = location
	target.velocity = Vector3.ZERO
	target.facing = direction
	target.grab_released = true
	target._update_hold_point()


func _park_other_movers() -> void:
	for other: CharacterBody3D in playground.movers:
		if other != mover:
			_place(other, Vector3(-6.0 + other.slot * 2.0, MOVER_HEIGHT, 8.0), Vector3.FORWARD)


func _clear_furniture() -> void:
	# The ghost's furniture has its own check; carrying is tested in an empty room.
	for prop: Node in get_nodes_in_group("furniture"):
		prop.queue_free()
	await _wait(INPUT_SECONDS)


func _clear_loot() -> void:
	for key: Key in [KEY_SPACE, KEY_E, KEY_SHIFT, KEY_D, KEY_A]:
		_key(key, false)
	for item: Node in get_nodes_in_group("carryables"):
		item.queue_free()
	await _wait(INPUT_SECONDS)


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_poll_phones()
		await process_frame


# --- Phone helpers ---
func _connect_phone(player_name: String) -> int:
	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	clients.append(client)
	inboxes.append([])
	var index: int = clients.size() - 1
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "hello", "name": player_name, "key": net.session_key})
	await _wait(INPUT_SECONDS)
	heartbeat = true
	_send(index, {"type": "ready"})
	await _wait(INPUT_SECONDS)
	return index


func _welcome_slot(index: int) -> int:
	for message: Dictionary in inboxes[index]:
		if message.get("type") == "welcome":
			return int(message.slot)
	return -1


func _poll_phones() -> void:
	var send_heartbeat: bool = heartbeat and Time.get_ticks_msec() >= next_heartbeat
	for index: int in range(clients.size()):
		var client: WebSocketPeer = clients[index]
		client.poll()
		while client.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(client.get_packet().get_string_from_utf8())
			if message is Dictionary:
				inboxes[index].append(message)
		if send_heartbeat:
			_send(index, {"type": "in", "x": 0, "y": 0})
	if send_heartbeat:
		next_heartbeat = Time.get_ticks_msec() + int(1000.0 / SETTINGS.INPUT_RATE)


func _send(index: int, message: Dictionary) -> void:
	if clients[index].get_ready_state() == WebSocketPeer.STATE_OPEN:
		clients[index].send_text(JSON.stringify(message))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
