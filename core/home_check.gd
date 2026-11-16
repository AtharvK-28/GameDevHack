# Checks going Home from the lobby to pick another map (decision 162): Esc reaches the title, a real phone stays
# connected on the same join code, and the next map's lobby has it back.
extends "res://core/match_check.gd"

const WAIT_SECONDS: float = 2.5 # Long enough for the page wipe and a scene change.


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting home_check.gd")
		quit(1)
		return
	game.selected_arena = "res://arenas/MansionMission.tscn"
	change_scene_to_file("res://Main.tscn")
	await _wait(WAIT_SECONDS)
	await _connect_phone("Asha")
	await _wait(SETTLE_SECONDS)
	var key: String = net.session_key
	_check(game.phase == "lobby" and net.players.size() == 1, "A phone is in the first map's lobby")

	await _key(KEY_ESCAPE)
	await _wait(WAIT_SECONDS)
	_check(current_scene != null and current_scene.scene_file_path.ends_with("main_menu.tscn"), "Esc in the lobby goes to the title screen (%s)" % (current_scene.scene_file_path if current_scene != null else "no scene"))
	_check(not paused, "The title screen is not left paused")
	_check(net.session_key == key and net.player_for_slot(0).socket != null, "The phone stays connected on the same join code")

	game.selected_arena = game.SHIP_ARENA
	change_scene_to_file("res://Main.tscn")
	await _wait(WAIT_SECONDS)
	_check(current_scene.arena.ARENA_NAME == "Ghost Ship" and game.phase == "lobby", "Picking another map opens its lobby")
	_check(net.session_key == key and net.player_for_slot(0).socket != null, "The phone is still there in the new lobby")
	_send(0, {"type": "ready"})
	await _wait(SETTLE_SECONDS)
	_check(net.player_for_slot(0).ready, "It can ready up for the new map")
	print("HOME CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
