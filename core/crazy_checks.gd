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
	await _check_throw()
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
	await _frames(2)
	snapshot.pressed = {}
	await get_tree().physics_frame


# --- Throw your teammate (decision 143) ---
func _check_throw() -> void:
	var carrier: CharacterBody3D = world.movers[0]
	var mate: CharacterBody3D = world.movers[1]
	await _lift_pair()
	_check(mate.lifted_by == carrier and carrier.lifting == mate and mate.global_position.y > carrier.global_position.y + 1.2, "GRAB with no loot in reach lifts an empty-handed teammate overhead")
	var start: Vector3 = carrier.global_position
	for frame: int in range(60):
		_set_input(0, Vector2.RIGHT, true)
		await get_tree().physics_frame
	var speed: float = Vector2(carrier.velocity.x, carrier.velocity.z).length()
	var riding: float = Vector2(mate.global_position.x - carrier.global_position.x, mate.global_position.z - carrier.global_position.z).length()
	_check(absf(speed - SETTINGS.MOVER_SPEED * SETTINGS.TEAMMATE_CARRY_SPEED) < 0.2 and absf(riding - SETTINGS.TEAMMATE_RIDE_FORWARD) < 0.05 and carrier.global_position.x > start.x + 1.5, "The carrier walks at %.0f%% speed with the teammate riding overhead (%.1f m/s)" % [SETTINGS.TEAMMATE_CARRY_SPEED * 100, speed])

	# THROW: an arc, a landing several metres on, and a short tumble.
	var launch_at: Vector3 = mate.global_position
	_set_input(0, Vector2.ZERO, true)
	router.snapshots[0].pressed = {"throw": true}
	await _frames(2) # Held two physics frames, so the mover surely reads it.
	router.snapshots[0].pressed = {}
	_check(mate.flying and carrier.lifting == null, "THROW launches the teammate")
	var peak: float = mate.global_position.y
	var waited: int = 0
	while mate.flying and waited < 240:
		peak = maxf(peak, mate.global_position.y)
		await get_tree().physics_frame
		waited += 1
	var thrown: float = Vector2(mate.global_position.x - launch_at.x, mate.global_position.z - launch_at.z).length()
	_check(not mate.flying and thrown > 3.5 and peak > launch_at.y + 0.3, "They fly in an arc and land %.1f m away" % thrown)
	_check(mate.is_tumbling(), "and stumble on landing")
	await _frames(int(SETTINGS.TEAMMATE_LAND_TUMBLE * 60) + 10)
	_check(not mate.is_tumbling() and mate.is_on_floor(), "Then they get up after %.1f s" % SETTINGS.TEAMMATE_LAND_TUMBLE)
	_check(not carrier.get_collision_exceptions().has(mate), "Once apart, the two collide again")

	# Letting go of GRAB puts them down on their feet in front.
	await _lift_pair()
	_set_input(0, Vector2.ZERO, false)
	await _frames(5)
	var gap: Vector3 = mate.global_position - carrier.global_position
	_check(mate.lifted_by == null and not mate.flying and absf(gap.y) < 0.2 and Vector2(gap.x, gap.z).length() > 0.6, "Letting go of GRAB sets the teammate down in front")

	# The lifted one wriggles free with BRACE.
	await _lift_pair()
	router.snapshots[1].pressed = {"brace": true}
	await _frames(2)
	router.snapshots[1].pressed = {}
	await _frames(3)
	_check(mate.lifted_by == null and carrier.lifting == null, "BRACE wriggles free")

	# Only empty hands: a teammate holding loot cannot be lifted, and loot in reach is grabbed first.
	await _clear_props()
	_park_others()
	_place(0, Vector2(-3.0, 21.0))
	_place(1, Vector2(-1.9, 21.0))
	carrier.facing = Vector3.RIGHT
	var vase := _mansion_loot("antique_vase", Vector2(-1.9, 21.6))
	await _frames(20)
	_set_input(1, Vector2.ZERO, true)
	vase.try_grab(mate, mate.hold_point, 1)
	mate.held_item = vase
	await _frames(5)
	await _press_grab(0)
	_check(mate.lifted_by == null and carrier.lifting == null, "A teammate holding loot cannot be lifted")
	_set_input(0, Vector2.ZERO)
	_set_input(1, Vector2.ZERO)
	await _clear_props()


# Mover 0 lifts mover 1 on the west lawn, both facing east.
func _lift_pair() -> void:
	var carrier: CharacterBody3D = world.movers[0]
	_set_input(0, Vector2.ZERO)
	_set_input(1, Vector2.ZERO)
	await _frames(2)
	_park_others()
	_place(0, Vector2(-3.0, 21.0))
	_place(1, Vector2(-1.9, 21.0))
	carrier.facing = Vector3.RIGHT
	await _frames(5)
	await _press_grab(0)


func _press_grab(slot: int) -> void:
	_set_input(slot, Vector2.ZERO, true)
	router.snapshots[slot].pressed = {"grab": true}
	await _frames(2)
	router.snapshots[slot].pressed = {}
	await _frames(3)
