# Checks Disaster Cam (decision 144) in a developer-mode match on the Old Mansion with three stand-ins and the bots
# off: the recorder tracks the round, a smash becomes a clip (with a copy of the shattered item), the replay plays
# before the round-end page and puts the world back after, Enter skips it, a small loss has no replay, and the final
# results open with the match's worst disasters.
extends "res://core/match_check.gd"

var dev: CanvasLayer
var replay: Control
var round_end: Control

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	skip_replays = false # This check presses the keys on the replay itself.
	game.selected_arena = "res://arenas/Mansion.tscn"
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	dev = playground.dev_tools
	await _wait(SETTLE_SECONDS)
	for control: Node in playground.find_children("*", "Control", true, false):
		var path: String = control.get_script().resource_path if control.get_script() != null else ""
		if path == "res://screens/disaster_replay.gd":
			replay = control
		elif path == "res://screens/round_end.gd":
			round_end = control
	_check(replay != null and round_end != null and playground.disaster_cam != null, "The match has a Disaster Cam recorder and replay screen")
	dev.forced = true
	for count: int in range(3):
		await _key(KEY_F10)
	await _wait(0.5)
	await _key(KEY_ENTER)
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	await _ctrl_key(KEY_B) # Bots off: a quiet round, so only the check breaks things.
	await _wait(1.0)
	var recorder: Node = playground.disaster_cam
	var tracked: int = recorder.bodies.filter(func(body: Node3D) -> bool: return is_instance_valid(body) and body.is_in_group("loot")).size()
	_check(tracked == get_nodes_in_group("loot").size() and recorder.frames.size() >= 20, "The recorder tracks every loot item and records frames (%d loot, %d frames)" % [tracked, recorder.frames.size()])

	# Round 1: shatter an item. It becomes the round's clip, with a copy of the item even though it is gone.
	var vase: Node3D = _cheapest_loot()
	var vase_index: int = recorder.body_index[vase.get_instance_id()]
	var vase_name: String = vase.item_name
	var round_first: int = game.round_index
	vase._lose_value(vase.value)
	await _wait(SETTINGS.DISASTER_CAM_TAIL + 0.3)
	var clip: Dictionary = recorder.clips.get(round_first, {})
	_check(not clip.is_empty() and clip.focal.item == vase_name and clip.focal.smashed, "Shattering %s makes the round's clip" % vase_name)
	_check(not clip.is_empty() and clip.puppets[vase_index] is Node3D and clip.puppets[vase_index].get_child_count() > 0, "The clip keeps a copy of the shattered item")
	var kinds: Array = clip.get("events", []).map(func(event: Dictionary) -> String: return event.kind)
	_check(kinds.has("sound") and kinds.has("label") and kinds.has("burst"), "The clip has the smash's sound, popup and shards")

	var movers_before: Array[Vector3] = []
	for mover: CharacterBody3D in playground.movers:
		movers_before.append(mover.global_position)
	await _ctrl_key(KEY_W)
	await _frame()
	_check(game.phase == "result" and replay.playing and replay.visible and not round_end.visible, "At the round end the replay plays before the round-end page")
	var other_loot: Node3D = get_nodes_in_group("loot")[0]
	_check(not other_loot.visible, "The real loot hides while puppets act the clip out")
	var seen_vase: bool = false
	var deadline: int = Time.get_ticks_msec() + 20000
	while replay.playing and Time.get_ticks_msec() < deadline:
		var puppet: Node3D = clip.puppets[vase_index]
		seen_vase = seen_vase or (replay.stage == "play" and puppet.is_inside_tree() and puppet.visible)
		await _frame()
	_check(seen_vase, "The shattered item appears in its own replay")
	_check(not replay.playing and round_end.visible and game.replay.is_empty(), "After the replay the round-end page shows")
	var restored: bool = other_loot.visible
	for slot: int in range(playground.movers.size()):
		restored = restored and playground.movers[slot].global_position.distance_to(movers_before[slot]) < 0.05
	_check(restored and playground.camera.follow_movers, "The world is put back: loot shown, movers where they were, the camera following")

	# Round 2: a small loss has no replay.
	await _key(KEY_ENTER)
	await _wait_for_phase("live")
	await _wait(0.5)
	var scratched: Node3D = _cheapest_loot()
	scratched._lose_value(mini(300, scratched.value - 1))
	await _wait(SETTINGS.DISASTER_CAM_TAIL + 0.3)
	await _ctrl_key(KEY_N) # Ends the round and makes the next one the last.
	await _frame()
	_check(game.phase == "result" and not replay.playing and round_end.visible, "A small scratch has no replay: the page shows at once")

	# Round 3: Enter skips the replay without moving on.
	await _key(KEY_ENTER)
	await _wait_for_phase("live")
	await _wait(0.5)
	var bigger: Node3D = _dearest_below(game.starting_value * 0.25) # Dear enough to top round 1, not enough to end the round.
	_check(bigger != null and bigger.value > clip.focal.total, "Round 3 has an item dearer than round 1's")
	bigger._lose_value(bigger.value)
	await _wait(SETTINGS.DISASTER_CAM_TAIL + 0.3)
	await _ctrl_key(KEY_L)
	await _frame()
	_check(replay.playing, "The last round's smash replays too")
	await _wait(1.0)
	await _key(KEY_ENTER)
	_check(not replay.playing and round_end.visible and game.phase == "result", "Enter skips the replay to the round-end page, and only that")

	# The final results open with the reel of the match's worst disasters, worst last.
	await _key(KEY_ENTER)
	await _frame()
	_check(game.phase == "final" and replay.playing and replay.reel_mode and replay.reel_place == 1, "The final results open with a reel of the two disasters")
	_check(replay.clip.get("round", -1) == round_first, "The reel starts with the smaller one")
	await _key(KEY_ENTER)
	_check(not replay.playing and game.replay.is_empty(), "Enter skips the reel to the final results")
	game.return_to_lobby()
	await _wait(0.3)
	_check(recorder.clips.is_empty(), "Back in the lobby the clips are gone")
	print("REPLAY CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _dearest_below(limit: float) -> Node3D:
	var dearest: Node3D = null
	for item: Node3D in get_nodes_in_group("loot"):
		if item.value < limit and (dearest == null or item.value > dearest.value):
			dearest = item
	return dearest


func _cheapest_loot() -> Node3D:
	var cheapest: Node3D = null
	for item: Node3D in get_nodes_in_group("loot"):
		if item.value > 1 and (cheapest == null or item.value < cheapest.value):
			cheapest = item
	return cheapest


func _ctrl_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.ctrl_pressed = true
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frame()
	await _frame()
