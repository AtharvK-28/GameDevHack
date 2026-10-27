# The Museum check's body (run by core/museum_check.gd), on the Ship check's world and movement helpers.
extends "res://core/ship_checks.gd"

# Walks from the van into each gallery: the long way round through the lobby's front door and the grand hall.
const LOBBY: Array[Vector2] = [Vector2(8, 22.6), Vector2(26.5, 22.6), Vector2(26.5, 17.5), Vector2(15, 17.5), Vector2(15, 11.5)]
const GALLERIES: Dictionary = {
	"Rotunda": [Vector2(15, 6.5)],
	"Art Gallery": [Vector2(12, 11.5), Vector2(6, 11.5)],
	"Egypt": [Vector2(12, 11.5), Vector2(5, 11.5), Vector2(5, 6.5)],
	"Space Gallery": [Vector2(18, 11.5), Vector2(23.5, 10.5)],
	"Jurassic Hall": [Vector2(18, 11.5), Vector2(25, 10.5), Vector2(25, 5.5)],
}
# The skull's way out: down from the rotunda, across the lobby, along the laser hall and out of its door to the van.
# The first leg slides it straight off the plinth before the pair turns it, so nobody swings into the plinth.
const SKULL_ROUTE: Array[Vector2] = [Vector2(15, 5.8), Vector2(15, 11.5), Vector2(15, 17.3), Vector2(9, 17.3), Vector2(2.1, 17.3), Vector2(2.1, 21.4)]

func run() -> int:
	router = get_tree().root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Museum.tscn")
	get_tree().root.add_child(world)
	arena = world.arena
	await _frames(120)

	# --- The loot pool ---
	var items: Array = get_tree().get_nodes_in_group("loot")
	var total: int = 0
	var skulls: int = 0
	for item: Loot in items:
		total += item.initial_value
		skulls += int(item.weight_class == SETTINGS.TWO_PERSON)
	_check(items.size() == 12 and total == 88000 and skulls == 1, "The full Museum pool is 12 items worth ₹88,000 with one T-Rex skull (%d, ₹%d)" % [items.size(), total])
	for item: Loot in items:
		var spot: Dictionary = _spot_under(item)
		var resting: float = item.global_position.y - item.item_size.y / 2.0
		_check(not spot.is_empty() and absf(resting - float(spot.get("floor", 0.0))) < 0.25, "%s rests on its spot (%.2f m, expected %.2f m)" % [item.item_name, resting, float(spot.get("floor", 0.0))])
	for players: int in [2, 3, 4]:
		var random := RandomNumberGenerator.new()
		random.seed = 321
		var pick: Array[Dictionary] = Catalog.pick_loot(&"museum", arena.layout.spawns.loot, SETTINGS.LOOT_COUNTS[players - 2], SETTINGS.HEAVY_LOOT_LIMITS[players - 2], random)
		var two_person: int = pick.filter(func(placement: Dictionary) -> bool: return placement.item.weight_class == SETTINGS.TWO_PERSON).size()
		var heavy: int = pick.filter(func(placement: Dictionary) -> bool: return placement.item.weight_class == SETTINGS.HEAVY).size()
		_check(pick.size() == SETTINGS.LOOT_COUNTS[players - 2] and two_person == 1 and heavy <= SETTINGS.HEAVY_LOOT_LIMITS[players - 2], "A seeded %d-player round has %d items and one skull" % [players, SETTINGS.LOOT_COUNTS[players - 2]])
	_check(world.camera.arena_yaw == SETTINGS.MUSEUM_CAMERA_YAW, "The Museum gets its own camera angle")
	_check(arena.truck != null and arena.get_node_or_null("Van") != null, "The van is parked at the loading dock with its delivery zone")
	await _clear_props()

	# --- Every gallery is reachable from the van ---
	for room: String in GALLERIES:
		_place(0, Vector2(6.0, 22.5))
		await _frames(5)
		var points: Array = LOBBY + GALLERIES[room]
		var reached: bool = await _walk(0, points)
		var mover: CharacterBody3D = world.movers[0]
		_check(reached and arena.room_at(mover.global_position) == room, "A mover walks from the van into the %s" % room)

	# --- The skull through the laser hall to the van ---
	var skull := _museum_loot("skull", Vector2(15, 3.6), 0.5)
	await _frames(30)
	for slot: int in [0, 1]:
		_place(slot, Vector2(15 + (-1.7 if slot == 0 else 1.7), 3.6))
		var mover: CharacterBody3D = world.movers[slot]
		mover.facing = Vector3.RIGHT if slot == 0 else Vector3.LEFT
		mover._update_hold_point()
		skull.try_grab(mover, mover.hold_point, slot)
		mover.held_item = skull
		_set_input(slot, Vector2.ZERO, true)
	await _frames(60)
	_check(skull.holder_count() == 2, "Two movers lift the T-Rex skull off its plinth")
	var route_ok: bool = true
	for target: Vector2 in SKULL_ROUTE:
		route_ok = await _carry_skull(skull, target, target != SKULL_ROUTE[0])
		if not route_ok:
			print("Skull stopped at ", skull.position if is_instance_valid(skull) else "freed", " aiming for ", target)
			break
	_check(route_ok, "Two movers carry the skull down the hall, through the laser hall and out of its door")
	if route_ok:
		var banked: int = arena.truck.banked_items
		for slot: int in [0, 1]:
			_set_input(slot, Vector2.ZERO, false)
		await _frames(20)
		_check(arena.truck.banked_items == banked + 1, "The skull banks at the van")
	for slot: int in [0, 1]:
		_set_input(slot, Vector2.ZERO, false)
	await _clear_props()

	# --- The moon rock floats ---
	var rock := _museum_loot("moon_rock", Vector2(15, 11.5), 0.0)
	var stone := _museum_loot("golden_mask", Vector2(16, 13.5), 0.0)
	await _frames(30)
	_check(rock is MoonRock, "The moon rock has its own behaviour")
	for item: Loot in [rock, stone]:
		item.position.y = 3.0
		item.linear_velocity = Vector3.ZERO
		item.thrown = true
		item.gravity_scale = SETTINGS.MOON_ROCK_GRAVITY if item == rock else 1.0
	await _frames(30)
	_check(rock.position.y > stone.position.y + 0.8, "Thrown, the moon rock drifts down far slower than other loot (%.1f m against %.1f m)" % [rock.position.y, stone.position.y])

	world.queue_free()
	await _frames(3)
	return failures


# --- Helpers ---
func _museum_loot(kind: String, at: Vector2, floor_height: float) -> Loot:
	var item: Loot = LOOT.instantiate()
	var entry: CatalogItem = load("res://props/catalog/museum/%s.tres" % kind)
	if entry.loot_script != null:
		item.set_script(entry.loot_script)
	item.catalog_item = entry
	item.position = Vector3(at.x, floor_height + entry.footprint.y / 2.0 + 0.03, at.y)
	arena.add_child(item)
	return item


func _spot_under(item: Loot) -> Dictionary:
	for spot: Dictionary in arena.layout.spawns.loot:
		if Vector2(spot.at[0], spot.at[1]).distance_to(Vector2(item.global_position.x, item.global_position.z)) < 0.3:
			return spot
	return {}


# Steers the pair so the skull's centre follows the waypoint, turning its long axis along the way it travels.
func _carry_skull(skull: Loot, target: Vector2, turn: bool) -> bool:
	for frame: int in range(ROUTE_FRAMES):
		if not is_instance_valid(skull) or skull.holder_count() != 2:
			return false
		var gap: Vector2 = target - Vector2(skull.position.x, skull.position.z)
		if gap.length() < ARRIVAL:
			for slot: int in [0, 1]:
				_set_input(slot, Vector2.ZERO, true)
			await _frames(12)
			return true
		var travel: Vector2 = gap.normalized()
		var axis := Vector2(skull.global_basis.x.x, skull.global_basis.x.z).normalized()
		var desired := Vector2(signf(travel.x), 0.0) if absf(travel.x) > absf(travel.y) else Vector2(0.0, signf(travel.y))
		if axis.dot(desired) < 0:
			desired = -desired
		var rotation_error: float = axis.cross(desired) if turn else 0.0
		for slot: int in [0, 1]:
			var sign_value: float = -1.0 if slot == 0 else 1.0
			var tangent := Vector2(-axis.y, axis.x) * sign_value
			_set_input(slot, (travel * (0.0 if absf(rotation_error) > 0.2 else 0.65) + tangent * rotation_error * 0.8).limit_length(), true)
		await get_tree().physics_frame
	return false
