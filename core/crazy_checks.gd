# The crazy-ideas check's body (run by core/crazy_check.gd), on the Mansion check's lawn and helpers.
extends "res://core/mansion_checks.gd"

func run() -> int:
	router = get_tree().root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Mansion.tscn")
	get_tree().root.add_child(world)
	arena = world.arena
	await _frames(120)
	await _clear_props()
	_park_others()
	await _check_hex()
	world.queue_free()
	await _frames(3)
	return failures


# --- The Haunted Controller (decision 142) ---
func _check_hex() -> void:
	world.set_ghost_slot(3)
	await _frames(5)
	var ghost: Node3D = world.ghost
	ghost.demo_rules = true
	ghost.opening_left = 0.0
	var victim: CharacterBody3D = world.movers[0]
	_place(0, CIRCLE_CENTRE)
	ghost.global_position = Vector3(CIRCLE_CENTRE.x + 2.0, ghost.global_position.y, CIRCLE_CENTRE.y)
	await _frames(5)
	_check(ghost.hex_target == victim and ghost.can_hex(), "The ghost can HEX the nearest mover within %.0f m" % SETTINGS.HEX_RANGE)
	var hud: Dictionary = ghost.hud()
	_check(hud.costs.haunt2 == SETTINGS.HEX_COST and hud.ok.haunt2, "In a match the ghost phone's second haunting button is HEX, for %d energy" % SETTINGS.HEX_COST)
	ghost.energy = 100.0
	await _ghost_press("haunt2")
	_check(victim.hex_state == "warn" and ghost.energy < 100.0 - SETTINGS.HEX_COST + 1.0, "HEX: the mover's phone cracks and flickers first, and it costs the ghost %d" % SETTINGS.HEX_COST)
	hud = ghost.hud()
	_check(not hud.ok.haunt2 and String(hud.reasons.haunt2) != "Ready", "Then HEX waits for its cooldown (%s)" % hud.reasons.haunt2)
	await _frames(int(SETTINGS.HEX_WARNING * 60) + 5)
	_check(victim.hex_state == "on", "After %.0f s the stick is mirrored" % SETTINGS.HEX_WARNING)

	# Pushing screen-right walks the mover screen-left while hexed.
	var right: Vector2 = router.stick_to_world(Vector2.RIGHT)
	var start: Vector3 = victim.global_position
	for frame: int in range(40):
		_set_input(0, right)
		await get_tree().physics_frame
	var moved := Vector2(victim.global_position.x - start.x, victim.global_position.z - start.z)
	var mirrored: Vector2 = router.stick_to_world(Vector2.LEFT)
	_check(moved.length() > 0.5 and moved.normalized().dot(mirrored) > 0.9, "Hexed, the stick is mirrored: pushing right walks left")
	_set_input(0, Vector2.ZERO)
	await _frames(int(SETTINGS.HEX_BREAK_SECONDS * 60) + 5)
	_check(victim.hex_state == "", "Letting go of the stick for %.1f s shakes the hex off" % SETTINGS.HEX_BREAK_SECONDS)

	# Kept moving, it wears off after HEX_SECONDS.
	ghost.hex_cooldown_left = 0.0
	ghost.shared_lock_left = 0.0
	ghost.energy = 100.0
	await _frames(2)
	await _ghost_press("haunt2")
	var held_for: float = 0.0
	while victim.hex_state != "" and held_for < SETTINGS.HEX_WARNING + SETTINGS.HEX_SECONDS + 2.0:
		var around: float = held_for * 1.5
		_set_input(0, Vector2(cos(around), sin(around)))
		await get_tree().physics_frame
		held_for += 1.0 / Engine.physics_ticks_per_second
	_check(absf(held_for - SETTINGS.HEX_WARNING - SETTINGS.HEX_SECONDS) < 0.2, "Kept moving, the hex wears off after %.0f s (%.1f s)" % [SETTINGS.HEX_WARNING + SETTINGS.HEX_SECONDS, held_for])
	_set_input(0, Vector2.ZERO)
	ghost.hex_cooldown_left = 0.0
	ghost.shared_lock_left = 0.0
	await _ghost_press("haunt2")
	victim.set_in_play(false)
	_check(victim.hex_state == "", "A mover leaving play is never left hexed")
	ghost.global_position = Vector3(CIRCLE_CENTRE.x + 20.0, ghost.global_position.y, CIRCLE_CENTRE.y)
	ghost.hex_cooldown_left = 0.0
	ghost.shared_lock_left = 0.0
	await _frames(3)
	_check(ghost.hex_target == null and String(ghost.hud().reasons.haunt2) == "Fly near a mover", "Nobody within %.0f m: HEX has no target" % SETTINGS.HEX_RANGE)
	world.set_ghost_slot(-1)
	await _clear_props()


func _ghost_press(button: String) -> void:
	var snapshot = router.snapshots[3]
	snapshot.pressed = {button: true}
	await get_tree().physics_frame
	snapshot.pressed = {}
	await get_tree().physics_frame
