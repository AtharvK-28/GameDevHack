# Verifies Light the Lanterns on the Ghost Ship with real Jolt bodies: seeded can spots, clearances, a real
# carry over the gangplank to a post, release-only delivery, the ghost handicap, deck lighting and restart.
extends SceneTree

# --- Check settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const ROUND_SEED: int = 1357
const CHECK_SECONDS: float = 0.6
const SURFACE_GAP: float = 0.04
const ROUTE_TIMEOUT: float = 12.0 # Seconds allowed for each route waypoint.
const ROUTE_TOLERANCE: float = 0.15

# --- Check state ---
var world: Node3D
var arena: Node3D
var game: Node
var router: Node
var failures: int = 0

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	router = root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	game.set_process(false)
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Ship.tscn")
	root.add_child(world)
	await _wait(1.5)
	_check(world.arena.generator == null, "Outside a match the Ship has no lantern task")
	game.host = world
	game.participants.assign([0, 1])
	game.phase = "live"
	world.setup_match_round(ROUND_SEED, game.participants, 0)
	arena = world.arena
	arena.wave_left = INF # Waves and motion are checked by the Ship check; keep this carry route calm and level.
	arena.motion_scale = 0.0
	await _wait(CHECK_SECONDS * 2.0)
	_check_spots()
	_check_clearance()
	await _check_carry_and_delivery()
	await _check_power()
	await _check_reset()
	world.queue_free()
	await process_frame
	print("LANTERN CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Seeded placement ---
func _check_spots() -> void:
	_check(arena.generator != null and arena.generator.posts.size() == 3, "A match builds three lantern posts")
	_check(get_nodes_in_group("task_batteries").size() == 3, "Exactly three oil cans spawn in a match")
	var initial: Array = arena.oil_can_spots()
	var seen: Dictionary = {}
	for seed_value: int in 60:
		arena.spawn_seed = seed_value
		var chosen: Array = arena.oil_can_spots()
		var unique: Dictionary = {}
		for spot: Vector3 in chosen:
			unique[spot] = true
			seen[spot] = true
		_check(chosen.size() == 3 and unique.size() == 3, "Seed %d picks three distinct can spots" % seed_value)
	arena.spawn_seed = ROUND_SEED
	_check(initial == arena.oil_can_spots(), "The same seed picks the same spots")
	_check(seen.size() == SETTINGS.OIL_CAN_SPOTS.size(), "Different seeds use every can spot")
	for can: Node3D in get_nodes_in_group("task_batteries"):
		_check(can.position.y > SETTINGS.SHIP_WATER_Y and can.linear_velocity.length() < 0.2, "An oil can rests on its deck at %s" % can.spawn_position)


func _check_clearance() -> void:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	for node: Node in get_nodes_in_group("task_batteries"):
		excluded.append(node.get_rid())
	for mover: Node in world.movers:
		excluded.append(mover.get_rid())
	for spot: Vector3 in SETTINGS.OIL_CAN_SPOTS:
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = SETTINGS.OIL_CAN_SIZE
		query.shape = box
		query.transform.origin = spot + Vector3.UP * (SETTINGS.OIL_CAN_SIZE.y / 2.0 + SURFACE_GAP)
		query.collision_mask = SETTINGS.WORLD_LAYER
		query.exclude = excluded
		_check(space.intersect_shape(query).is_empty(), "Can spot %s is clear of the hull and furniture" % spot)
		var clear: bool = true
		for loot_spot: Dictionary in arena.layout.spawns.loot:
			clear = clear and Vector2(spot.x - loot_spot.at[0], spot.z - loot_spot.at[1]).length() > 1.2
		_check(clear, "Can spot %s stays apart from every loot anchor" % spot)
	var area: Array = arena.layout.delivery.rect # Built here: naming ArenaBuilder would compile it before the autoloads.
	var delivery := Rect2(area[0], area[1], area[2], area[3])
	for index: int in SETTINGS.LANTERN_POST_SPOTS.size():
		var spot: Vector3 = SETTINGS.LANTERN_POST_SPOTS[index]
		var at := Vector2(spot.x, spot.z)
		var mark := Rect2(at - Vector2(SETTINGS.LANTERN_ZONE_SIZE.x, SETTINGS.LANTERN_ZONE_SIZE.z) / 2.0, Vector2(SETTINGS.LANTERN_ZONE_SIZE.x, SETTINGS.LANTERN_ZONE_SIZE.z))
		_check(not mark.intersects(delivery), "Lantern mark %d stays off the amber delivery area" % index)
		var spawns_clear: bool = true
		for spawn: Array in arena.layout.spawns.movers:
			spawns_clear = spawns_clear and not mark.grow(SETTINGS.CAPSULE_RADIUS).has_point(Vector2(spawn[0], spawn[1]))
		_check(spawns_clear, "Lantern mark %d leaves every tug spawn clear" % index)


# --- Carrying and release-only delivery ---
func _check_carry_and_delivery() -> void:
	var posts: Node3D = arena.generator
	var mover: CharacterBody3D = world.movers[1]
	var can: RigidBody3D = get_nodes_in_group("task_batteries")[0]
	_check(can.weight_class == SETTINGS.MEDIUM and not can.can_throw(), "An oil can is a medium carry and cannot be thrown")
	_check(not can.is_in_group("loot") and can.get_node_or_null("Possessable") == null, "An oil can has no value and cannot be possessed")
	can._on_impact(20.0)
	_check(not can.finished, "Impacts cannot destroy an oil can")
	can.position = Vector3(14, SETTINGS.SHIP_WATER_Y - 0.5, 12)
	await _wait(CHECK_SECONDS)
	_check(can.position.distance_to(can.spawn_position) < 0.1, "A can lost overboard returns to its spawn")

	var post: Vector3 = posts.to_global(posts.posts[0])
	can.position = post + Vector3.UP * SETTINGS.OIL_CAN_SIZE.y / 2.0
	can.linear_velocity = Vector3.ZERO
	await _wait(CHECK_SECONDS)
	_check(posts.delivered == 0, "A loose can sliding onto a post does not count")

	# A real carry from the main deck over the gangplank onto the tug, ending at the left post.
	mover.position = Vector3(12.0, SETTINGS.CAPSULE_HEIGHT / 2.0, 9.0)
	mover.facing = Vector3.BACK
	mover._update_hold_point()
	can.position = mover.hold_point.global_position
	can.linear_velocity = Vector3.ZERO
	await _wait(0.1)
	_check(can.try_grab(mover, mover.hold_point, 1), "A mover can pick up an oil can")
	mover.held_item = can
	router.for_slot(1).buttons.grab = true
	_check(is_equal_approx(mover.movement_speed(), SETTINGS.MOVER_SPEED * SETTINGS.CARRY_SPEEDS[SETTINGS.MEDIUM]), "A can slows its mover to the medium carry speed")
	_check(not posts.try_deliver(can), "A held can cannot be delivered")
	for waypoint: Vector2 in [Vector2(12.0, 15.0), Vector2(10.2, 18.2), Vector2(9.9, 18.2)]:
		await _walk_to(mover, waypoint)
	await _wait(CHECK_SECONDS)
	_check(posts.contains_point(can.global_position) and can.is_held(), "A can carried over the gangplank reaches a lantern post")
	var banked: int = arena.truck.banked_value
	var loot_total: int = get_nodes_in_group("loot").size()
	can.release()
	_check(posts.delivered == 1 and posts.lit[0] and not posts.powered, "The first release lights one post only")
	_check(not posts.try_deliver(can) and posts.delivered == 1, "A can cannot count twice")
	router.for_slot(1).buttons.grab = false
	mover.held_item = null
	await _wait(CHECK_SECONDS)
	_check(arena.truck.banked_value == banked and get_nodes_in_group("loot").size() == loot_total, "Lighting a post changes no money or loot")
	_check(posts.post_at(post + Vector3.UP * 0.3) == -1, "A lit post accepts no more oil")

	world.ghost.hauntings[0].cooldown_left = 10.0
	var remaining: Array = get_nodes_in_group("task_batteries").filter(func(node: Node) -> bool: return not node.finished)
	for index: int in remaining.size():
		var other: RigidBody3D = remaining[index]
		other.position = posts.to_global(posts.posts[index + 1]) + Vector3.UP * SETTINGS.OIL_CAN_SIZE.y / 2.0
		other.linear_velocity = Vector3.ZERO
		other.try_grab(mover, mover.hold_point, 1)
		other.release()
	_check(posts.delivered == 3 and posts.powered, "Three lit posts complete the task, the stern castle one included")
	_check(is_equal_approx(world.ghost.hauntings[0].cooldown_left, 15.0), "Lighting the lanterns stretches the running Gust cooldown")


# --- Ghost and lighting ---
func _check_power() -> void:
	var ghost: Node3D = world.ghost
	_check(ghost.generator_powered, "The ghost receives the lantern handicap")
	_check(is_equal_approx(ghost.movement_speed(), SETTINGS.WISP_SPEED * SETTINGS.GENERATOR_SPEED_RATIO), "The free ghost flies slower")
	_check(is_equal_approx(ghost.hauntings[0].cooldown, SETTINGS.SHIP_GUST_COOLDOWN * SETTINGS.GENERATOR_COOLDOWN_RATIO), "Gust of Wind cools down slower")
	await _wait(SETTINGS.GENERATOR_LIGHT_FADE + 0.2)
	var environment: Environment = arena.get_node("ShipEnvironment/WorldEnvironment").environment
	_check(is_equal_approx(environment.ambient_light_energy, SETTINGS.SHIP_AMBIENT_ENERGY * SETTINGS.GENERATOR_AMBIENT_RATIO), "The deck's ambient light brightens")
	var sky: Node = arena.get_node("ShipEnvironment")
	_check(is_equal_approx(sky.moon.light_energy, SETTINGS.SHIP_MOON_ENERGY * SETTINGS.GENERATOR_MOON_RATIO), "The moon brightens")
	sky.flash_lightning()
	await _wait(SETTINGS.SHIP_LIGHTNING_DURATION + 0.2)
	_check(is_equal_approx(sky.moon.light_energy, SETTINGS.SHIP_MOON_ENERGY * SETTINGS.GENERATOR_MOON_RATIO), "Lightning returns to the brighter moon")
	var lamps: Array[Node] = arena.get_node("ShipRig/ShipDressing").find_children("*", "OmniLight3D", true, false)
	_check(lamps.size() <= 8 and lamps.all(func(lamp: OmniLight3D) -> bool: return is_equal_approx(lamp.light_energy, SETTINGS.SHIP_LAMP_ENERGY * SETTINGS.LANTERN_LAMP_RATIO)), "Deck lamps brighten without adding lights")
	_check(arena.generator.hud_text() == "Lanterns lit", "The HUD names the finished task")


# --- Reset ---
func _check_reset() -> void:
	var spots: Array = arena.oil_can_spots()
	world.setup_match_round(ROUND_SEED, game.participants, 0)
	arena = world.arena
	await _wait(CHECK_SECONDS)
	_check(not arena.generator.powered and arena.generator.delivered == 0, "Restart unlights every post")
	_check(arena.oil_can_spots() == spots and get_nodes_in_group("task_batteries").size() == 3, "Restart restores the same three cans")
	_check(not world.ghost.generator_powered, "Restart restores the ghost's full strength")


# --- Helpers ---
func _walk_to(mover: CharacterBody3D, target: Vector2) -> void:
	var deadline: int = Time.get_ticks_msec() + int(ROUTE_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var offset: Vector2 = target - Vector2(mover.position.x, mover.position.z)
		if offset.length() < ROUTE_TOLERANCE:
			router.for_slot(1).direction = Vector2.ZERO
			return
		router.for_slot(1).direction = offset.normalized() * minf(1.0, offset.length())
		await physics_frame
	router.for_slot(1).direction = Vector2.ZERO
	_check(false, "Can route reaches %s" % target)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _check(ok: bool, description: String) -> void:
	print("PASS: " if ok else "FAIL: ", description)
	if not ok:
		failures += 1
