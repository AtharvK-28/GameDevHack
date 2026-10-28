# The Museum check's body (run by core/museum_check.gd), on the Ship check's world and movement helpers.
extends "res://core/ship_checks.gd"

# Walks from the van into each gallery: in through the laser hall's door, across the lobby and up the grand hall
# (the lobby's front door is the revolving door, tested on its own).
const LOBBY: Array[Vector2] = [Vector2(4.5, 21.6), Vector2(2.1, 21.4), Vector2(2.1, 17.3), Vector2(9, 17.3), Vector2(15, 17.3), Vector2(15, 11.5)]
const GALLERIES: Dictionary = {
	"Rotunda": [Vector2(15, 6.5)],
	"Art Gallery": [Vector2(12, 11.5), Vector2(6, 11.5)],
	"Egypt": [Vector2(12, 11.5), Vector2(5, 11.5), Vector2(5, 6.5)],
	"Space Gallery": [Vector2(18, 11.5), Vector2(23.5, 10.5)],
	"Jurassic Hall": [Vector2(18, 11.5), Vector2(25, 10.5), Vector2(25, 5.5)],
}
# The skull's way out: down from the rotunda, across the lobby, along the laser hall and out of its door to the van.
# The first leg slides it straight off the plinth before the pair turns it, so nobody swings into the plinth.
const SKULL_ROUTE: Array[Vector2] = [Vector2(12.3, 5.8), Vector2(15, 6.0), Vector2(15, 11.5), Vector2(15, 17.3), Vector2(9, 17.3), Vector2(2.1, 17.3), Vector2(2.1, 21.4)]

func run() -> int:
	router = get_tree().root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Museum.tscn")
	get_tree().root.add_child(world)
	arena = world.arena
	arena.get_node("MuseumAlarm").enabled = false # On only for its own section below.
	await _frames(120)

	# --- The loot pool ---
	var items: Array = get_tree().get_nodes_in_group("loot")
	var total: int = 0
	var skulls: int = 0
	for item: Loot in items:
		total += item.initial_value
		skulls += int(item.weight_class == SETTINGS.TWO_PERSON)
	_check(items.size() == 20 and total == 106700 and skulls == 1, "The full Museum has 16 exhibits and 4 gift-shop souvenirs worth ₹1,06,700, with one T-Rex skull (%d, ₹%d)" % [items.size(), total])
	var souvenirs: Array = items.filter(func(item: Loot) -> bool: return &"museum_gift" in item.catalog_item.pools)
	_check(souvenirs.size() == 4 and souvenirs.all(func(item: Loot) -> bool: return item.global_position.y > 0.9), "The gift shop's four souvenirs sit on its counter")
	for item: Loot in items:
		if item in souvenirs:
			continue
		var spot: Dictionary = _spot_under(item)
		var resting: float = item.global_position.y - item.item_size.y / 2.0
		_check(not spot.is_empty() and absf(resting - float(spot.get("floor", 0.0))) < 0.25, "%s rests on its spot (%.2f m, expected %.2f m)" % [item.item_name, resting, float(spot.get("floor", 0.0))])
	for players: int in [2, 3, 4]:
		var random := RandomNumberGenerator.new()
		random.seed = 321
		var pick: Array[Dictionary] = Catalog.pick_loot(&"museum", arena.layout.spawns.loot, SETTINGS.LOOT_COUNTS[players - 2], SETTINGS.HEAVY_LOOT_LIMITS[players - 2], random)
		var two_person: int = pick.filter(func(placement: Dictionary) -> bool: return placement.item.weight_class == SETTINGS.TWO_PERSON).size()
		var heavy: int = pick.filter(func(placement: Dictionary) -> bool: return placement.item.weight_class == SETTINGS.HEAVY).size()
		var goats: int = pick.filter(func(placement: Dictionary) -> bool: return placement.item.id == &"museum_goat").size()
		_check(pick.size() == SETTINGS.LOOT_COUNTS[players - 2] and two_person == 1 and goats == 1 and heavy <= SETTINGS.HEAVY_LOOT_LIMITS[players - 2], "A seeded %d-player round has %d items, one skull and the goat" % [players, SETTINGS.LOOT_COUNTS[players - 2]])
	_check(world.camera.arena_yaw == SETTINGS.MUSEUM_CAMERA_YAW, "The Museum gets its own camera angle")
	var neck: Vector3 = SETTINGS.SKULL_NECK
	var on_neck: Array = items.filter(func(item: Node) -> bool: return item is TRexSkull and Vector2(item.global_position.x - neck.x, item.global_position.z - neck.z).length() < 0.3)
	_check(on_neck.size() == 1 and absf(on_neck[0].global_position.y - on_neck[0].item_size.y / 2.0 - neck.y) < 0.2, "The T-Rex skull starts on the skeleton's neck bracket")
	var dressing: Node = arena.get_node("MuseumDressing")
	_check(arena.get_node("MuseumDressing/TRexSkeleton") != null and dressing.skull_plaque.text == SETTINGS.SKELETON_PLAQUE, "The skeleton stands in the rotunda, its plaque saying do not touch")
	_check(arena.truck != null and arena.get_node_or_null("Van") != null, "The van is parked at the loading dock with its delivery zone")
	# --- Bahadur's toys ---
	var trex: RigidBody3D = null
	var door: Node3D = null
	for node: Node in arena.get_children():
		if node.scene_file_path.ends_with("Animatronic.tscn"):
			trex = node
		elif node.scene_file_path.ends_with("RevolvingDoor.tscn"):
			door = node
	_check(trex != null and trex.get_node("Possessable").kind == Possessable.Kind.SLIDER, "The animatronic T-Rex stands in the Jurassic Hall, possessable like the sofa")
	_check(door != null and door.get_node("Possessable").kind == Possessable.Kind.DOOR and door.get_node("Possessable").action_label() == "SPIN", "The revolving door turns in the lobby's doorway; its ACTION is SPIN")
	var sfx: Node = get_tree().root.get_node("Sfx")
	_check(arena.MUSIC_TRACK == "round_museum" and ResourceLoader.exists(sfx.MUSIC_TRACKS[arena.MUSIC_TRACK]), "The Museum has its own round music")
	var host_was: Node3D = Game.host
	Game.host = world
	sfx.start_ambient()
	_check(sfx.ambient.playing and sfx.ambient.stream == sfx.city_bed and sfx.city_bed.loop_mode == AudioStreamWAV.LOOP_FORWARD, "The Museum's night sounds like a city, not the Mansion's crickets")
	sfx.stop_ambient()
	Game.host = host_was
	_check(sfx.sounds.has("siren") and ResourceLoader.exists(arena.get_node("MuseumEnvironment").HORN), "A siren wails far off or a car honks now and then")
	var phone_script: String = FileAccess.get_file_as_string("res://controller/controller.js")
	_check(phone_script.contains('"%s": "JAAGTE RAHO"' % arena.ARENA_NAME), "The ghost's phone names the Museum's haunting JAAGTE RAHO, not SHAKE")
	var turned: float = door.get_node("Wings").rotation.y
	await _frames(60)
	_check(absf(door.get_node("Wings").rotation.y - turned) > deg_to_rad(SETTINGS.REVOLVE_IDLE_SPEED * 0.5), "The door's wings turn slowly on their own")
	world.set_ghost_slot(3)
	await _frames(5)
	var bahadur: Node3D = world.ghost
	var from: Vector3 = trex.global_position
	bahadur.possess(trex.get_node("Possessable"))
	for frame: int in range(70):
		_set_input(3, Vector2(-1, 0))
		await get_tree().physics_frame
	_set_input(3, Vector2.ZERO)
	_check(trex.global_position.distance_to(from) > 1.0 and String(trex.player.current_animation).ends_with("_Walk"), "Bahadur walks the T-Rex across the hall (%.1f m) and it plays its walk" % trex.global_position.distance_to(from))
	trex.get_node("Possessable").act(Vector2(-1, 0))
	await _frames(3)
	_check(String(trex.player.current_animation).ends_with("_Attack"), "SHOVE: the T-Rex charges with its attack and a roar")
	bahadur.leave()
	world.set_ghost_slot(-1)
	await _frames(5)
	_place(0, Vector2(26.5, 20.6))
	await _frames(5)
	door.act()
	await _frames(10)
	_check(world.movers[0].is_tumbling() and not door.can_act(), "SPIN: the door whips round and knocks down the mover inside, then needs a rest")
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
	var skull := _museum_loot("skull", Vector2(SETTINGS.SKULL_NECK.x, SETTINGS.SKULL_NECK.z), SETTINGS.SKULL_NECK.y)
	await _frames(30)
	for slot: int in [0, 1]:
		_place(slot, Vector2(SETTINGS.SKULL_NECK.x + (-1.65 if slot == 0 else 1.65), SETTINGS.SKULL_NECK.z))
		var mover: CharacterBody3D = world.movers[slot]
		mover.facing = Vector3.RIGHT if slot == 0 else Vector3.LEFT
		mover._update_hold_point()
		skull.try_grab(mover, mover.hold_point, slot)
		mover.held_item = skull
		_set_input(slot, Vector2.ZERO, true)
	await _frames(60)
	_check(skull.holder_count() == 2, "Two movers lift the T-Rex skull off the skeleton's neck")
	var route_ok: bool = true
	for target: Vector2 in SKULL_ROUTE:
		route_ok = await _carry_skull(skull, target, target != SKULL_ROUTE[0])
		if not route_ok:
			print("Skull stopped at ", skull.position if is_instance_valid(skull) else "freed", " aiming for ", target)
			break
	_check(route_ok, "Two movers carry the skull down the hall, through the laser hall and out of its door")
	await _frames(40)
	_check(arena.get_node("MuseumDressing").skull_plaque.text == SETTINGS.SKELETON_PLAQUE_HEADLESS, "With the skull gone, the plaque reads: skull removed for cleaning")
	if route_ok:
		var banked: int = arena.truck.banked_items
		for slot: int in [0, 1]:
			_set_input(slot, Vector2.ZERO, false)
		await _frames(20)
		_check(arena.truck.banked_items == banked + 1, "The skull banks at the van")
	for slot: int in [0, 1]:
		_set_input(slot, Vector2.ZERO, false)
	await _clear_props()

	# --- Lost value shows as lost teeth ---
	var damaged := _museum_loot("skull", Vector2(15, 11.5), 0.0) as TRexSkull
	await _frames(20)
	_check(damaged.teeth.size() == 10, "The skull has ten teeth")
	damaged._lose_value(damaged.initial_value / 2)
	await _frames(5)
	var hidden: int = damaged.teeth.filter(func(tooth: Node3D) -> bool: return not tooth.visible).size()
	_check(hidden == 5 and damaged.lost_teeth == 5, "Losing half its value knocks out half its teeth (%d)" % hidden)
	damaged.queue_free()
	await _clear_props()

	# --- Bahadur and JAAGTE RAHO! ---
	world.set_ghost_slot(3)
	var ghost: Node3D = world.ghost
	await _frames(10)
	var watchmen: Array = ghost.find_children("*", "Node3D", true, false).filter(func(node: Node) -> bool: return node is GhostWatchmanModel)
	_check(watchmen.size() == 1, "The Museum's ghost is Bahadur, the night watchman")
	var haunting: Node = ghost.hauntings[0]
	_check(haunting is JaagteRaho and haunting.cost == SETTINGS.JAAGTE_COST and haunting.cooldown == SETTINGS.JAAGTE_COOLDOWN, "The Museum's haunting is JAAGTE RAHO! (cost %d, cooldown %.0f s)" % [SETTINGS.JAAGTE_COST, SETTINGS.JAAGTE_COOLDOWN])
	ghost.global_position = Vector3(15, ghost.global_position.y, 11.5)
	var walker: CharacterBody3D = world.movers[0]
	var statue: CharacterBody3D = world.movers[1]
	_place(0, Vector2(14.0, 11.5))
	_place(1, Vector2(16.0, 12.0))
	var mask := _museum_loot("golden_mask", Vector2(14.0, 12.1), 0.0)
	await _frames(10)
	_set_input(0, Vector2.ZERO, true)
	mask.try_grab(walker, walker.hold_point, 0)
	walker.held_item = mask
	_set_input(1, Vector2.ZERO, false, true)
	var caught: Array[int] = []
	arena.caught_in_beam.connect(func(slot: int) -> void: caught.append(slot))
	var lamp: Light3D = arena.gallery_lights.keys()[0]
	var full: float = arena.gallery_lights[lamp]
	haunting.trigger(ghost)
	await _frames(int(SETTINGS.JAAGTE_WARNING * 60) + 20)
	_check(lamp.light_energy < full * 0.5, "The whistle blows and the galleries go dark")
	# Walk in circles inside the beam, carrying the mask.
	for frame: int in range(60):
		_set_input(0, Vector2(cos(frame * 0.2), sin(frame * 0.2)) * 0.6, true)
		_set_input(1, Vector2.ZERO, false, true)
		await get_tree().physics_frame
	_check(walker.is_tumbling() and walker.held_item == null and 0 in caught, "Moving in the torch beam: HALT!, the mover drops the mask and tumbles")
	_check(not statue.is_tumbling() and 1 not in caught, "Holding BRACE in the beam: frozen like a statue, not caught")
	_set_input(0, Vector2.ZERO)
	_set_input(1, Vector2.ZERO)
	await _frames(int((SETTINGS.JAAGTE_DURATION + SETTINGS.JAAGTE_FADE_TIME) * 60) + 30)
	_check(not haunting.is_active() and is_equal_approx(lamp.light_energy, full), "After the run the lights come back up")
	world.set_ghost_slot(-1)
	await _clear_props()

	# --- The laser hall ---
	var lasers: Node = arena.get_node("MuseumLasers")
	_check(lasers.gates.size() == 2 and SETTINGS.LASER_GATES_X[1] - SETTINGS.LASER_GATES_X[0] >= 4.5, "Two laser gates cross the laser hall, 4.5 m apart")
	var states: Array[bool] = []
	for step: int in range(12):
		lasers.cycle_time = step * SETTINGS.LASER_PERIOD / 12.0
		states.append(lasers.is_on(0))
	_check(states.has(true) and states.has(false), "The gates blink on and off, each a step behind the last")
	world.set_ghost_slot(3)
	await _frames(5)
	var ghost_now: Node3D = world.ghost
	var trips: Array[int] = []
	arena.alarm_tripped.connect(func(slot: int) -> void: trips.append(slot))
	# Through gate 0 while it is lit: the alarm, and energy for the ghost.
	ghost_now.energy = 40.0
	lasers.cycle_time = 0.1 # Gate 0 at the start of its lit share.
	_place(0, Vector2(SETTINGS.LASER_GATES_X[0] + 0.9, 17.5))
	await _frames(3)
	lasers.cycle_time = 0.1
	var crossed: bool = await _walk(0, [Vector2(SETTINGS.LASER_GATES_X[0] - 0.9, 17.5)])
	_check(crossed and trips.size() == 1 and ghost_now.energy > 40.0, "Crossing a lit laser trips the alarm and feeds the ghost (energy %.0f)" % ghost_now.energy)
	# Back through it while it is dark: nothing.
	await _frames(int(SETTINGS.LASER_TRIP_GAP * 60) + 5)
	var before: int = trips.size()
	_place(0, Vector2(SETTINGS.LASER_GATES_X[0] - 0.9, 17.5))
	await _frames(3)
	lasers.cycle_time = SETTINGS.LASER_PERIOD * (SETTINGS.LASER_ON_SHARE + 0.05) # Gate 0 just gone dark.
	crossed = await _walk(0, [Vector2(SETTINGS.LASER_GATES_X[0] + 0.9, 17.5)])
	_check(crossed and trips.size() == before, "Crossing while the gate is dark sets nothing off")
	# Thrown over a lit gate, feet above the top beam (decision 143): nothing; standing in it: the alarm.
	await _frames(int(SETTINGS.LASER_TRIP_GAP * 60) + 5)
	before = trips.size()
	lasers.cycle_time = 0.1
	var flier: CharacterBody3D = world.movers[0]
	flier.global_position = Vector3(SETTINGS.LASER_GATES_X[0], SETTINGS.LASER_HEIGHTS[-1] + SETTINGS.CAPSULE_HEIGHT / 2.0 + 0.3, 17.5)
	flier.velocity = Vector3.ZERO
	await _frames(2)
	_check(trips.size() == before, "A mover flying over a lit gate, feet above the top beam, does not trip it")
	_place(0, Vector2(SETTINGS.LASER_GATES_X[0], 17.5))
	await _frames(3)
	_check(trips.size() == before + 1, "Standing in the same lit gate does")
	world.set_ghost_slot(-1)
	await _clear_props()

	# --- Swap the Fakes ---
	arena._spawn_fakes_task()
	await _frames(20)
	var task: Node = arena.generator
	var replicas: Array = get_tree().get_nodes_in_group("task_batteries")
	_check(task != null and task.TASK_NAME == "Fakes" and replicas.size() == 3 and task.hud_text() == "Fakes 0/3", "Swap the Fakes: three replicas wait by the van")
	var stray: Node = replicas[0]
	stray.global_position = Vector3(15, 0.5, 11.5)
	_check(not task.try_deliver(stray), "A fake dropped anywhere else does not count")
	world.set_ghost_slot(3)
	await _frames(5)
	for index: int in range(replicas.size()):
		var replica: RigidBody3D = replicas[index]
		replica.global_position = SETTINGS.FAKE_PLINTH_SPOTS[index] + Vector3.UP * (replica.item_size.y / 2.0 + 0.05)
		replica.linear_velocity = Vector3.ZERO
		await _frames(2)
		task.try_deliver(replica)
	await _frames(5)
	_check(task.powered and task.hud_text() == "Fakes swapped" and world.ghost.generator_powered, "All three fakes swapped: the cameras see nothing missing and Bahadur is slowed")
	world.set_ghost_slot(-1)
	await _clear_props()

	# --- Personalities ---
	world.set_ghost_slot(3)
	await _frames(5)
	var watcher: Node3D = world.ghost
	var mona := _museum_loot("mona_lisa", Vector2(15, 11.5), 0.0) as MonaLisaCousin
	var goat := _museum_loot("goat", Vector2(13, 12.5), 0.0) as MuseumGoat
	var hand := _museum_loot("mummy_hand", Vector2(17, 12.5), 0.0) as MummyHand
	await _frames(30)
	var alarms: Array[int] = []
	arena.alarm_tripped.connect(func(slot: int) -> void: alarms.append(slot))
	watcher.energy = 30.0
	mona.last_carrier_slot = 0
	mona.apply_impact(SETTINGS.MONA_SCREAM_SPEED + 0.5)
	_check(watcher.energy > 30.0 and alarms.has(0), "Bumped, Mona Lisa's cousin screams: the ghost gains energy and the bumper is counted")
	var goat_value: int = goat.value
	goat._lose_value(500)
	_check(goat.value == goat_value, "A knock only makes the goat bleat: it never loses value")
	var goals: RefCounted = load("res://core/round_goals.gd").new()
	goals.start(arena, get_tree().get_nodes_in_group("loot"), 1)
	goals.goal = {"id": "goat", "text": "Rescue the goat", "state": "open"}
	goals.on_delivered(goat.get_instance_id(), goat.value, goat.initial_value)
	_check(goals.goat_id == goat.get_instance_id() and goals.goal.state != "open", "Rescue the goat: banking it settles the bonus goal")
	var hand_home: Vector3 = hand.global_position
	hand.global_position = hand_home + Vector3(3.0, 0.2, 0.0)
	hand.linear_velocity = Vector3.ZERO
	await _frames(int((SETTINGS.MUMMY_WAIT + 3.0) * 60))
	_check(hand.global_position.distance_to(hand_home) < 2.2, "Put down away from home, the mummy's hand crawls back (%.1f m left)" % hand.global_position.distance_to(hand_home))
	world.set_ghost_slot(-1)
	await _clear_props()

	# --- The ALARM and lockdown ---
	var alarm: Node = arena.get_node("MuseumAlarm")
	alarm.enabled = true
	arena.raise_alarm(0.0, -1, 60.0)
	_check(is_equal_approx(alarm.level, 60.0) and alarm.state == "", "Alarms fill the ALARM bar (60%)")
	arena.raise_alarm(0.0, -1, 60.0)
	_check(alarm.state == "warning", "A full bar: police lights and a countdown to lockdown")
	await _frames(int(SETTINGS.ALARM_WARNING * 60) + 10)
	_check(alarm.state == "lockdown" and alarm.shutters.size() == 3, "Then three shutters drop over the back galleries' doorways")
	_place(0, Vector2(15.0, 9.5))
	await _frames(5)
	var shut_out: bool = await _walk(0, [Vector2(15.0, 6.5)])
	_check(not shut_out and world.movers[0].global_position.z > SETTINGS.ALARM_SHUTTER_Z, "A shutter blocks the way into the rotunda")
	_set_input(0, Vector2.ZERO)
	await _frames(int(SETTINGS.ALARM_LOCKDOWN * 60) + 10)
	_check(alarm.state == "" and alarm.shutters.is_empty() and alarm.level == 0.0, "After the lockdown the shutters rise and the bar resets")
	await _clear_props()

	# --- The dinosaur egg ---
	var egg := _museum_loot("dino_egg", Vector2(15, 11.5), 0.0) as DinoEgg
	await _frames(20)
	egg._lose_value(egg.value)
	await _frames(10)
	var babies: Array = get_tree().get_nodes_in_group("loot").filter(func(item: Node) -> bool: return item is BabyRaptor)
	_check(babies.size() == 1, "The egg breaks and a baby raptor hatches")
	if babies.size() == 1:
		var baby: Loot = babies[0]
		var start: Vector3 = baby.global_position
		_place(0, Vector2(start.x + 1.2, start.z))
		await _frames(50)
		_check(baby.global_position.distance_to(start) > 0.8, "Come near the baby raptor and it runs (%.1f m)" % baby.global_position.distance_to(start))
	await _clear_props()

	# --- Display cases ---
	var case_script: Script = load("res://arenas/dressing/display_case.gd")
	var cased: Array[Loot] = []
	for index: int in range(2):
		var exhibit := _museum_loot("golden_mask", Vector2(13.0 + index * 4.0, 11.5), 0.0)
		var glass: Node3D = case_script.new()
		glass.setup(exhibit)
		glass.position = Vector3(13.0 + index * 4.0, 0.0, 11.5)
		arena.add_child(glass)
		cased.append(exhibit)
	await _frames(20)
	var picker: CharacterBody3D = world.movers[0]
	_check(cased[0].in_closed_case() and cased[0].grab_point_for(picker) == Vector3.INF and not cased[0].try_grab(picker, picker.hold_point, 0), "An exhibit behind glass cannot be grabbed")
	_check(cased[0].is_spent(), "The ghost cannot possess an exhibit behind glass")
	_place(0, Vector2(13.0, 12.4))
	await _frames(5)
	for frame: int in range(int(SETTINGS.CASE_UNLOCK_SECONDS * 60) + 15):
		_set_input(0, Vector2.ZERO, true)
		await get_tree().physics_frame
	_set_input(0, Vector2.ZERO)
	await _frames(5)
	_check(not cased[0].in_closed_case() and cased[0].grab_point_for(picker) != Vector3.INF, "Holding GRAB at the case for %.0f s unlocks it quietly" % SETTINGS.CASE_UNLOCK_SECONDS)
	var alarm_box: Node = arena.get_node("MuseumAlarm")
	alarm_box.enabled = true
	var level_before: float = alarm_box.level
	_place(0, Vector2(17.0, 12.4))
	await _frames(5)
	router.snapshots[0].pressed = {"throw": true}
	await _frames(2)
	router.snapshots[0].pressed = {}
	_check(not cased[1].in_closed_case() and alarm_box.level >= level_before + SETTINGS.ALARM_CASE - 0.1, "THROW at a case smashes it at once, and the ALARM bar jumps")
	alarm_box._open()
	alarm_box.enabled = false
	await _clear_props()

	# --- Security cameras ---
	var cams: Node = arena.get_node("MuseumCameras")
	_check(cams.cameras.size() == 3, "Three security cameras watch Egypt, the Art Gallery and the Space Gallery")
	var egypt: Dictionary = cams.cameras[0]
	var head: Node3D = egypt.head
	var forward := Vector2(-sin(head.rotation.y), -cos(head.rotation.y))
	var in_view: Vector2 = Vector2(head.global_position.x, head.global_position.z) + forward * 4.0
	_place(0, in_view)
	await _frames(2)
	_check(cams.sees(world.movers[0]) == "Egypt", "A mover in front of the Egypt camera is spotted")
	_place(0, Vector2(15.0, 11.5))
	await _frames(2)
	_check(cams.sees(world.movers[0]) == "", "A mover in the Grand Hall, out of every camera's gallery, is not")
	await _clear_props()

	# --- Developer shortcuts (decision 141) ---
	var dev: CanvasLayer = load("res://core/dev_tools.gd").new() # Main makes one only for matches.
	dev.host = world
	world.add_child(dev)
	var sirens: Node = arena.get_node("MuseumAlarm")
	_check(dev.museum_alarm(arena) == "ALARM full: police on the way" and sirens.state == "warning", "Developer Ctrl+2 fills the ALARM: the police are on the way")
	_check(dev.museum_line(arena).contains("police in"), "The overlay shows the police countdown")
	dev.museum_alarm(arena)
	_check(sirens.state == "lockdown" and sirens.shutters.size() == 3 and dev.museum_line(arena).contains("LOCKDOWN"), "Ctrl+2 again skips to the lockdown")
	dev.museum_alarm(arena)
	_check(sirens.state == "" and sirens.shutters.is_empty(), "Ctrl+2 during the lockdown lifts the shutters")
	sirens.enabled = false
	var gates: Node = arena.get_node("MuseumLasers")
	_check(dev.museum_lasers(arena) == "Lasers off" and not gates.is_on(0) and not gates.is_on(1) and dev.museum_line(arena).contains("lasers off"), "Developer Ctrl+4 switches the lasers off")
	dev.museum_lasers(arena)
	_check(gates.enabled, "and back on")
	_check(dev.museum_line(arena).contains("cases") and dev.museum_line(arena).contains("CCTV"), "The overlay's Museum line lists the cameras and the glass cases")
	dev.queue_free()

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
