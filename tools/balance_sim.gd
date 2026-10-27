# Plays seeded bot rounds on each arena and reports how they went, to compare balance changes on the same rounds.
# Three developer-mode stand-ins play every round (core/bot_crew.gd): one ghost, two movers. Bots play worse than
# people, so read the numbers as a direction, not as the win rate a crew will see.
# Run:  godot --headless --path . --script res://tools/balance_sim.gd -- --rounds=10 --speed=3
extends "res://core/match_check.gd"

const ARENAS: Array[String] = ["res://arenas/Ship.tscn", "res://arenas/Mansion.tscn"]
const ROUND_TIMEOUT: float = 400.0 # Real seconds for one round, with room for a slow machine.
const FIRST_SEED: int = 100 # Round n plays seed FIRST_SEED + n on every run.

var rounds: int = 10
var speed: float = 3.0

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before the balance run.")
		quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rounds="):
			rounds = int(argument.trim_prefix("--rounds="))
		elif argument.begins_with("--speed="):
			speed = float(argument.trim_prefix("--speed="))
	for arena_path: String in ARENAS:
		await _play_arena(arena_path)
	quit(0)


func _play_arena(arena_path: String) -> void:
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
	var wins: int = 0
	var banked_share: float = 0.0
	var lost_share: float = 0.0
	var name: String = ""
	for index: int in range(rounds):
		seed(FIRST_SEED + index) # The match draws its round seed from the global generator.
		game.start_match()
		await _wait(0.2)
		await _key(KEY_ESCAPE)
		await _wait_for_phase("live")
		name = playground.arena.ARENA_NAME
		game.normal_speed = speed
		Engine.time_scale = speed
		var deadline: int = Time.get_ticks_msec() + int(ROUND_TIMEOUT * 1000.0)
		while game.phase == "live" and Time.get_ticks_msec() < deadline:
			await _frame()
		var won: bool = game.result.get("moversWon", false)
		wins += 1 if won else 0
		banked_share += float(game.banked_value) / game.starting_value
		lost_share += float(game.lost_value) / game.starting_value
		print("%s round %d (seed %d): %s · banked %d%% · lost %d%% · %s" % [name, index + 1, FIRST_SEED + index, "movers" if won else "ghost",
			roundi(100.0 * game.banked_value / game.starting_value), roundi(100.0 * game.lost_value / game.starting_value), game.result.get("reason", "")])
		game.return_to_lobby()
		await _wait(0.5) # The stand-ins ready up again.
	print("BALANCE %s: movers won %d of %d · average banked %d%% · average lost %d%%" % [name, wins, rounds, roundi(100.0 * banked_share / rounds), roundi(100.0 * lost_share / rounds)])
	game.return_to_lobby()
	net.rotate_session()
	root.remove_child(playground)
	playground.free()
	await _wait(0.3)
