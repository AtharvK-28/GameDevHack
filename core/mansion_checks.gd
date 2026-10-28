# The Mansion check's body (run by core/mansion_check.gd), on the Ship check's world and movement helpers.
extends "res://core/ship_checks.gd"

const CIRCLE_CENTRE := Vector2(2.5, 18.5) # Open lawn in front of the house; the carried item swings 2.5 m out, clear of the front gate.
const CIRCLE_RADIUS: float = 1.8
const PARKING := Vector2(-6.0, 16.0) # Open lawn west of the house, where the idle movers wait out of the way.

func run() -> int:
	router = get_tree().root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Mansion.tscn")
	get_tree().root.add_child(world)
	arena = world.arena
	await _frames(120)

	# --- The pool ---
	var items: Array = get_tree().get_nodes_in_group("loot")
	var total: int = 0
	for item: Loot in items:
		total += item.initial_value
	_check(items.size() == 21 and total == 91000, "The full Mansion has 21 items worth ₹91,000 (%d, ₹%d)" % [items.size(), total])
	for kind: Script in [CatBox, FishTank, CursedDoll, GrandfatherClock]:
		var found: Array = items.filter(func(item: Node) -> bool: return item.get_script() == kind)
		_check(found.size() == 1, "The Mansion has its %s" % kind.get_global_name())
	for players: int in [2, 3, 4]:
		for round_seed: int in [1, 77, 123]:
			var random := RandomNumberGenerator.new()
			random.seed = round_seed
			var pick: Array[Dictionary] = Catalog.pick_loot(&"mansion", arena.layout.spawns.loot, SETTINGS.LOOT_COUNTS[players - 2], SETTINGS.HEAVY_LOOT_LIMITS[players - 2], random)
			var ids: Array = pick.map(func(placement: Dictionary) -> StringName: return placement.item.id)
			_check(pick.size() == SETTINGS.LOOT_COUNTS[players - 2] and &"cat_box" in ids and &"cursed_doll" in ids and &"grand_piano" in ids, "A seeded %d-player round (seed %d) has the cat in a box, the cursed doll and the piano" % [players, round_seed])
	var sfx: Node = get_tree().root.get_node("Sfx")
	_check(["meow", "slosh", "chime", "giggle"].all(func(sound: String) -> bool: return sfx.sounds.has(sound)), "The cat meows, the tank sloshes, the clock chimes and the doll giggles")

	# --- The ghost may use every furniture kind in a match ---
	world.set_ghost_slot(3)
	await _frames(5)
	var ghost: Node3D = world.ghost
	ghost.demo_rules = true
	var door: Node3D = arena.get_node("MansionDressing/Kitchen/KitchenDoorMount/KitchenDoor")
	ghost.global_position = door.global_position + Vector3(0.3, 0.0, 0.3)
	await _frames(10)
	_check(is_instance_valid(ghost.target) and ghost.target.kind == Possessable.Kind.DOOR, "In a Mansion match the ghost may possess the kitchen door, not only sliders")
	world.set_ghost_slot(-1)
	await _clear_props()

	# --- The cat in a box ---
	_park_others()
	var box := await _held(_mansion_loot("cat_box", CIRCLE_CENTRE + Vector2(CIRCLE_RADIUS, 0.6))) as CatBox
	await _circle(0.6, 3.0)
	_check(box.has_cat and not box.warned, "Walked carefully, the cat stays in its box")
	var start_value: int = box.value
	var leapt: float = await _circle_until(func() -> bool: return not box.has_cat, SETTINGS.CAT_WARN_SECONDS + SETTINGS.CAT_ESCAPE_SECONDS + 2.0)
	_check(not box.has_cat and leapt < SETTINGS.CAT_WARN_SECONDS + SETTINGS.CAT_ESCAPE_SECONDS + 1.0, "Run with it and the cat grumbles, then leaps out (%.1f s)" % leapt)
	_set_input(0, Vector2.ZERO)
	await _frames(5)
	var cats: Array = get_tree().get_nodes_in_group("loot").filter(func(item: Node) -> bool: return item is MansionCat)
	_check(cats.size() == 1 and box.value + cats[0].value == start_value and box.value == roundi(start_value * SETTINGS.CAT_BOX_SHARE) and box.value == box.initial_value,
			"The empty box keeps %d%% and the cat takes the rest; nothing is lost" % roundi(SETTINGS.CAT_BOX_SHARE * 100))
	if cats.size() == 1:
		var cat: Loot = cats[0]
		await _frames(60)
		var cat_start: Vector3 = cat.global_position
		_place(1, Vector2(cat_start.x + 1.2, cat_start.z))
		await _frames(50)
		_check(cat.global_position.distance_to(cat_start) > 0.8, "Come near the cat and it runs (%.1f m)" % cat.global_position.distance_to(cat_start))
		var cat_value: int = cat.value
		cat._lose_value(500)
		_check(cat.value == cat_value, "A knock only makes the cat hiss: it never loses value")
	await _clear_props()
	var knocked := _mansion_loot("cat_box", Vector2(8.0, 19.0))
	await _frames(20)
	knocked.apply_impact(SETTINGS.CAT_STARTLE_SPEED + 0.5)
	await _frames(3)
	_check(not knocked.has_cat, "A hard knock makes the cat leap out too")
	await _clear_props()

	# --- The fish tank ---
	_park_others()
	var tank := await _held(_mansion_loot("fish_tank", CIRCLE_CENTRE + Vector2(CIRCLE_RADIUS, 0.6))) as FishTank
	await _circle(0.6, 3.0)
	_check(tank.value == tank.initial_value, "Walked carefully, the fish tank keeps every drop")
	await _circle(1.0, 3.0)
	var floor_value: int = ceili(tank.initial_value * SETTINGS.FISH_TANK_FLOOR_SHARE)
	_check(tank.value < tank.initial_value and tank.value > floor_value and tank.water.scale.y < 1.0, "Run with it and it sloshes, spilling value and water (₹%d left)" % tank.value)
	tank.value = floor_value + 50
	await _circle(1.0, 2.0)
	_check(tank.value == floor_value and not tank.finished, "It never spills below the empty tank (₹%d)" % floor_value)
	_set_input(0, Vector2.ZERO)
	await _clear_props()

	# --- The cursed doll ---
	var doll := _mansion_loot("cursed_doll", Vector2(2.5, 17.5)) as CursedDoll
	await _frames(30)
	var doll_home: Vector3 = doll.global_position
	doll.global_position = doll_home + Vector3(3.0, 0.2, 0.0)
	doll.linear_velocity = Vector3.ZERO
	await _frames(int((SETTINGS.DOLL_WAIT + 3.0) * 60))
	var left: float = Vector2(doll.global_position.x - doll_home.x, doll.global_position.z - doll_home.z).length()
	_check(left < 1.2 and doll.crawling, "Put down away from home, the cursed doll giggles and walks back (%.1f m left)" % left)
	await _frames(120)
	left = Vector2(doll.global_position.x - doll_home.x, doll.global_position.z - doll_home.z).length()
	_check(left < SETTINGS.MUMMY_HOME_RADIUS + 0.1 and absf(doll.model.rotation.z) < 0.01, "It stops at home and stands still (%.2f m)" % left)
	await _clear_props()

	# --- The grandfather clock ---
	world.set_ghost_slot(3)
	await _frames(5)
	var seth: Node3D = world.ghost
	var clock := _mansion_loot("grandfather_clock", Vector2(8.0, 19.0)) as GrandfatherClock
	await _frames(30)
	var goals: RefCounted = load("res://core/round_goals.gd").new()
	goals.start(arena, get_tree().get_nodes_in_group("loot"), 1)
	var offered: bool = false
	for round_seed: int in range(40):
		goals.start(arena, get_tree().get_nodes_in_group("loot"), round_seed)
		offered = offered or goals.goal.id == "quiet"
	_check(offered, "With the clock in the round, \"Don't wake Seth-ji\" can be the bonus goal")
	goals.goal = {"id": "quiet", "text": "", "state": "open"}
	var chimes: Array[int] = []
	arena.clock_chimed.connect(func(slot: int) -> void: chimes.append(slot))
	seth.energy = 30.0
	clock.apply_impact(SETTINGS.CLOCK_CHIME_SPEED * 0.5)
	_check(chimes.is_empty(), "A gentle touch does not set the clock off")
	clock.last_carrier_slot = 0
	clock.thrown = true
	clock.apply_impact(SETTINGS.CLOCK_CHIME_SPEED + 0.3)
	clock.thrown = false
	_check(chimes.size() == 1 and chimes[0] == 0 and seth.energy > 30.0, "Bumped, the clock chimes: Seth-ji gains energy and the bumper is counted")
	clock.apply_impact(SETTINGS.CLOCK_CHIME_SPEED + 0.3)
	_check(chimes.size() == 1, "It chimes at most once every %.0f s" % SETTINGS.CLOCK_CHIME_REST)
	goals.on_chimed()
	_check(goals.goal.state == "failed", "A chime fails \"Don't wake Seth-ji\"")
	goals.goal = {"id": "quiet", "text": "", "state": "open"}
	goals.finish()
	_check(goals.goal.state == "met", "A round with no chimes meets it")
	var game: Node = get_tree().root.get_node("Game")
	var awards: Array[Dictionary] = game.awards_for({0: {"chimes": 2}, 1: {"banked": 3000}})
	_check(awards.any(func(award: Dictionary) -> bool: return award.slot == 0 and award.title == "GRANDFATHER'S ALARM"), "Whoever rang the clock most gets GRANDFATHER'S ALARM")
	world.set_ghost_slot(-1)
	await _clear_props()

	world.queue_free()
	await _frames(3)
	return failures


func _mansion_loot(kind: String, at: Vector2) -> Loot:
	var item: Loot = LOOT.instantiate()
	var entry: CatalogItem = load("res://props/catalog/mansion/%s.tres" % kind)
	if entry.loot_script != null:
		item.set_script(entry.loot_script)
	item.catalog_item = entry
	item.position = Vector3(at.x, arena.floor_height_at(Vector3(at.x, 0, at.y)) + entry.footprint.y / 2.0 + 0.03, at.y)
	arena.add_child(item)
	return item


# Movers 1 to 3 wait on the far lawn, clear of the circle (they start by the truck, right in its way).
func _park_others() -> void:
	for slot: int in [1, 2, 3]:
		world.movers[slot].global_position = Vector3(PARKING.x, SETTINGS.CAPSULE_HEIGHT / 2.0 + 0.05, PARKING.y + slot * 1.5)
		world.movers[slot].velocity = Vector3.ZERO


# Mover 0 stands on the circle with the item in hand.
func _held(item: Loot) -> Loot:
	var mover: CharacterBody3D = world.movers[0]
	_place(0, CIRCLE_CENTRE + Vector2(CIRCLE_RADIUS, 0))
	await _frames(10)
	_set_input(0, Vector2.ZERO, true) # Carrying is hold-to-carry: GRAB stays down.
	item.try_grab(mover, mover.hold_point, 0)
	mover.held_item = item
	await _frames(20)
	return item


func _circle(stick: float, seconds: float) -> void:
	await _circle_until(func() -> bool: return false, seconds, stick)


# Mover 0 runs round the circle until the condition holds or time runs out; returns the seconds taken.
func _circle_until(done: Callable, seconds: float, stick: float = 1.0) -> float:
	var mover: CharacterBody3D = world.movers[0]
	var elapsed: float = 0.0
	while elapsed < seconds:
		if done.call():
			return elapsed
		var at := Vector2(mover.position.x, mover.position.z)
		var out: Vector2 = at - CIRCLE_CENTRE
		var tangent := Vector2(out.y, -out.x).normalized()
		var correction: Vector2 = -out.normalized() * (out.length() - CIRCLE_RADIUS)
		_set_input(0, (tangent + correction).normalized() * stick, true)
		await get_tree().physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
	return elapsed
