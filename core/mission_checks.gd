# The Sabotage Showdown mission's body (run by core/mission_check.gd), on the Mansion mission arena. It proves
# the thing the mode is for: that the four steps are a sequence and not four errands in any order.
extends Node

const SETTINGS := preload("res://autoload/Balance.gd")
const WIRE_PUZZLE := preload("res://core/wire_puzzle.gd")
const MISSION_SCRIPT := preload("res://core/mission.gd")
const PUSH_FRAMES: int = 120 # Two seconds of walking into something, which is plenty to prove it blocks.

var world: Node3D
var arena: Node3D
var router: Node
var failures: int = 0
var mission: Node
var fuse_box: Node3D
var gate: StaticBody3D
var cupboard: Area3D


# --- Check runner ---
func run() -> int:
	router = get_tree().root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/MansionMission.tscn")
	get_tree().root.add_child(world)
	arena = world.arena
	await _frames(90)

	mission = arena.mission
	fuse_box = arena.fuse_box
	gate = arena.stair_gate
	cupboard = _find_cupboard()
	_check(mission != null and fuse_box != null and gate != null and cupboard != null, "The mission, its gate, cupboard and fuse box are all built")
	if mission == null or gate == null or fuse_box == null or cupboard == null:
		return 1

	_check_sequence_rules()
	_check_wire_puzzle()
	await _check_gate_blocks()
	await _check_run_through()
	return failures


# --- The sequence is a sequence ---
func _check_sequence_rules() -> void:
	var fresh: Node = MISSION_SCRIPT.new(SETTINGS.MISSION_STEPS)
	_check(fresh.steps.size() >= 3, "The mission has at least three steps (%d)" % fresh.steps.size())
	_check(fresh.is_open("key") and not fresh.is_open("cupboard"), "Only the first step is open to begin with")
	_check(not fresh.complete("haul") and not fresh.complete("wires"), "A later step cannot be finished out of turn")
	_check(fresh.done_count == 0, "A refused step leaves the mission where it was")
	_check(fresh.complete("key"), "The open step can be finished")
	_check(fresh.is_open("cupboard") and not fresh.is_open("wires"), "Finishing one step opens exactly the next")
	_check(not fresh.complete("key"), "A finished step cannot be finished twice")
	for id: String in ["cupboard", "wires", "haul"]:
		fresh.complete(id)
	_check(fresh.is_finished(), "Finishing every step in order completes the mission")
	fresh.free()


# --- The wire puzzle ---
func _check_wire_puzzle() -> void:
	var puzzle: RefCounted = WIRE_PUZZLE.new()
	puzzle.start(0, 100)
	_check(puzzle.left.size() == SETTINGS.MISSION_WIRE_PAIRS and puzzle.right.size() == SETTINGS.MISSION_WIRE_PAIRS, "The puzzle deals %d pairs" % SETTINGS.MISSION_WIRE_PAIRS)

	var wrong_left: int = -1
	var wrong_right: int = -1
	for left_pin: int in puzzle.left.size():
		for right_pin: int in puzzle.right.size():
			if puzzle.left[left_pin] != puzzle.right[right_pin]:
				wrong_left = left_pin
				wrong_right = right_pin
	_check(wrong_left >= 0 and not puzzle.join(wrong_left, wrong_right), "Joining two different colours is refused")
	var first_match: int = puzzle.right.find(puzzle.left[0])
	_check(puzzle.join(0, first_match), "Joining a matching pair sticks")
	_check(not puzzle.join(0, first_match), "A pin already wired cannot be wired again")
	_check(not puzzle.is_solved(), "One pair of %d is not solved" % SETTINGS.MISSION_WIRE_PAIRS)
	for left_pin: int in range(1, puzzle.left.size()):
		puzzle.join(left_pin, puzzle.right.find(puzzle.left[left_pin]))
	_check(puzzle.is_solved(), "Every pair matched solves it")

	var repeat: RefCounted = WIRE_PUZZLE.new()
	repeat.start(0, 100)
	_check(repeat.left == puzzle.left and repeat.right == puzzle.right, "The same round seed deals the same puzzle, so a restart is fair")
	var other: RefCounted = WIRE_PUZZLE.new()
	other.start(0, 101)
	_check(other.left != puzzle.left or other.right != puzzle.right, "A different round deals a different puzzle")

	var pins: int = SETTINGS.MISSION_WIRE_PAIRS
	_check(not puzzle.join(-1, 0) and not puzzle.join(0, pins) and not puzzle.join(pins + 50, 0), "Out-of-range pins are refused, so a junk message cannot reach the puzzle")


# --- The gate really blocks ---
func _check_gate_blocks() -> void:
	_check(gate.shut and not gate.blocker.disabled, "The stair gate starts shut")
	var gate_z: float = SETTINGS.MISSION_GATE_AT.z
	_place(0, Vector2(SETTINGS.MISSION_GATE_AT.x, gate_z + 1.5))
	await _frames(5)
	await _push(0, Vector2(0.0, -1.0))
	_check(world.movers[0].global_position.z > gate_z - 0.3, "A mover walking at the shut gate is stopped by it (reached z %.2f)" % world.movers[0].global_position.z)

	gate.set_shut(false)
	await _frames(60) # The gate swings over SWING_SECONDS, and its collider clears on a deferred call.
	_check(not gate.shut and gate.blocker.disabled, "Power swings the gate open and takes its collider away")
	await _push(0, Vector2(0.0, -1.0))
	_check(world.movers[0].global_position.z < gate_z - 0.3, "With the gate open the mover walks through (reached z %.2f)" % world.movers[0].global_position.z)

	gate.set_shut(true)
	await _frames(60)
	_check(gate.shut and not gate.blocker.disabled, "Cutting the power shuts it again")


# --- The whole run, in order ---
func _check_run_through() -> void:
	var key: Node3D = get_tree().get_first_node_in_group("mission_key")
	var prize: Node3D = get_tree().get_first_node_in_group("mission_prize")
	_check(key != null and prize != null, "The key and the strongbox are both in the world")
	if key == null or prize == null:
		return
	_check(key.global_position.z > SETTINGS.MISSION_GATE_AT.z, "The key never spawns behind the gate it opens")
	_check(prize.global_position.z < SETTINGS.MISSION_GATE_AT.z, "The strongbox is on the gallery, behind the gate")
	_check(key.weight_class == SETTINGS.LIGHT, "The key is light, so one mover can run with it")
	_check(prize.value == SETTINGS.MISSION_STRONGBOX_VALUE, "The strongbox is worth %d" % prize.value)
	_check(key.get_node_or_null("Possessable") == null, "The key carries nothing the ghost can possess")

	# Step one: a mover picks the key up.
	_place(0, Vector2(key.global_position.x, key.global_position.z + 0.8))
	await _frames(10)
	await _grab(0, key)
	_check(mission.is_done("key"), "Picking the key up finishes step one")

	# Step two: the cupboard takes it, and would not have taken it earlier.
	_check(not cupboard.open, "The cupboard is shut until the key arrives")
	# Carry it to the cupboard. The mover and the key move together, because teleporting a carrier alone leaves
	# its item snagged behind it; then walk in until the key is actually over the zone and let go.
	var mover: CharacterBody3D = world.movers[0]
	var approach := Vector3(SETTINGS.MISSION_CUPBOARD_AT.x, mover.global_position.y, SETTINGS.MISSION_CUPBOARD_AT.z + 3.0)
	mover.global_position = approach
	key.global_position = approach + Vector3(0.0, 0.0, -SETTINGS.HOLD_DISTANCE)
	key.linear_velocity = Vector3.ZERO
	key.angular_velocity = Vector3.ZERO
	await _frames(20)
	var over: bool = await _push_until(0, Vector2(0.0, -1.0), func() -> bool: return cupboard.contains_point(key.global_position))
	print("INFO: after the approach the mover is at %.2f,%.2f and the key at %.2f,%.2f,%.2f; cupboard centre %.2f,%.2f half %.2f"
		% [mover.global_position.x, mover.global_position.z, key.global_position.x, key.global_position.y,
		key.global_position.z, cupboard.global_position.x, cupboard.global_position.z, SETTINGS.MISSION_CUPBOARD_SIZE.x / 2.0])
	_check(over, "The crew can walk the key into the cupboard zone")
	_set_input(0, Vector2.ZERO, false) # Letting go with the key over the cupboard delivers it.
	await _frames(25)
	_check(mission.is_done("cupboard") and cupboard.open, "Releasing the key in the cupboard finishes step two and opens it")

	# Step three: the puzzle's answer powers the box, which opens the gate.
	_check(not fuse_box.powered and gate.shut, "The power is still off, so the gallery is still shut")
	fuse_box.solved_puzzle()
	await _frames(60)
	_check(mission.is_done("wires") and fuse_box.powered and not gate.shut, "Solving the wires finishes step three, powers the box and opens the gate")

	# The two-sided switch, and the crew's counter to it.
	_check(fuse_box.can_cut(), "With the power on the ghost may cut it")
	_check(fuse_box.cut_power() and not fuse_box.powered, "The ghost cuts the power")
	await _frames(60)
	_check(gate.shut, "Cutting the power shuts the gallery off again")
	_check(not fuse_box.can_cut(), "It cannot be cut again at once: the cooldown stops the ghost leaning on it")
	fuse_box.set_powered(true)
	await _frames(60)
	_check(not gate.shut, "A mover throwing the breaker back on reverses the ghost's cut")
	_check(not mission.is_finished(), "The mission is still not complete until the strongbox is out")


# --- Helpers ---
func _push_until(slot: int, direction: Vector2, done: Callable, frames: int = 240) -> bool:
	# Walk until something is true, rather than for a fixed count, so the mover never overshoots the target.
	for frame: int in frames:
		if done.call():
			_set_input(slot, Vector2.ZERO, is_instance_valid(world.movers[slot].held_item))
			await _frames(3)
			return true
		_set_input(slot, direction, is_instance_valid(world.movers[slot].held_item))
		await get_tree().physics_frame
	_set_input(slot, Vector2.ZERO, is_instance_valid(world.movers[slot].held_item))
	return false


func _push(slot: int, direction: Vector2) -> void:
	for frame: int in PUSH_FRAMES:
		_set_input(slot, direction, is_instance_valid(world.movers[slot].held_item))
		await get_tree().physics_frame
	_set_input(slot, Vector2.ZERO, is_instance_valid(world.movers[slot].held_item))
	await _frames(5)


func _grab(slot: int, item: Node3D) -> void:
	for frame: int in 60:
		var mover: CharacterBody3D = world.movers[slot]
		if is_instance_valid(mover.held_item):
			break
		var gap := Vector2(item.global_position.x - mover.global_position.x, item.global_position.z - mover.global_position.z)
		_set_input(slot, gap.normalized() * 0.3 if gap.length() > 0.7 else Vector2.ZERO, true)
		await get_tree().physics_frame
	_set_input(slot, Vector2.ZERO, true)
	await _frames(5)


func _place(slot: int, point: Vector2) -> void:
	var mover: CharacterBody3D = world.movers[slot]
	var height: float = arena.floor_height_at(Vector3(point.x, 0, point.y))
	mover.reset_for_round(Vector3(point.x, height + SETTINGS.CAPSULE_HEIGHT / 2.0 + 0.02, point.y), true)
	_set_input(slot, Vector2.ZERO)


func _set_input(slot: int, direction: Vector2, grab: bool = false, brace: bool = false) -> void:
	var snapshot = router.snapshots[slot]
	snapshot.direction = direction
	snapshot.buttons = {"grab": grab, "brace": brace}
	snapshot.pressed = {}
	snapshot.released = {}


func _find_cupboard() -> Area3D:
	for child: Node in arena.get_children():
		if child is Area3D and child.has_method("try_deliver") and "open" in child:
			return child
	return null


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().physics_frame


func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
