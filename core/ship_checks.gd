# Real Ship physics checks; shared by the standalone Ship check and the arena layout regression check.
extends Node

const SETTINGS := preload("res://autoload/Balance.gd")
const LOOT := preload("res://props/Loot.tscn")
const ARRIVAL: float = 0.35
const ROUTE_FRAMES: int = 900
var world: Node3D
var arena: Node3D
var router: Node
var failures: int = 0

# --- Check runner ---
func run() -> int:
	router = get_tree().root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Ship.tscn")
	get_tree().root.add_child(world)
	arena = world.arena
	await _frames(90)
	_check(arena.truck != null, "Ship has a tug delivery zone")
	_check(get_tree().get_nodes_in_group("loot").size() == 18, "Full Ship loot pool contains 18 items")
	var total: int = 0
	for item: Loot in get_tree().get_nodes_in_group("loot"):
		total += item.initial_value
		_check(item.position.y > SETTINGS.SHIP_WATER_Y and absf(item.position.y - arena.floor_height_at(item.position) - item.item_size.y / 2.0) < 0.4, "%s settles on its intended deck" % item.item_name)
	_check(total == 74500, "Full Ship pool is worth 74500 rupees")
	_check(arena.room_at(Vector3(11.5, -0.7, 3)) == "Cargo Hold", "Hold has a separate floor-aware progress zone")
	_check(arena.room_at(Vector3(11.5, 0.8, 6)) == "Main Deck", "Main deck zone resolves independently")
	_check(world.camera.arena_yaw == SETTINGS.SHIP_CAMERA_YAW, "Ship gets its approved camera yaw")
	_check(not arena.has_node("Ground"), "No ground collider under the ocean")
	var kinds: Dictionary = {}
	for prop: Node in get_tree().get_nodes_in_group("furniture"):
		kinds[prop.get_node("Possessable").kind] = true
	_check(kinds.size() == 5, "Ship has all five possession types")
	for players: int in [2, 3, 4]:
		var random := RandomNumberGenerator.new()
		random.seed = 123
		var pick: Array[Dictionary] = Catalog.pick_loot(&"ship", arena.layout.spawns.loot, SETTINGS.LOOT_COUNTS[players - 2], SETTINGS.HEAVY_LOOT_LIMITS[players - 2], random)
		var chests: int = 0
		for placement: Dictionary in pick:
			chests += int(placement.item.weight_class == SETTINGS.TWO_PERSON)
		_check(pick.size() == SETTINGS.LOOT_COUNTS[players - 2] and chests == 1, "Seeded %d-player round has the right count and one chest" % players)
	await _clear_props()
	await _check_barrel()
	await _check_walks()
	await _check_chest_route()
	await _check_captain()
	await _check_wind()
	await _check_overboard()
	world.queue_free()
	await _frames(3)
	return failures


# --- Routes and clearances ---
func _check_barrel() -> void:
	var barrel := _loot("barrel", Vector2(14, 8))
	await _frames(20)
	barrel.apply_torque_impulse(Vector3.FORWARD * barrel.mass)
	await _frames(35)
	_check(absf(barrel.rotation.z) > 0.1, "Released rum barrels physically roll")
	barrel.queue_free()
	await _frames(3)


func _check_walks() -> void:
	var routes: Array = [
		[Vector2(2, 8.5), Vector2(7, 8.5), Vector2(10, 8.5), Vector2(14, 8.5), Vector2(14, 16)],
		[Vector2(23, 8.5), Vector2(19, 8.5), Vector2(15, 8.5), Vector2(14, 9), Vector2(14, 16)],
		[Vector2(11.5, 3.8), Vector2(19, 3.8), Vector2(19, 6), Vector2(14, 6), Vector2(14, 16)]
	]
	for index: int in range(routes.size()):
		var route: Array = routes[index]
		_place(0, route[0])
		_check(await _walk(0, route.slice(1)), "Mover route %d reaches the tug through its ramp and gangplank" % index)
		_check(arena.truck.contains_point(world.movers[0].position), "Route ends in the tug's banking area")
	# Every single-person weight climbs and descends the hold ramp while held.
	for kind: String in ["compass", "telescope", "bell"]:
		_place(0, Vector2(18.5, 3))
		var mover: CharacterBody3D = world.movers[0]
		var item := _loot(kind, Vector2(18, 3))
		mover.facing = Vector3.LEFT
		mover._update_hold_point()
		item.try_grab(mover, mover.hold_point, 0)
		mover.held_item = item
		_set_input(0, Vector2.ZERO, true)
		await _frames(35)
		var down: bool = await _walk(0, [Vector2(11.5, 3)])
		var up: bool = await _walk(0, [Vector2(19, 3)])
		_check(down and up and mover.held_item == item, "%s can be carried down and up the hold ramp" % item.item_name)
		mover._let_go()
		item.queue_free()
		await _frames(3)


func _check_chest_route() -> void:
	# Test the complete continuous route, with real two-player steering at the two turns.
	var chest := _loot("chest", Vector2(11.5, 3.8))
	for slot: int in [0, 1]:
		var offset: float = -1.6 if slot == 0 else 1.6
		_place(slot, Vector2(11.5 + offset, 3.8))
		var mover: CharacterBody3D = world.movers[slot]
		mover.facing = Vector3.RIGHT if slot == 0 else Vector3.LEFT
		mover._update_hold_point()
		chest.try_grab(mover, mover.hold_point, slot)
		mover.held_item = chest
		_set_input(slot, Vector2.ZERO, true)
	await _frames(50)
	_check(chest.holder_count() == 2, "Two movers take the chest in the open hold")
	var route_ok: bool = true
	for target: Vector2 in [Vector2(19, 3.8), Vector2(19, 6), Vector2(14, 6), Vector2(14, 8), Vector2(14, 16)]:
		route_ok = await _carry_chest(chest, target) and route_ok
		if not is_instance_valid(chest) or chest.holder_count() < 2:
			break
	_check(route_ok and is_instance_valid(chest) and chest.holder_count() == 2, "Two movers carry the chest from the hold, turn and cross the 2.2 m plank")
	if is_instance_valid(chest):
		var before: int = arena.truck.banked_items
		for slot: int in [0, 1]:
			_set_input(slot, Vector2.ZERO, false)
		await _frames(15)
		_check(arena.truck.banked_items == before + 1, "Chest banks once when its last carrier releases on the tug")


func _carry_chest(chest: Loot, target: Vector2) -> bool:
	for frame: int in range(ROUTE_FRAMES):
		if not is_instance_valid(chest) or chest.holder_count() != 2:
			return false
		var gap: Vector2 = target - Vector2(chest.position.x, chest.position.z)
		if gap.length() < ARRIVAL:
			for slot: int in [0, 1]:
				_set_input(slot, Vector2.ZERO, true)
			await _frames(12)
			return true
		var travel: Vector2 = gap.normalized()
		# Align the chest's long axis with the route while its centre follows the waypoint.
		var axis := Vector2(chest.global_basis.x.x, chest.global_basis.x.z).normalized()
		var desired := Vector2.RIGHT
		if target.y > 10.0:
			desired = Vector2.DOWN
		if axis.dot(desired) < 0:
			desired = -desired
		var rotation_error: float = axis.cross(desired)
		for slot: int in [0, 1]:
			var sign_value: float = -1.0 if slot == 0 else 1.0
			var tangent := Vector2(-axis.y, axis.x) * sign_value
			_set_input(slot, (travel * (0.0 if absf(rotation_error) > 0.2 else 0.65) + tangent * rotation_error * 0.8).limit_length(), true)
		await get_tree().physics_frame
	return false


# --- Wind and rescue ---
# --- The Ghost Ship's own ghost ---
func _check_captain() -> void:
	# The captain is built from shapes with no clips, so the things that would silently break are
	# checked here: his body, his colours, which way he faces and his shadow.
	world.set_ghost_slot(3)
	var ghost: Node3D = world.ghost
	_check(ghost.model is GhostCaptainModel, "The Ghost Ship's ghost is the drowned captain, not the bedsheet wisp")
	var parts: Array[Node] = ghost.model.body.find_children("*", "MeshInstance3D", true, false)
	_check(parts.size() > 10 and ghost.model.materials.size() == parts.size(), "Every one of his parts is ghosted")

	var coloured: bool = true
	for material: ShaderMaterial in ghost.model.materials:
		coloured = coloured and material.get_shader_parameter(&"base_colour") != null
	_check(coloured, "Each part carries its own colour, so he is not washed out to a plain silhouette")

	var shadowed: bool = false
	for part: MeshInstance3D in parts:
		shadowed = shadowed or part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check(not shadowed, "He casts no shadow, which would give the ghost away")

	# He is built facing +Z, so travelling +Z must leave him facing +Z.
	ghost.model.rotation.y = PI
	for frame: int in range(60):
		ghost.model.update_motion(Vector3(0, 0, Balance.WISP_SPEED), 1.0 / 60.0)
	_check(ghost.model.global_basis.z.dot(Vector3.BACK) > 0.9, "He faces the way he flies")

	ghost.model.play_exorcised(1.0)
	_check(ghost.model.is_busy(), "Being blasted out of a prop starts his tumble")
	await _frames(60)
	_check(not ghost.model.is_busy(), "The tumble ends on its own")

	world.set_ghost_slot(-1)
	await _frames(5)


func _check_wind() -> void:
	_place(0, Vector2(14, 8))
	_place(1, Vector2(11, 8))
	world.set_ghost_slot(3)
	var ghost: Node3D = world.ghost
	ghost.demo_rules = true
	ghost.opening_left = 0
	ghost.aim = Vector2(0, 1)
	ghost.energy = SETTINGS.ENERGY_MAX
	ghost._try_haunting(0)
	_check(ghost.hauntings[0].phase == Haunting.Phase.WARNING and not arena.wind_active, "Wind warns before pushing anyone")
	_set_input(0, Vector2.ZERO, false, true)
	_set_input(1, Vector2(0, 1))
	await _frames(80)
	_check(world.movers[1].is_tumbling(), "Walking with the gust tumbles a mover")
	_check(not world.movers[0].is_tumbling() and world.movers[0].position.distance_to(Vector3(14, 0.8, 8)) < 0.3, "Bracing holds a mover against the gust")
	_set_input(0, Vector2(-1, 0))
	await _frames(20)
	_check(not world.movers[0].is_tumbling(), "Walking across the gust is a valid counter")
	await _frames(160)
	_check(not arena.wind_active, "Wind ends and clears its effect")
	world.set_ghost_slot(-1)
	_place(0, Vector2(14, 8))
	_set_input(0, Vector2.ZERO)
	arena.wind_direction = Vector3.BACK
	arena.wind_active = true
	await _frames(60)
	_check(absf(world.movers[0].position.z - 9.0) < 0.2, "Stationary gust drift stays at one metre per second without accelerating")
	arena.wind_active = false


func _check_overboard() -> void:
	_place(0, Vector2(14, 11.5))
	var mover: CharacterBody3D = world.movers[0]
	mover.position.x = 16.0
	await _frames(65)
	_check(arena.rescues.has(0) and not mover.in_play, "Falling off the unrailed plank starts a tug rescue")
	var left: float = arena.rescues.get(0, {}).get("left", 0)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	_check(is_equal_approx(arena.rescues.get(0, {}).get("left", 0), left), "Rescue countdown pauses with arena simulation")
	arena.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(150)
	_check(mover.in_play and mover.position.y > 0 and mover.position.z > 13.6 and mover.held_item == null, "Mover returns to the tug empty-handed after two seconds")
	# A forced release inside the zone still cannot bank an item.
	var forced := _loot("compass", Vector2(14, 16))
	forced.try_grab(mover, mover.hold_point, 0)
	mover.held_item = forced
	var banked_before: int = arena.truck.banked_items
	arena._begin_rescue(mover)
	_check(arena.truck.banked_items == banked_before and not forced.is_held(), "Rescue drops cannot accidentally deliver held loot")
	forced.queue_free()
	var item := _loot("compass", Vector2(16, 12))
	item.position.y = SETTINGS.SHIP_WATER_Y - 0.1
	var item_ref: WeakRef = weakref(item)
	await _frames(3)
	_check(item_ref.get_ref() == null, "Overboard loot is removed once at the fixed water plane")


# --- Helpers ---
func _loot(kind: String, at: Vector2) -> Loot:
	var item: Loot = LOOT.instantiate()
	item.catalog_item = load("res://props/catalog/ship/%s.tres" % kind)
	item.position = Vector3(at.x, arena.floor_height_at(Vector3(at.x, 0, at.y)) + item.catalog_item.footprint.y / 2.0 + 0.03, at.y)
	arena.add_child(item)
	return item


func _place(slot: int, point: Vector2) -> void:
	var mover: CharacterBody3D = world.movers[slot]
	var height: float = arena.floor_height_at(Vector3(point.x, 0, point.y))
	mover.reset_for_round(Vector3(point.x, height + SETTINGS.CAPSULE_HEIGHT / 2.0 + 0.02, point.y), true)
	_set_input(slot, Vector2.ZERO)


func _walk(slot: int, points: Array) -> bool:
	var held: bool = is_instance_valid(world.movers[slot].held_item)
	for target: Vector2 in points:
		var reached: bool = false
		for frame: int in range(ROUTE_FRAMES):
			var position: Vector3 = world.movers[slot].position
			var gap: Vector2 = target - Vector2(position.x, position.z)
			if gap.length() < ARRIVAL:
				reached = true
				break
			_set_input(slot, gap.normalized() * minf(1.0, gap.length()), held)
			await get_tree().physics_frame
		if not reached:
			print("Route stopped at ", world.movers[slot].position, " aiming for ", target)
			return false
	_set_input(slot, Vector2.ZERO, held)
	await _frames(10)
	return true


func _set_input(slot: int, direction: Vector2, grab: bool = false, brace: bool = false) -> void:
	var snapshot = router.snapshots[slot]
	snapshot.direction = direction
	snapshot.buttons = {"grab": grab, "brace": brace}
	snapshot.pressed = {}
	snapshot.released = {}


func _clear_props() -> void:
	for node: Node in get_tree().get_nodes_in_group("loot") + get_tree().get_nodes_in_group("furniture"):
		node.queue_free()
	for mover: CharacterBody3D in world.movers:
		mover.set_in_play(false)
	await _frames(3)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().physics_frame


func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
