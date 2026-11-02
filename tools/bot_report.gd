# Plays one seeded bot round and reports what the crew actually did, item by item. Decision 152 left the Museum
# unmeasurable: the balance sim only prints a win rate, so a round that banks 29% looks the same whether the bots
# were beaten by the ghost or never reached half the loot. This tool answers "which items, and why not".
# Run:  godot --headless --path . --script res://tools/bot_report.gd -- --arena=Museum [--seed=100] [--speed=3]
extends "res://core/match_check.gd"

# --- Settings ---
const ARENA_PATHS: Dictionary = {
	"Ship": "res://arenas/Ship.tscn", "Mansion": "res://arenas/Mansion.tscn", "Museum": "res://arenas/Museum.tscn",
}
const ROUND_TIMEOUT: float = 400.0 # Real seconds, with room for a slow machine.
const SAMPLE_SECONDS: float = 0.25 # How often bot modes are sampled.

# --- Run state ---
var arena_name: String = "Museum"
var round_seed: int = 100
var speed: float = 3.0
var items: Dictionary = {} # Item name -> what we know about it.
var mode_seconds: Dictionary = {} # Bot slot -> {mode -> seconds}.
var banked_log: Array[String] = []
var alarm_peak: float = 0.0
var lockdowns: int = 0
var in_lockdown: bool = false
var round_length: float = 0.0
var round_clock: float = 0.0


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before the bot report.")
		quit(1)
		return
	_read_arguments()
	await _play_round()
	quit(0)


func _read_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--arena="):
			arena_name = argument.trim_prefix("--arena=")
		elif argument.begins_with("--seed="):
			round_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--speed="):
			speed = float(argument.trim_prefix("--speed="))


# --- One round ---
func _play_round() -> void:
	game.selected_arena = ARENA_PATHS.get(arena_name, ARENA_PATHS.Museum)
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	var dev: CanvasLayer = playground.dev_tools
	dev.forced = true
	await _wait(SETTLE_SECONDS)
	for count: int in range(3):
		dev.add_stand_in()
	await _wait(0.6)
	router.selected_slot = 3 # Nobody's slot: the bots play all three.

	seed(round_seed)
	game.start_match()
	await _wait(0.2)
	if game.phase == "intro":
		await _key(KEY_ESCAPE)
		await _skip_briefing()
	await _wait_for_phase("live")
	round_length = game.seconds_left
	_snapshot_loot()
	playground.arena.truck.banked.connect(_on_banked)
	game.normal_speed = speed
	Engine.time_scale = speed

	# The round's own timer is the clock, so samples stay in game seconds whatever the speed-up.
	var deadline: int = Time.get_ticks_msec() + int(ROUND_TIMEOUT * 1000.0)
	var last_sample: float = 0.0
	while game.phase == "live" and Time.get_ticks_msec() < deadline:
		await _frame()
		round_clock = round_length - game.seconds_left
		if round_clock - last_sample >= SAMPLE_SECONDS:
			_sample(round_clock - last_sample)
			last_sample = round_clock
	_report()


func _snapshot_loot() -> void:
	for item: Node in get_nodes_in_group("loot"):
		items[item.item_name] = {
			"value": item.initial_value, "weight": item.weight_class, "node": item,
			"cased": item.has_method("in_closed_case") and item.in_closed_case(),
			"held_by_anyone": false, "banked": 0, "case_opened_at": -1.0, "first_held_at": -1.0,
			"targeted": 0.0, # Seconds a bot had this item as its goal.
			"was_held": false, "last_value": item.initial_value, "drops": 0,
			"lost_held": 0, "lost_loose": 0, # Value lost in somebody's hands, and value lost lying about.
		}


func _sample(step: float) -> void:
	var crew: Node = playground.dev_tools.bot_crew
	for bot: RefCounted in crew.bots:
		if not mode_seconds.has(bot.phone.slot):
			mode_seconds[bot.phone.slot] = {}
		var tally: Dictionary = mode_seconds[bot.phone.slot]
		tally[bot.mode] = tally.get(bot.mode, 0.0) + step
		if is_instance_valid(bot.item) and items.has(bot.item.item_name):
			items[bot.item.item_name].targeted += step
	for item_name: String in items:
		var record: Dictionary = items[item_name]
		var item: Node = record.node
		if not is_instance_valid(item):
			continue
		var held: bool = item.is_held()
		if held and record.first_held_at < 0.0:
			record.first_held_at = round_clock
			record.held_by_anyone = true
		# Where the money went: value shed while carried is handling, value shed loose is drops and the ghost.
		var lost: int = int(record.last_value) - item.value
		if lost > 0:
			record[("lost_held" if held else "lost_loose")] += lost
		record.last_value = item.value
		if record.was_held and not held and not item.finished:
			record.drops += 1
		record.was_held = held
		if record.cased and record.case_opened_at < 0.0 and not item.in_closed_case():
			record.case_opened_at = round_clock
	var alarm: Node = playground.arena.get_node_or_null("MuseumAlarm")
	if alarm != null:
		alarm_peak = maxf(alarm_peak, alarm.level)
		if alarm.state == "lockdown" and not in_lockdown:
			lockdowns += 1
		in_lockdown = alarm.state == "lockdown"


func _on_banked(value: int, _carrier_slot: int) -> void:
	# The item has already retired by now, so find the one that just vanished from the loot group.
	for item_name: String in items:
		var record: Dictionary = items[item_name]
		if record.banked == 0 and (not is_instance_valid(record.node) or record.node.finished):
			record.banked = value
			banked_log.append("%5.0fs  %-22s ₹%d" % [round_clock, item_name, value])
			return


# --- The report ---
func _report() -> void:
	print("\n================ BOT REPORT · %s · seed %d ================" % [arena_name, round_seed])
	print("Round ended: %s · banked %d%% of ₹%d · lost %d%%" % [game.result.get("reason", "?"),
		roundi(100.0 * game.banked_value / game.starting_value), game.starting_value,
		roundi(100.0 * game.lost_value / game.starting_value)])

	print("\n-- Loot --")
	print("%-24s %8s %-10s %-7s %6s %s" % ["ITEM", "VALUE", "WEIGHT", "CASED", "WANTED", "OUTCOME"])
	var never_touched: int = 0
	var never_touched_value: int = 0
	var cased_untouched: int = 0
	for item_name: String in items:
		var record: Dictionary = items[item_name]
		var outcome: String = _outcome_of(record)
		if outcome.begins_with("never touched"):
			never_touched += 1
			never_touched_value += int(record.value)
			if record.cased:
				cased_untouched += 1
		print("%-24s %8d %-10s %-7s %5.0fs %s" % [item_name, record.value, _weight_name(int(record.weight)),
			"yes" if record.cased else "-", record.targeted, outcome])
	print("Never touched: %d of %d items, ₹%d (%d%% of the round) · of those, %d were under glass"
		% [never_touched, items.size(), never_touched_value,
		roundi(100.0 * never_touched_value / game.starting_value), cased_untouched])

	print("\n-- Deliveries --")
	var face: int = 0
	var paid: int = 0
	for item_name: String in items:
		if items[item_name].banked > 0:
			face += int(items[item_name].value)
			paid += int(items[item_name].banked)
	if face > 0:
		print("Delivered ₹%d of ₹%d face value: %d%% survived the carry" % [paid, face, roundi(100.0 * paid / face)])
	var held_loss: int = 0
	var loose_loss: int = 0
	var drops: int = 0
	for item_name: String in items:
		held_loss += int(items[item_name].lost_held)
		loose_loss += int(items[item_name].lost_loose)
		drops += int(items[item_name].drops)
	print("Value lost in somebody's hands ₹%d · lost loose (dropped, shoved, cursed) ₹%d · %d drops" % [held_loss, loose_loss, drops])
	for line: String in banked_log:
		print(line)
	if banked_log.is_empty():
		print("none")

	print("\n-- Bot time --")
	for slot: int in mode_seconds:
		var tally: Dictionary = mode_seconds[slot]
		var parts: Array[String] = []
		for mode: String in tally:
			parts.append("%s %.0fs" % [mode, tally[mode]])
		print("slot %d: %s" % [slot, " · ".join(parts)])

	if playground.arena.get_node_or_null("MuseumAlarm") != null:
		print("")
		print("-- ALARM --")
		print("peak %.0f%% · lockdowns %d" % [alarm_peak, lockdowns])
	print("=========================================================\n")


func _outcome_of(record: Dictionary) -> String:
	if record.banked > 0:
		return "BANKED ₹%d" % record.banked
	var item: Node = record.node
	if not is_instance_valid(item):
		return "gone (smashed or lost)"
	if item.finished:
		return "gone (smashed or lost)"
	if record.cased and item.in_closed_case():
		return "never touched · still under glass"
	if record.first_held_at < 0.0:
		return "never touched · %.0f m from the van" % _distance_to_delivery(item)
	return "picked up at %.0fs, dropped · %.0f m from the van · ₹%d left" % [record.first_held_at,
		_distance_to_delivery(item), item.value]


func _distance_to_delivery(item: Node) -> float:
	return item.global_position.distance_to(playground.arena.truck.global_position)


func _weight_name(weight: int) -> String:
	match weight:
		SETTINGS.LIGHT: return "light"
		SETTINGS.HEAVY: return "heavy"
		SETTINGS.TWO_PERSON: return "two-person"
	return "medium"
