# Checks that the stick is screen-relative (decision 124): on the Ghost Ship and the Old Mansion, a real WebSocket
# phone pushes up, down, left and right and the host moves the mover the same way on the big screen (measured
# through the live camera), and a push up walks it up the screen. Bots' world directions survive the trip to a stick and back.
extends "res://core/match_check.gd"

const PUSH_SECONDS: float = 0.6
const MIN_PIXELS: float = 40.0 # Screen pixels the mover must travel the right way.
const MAX_DRIFT: float = 0.35 # Most sideways travel allowed, as a share of the travel the right way.
const MAX_ANGLE: float = 10.0 # Degrees a stick direction may differ from the way it moves on screen.

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	for arena_path: String in ["res://arenas/Ship.tscn", "res://arenas/Mansion.tscn"]:
		await _check_arena(arena_path)
	print("STICK CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _check_arena(arena_path: String) -> void:
	game.selected_arena = arena_path
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	await _wait(SETTLE_SECONDS)
	var first: int = clients.size()
	await _connect_phone("Asha")
	await _connect_phone("Bilal")
	for index: int in [first, first + 1]:
		_send(index, {"type": "ready"})
	await _wait(0.3)
	game.start_match()
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	var name: String = playground.arena.ARENA_NAME
	if playground.arena.has_method("start_wave"):
		playground.arena.motion_scale = 0.0 # A level ship, so only the stick moves the mover.
		playground.arena.wave_left = INF
	var index: int = first + 1 - game.ghost_slot # The mover's phone: slots follow joining order.
	var mover: CharacterBody3D = playground.movers[1 - game.ghost_slot]
	var camera: Camera3D = playground.camera

	var probe := Vector2(0.6, -0.8)
	_check(router.world_to_stick(router.stick_to_world(probe)).is_equal_approx(probe), "%s: a stick survives the trip to the world and back" % name)
	# Each main stick direction from the phone becomes the world direction that points the same way on screen.
	var worst: float = 0.0
	for push: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2(1, -1).normalized()]:
		sticks[index] = router.stick_to_world(push) # The heartbeat converts it back, so it repeats the same push.
		_send(index, {"type": "in", "x": push.x, "y": push.y})
		await _wait(INPUT_SECONDS)
		var world: Vector2 = router.for_slot(mover.slot).direction
		# Measured where the camera looks: off-centre, perspective leans "away" toward the vanishing point.
		var at: Vector3 = Vector3(camera.focus.x, mover.global_position.y, camera.focus.z)
		var on_screen: Vector2 = camera.unproject_position(at + Vector3(world.x, 0.0, world.y)) - camera.unproject_position(at)
		var off: float = rad_to_deg(absf(on_screen.angle_to(push)))
		if push.x == 0.0 or push.y == 0.0:
			worst = maxf(worst, off)
		else:
			print("INFO: %s: a diagonal stick is %.1f degrees off on screen (the tilted camera foreshortens the floor)" % [name, off])
	_check(worst < MAX_ANGLE, "%s: up, down, left and right move the same way on screen (worst %.1f degrees off)" % [name, worst])

	# And a real walk: pushing up carries the mover up the screen.
	var from: Vector3 = mover.global_position
	sticks[index] = router.stick_to_world(Vector2.UP)
	_send(index, {"type": "in", "x": 0, "y": -1})
	await _wait(PUSH_SECONDS)
	sticks[index] = Vector2.ZERO
	_send(index, {"type": "in", "x": 0, "y": 0})
	# Both ends through the camera as it is now: it follows the movers, which would hide part of the walk.
	var moved: Vector2 = camera.unproject_position(mover.global_position) - camera.unproject_position(from)
	_check(-moved.y > MIN_PIXELS and absf(moved.x) < -moved.y * MAX_DRIFT, "%s: stick up walks the mover up the screen (%.0f px up, %.0f across)" % [name, -moved.y, absf(moved.x)])
	await _wait(0.3)

	for client_index: int in [first, first + 1]:
		clients[client_index].close()
	game.return_to_lobby()
	net.rotate_session()
	root.remove_child(playground)
	playground.free()
	await _wait(0.3)
