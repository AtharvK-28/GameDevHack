# Verifies Battery Run with real Jolt bodies: seeded spots, carrying, release-only delivery, quota isolation,
# the permanent generator effects, pause, restart and all candidate spawn clearances.
extends SceneTree

# --- Check settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const ROUND_SEED: int = 2468
const CHECK_SECONDS: float = 0.6
const SURFACE_GAP: float = 0.04
const ROUTE_TIMEOUT: float = 10.0 # Seconds allowed for each task route waypoint.
const ROUTE_TOLERANCE: float = 0.15 # Metres; tight enough to release within the generator mark.

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
	world.arena_scene = load("res://arenas/Mansion.tscn")
	root.add_child(world)
	arena = world.arena
	await _wait(2.5)
	await _check_clearance()
	game.host = world
	game.participants.assign([0, 1])
	game.phase = "live"
	world.setup_match_round(ROUND_SEED, game.participants, 0)
	arena = world.arena
	await _wait(CHECK_SECONDS)
	_check_spots()
	await _check_clearance()
	await _check_carry_and_delivery()
	await _check_power()
	await _check_reset()
	world.queue_free()
	await process_frame
	print("BATTERY CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Seeded placement ---
func _check_spots() -> void:
	var seen: Dictionary = {}
	var initial: Array = arena.battery_spots()
	_check(arena.layout.spawns.batteries.size() == 10, "Ten authored battery spots")
	_check(get_nodes_in_group("task_batteries").size() == 3, "Exactly three batteries spawn in a match")
	for seed_value: int in 40:
		arena.spawn_seed = seed_value
		var chosen: Array = arena.battery_spots()
		var ids: Dictionary = {}
		for spot: Dictionary in chosen:
			ids[spot.id] = true
			seen[spot.id] = true
		_check(chosen.size() == 3 and ids.size() == 3, "Seed %d selects three distinct spots" % seed_value)
	arena.spawn_seed = ROUND_SEED
	_check(initial == arena.battery_spots(), "Restart seed preserves the three selected spots")
	_check(seen.size() == 10, "Different seeds use the entire ten-spot pool")


func _check_clearance() -> void:
	# Each candidate needs its whole battery volume free above the supporting floor, not just a clear centre.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	for node: Node in get_nodes_in_group("task_batteries"):
		excluded.append(node.get_rid())
	for mover: Node in world.movers:
		excluded.append(mover.get_rid())
	for spot: Dictionary in arena.layout.spawns.batteries:
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = SETTINGS.BATTERY_SIZE
		query.shape = box
		query.transform.origin = Vector3(spot.at[0], spot.floor + SETTINGS.BATTERY_SIZE.y / 2.0 + SURFACE_GAP, spot.at[1])
		query.collision_mask = SETTINGS.WORLD_LAYER | SETTINGS.LOOT_LAYER
		query.exclude = excluded
		_check(space.intersect_shape(query).is_empty(), "Battery spot %s is clear of walls, furniture and spawned loot" % spot.id)
	# Seeded loot can occupy different spots; run every catalog item in its relevant spawn through a footprint check.
	var spots: Array = arena.layout.spawns.loot
	for battery_spot: Dictionary in arena.layout.spawns.batteries:
		var clear: bool = true
		for loot_spot: Dictionary in spots:
			var separation := Vector2(battery_spot.at[0] - loot_spot.at[0], battery_spot.at[1] - loot_spot.at[1])
			clear = clear and separation.length() > SETTINGS.BATTERY_SIZE.length()
		_check(clear, "Battery spot %s stays separate from every loot anchor" % battery_spot.id)


# --- Carrying and release-only delivery ---
func _check_carry_and_delivery() -> void:
	var generator: Area3D = arena.generator
	var mover: CharacterBody3D = world.movers[1]
	var battery: RigidBody3D = get_nodes_in_group("task_batteries")[0]
	_check(battery.weight_class == SETTINGS.HEAVY and not battery.can_throw(), "Battery uses heavy single-person carry and cannot be thrown")
	_check(not battery.is_in_group("loot") and battery.get_node_or_null("Possessable") == null, "Battery has no loot value or possession component")
	battery._on_impact(20.0)
	_check(not battery.finished, "Impacts cannot destroy the battery")
	battery.position.y = SETTINGS.BATTERY_RECOVERY_DEPTH - 1.0
	await _wait(CHECK_SECONDS)
	_check(battery.position.distance_to(battery.spawn_position) < 0.1, "An escaped battery returns to its spawn")
	mover.position = generator.position + Vector3(0, SETTINGS.CAPSULE_HEIGHT / 2.0, -SETTINGS.HOLD_DISTANCE)
	mover.facing = Vector3.BACK
	mover._update_hold_point()
	battery.position = generator.position + Vector3.UP * SETTINGS.BATTERY_SIZE.y / 2.0
	battery.linear_velocity = Vector3.ZERO
	battery.angular_velocity = Vector3.ZERO
	await _wait(CHECK_SECONDS)
	_check(generator.delivered == 0, "A loose battery sliding into the generator does not count")
	_check(battery.try_grab(mover, mover.hold_point, 1), "A mover can pick up the battery")
	mover.held_item = battery
	router.for_slot(1).buttons.grab = true
	_check(is_equal_approx(mover.movement_speed(), SETTINGS.MOVER_SPEED * SETTINGS.CARRY_SPEEDS[SETTINGS.HEAVY]), "Battery slows its mover to the heavy carry speed")
	_check(not generator.try_deliver(battery), "A held battery cannot be delivered")
	# A real heavy carry leaves the house through the front door and approaches the open face of the generator.
	mover.position = Vector3(7.75, 0.8, 13.0)
	mover.facing = Vector3.BACK
	mover._update_hold_point()
	battery.position = Vector3(7.75, 0.5, 14.25)
	battery.linear_velocity = Vector3.ZERO
	await _wait(CHECK_SECONDS)
	for waypoint: Vector2 in [Vector2(7.75, 21.0), Vector2(4.2, 21.0), Vector2(4.2, 20.1)]:
		await _walk_to(mover, waypoint)
	await _wait(CHECK_SECONDS)
	_check(generator.contains_point(battery.global_position) and battery.is_held(), "A heavy battery can be carried through the front door into the generator zone")
	var loot_total: int = get_nodes_in_group("loot").size()
	var banked: int = arena.truck.banked_value
	battery.release()
	_check(generator.delivered == 1 and not generator.powered, "First mover release counts once without powering the generator")
	_check(not generator.try_deliver(battery) and generator.delivered == 1, "Repeated delivery cannot count a battery twice")
	router.for_slot(1).buttons.grab = false
	mover.held_item = null
	await _wait(CHECK_SECONDS)
	_check(arena.truck.banked_value == banked and get_nodes_in_group("loot").size() == loot_total, "Battery delivery changes no money or loot count")
	world.ghost.hauntings[0].cooldown_left = 10.0
	world.ghost.curse_cooldown_left = 5.0
	for remaining: Node3D in get_nodes_in_group("task_batteries"):
		remaining.position = generator.position + Vector3.UP * SETTINGS.BATTERY_SIZE.y / 2.0
		remaining.linear_velocity = Vector3.ZERO
		remaining.try_grab(mover, mover.hold_point, 1)
		remaining.release()
	_check(generator.delivered == 3 and generator.powered, "All three releases power the generator")
	_check(is_equal_approx(world.ghost.hauntings[0].cooldown_left, 15.0) and is_equal_approx(world.ghost.curse_cooldown_left, 7.5), "Powering the generator extends running cooldowns without restarting them")
	await _wait(CHECK_SECONDS)


# --- Ghost and lighting ---
func _check_power() -> void:
	var ghost: Node3D = world.ghost
	_check(ghost.generator_powered, "The current ghost receives the generator handicap")
	_check(is_equal_approx(ghost.movement_speed(), SETTINGS.WISP_SPEED * 0.75), "Free wisp is 25% slower")
	ghost.position = Vector3(2, SETTINGS.WISP_HEIGHT, 24)
	var before: Vector3 = ghost.position
	router.for_slot(0).direction = Vector2.RIGHT
	await _wait(CHECK_SECONDS)
	router.for_slot(0).direction = Vector2.ZERO
	_check(absf(ghost.position.x - before.x - SETTINGS.WISP_SPEED * 0.75 * CHECK_SECONDS) < 0.15, "Real wisp motion uses the reduced flight speed")
	ghost.energy = 0.0
	ghost._update_energy(1.0)
	_check(is_equal_approx(ghost.energy, SETTINGS.MATCH_ENERGY_REGEN[0] * 0.5), "Free-wisp regeneration is halved")
	_check(is_equal_approx(ghost.hauntings[0].cooldown, SETTINGS.SHAKE_COOLDOWN * 1.5), "House Shake cooldown is 50% longer")
	_check(is_equal_approx(ghost.curse_cooldown_duration, SETTINGS.CURSE_COOLDOWN * 1.5), "Curse cooldown is 50% longer")
	ghost.curse_cooldown_left = ghost.curse_cooldown_duration
	ghost.hauntings[0].cooldown_left = ghost.hauntings[0].cooldown
	_check(is_equal_approx(ghost.hud().cd.haunt3, 1.0) and is_equal_approx(ghost.hud().cd.haunt1, 1.0), "Phone cooldown rings use the longer totals")
	ghost.apply_generator_power()
	_check(is_equal_approx(ghost.curse_cooldown_duration, SETTINGS.CURSE_COOLDOWN * 1.5), "Generator power cannot stack")
	ghost.energy = SETTINGS.ENERGY_MAX
	ghost.opening_left = 0.0
	ghost.shared_lock_left = 0.0
	ghost.hauntings[0].cooldown_left = 0.0
	_check(ghost.can_haunt(0), "House Shake remains available when powered")
	var loot: Node3D = get_nodes_in_group("loot")[0]
	ghost.position = loot.position
	ghost.curse_cooldown_left = 0.0
	ghost._update_curse_target()
	_check(ghost.can_curse(), "Curse remains available when powered")
	ghost._try_curse()
	_check(is_equal_approx(ghost.curse_cooldown_left, SETTINGS.CURSE_COOLDOWN * 1.5), "A new Curse starts its extended cooldown")
	ghost.energy = 50.0
	ghost.possess(loot.get_node("Possessable"))
	ghost._update_energy(1.0)
	_check(is_equal_approx(ghost.energy, 50.0 - SETTINGS.POSSESS_DRAIN), "Possession drain is unchanged while powered")
	_check(ghost.can_act(), "Possessed prop actions stay available")
	ghost.leave()
	await _wait(SETTINGS.GENERATOR_LIGHT_FADE)
	_check(is_equal_approx(arena.get_node("WorldEnvironment").environment.ambient_light_energy, SETTINGS.MOOD_AMBIENT_ENERGY * SETTINGS.GENERATOR_AMBIENT_RATIO), "Arena ambient light brightens")
	_check(is_equal_approx(arena.get_node("Moonlight").light_energy, SETTINGS.MOON_ENERGY * SETTINGS.GENERATOR_MOON_RATIO), "Moonlight improves gently")
	var weather: Node = arena.get_node("MansionEnvironment/SkyEvents")
	weather.strike(0.0)
	await _wait(SETTINGS.LIGHTNING_FLASH_TIME * 2.0 + CHECK_SECONDS)
	_check(is_equal_approx(arena.get_node("WorldEnvironment").environment.ambient_light_energy, SETTINGS.MOOD_AMBIENT_ENERGY * SETTINGS.GENERATOR_AMBIENT_RATIO), "Lightning restores powered lighting rather than the old dim baseline")
	paused = true
	var energy: float = ghost.energy
	var cooldown: float = ghost.curse_cooldown_left
	await _wait(CHECK_SECONDS)
	_check(is_equal_approx(ghost.energy, energy) and is_equal_approx(ghost.curse_cooldown_left, cooldown), "Pause freezes ghost regeneration and cooldowns")
	paused = false
	_check(arena.generator.powered, "Generator stays powered after pausing")


# --- Reset ---
func _check_reset() -> void:
	var positions: Array = arena.battery_spots()
	world.setup_match_round(ROUND_SEED, game.participants, 0)
	arena = world.arena
	_check(not arena.generator.powered and arena.generator.delivered == 0, "Restart resets generator progress")
	_check(arena.battery_spots() == positions and get_nodes_in_group("task_batteries").size() == 3, "Restart restores the same three battery spots")
	_check(not world.ghost.generator_powered and is_equal_approx(world.ghost.movement_speed(), SETTINGS.WISP_SPEED), "Restart restores original ghost tuning")
	_check(is_equal_approx(arena.get_node("WorldEnvironment").environment.ambient_light_energy, SETTINGS.MOOD_AMBIENT_ENERGY), "Restart restores dim lighting")


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
	_check(false, "Battery route reaches %s" % target)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _check(ok: bool, description: String) -> void:
	print("PASS: " if ok else "FAIL: ", description)
	if not ok:
		failures += 1
