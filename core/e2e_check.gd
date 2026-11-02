# End to end: every arena played from the lobby to the story's ending, with a real phone on a real socket and a
# bot crew doing the work. The other suites each prove one part on a harness arena; this one proves the parts fit
# together in the game a player actually loads: the arena builds, the story runs, the roles rotate, a round is
# played and scored, the standings add up and the ending hands back to the lobby.
# Run:  godot --headless --path . --script res://core/e2e_check.gd
extends "res://core/match_check.gd"

# --- Check settings ---
const ARENAS: Array[String] = ["res://arenas/Mansion.tscn", "res://arenas/Ship.tscn", "res://arenas/Museum.tscn"]
const FULL_ROUND_ARENA: String = "res://arenas/Mansion.tscn" # One arena plays a whole round, to prove loot can be banked.
const PLAY_SPEED: float = 3.0
const PLAY_SECONDS: float = 25.0 # Game seconds of real bot play in a round that is then cut short.
const FULL_ROUND_TIMEOUT: float = 300.0 # Real seconds to let the full round finish.
const MOVED_DISTANCE: float = 0.5 # Metres a bot must cover for the input path to count as working.


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting e2e_check.gd")
		quit(1)
		return
	for arena_path: String in ARENAS:
		await _play_arena(arena_path)
	for client: WebSocketPeer in clients:
		client.close()
	await _wait(INPUT_SECONDS)
	print("E2E CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- One arena, lobby to ending ---
func _play_arena(arena_path: String) -> void:
	var arena_label: String = arena_path.get_file().get_basename()
	game.selected_arena = arena_path
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	await _wait(SETTLE_SECONDS)

	# One real phone and two developer stand-ins the bots play, so the round is played rather than simulated.
	await _connect_phone("Asha")
	var dev: CanvasLayer = playground.dev_tools
	dev.forced = true
	for count: int in range(2):
		dev.add_stand_in()
	await _wait(SETTLE_SECONDS)
	router.selected_slot = 3 # Nobody's slot, so the bots play both stand-ins.
	_check(net.players.size() == 3, "%s: a real phone and two stand-ins are in the lobby" % arena_label)

	await _start_match(arena_label)
	await _check_arena_built(arena_label)
	var rounds: int = game.participants.size()
	var ghosts: Array[int] = []
	for index: int in range(rounds):
		ghosts.append(await _play_round(arena_label, index, arena_path == FULL_ROUND_ARENA and index == 0))
	_check(ghosts.size() == rounds and ghosts.size() == _unique(ghosts).size(), "%s: over %d rounds every player is the ghost exactly once" % [arena_label, rounds])
	await _check_ending(arena_label)

	game.return_to_lobby()
	net.rotate_session()
	root.remove_child(playground)
	playground.free()
	clients.clear()
	inboxes.clear()
	sticks.clear()
	pids.clear()
	secrets.clear()
	await _wait(SETTLE_SECONDS)


func _start_match(arena_label: String) -> void:
	_send(0, {"type": "ready"})
	await _wait(SETTLE_SECONDS)
	await _key(KEY_ENTER)
	await _wait(INPUT_SECONDS)
	_check(game.phase == "intro" and _last(0, "match").get("phase") == "intro", "%s: starting the match opens the story, and the phone is told so" % arena_label)
	await _key(KEY_ESCAPE)
	await _wait(INPUT_SECONDS)
	# A map with a briefing (decision 155) points out its hazards before the first round, still inside "intro".
	var briefing: Node = get_first_node_in_group("arena_briefing")
	var briefed: bool = briefing != null and briefing.visible
	_check(briefed == SETTINGS.BRIEFING_MARKS.has(arena_path_of(arena_label)), "%s: %s a briefing after the story" % [arena_label, "shows" if briefed else "goes straight on with no"])
	if briefed:
		_check(game.phase == "intro", "%s: the briefing holds the intro rather than starting the round behind it" % arena_label)
		await _key(KEY_ESCAPE)
	await _wait_for_phase("reveal")
	_check(game.phase == "reveal", "%s: Esc skips the story to the role reveal" % arena_label)


func _check_arena_built(arena_label: String) -> void:
	var arena: Node3D = playground.arena
	var loot: Array = get_nodes_in_group("loot")
	var worth: int = 0
	for item: Node in loot:
		worth += item.initial_value
	_check(arena != null and not String(arena.ARENA_NAME).is_empty(), "%s: the arena loaded and names itself" % arena_label)
	_check(loot.size() >= 2 and worth == game.starting_value and worth > 0, "%s: %d items worth the round's whole %s are in the world" % [arena_label, loot.size(), _rupees(worth)])
	_check(arena.truck != null and arena.truck.banked_value == 0, "%s: the delivery zone is there and empty" % arena_label)
	_check(not preload("res://core/bot_routes.gd").ROUTES.get(arena.scene_file_path, {}).is_empty(), "%s: the bots have a route map for this arena" % arena_label)


# --- One round; returns the slot that was the ghost ---
func _play_round(arena_label: String, index: int, full_length: bool) -> int:
	await _wait_for_phase("reveal")
	for inbox: Array in inboxes:
		inbox.clear() # Each round is judged on its own messages, never on one left over from the last.
	var ghost_slot: int = game.ghost_slot
	_check(ghost_slot in game.participants, "%s round %d: the ghost is one of the players (phone %d)" % [arena_label, index + 1, ghost_slot + 1])
	# A phone works out its own role from the match snapshot: it knows its slot, the host names the ghost's.
	await _wait_until(func() -> bool: return not _last(0, "match").is_empty(), PHASE_TIMEOUT)
	var told: Dictionary = _last(0, "match")
	_check(told.get("ghost", -1) == ghost_slot and told.get("phase") == "reveal", "%s round %d: the reveal tells the phone who the ghost is (phone %d)" % [arena_label, index + 1, ghost_slot + 1])

	await _wait_for_phase("live")
	var started: Array[Vector3] = []
	for mover: CharacterBody3D in playground.movers:
		started.append(mover.global_position)
	game.normal_speed = PLAY_SPEED
	Engine.time_scale = PLAY_SPEED
	if full_length:
		await _play_to_the_end(arena_label)
	else:
		await _wait(PLAY_SECONDS / PLAY_SPEED)
		_check_bots_moved(arena_label, index, started)
		game.seconds_left = 0.2
	await _wait_for_phase("result")
	Engine.time_scale = 1.0
	if not game.replay.is_empty():
		await _key(KEY_SPACE) # Skip the Disaster Cam; the round-end page and the phone's result come after it.
	await _wait_until(func() -> bool: return not _last(0, "result").is_empty(), PHASE_TIMEOUT)

	_check(game.result.has("moversWon") and game.result.get("starting", 0) == game.starting_value, "%s round %d: the round is scored and the snapshot keeps its starting value" % [arena_label, index + 1])
	_check(game.banked_value + game.lost_value <= game.starting_value, "%s round %d: banked plus lost never exceeds what was in the house" % [arena_label, index + 1])
	_check(not _last(0, "result").is_empty(), "%s round %d: the phone is shown the result" % [arena_label, index + 1])
	await _key(KEY_ENTER)
	await _wait(INPUT_SECONDS)
	return ghost_slot


func _play_to_the_end(arena_label: String) -> void:
	# One arena plays a round out, so the whole chain from a bot's thumb to money in the truck is proven once.
	var deadline: int = Time.get_ticks_msec() + int(FULL_ROUND_TIMEOUT * 1000.0)
	while game.phase == "live" and Time.get_ticks_msec() < deadline:
		await _frame()
	_check(playground.arena.truck.banked_items > 0, "%s: playing a round out, the bot crew carried %d item(s) to the truck for %s" % [arena_label, playground.arena.truck.banked_items, _rupees(game.banked_value)])


func _check_bots_moved(arena_label: String, index: int, started: Array[Vector3]) -> void:
	var furthest: float = 0.0
	for slot: int in range(started.size()):
		if slot == 0 or not playground.movers[slot].in_play:
			continue # Slot 0 is the real phone, standing still; the ghost is out of play as a mover.
		furthest = maxf(furthest, started[slot].distance_to(playground.movers[slot].global_position))
	_check(furthest >= MOVED_DISTANCE, "%s round %d: a bot walked %.1f m, so phones, router, bots and arena are joined up" % [arena_label, index + 1, furthest])


# --- The standings and the story's ending ---
func _check_ending(arena_label: String) -> void:
	await _wait(INPUT_SECONDS)
	_check(game.phase == "final", "%s: the last round ends on the final standings" % arena_label)
	var rows: Array = game.standings()
	var sorted_rows: bool = true
	for index: int in range(1, rows.size()):
		sorted_rows = sorted_rows and rows[index - 1].points >= rows[index].points
	_check(rows.size() == 3 and sorted_rows, "%s: all three players are ranked, highest first" % arena_label)
	_check(not _last(0, "final").is_empty(), "%s: the phone is shown the standings" % arena_label)
	await _key(KEY_ENTER)
	if arena_label == "Museum": # The Museum's ending opens with The Getaway (decision 147); Esc skips to the epilogue.
		_check(game.phase == "live" and game.getaway, "Museum: Enter opens The Getaway before the ending")
		await _key(KEY_ESCAPE)
	_check(game.phase == "outro", "%s: Enter plays this arena's own ending" % arena_label)
	await _key(KEY_ESCAPE)
	await _wait(INPUT_SECONDS)
	_check(game.phase == "lobby", "%s: the ending hands back to the lobby, ready for the next crew" % arena_label)


# --- Helpers ---
func arena_path_of(arena_label: String) -> String:
	return "res://arenas/%s.tscn" % arena_label


func _unique(slots: Array[int]) -> Array[int]:
	var seen: Array[int] = []
	for slot: int in slots:
		if slot not in seen:
			seen.append(slot)
	return seen
