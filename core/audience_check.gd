# Checks the audience with real WebSocket phones: late and fifth phones join the audience, votes count once per
# phone, ties go to chaos, each outcome happens, and the timed vote opens on its own in live play.
extends "res://core/match_check.gd"

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	await _wait(SETTLE_SECONDS) # Let the host come up before the first phone says hello.
	await _connect_phone("Asha")
	await _connect_phone("Bilal")
	await _connect_watcher("Cara", true) # Asks to watch, in the lobby.
	_check(_last(2, "welcome").get("audience", false) and net.players.size() == 2 and net.audience_count() == 1, "A phone that asks to watch joins the audience, not the crew")
	for index: int in range(2):
		_send(index, {"type": "ready"})
	await _wait(0.3)
	game.start_match()
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	await _connect_watcher("Dev", false) # A plain join mid-match.
	_check(_last(3, "welcome").get("audience", false) and net.players.size() == 2 and net.audience_count() == 2, "A phone joining mid-match becomes audience instead of being turned away")

	var vote: Node = playground.audience_vote
	vote.open_vote()
	await _wait(0.2)
	_check(_last(2, "vote").get("open", false) and _last(3, "vote").get("options", []).size() == 3 and _last(0, "vote").is_empty(), "Audience phones get the vote; players' phones don't")
	_send(2, {"type": "vote", "o": 2})
	_send(3, {"type": "vote", "o": 0})
	_send(3, {"type": "vote", "o": 2}) # Changed their mind.
	_send(3, {"type": "vote", "o": 9})
	_send(0, {"type": "vote", "o": 0}) # A player, not audience.
	await _wait(0.2)
	_check(vote.tally() == [0, 0, 2], "One vote per audience phone, the latest counts, junk and players ignored (%s)" % [vote.tally()])
	var ghost: Node3D = playground.ghost
	var haunting: Haunting = ghost.hauntings[0]
	haunting.cooldown_left = 0.0
	vote.close_vote()
	await _wait(0.1)
	_check(haunting.is_active() and is_equal_approx(haunting.cooldown_left, 0.0), "CHAOS triggers the House Shake with its warning, without spending the ghost's cooldown")
	_check(_last(2, "vote").get("winner", -1) == 2, "Audience phones hear the result")
	await _wait_until(func() -> bool: return not haunting.is_active(), 6.0)

	ghost.energy = 50.0
	playground.apply_audience_choice("ghost")
	_check(is_equal_approx(ghost.energy, 50.0 + SETTINGS.VOTE_GHOST_ENERGY), "HELP THE GHOST adds energy")
	var mover: CharacterBody3D = playground.movers[1 - game.ghost_slot]
	playground.apply_audience_choice("movers")
	_check(mover.boost_left > 0.0 and is_equal_approx(mover.movement_speed(), SETTINGS.MOVER_SPEED * SETTINGS.VOTE_SPEED_BOOST), "HELP THE MOVERS speeds the movers up")

	vote.open_vote()
	vote.votes = {"a": 0, "b": 2}
	vote.close_vote()
	_check(vote.winner == 2, "A tie goes to chaos")
	vote.open_vote()
	vote.close_vote()
	_check(vote.winner == -1, "No votes, nothing happens")
	vote.next_left = 0.05
	await _wait(0.3)
	_check(vote.open, "The next vote opens by itself during live play")

	for client: WebSocketPeer in clients:
		client.close()
	game.return_to_lobby()
	await _wait(0.1)
	print("AUDIENCE CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _connect_watcher(watcher_name: String, asks: bool) -> void:
	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	clients.append(client)
	inboxes.append([])
	sticks.append(Vector2.ZERO)
	pids.append("")
	secrets.append("")
	var index: int = clients.size() - 1
	await _wait(INPUT_SECONDS)
	var hello: Dictionary = {"type": "hello", "name": watcher_name, "key": net.session_key}
	if asks:
		hello.audience = true
	_send(index, hello)
	await _wait(INPUT_SECONDS * 2.0)
