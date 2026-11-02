# The wire puzzle over a real socket (decision 158): a phone standing at the fuse box is dealt the puzzle, its
# joins are judged by the host, junk is refused, walking away drops it, and solving it powers the box. The
# mission's own logic is checked by core/mission_check.gd; this is the protocol and the host's half of it.
# Run:  godot --headless --path . --script res://core/wire_check.gd
extends "res://core/match_check.gd"


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting wire_check.gd")
		quit(1)
		return
	game.selected_arena = "res://arenas/MansionMission.tscn"
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	await _wait(SETTLE_SECONDS)
	await _connect_phone("Asha")
	await _connect_phone("Bilal")
	for index: int in range(clients.size()):
		_send(index, {"type": "ready"})
	await _wait(SETTLE_SECONDS)
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE) # Skip the story.
	await _wait_for_phase("live")

	var arena: Node3D = playground.arena
	var box: Node3D = arena.fuse_box
	var mission: Node = arena.mission
	_check(box != null and mission != null, "The mission arena is live with its fuse box")
	if box == null or mission == null:
		_finish()
		return

	# Stand a mover at the box with the first two steps already behind them.
	var slot: int = game.participants[0] if game.ghost_slot != game.participants[0] else game.participants[1]
	mission.complete("key")
	mission.complete("cupboard")
	_check(mission.is_open("wires"), "The crew have reached the wires step")
	var mover: CharacterBody3D = playground.movers[slot]
	mover.global_position = box.global_position + Vector3(0.0, SETTINGS.CAPSULE_HEIGHT / 2.0, 0.8)
	await _wait(INPUT_SECONDS)

	# Holding GRAB at the box deals the puzzle to that phone and nobody else's.
	var index: int = _index_of(slot)
	_send(index, {"type": "btn", "b": "grab", "down": true})
	await _wait_until(func() -> bool: return not _last(index, "wires").is_empty(), PHASE_TIMEOUT)
	var dealt: Dictionary = _last(index, "wires")
	_check(dealt.get("open", false) and dealt.get("left", []).size() == SETTINGS.MISSION_WIRE_PAIRS, "Holding GRAB at the box deals the puzzle to that phone")
	_check(playground.wire_puzzle.open and playground.wire_puzzle.slot == slot, "The host knows whose puzzle it is")

	# A junk join is refused and changes nothing; the host never trusts the phone's arithmetic.
	var before: Array = playground.wire_puzzle.joined.duplicate()
	_send(index, {"type": "wire", "l": 99, "r": 0})
	_send(index, {"type": "wire", "l": "nonsense", "r": null})
	await _wait(INPUT_SECONDS * 3)
	_check(playground.wire_puzzle.joined == before, "Out-of-range and malformed joins are refused")

	var wrong: Array[int] = _mismatched()
	if not wrong.is_empty():
		_send(index, {"type": "wire", "l": wrong[0], "r": wrong[1]})
		await _wait(INPUT_SECONDS * 3)
		_check(playground.wire_puzzle.joined == before, "Joining two different colours is refused over the socket too")

	# Walking away drops it, joins and all.
	mover.global_position += Vector3(0.0, 0.0, 6.0)
	await _wait(INPUT_SECONDS * 4)
	_check(not playground.wire_puzzle.open and not box.powered, "Walking away from the box drops the puzzle")
	var dropped: Dictionary = _last(index, "wires")
	_check(not dropped.get("open", true) and not dropped.get("solved", true), "The phone is told the puzzle closed unsolved")

	# Back at the box, solve it properly: the box powers up and the step is done.
	mover.global_position = box.global_position + Vector3(0.0, SETTINGS.CAPSULE_HEIGHT / 2.0, 0.8)
	await _wait_until(func() -> bool: return playground.wire_puzzle.open, PHASE_TIMEOUT)
	_check(playground.wire_puzzle.open, "Coming back to the box deals a fresh puzzle")
	for left_pin: int in SETTINGS.MISSION_WIRE_PAIRS:
		_send(index, {"type": "wire", "l": left_pin, "r": _match_for(left_pin)})
		await _wait(INPUT_SECONDS * 2)
	_check(mission.is_done("wires") and box.powered, "Matching every pair finishes the step and powers the box")
	var closed: Dictionary = _last(index, "wires")
	_check(not closed.get("open", true) and closed.get("solved", false), "The phone is told it was solved")
	_check(not arena.stair_gate.shut, "The power opens the stair gate, so the gallery is reachable at last")
	_send(index, {"type": "btn", "b": "grab", "down": false})
	_finish()


func _finish() -> void:
	for client: WebSocketPeer in clients:
		client.close()
	print("WIRE CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Helpers ---
func _index_of(slot: int) -> int:
	for index: int in range(pids.size()):
		if net.player_for_slot(slot).get("pid", "") == pids[index]:
			return index
	return 0


func _match_for(left_pin: int) -> int:
	var puzzle: RefCounted = playground.wire_puzzle
	return puzzle.right.find(puzzle.left[left_pin])


func _mismatched() -> Array[int]:
	var puzzle: RefCounted = playground.wire_puzzle
	for left_pin: int in puzzle.left.size():
		for right_pin: int in puzzle.right.size():
			if puzzle.left[left_pin] != puzzle.right[right_pin]:
				return [left_pin, right_pin]
	return []
