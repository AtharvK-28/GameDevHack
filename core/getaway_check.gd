# Checks The Getaway (decision 147) in a developer-mode Museum match with two stand-ins: it opens from the final results
# with everyone a mover and no ghost, the world keeps the players on the truck, each ghost's attack lands and has its
# counter, gold off the tailgate is lost, the GOLD SAVED page leads to the epilogue, and the lobby gets its map back.
extends "res://core/match_check.gd"

var arena: Node3D
var movers: Array = []

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	game.selected_arena = game.MUSEUM_ARENA
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	var dev: CanvasLayer = playground.dev_tools
	await _wait(SETTLE_SECONDS)
	dev.forced = true
	for count: int in range(2):
		await _key(KEY_F10)
	await _wait(0.5)
	await _key(KEY_ENTER)
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	game._set_phase("final")
	await _wait(0.2)
	await _key(KEY_ENTER)
	await _wait(0.5)
	arena = playground.arena
	_check(game.phase == "live" and game.getaway and arena.ARENA_NAME == "The Getaway", "Enter on the Museum's final results opens The Getaway")
	_check(game.ghost_slot == -1 and not is_instance_valid(playground.ghost), "Nobody is the ghost")
	for slot: int in game.participants:
		movers.append(playground.movers[slot])
		_check(net.player_for_slot(slot).role == "mover" and playground.movers[slot].in_play, "Player %d is a mover on the truck" % (slot + 1))
	var result: Dictionary = arena.gold_result()
	_check(result.total > 0 and result.saved == result.total, "All the gold starts aboard (%d)" % result.total)
	await _wait(1.0)
	var on_bed: bool = true
	for item: Node3D in arena.gold:
		on_bed = on_bed and absf(item.global_position.y) < 1.5 and absf(item.global_position.x) < 3.0
	_check(on_bed, "The gold rests on the bed")
	var scenery: Vector3 = arena.scrolling[0].position
	await _wait(0.2)
	_check(not arena.scrolling[0].position.is_equal_approx(scenery), "The road scrolls past")
	playground.movers[game.participants[0]].global_position = Vector3(0.0, 0.8, 30.0)
	await _wait(0.1)
	_check(playground.movers[game.participants[0]].global_position.z < 4.5, "Movers can't leave the truck")

	await _check_tailgate()
	await _check_carrying()
	await _check_vases()
	router.process_mode = Node.PROCESS_MODE_DISABLED # So the check's own button presses stay pressed.
	await _check_waves()
	await _check_beam()
	router.process_mode = Node.PROCESS_MODE_INHERIT

	# Time up: the GOLD SAVED page, then the epilogue, then the lobby with the Museum back.
	game.seconds_left = 0.1
	await _wait(0.4)
	_check(game.phase == "saved" and game.getaway_result.has("stars"), "When time is up the GOLD SAVED page shows")
	await _key(KEY_ENTER)
	await _wait(0.2)
	_check(game.phase == "outro", "Enter goes on to the epilogue")
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	_check(game.phase == "lobby" and not game.getaway and playground.arena.ARENA_NAME == "Museum of Mostly Real Things", "The lobby has the Museum back")
	_check(playground.camera.follow_movers and playground.camera.pitch_degrees == SETTINGS.CAMERA_ANGLE, "The camera is back to normal")
	await _wait(0.3)
	await _key(KEY_ENTER)
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	_check(game.phase == "live" and not game.getaway and is_instance_valid(playground.ghost), "A normal match runs afterwards, with a ghost")
	print("GETAWAY CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _check_carrying() -> void:
	# The crew's whole job: pick loose gold up and carry it back up the bed.
	router.process_mode = Node.PROCESS_MODE_DISABLED
	var mover: CharacterBody3D = movers[0]
	var item: RigidBody3D = null
	for candidate: RigidBody3D in arena._loose_gold():
		if candidate.weight_class != SETTINGS.TWO_PERSON and (item == null or candidate.value > item.value):
			item = candidate
	item.global_position = Vector3(1.0, 0.4, 2.0)
	mover.global_position = Vector3(0.0, 0.8, 2.0)
	mover.facing = Vector3.RIGHT
	await _wait(0.1)
	var snapshot = router.snapshots[mover.slot]
	snapshot.buttons = {"grab": true}
	snapshot.pressed = {"grab": true}
	await _wait(0.05)
	snapshot.pressed = {}
	await _wait(0.2)
	_check(item.is_held_by(mover), "A mover can pick the gold up (%s)" % item.item_name)
	var start: float = item.global_position.z
	snapshot.direction = Vector2.UP
	await _wait(0.8)
	snapshot.direction = Vector2.ZERO
	_check(item.is_held_by(mover) and item.global_position.z < start - 1.0, "and carry it back up the bed")
	snapshot.buttons = {}
	await _wait(0.2)
	router.process_mode = Node.PROCESS_MODE_INHERIT


func _check_tailgate() -> void:
	var item: RigidBody3D = arena._loose_gold()[-1]
	var value: int = item.value
	var before: int = arena.gold_result().saved
	item.global_position = Vector3(0.0, 0.5, SETTINGS.GETAWAY_BED_HALF.y + 1.0)
	await _wait(0.2)
	_check(arena.gold_result().saved == before - value and arena.lost_value >= value, "Gold off the tailgate is lost (%d)" % value)


func _check_vases() -> void:
	var mover: CharacterBody3D = movers[0]
	await _wait(0.1)
	arena._vase_lands(mover.global_position)
	_check(mover.is_tumbling(), "A vase knocks a mover down")
	await _wait(SETTINGS.TUMBLE_DURATION + 0.3)


func _check_waves() -> void:
	var steady: CharacterBody3D = movers[0]
	var washed: CharacterBody3D = movers[1]
	router.snapshots[steady.slot].buttons = {"brace": true}
	await _wait(0.2)
	arena._wave_hits()
	_check(not steady.is_tumbling() and washed.is_tumbling(), "A wave spares the mover who braces and floors the one who doesn't")
	router.snapshots[steady.slot].buttons = {}
	await _wait(SETTINGS.TUMBLE_DURATION + 0.3)


func _check_beam() -> void:
	var mover: CharacterBody3D = movers[0]
	arena.elapsed = SETTINGS.GETAWAY_SECONDS - 10.0 # Bahadur's stage.
	await _frame()
	await _frame()
	arena.beam_left = 2.0
	arena.pool.show()
	var deadline: int = Time.get_ticks_msec() + 2000
	var caught: bool = false
	mover.global_position = Vector3(0.0, 0.8, 0.0)
	while Time.get_ticks_msec() < deadline and not caught:
		arena.beam_time = 0.0
		router.snapshots[mover.slot].direction = Vector2.RIGHT
		await _frame()
		mover.global_position.x = 0.0
		caught = mover.is_tumbling()
	router.snapshots[mover.slot].direction = Vector2.ZERO
	_check(caught, "The searchlight catches a mover who moves")
	arena.beam_left = 0.0
	arena.pool.hide()
