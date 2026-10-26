# Checks developer mode's playing stand-ins (decision 121): on the Ghost Ship and the Old Mansion, three stand-ins
# with no keyboard player play a whole round at ×3 speed. Mover bots must carry loot and move the two-person item
# together along its path; the ghost bot must haunt and possess. Who wins varies from run to run (the physics and
# the ghost see to that), so the score is printed, not judged. -- --trace adds a log.
extends "res://core/match_check.gd"

const ARENAS: Array[String] = ["res://arenas/Ship.tscn", "res://arenas/Mansion.tscn"]
const SPEED: float = 3.0
const SPEED_ARGUMENT: String = "--speed=" # -- --speed=1 plays at normal speed instead.
const ROUND_TIMEOUT: float = 200.0 # Real seconds: a 150 s round at ×1, with room for a slow machine.
const ROUND_SEEDS: Array[int] = [3, 11] # Match seeds: the same loot each run.

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	for index: int in range(ARENAS.size()):
		await _play_round(ARENAS[index], ROUND_SEEDS[index])
	print("BOT CREW CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _play_round(arena_path: String, round_seed: int) -> void:
	game.selected_arena = arena_path
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	var dev: CanvasLayer = playground.dev_tools
	dev.forced = true
	await _wait(SETTLE_SECONDS)
	for count: int in range(3):
		dev.add_stand_in()
	await _wait(0.6)
	router.selected_slot = 3 # Nobody's slot: the bots play all three.
	seed(round_seed) # The match draws its round seed from the global generator.
	game.start_match()
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	var speed: float = SPEED
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SPEED_ARGUMENT):
			speed = float(argument.trim_prefix(SPEED_ARGUMENT))
	game.normal_speed = speed
	Engine.time_scale = speed
	await _wait(0.2) # The bots pick their roles on their first live frame.
	var name: String = playground.arena.ARENA_NAME
	var ghost: Node3D = playground.ghost
	var pair_item: Node3D = dev.bot_crew.pair_item
	var deliveries: Array[int] = [0] # In an array: a lambda captures a plain local by value.
	game.host.arena.truck.delivered.connect(func(_value: int, _slots: Array[int]) -> void: deliveries[0] += 1)
	if OS.get_cmdline_user_args().has("--trace"):
		for item: Node in get_nodes_in_group("loot"):
			item.damaged.connect(func(loss: int, _remaining: int) -> void:
				if loss >= 200:
					print("  %s lost %d · held %s · thrown %s · possessed %s · at %s" % [item.item_name, loss, item.is_held(), item.thrown, item.haunted, item.global_position.snapped(Vector3.ONE * 0.1)]))
	var haunted: bool = false
	var possessed: bool = false
	var pair_moved: bool = false
	var carried: bool = false
	var deadline: int = Time.get_ticks_msec() + int(ROUND_TIMEOUT * 1000.0)
	while game.phase == "live" and Time.get_ticks_msec() < deadline:
		if pair_item == null and is_instance_valid(dev.bot_crew.pair_item):
			pair_item = dev.bot_crew.pair_item
		haunted = haunted or (is_instance_valid(ghost) and ghost.hauntings[0].is_active())
		possessed = possessed or (is_instance_valid(ghost) and is_instance_valid(ghost.possessing))
		pair_moved = pair_moved or dev.bot_crew.pair_waypoint >= 1
		for bot: RefCounted in dev.bot_crew.bots:
			carried = carried or is_instance_valid(bot.mover.held_item)
		if OS.get_cmdline_user_args().has("--trace") and Engine.get_process_frames() % 120 == 0:
			_trace(dev.bot_crew)
		await _frame()
	print("%s: %s · banked ₹%d of ₹%d · %d deliveries · pair item %s" % [name, "movers won" if game.result.get("moversWon", false) else "ghost won", game.banked_value, game.starting_value, deliveries[0],
		"carried along its path" if pair_moved else "not moved"])
	_check(game.phase == "result", "%s: the bots play the round to its end" % name)
	_check(carried, "%s: mover bots pick up loot" % name)
	_check(pair_moved, "%s: two mover bots carry the two-person item along its path" % name)
	_check(haunted and possessed, "%s: the ghost bot haunts and possesses (haunted %s, possessed %s)" % [name, haunted, possessed])
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s: the round end runs at normal speed" % name)
	game.return_to_lobby()
	net.rotate_session()
	root.remove_child(playground)
	playground.free()
	await _wait(0.3)


func _trace(crew: Node) -> void:
	var line: String = "%.0f s left · banked %d lost %d ·" % [game.seconds_left, game.banked_value, game.lost_value]
	for bot: RefCounted in crew.bots:
		var at: Vector3 = bot.mover.global_position
		line += " P%d %s %s (%.1f, %.1f, %.1f) route %d stuck %d ·" % [bot.phone.slot + 1, bot.mode, bot.item.item_name if is_instance_valid(bot.item) else "-", at.x, at.y, at.z, bot.route.size(), bot.stuck_count]
	if is_instance_valid(crew.pair_item):
		line += " pair holders %d wp %d value %d" % [crew.pair_item.holder_count(), crew.pair_waypoint, crew.pair_item.value]
		for index: int in range(2):
			line += " h%d %s" % [index, crew.pair_item.handle_position(index).snapped(Vector3.ONE * 0.1)]
		for bot: RefCounted in crew.bots:
			line += " · P%d end %d grab %s stick %s facing %s" % [bot.phone.slot + 1, bot.pair_end, bot.phone.buttons.get("grab", false), bot.phone.stick.snapped(Vector2.ONE * 0.01), Vector2(bot.mover.facing.x, bot.mover.facing.z).snapped(Vector2.ONE * 0.01)]
	print(line)
