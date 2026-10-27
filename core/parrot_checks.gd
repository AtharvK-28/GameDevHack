# The parrot check's body (run by core/parrot_check.gd), on the Ship check's world and helpers.
extends "res://core/ship_checks.gd"

const CIRCLE_CENTRE := Vector2(11.8, 6.6) # Open main deck, clear of the masts and the castle steps.
const CIRCLE_RADIUS: float = 2.0 # The carried parrot swings about a metre outside the circle.

func run() -> int:
	router = get_tree().root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Ship.tscn")
	get_tree().root.add_child(world)
	arena = world.arena
	arena.motion_scale = 0.0
	await _frames(90)

	# --- Spawning ---
	var spawned: Array = get_tree().get_nodes_in_group("loot").filter(func(item: Node) -> bool: return item is Parrot)
	_check(spawned.size() == 1 and spawned[0].value == _parrot_value(), "The full Ship pool has one parrot worth ₹4,000")
	_check(spawned.size() == 1 and arena.room_at(spawned[0].global_position) == "Quarterdeck", "The parrot starts on the quarterdeck")
	for players: int in [2, 3, 4]:
		for round_seed: int in [1, 77, 123]:
			var random := RandomNumberGenerator.new()
			random.seed = round_seed
			var pick: Array[Dictionary] = Catalog.pick_loot(&"ship", arena.layout.spawns.loot, SETTINGS.LOOT_COUNTS[players - 2], SETTINGS.HEAVY_LOOT_LIMITS[players - 2], random)
			var parrots: int = pick.filter(func(placement: Dictionary) -> bool: return placement.item.id == &"ship_parrot").size()
			_check(parrots == 1 and pick.size() == SETTINGS.LOOT_COUNTS[players - 2], "A seeded %d-player round (seed %d) has the parrot" % [players, round_seed])
	# Perches keep clear of everything else placed on deck, so a landing never sits on loot or a lantern task spot.
	var anchors: Array[Vector2] = []
	for spot: Dictionary in arena.layout.spawns.loot:
		if spot.role != "parrot":
			anchors.append(Vector2(spot.at[0], spot.at[1]))
	for point: Vector3 in SETTINGS.OIL_CAN_SPOTS + SETTINGS.LANTERN_POST_SPOTS:
		anchors.append(Vector2(point.x, point.z))
	for spot: Dictionary in arena.layout.spawns.perches:
		var nearest: float = INF
		for anchor: Vector2 in anchors:
			nearest = minf(nearest, anchor.distance_to(Vector2(spot.at[0], spot.at[1])))
		_check(nearest > 1.2, "Perch %s keeps 1.2 m clear of loot spots, oil-can spots and lantern posts (%.1f m)" % [spot.id, nearest])
	_check(get_tree().root.get_node("Sfx").sounds.has("squawk"), "The parrot has its squawk")
	_check(pow(SETTINGS.BOT_CARRY_STICK, SETTINGS.STICK_RESPONSE_EXPONENT) < SETTINGS.PARROT_CALM_RATIO, "Bots carry slower than the parrot's limit, so they never scare it")
	await _clear_props()

	# --- A walking carrier keeps it ---
	var mover: CharacterBody3D = world.movers[0]
	var parrot := await _held_parrot()
	await _circle(0, 0.6, 4.0)
	_check(parrot.is_held_by(mover) and not parrot.warned and not parrot.flying, "Walking at 0.6 stick for 4 s: the parrot stays calm in hand")

	# --- Slowing down resets the count ---
	await _circle(0, 1.0, 1.2)
	await _circle(0, 0.0, 0.5)
	await _circle(0, 1.0, 1.2)
	_check(parrot.is_held_by(mover) and not parrot.warned, "Running 1.2 s, stopping, running 1.2 s again: no warning")

	# --- A running carrier gets a warning, then loses it ---
	await _circle(0, 0.0, 0.5)
	var time: float = await _circle_until(0, func() -> bool: return parrot.warned, 4.0)
	_check(parrot.warned and parrot.is_held_by(mover), "Running with it brings the SQUAWK! warning (after %.1f s) while still in hand" % time)
	time = await _circle_until(0, func() -> bool: return parrot.flying, 3.0)
	var took_off: Vector3 = parrot.global_position
	_check(parrot.flying and not parrot.is_held() and absf(time - SETTINGS.PARROT_ESCAPE_SECONDS) < 0.3, "Still running %.1f s after the warning, it flies off" % time)
	_set_input(0, Vector2.ZERO)
	await _frames(2)
	_check(mover.held_item == null, "The carrier's hands are empty")
	_check(parrot.grab_point_for(mover) == Vector3.INF and not parrot.try_grab(mover, mover.hold_point, 0), "Nobody can grab it in the air")
	_check(not parrot.get_node("Possessable").can_be_possessed(), "The ghost cannot possess it in the air")
	await _land(parrot)
	_check(not parrot.flying and parrot.value == _parrot_value(), "It lands with its full value")
	_check(parrot.global_position.distance_to(took_off) >= SETTINGS.PARROT_MIN_HOP - 0.5, "It lands at least %.0f m from where it took off" % SETTINGS.PARROT_MIN_HOP)
	_check(_on_a_perch(parrot), "It lands on one of the ship's perches")
	_check(parrot.get_node("Possessable").can_be_possessed(), "Once landed, the ghost may possess it again")

	# --- It refuses to be thrown ---
	parrot.queue_free()
	parrot = await _held_parrot()
	router.snapshots[0].pressed = {"throw": true}
	await _frames(2)
	router.snapshots[0].pressed = {}
	_check(parrot.flying and mover.held_item == null, "THROW: it flies off instead of being thrown")
	await _land(parrot)
	_check(parrot.value == _parrot_value() and _on_a_perch(parrot), "and lands on a perch at full value")

	# --- A hard knock makes it fly, not lose value ---
	parrot.queue_free()
	parrot = await _held_parrot()
	parrot.apply_impact(SETTINGS.DAMAGE_SPEED_THRESHOLD - 0.5)
	_check(not parrot.flying and parrot.is_held(), "A soft bump does nothing")
	parrot.apply_impact(SETTINGS.DAMAGE_SPEED_THRESHOLD + 2.0)
	_check(parrot.flying and parrot.value == _parrot_value(), "A hard knock makes it fly off with its full value")
	await _land(parrot)

	# --- The sea cannot take it ---
	parrot.queue_free()
	await _frames(2)
	parrot = _parrot(Vector2(14.5, 13.8))
	parrot.position.y = SETTINGS.SHIP_WATER_Y - 0.1
	await _frames(3)
	_check(is_instance_valid(parrot) and parrot.flying, "Dropped in the sea, it flies back instead of sinking")
	await _land(parrot)
	_check(is_instance_valid(parrot) and parrot.value == _parrot_value() and parrot.global_position.y > SETTINGS.SHIP_WATER_Y and _on_a_perch(parrot), "and lands on the ship at full value")

	# --- Delivered like any loot ---
	parrot.queue_free()
	_place(0, Vector2(12, 18.3))
	parrot = await _held_parrot(false)
	var banked: int = arena.truck.banked_value
	parrot.release(Vector3.ZERO, mover)
	mover.held_item = null
	await _frames(2)
	_check(arena.truck.banked_value == banked + _parrot_value(), "Put down on the tug, it banks ₹4,000")

	world.queue_free()
	await _frames(3)
	return failures


# --- Helpers ---
func _parrot_value() -> int:
	return load("res://props/catalog/ship/parrot.tres").value


func _parrot(at: Vector2) -> Parrot:
	var item: Loot = LOOT.instantiate()
	item.set_script(load("res://props/parrot.gd"))
	item.catalog_item = load("res://props/catalog/ship/parrot.tres")
	item.position = Vector3(at.x, arena.floor_height_at(Vector3(at.x, 0, at.y)) + item.catalog_item.footprint.y / 2.0 + 0.03, at.y)
	arena.add_child(item)
	return item


# Mover 0 picks up a fresh parrot; by default on the circle's start, where it can run.
func _held_parrot(to_circle: bool = true) -> Parrot:
	var mover: CharacterBody3D = world.movers[0]
	if to_circle:
		_place(0, CIRCLE_CENTRE + Vector2(CIRCLE_RADIUS, 0))
	await _frames(5)
	var at := Vector2(mover.position.x, mover.position.z)
	var parrot := _parrot(at + Vector2(0, 0.6))
	await _frames(5)
	_set_input(0, Vector2.ZERO, true) # Carrying is hold-to-carry: GRAB stays down.
	parrot.try_grab(mover, mover.hold_point, 0)
	mover.held_item = parrot
	await _frames(20)
	return parrot


# Mover 0 runs round the circle at this stick for this long.
func _circle(slot: int, stick: float, seconds: float) -> void:
	await _circle_until(slot, func() -> bool: return false, seconds, stick)


# Runs round the circle until the condition holds or time runs out; returns the seconds taken.
func _circle_until(slot: int, done: Callable, seconds: float, stick: float = 1.0) -> float:
	var mover: CharacterBody3D = world.movers[slot]
	var elapsed: float = 0.0
	while elapsed < seconds:
		if done.call():
			return elapsed
		var at := Vector2(mover.position.x, mover.position.z)
		var out: Vector2 = at - CIRCLE_CENTRE
		var tangent := Vector2(out.y, -out.x).normalized()
		var correction: Vector2 = -out.normalized() * (out.length() - CIRCLE_RADIUS)
		_set_input(slot, (tangent + correction).normalized() * stick if stick > 0.0 else Vector2.ZERO, true)
		await get_tree().physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
	return elapsed


func _land(parrot: Parrot) -> void:
	for frame: int in range(int((SETTINGS.PARROT_FLIGHT_SECONDS + 1.0) * Engine.physics_ticks_per_second)):
		if not is_instance_valid(parrot) or not parrot.flying:
			break
		await get_tree().physics_frame
	await _frames(30)


func _on_a_perch(parrot: Parrot) -> bool:
	for spot: Dictionary in arena.layout.spawns.perches:
		var perch := Vector2(spot.at[0], spot.at[1])
		if perch.distance_to(Vector2(parrot.global_position.x, parrot.global_position.z)) < 0.8:
			return true
	return false
