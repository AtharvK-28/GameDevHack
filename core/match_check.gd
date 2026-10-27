# Runs a whole match with two real WebSocket phones and the host keys: lobby, seeded setup, role reveal, live
# play, Curse and haunting limits, scoring boundaries, restart, ghost rotation, disconnect pause, final standings.
# This script compiles before the autoloads exist, so it reaches them through the scene tree.
extends SceneTree

# --- Test settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const INPUT_SECONDS: float = 0.12
const SETTLE_SECONDS: float = 0.6
const PHASE_TIMEOUT: float = 6.0 # Seconds to wait for a phase change.
const MOVER_HEIGHT: float = 0.8
const TOLERANCE: float = 0.3 # Metres per second, or energy per second.
const BOUNDARY_START: int = 1000 # Rupees: a round rebuilt so the 55% target and 45% limit (one mover) are whole numbers.
const BOUNDARY_PIANO: int = 550
const BOUNDARY_SMALL: int = 90 # Each of the five other items; 5 × 90 = 450 is exactly the loss limit.

# --- Test state ---
var game: Node
var net: Node
var router: Node
var playground: Node3D
var failures: int = 0
var clients: Array[WebSocketPeer] = []
var inboxes: Array[Array] = []
var sticks: Array[Vector2] = []
var pids: Array[String] = []
var secrets: Array[String] = []
var next_heartbeat: int = 0
var fresh_layout: Array = [] # Round 1's seeded layout, before any scenario changes it.

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting match_check.gd")
		quit(1)
		return
	var scripts_loaded: bool = true
	for path: String in ["res://main.gd", "res://autoload/Game.gd", "res://core/qr_code.gd", "res://screens/lobby.gd", "res://screens/hud.gd", "res://screens/round_end.gd", "res://screens/results.gd", "res://screens/role_reveal.gd", "res://actors/party_camera.gd"]:
		var script: Script = load(path)
		scripts_loaded = scripts_loaded and script != null and script.can_instantiate()
	_check(scripts_loaded, "Match, screen and camera scripts compile")
	if not scripts_loaded:
		quit(1)
		return

	playground = load("res://Main.tscn").instantiate()
	playground.arena_scene = load("res://arenas/Greybox.tscn") # Its scenarios use the greybox's coordinates.
	root.add_child(playground)
	await _wait(INPUT_SECONDS)
	await _check_lobby()
	await _check_reveal()
	await _check_host_pause()
	await _check_live_and_ghost_limits()
	await _check_curse_slowdown()
	await _check_exact_boundary()
	await _check_restart()
	await _check_early_loss()
	await _check_rotation_and_timeout()
	await _check_disconnect()
	await _check_full_match()
	for client: WebSocketPeer in clients:
		client.close()
	await _wait(INPUT_SECONDS)
	print("MATCH CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Lobby and setup ---
func _check_lobby() -> void:
	_check(game.phase == "lobby" and paused, "The match opens in the lobby with the world paused")
	await _connect_phone("Asha")
	await _connect_phone("Bilal")
	_check(_last(0, "match").get("phase") == "lobby", "Phones receive the lobby phase")
	game.start_match()
	_check(game.phase == "lobby", "The match cannot start before two phones are ready")
	for index: int in range(2):
		_send(index, {"type": "ready"})
	await _wait(SETTLE_SECONDS)
	_check(game.can_start() and _last(0, "match").get("canStart") == true, "Two ready phones can start (and phones are told)")
	var me: Dictionary = {}
	for player: Dictionary in _last(1, "match").get("players", []):
		if int(player.slot) == 1:
			me = player
	_check(me.get("ready") == true, "The match message tells each phone its own ready state")
	await _key(KEY_ENTER)
	_check(game.phase == "intro" and game.participants == [0, 1] and game.round_count == 4, "Enter starts a 2-player match of 4 rounds with the intro cutscene")
	await _wait(SETTLE_SECONDS)
	_check(_last(1, "match").get("phase") == "intro" and paused and not router.input_enabled, "During the intro the world is paused, phone input is off and phones are told")
	await _key(KEY_ESCAPE)
	_check(game.phase == "reveal", "Esc skips the intro to the round 1 reveal")


func _check_reveal() -> void:
	await _wait(INPUT_SECONDS)
	_check(_last(0, "role").get("role") == "ghost" and _last(1, "role").get("role") == "mover", "Round 1: phone 1 is the ghost and phone 2 a mover")
	_check(_last(1, "match").get("phase") == "reveal" and paused and not router.input_enabled, "During the reveal the world is paused and phone input is off")

	var loot: Array[Node] = get_nodes_in_group("loot")
	var pianos: int = 0
	var total: int = 0
	for item: Node in loot:
		total += item.value
		if item.weight_class == SETTINGS.TWO_PERSON:
			pianos += 1
	_check(loot.size() == get_nodes_in_group("loot").size() and pianos == 1, "Two players get %d seeded items with exactly one centrepiece (%d)" % [get_nodes_in_group("loot").size(), loot.size()])
	_check(game.starting_value == total and game.target_value() == ceili(total * 55 / 100.0), "The starting value is the spawned total (%s) and one mover's target is 55%%" % _rupees(total))
	fresh_layout = _layout()
	_check(load("res://props/loot.gd").lone_mover == true, "A 2-player match makes the one mover the lone mover")

	# A third phone cannot join the crew mid-match; it is seated in the audience instead (decision 119).
	var outsider := WebSocketPeer.new()
	outsider.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	var deadline: int = Time.get_ticks_msec() + 2000
	var said_hello: bool = false
	var welcome: Dictionary = {}
	while Time.get_ticks_msec() < deadline and welcome.is_empty():
		outsider.poll()
		if outsider.get_ready_state() == WebSocketPeer.STATE_OPEN and not said_hello:
			outsider.send_text(JSON.stringify({"type": "hello", "name": "Late", "key": net.session_key}))
			said_hello = true
		while outsider.get_available_packet_count() > 0:
			var reply: Variant = JSON.parse_string(outsider.get_packet().get_string_from_utf8())
			if reply is Dictionary and reply.get("type") == "welcome":
				welcome = reply
		await _frame()
	_check(welcome.get("audience", false) and net.players.size() == 2, "A new phone mid-match joins the audience, not the crew")
	outsider.close()

	# Buttons pressed during the reveal do nothing.
	_send(1, {"type": "btn", "b": "grab", "down": true})
	await _wait(INPUT_SECONDS)
	_check(router.for_slot(1).buttons.is_empty(), "Phone buttons are ignored outside live play")
	_send(1, {"type": "btn", "b": "grab", "down": false})
	await _wait_for_phase("live")
	_check(game.phase == "live" and not paused and router.input_enabled, "After the 3 s countdown the round is live")


# --- Live play, camera, energy and haunting limits ---
func _check_live_and_ghost_limits() -> void:
	var start_time: float = game.seconds_left
	await _wait(1.0)
	_check(game.seconds_left < start_time - 0.8, "The round timer counts down while live")
	var camera: Camera3D = get_first_node_in_group("party_camera")
	var forward: Vector3 = -camera.global_basis.z
	var yaw: float = rad_to_deg(atan2(-forward.x, -forward.z))
	var pitch: float = rad_to_deg(asin(-forward.y))
	_check(absf(yaw - SETTINGS.CAMERA_YAW) < 1.0 and absf(pitch - SETTINGS.CAMERA_ANGLE) < 1.0, "Three-quarter camera: %.1f° down, %.1f° sideways" % [pitch, yaw])
	var mover_b: CharacterBody3D = playground.movers[1]
	await _wait(1.5)
	# The camera frames the movers and the ghost; with one of each, it centres between them.
	var ghost_point: Vector3 = game.ghost().global_position
	var middle := (mover_b.global_position + ghost_point) / 2.0
	var focus_gap: float = Vector2(camera.focus.x - middle.x, camera.focus.z - middle.z).length()
	_check(focus_gap < 1.0 and not playground.movers[0].visible, "The camera frames the mover and the ghost together (%.2f m off); the ghost's mover is hidden" % focus_gap)

	var ghost: Node3D = game.ghost()
	_check(ghost != null and ghost.demo_rules and ghost.mover_count == 1, "The demo ghost is in play against one mover")
	ghost.energy = 50.0
	await _wait(1.0)
	_check(absf(ghost.energy - 58.0) < TOLERANCE * 5.0, "A free wisp regains 8 energy per second against one mover (%.1f)" % ghost.energy)

	# Opening protection: the first 8 s of live play allow no hauntings, and the phone says so.
	var hud: Dictionary = _last(0, "hud")
	_check(hud.get("simple") == true and hud.get("ok", {}).get("haunt1") == false and String(hud.get("reasons", {}).get("haunt1", "")).begins_with("Opening protection:"), "Phone shows the opening protection: \"%s\"" % hud.get("reasons", {}).get("haunt1", ""))
	_check(hud.get("target") == "Grand piano", "The wisp's Curse target is the nearby piano")
	var piano: Node = _piano()
	await _tap(0, "haunt3")
	_check(piano.curse_left == 0.0, "Curse is refused during the opening protection")
	await _wait_until(func() -> bool: return ghost.opening_left <= 0.0, SETTINGS.HAUNT_OPENING_GRACE)
	var energy_before: float = ghost.energy
	await _tap(0, "haunt3")
	_check(piano.curse_left > SETTINGS.CURSE_DURATION - 0.5 and absf(energy_before - ghost.energy - SETTINGS.CURSE_COST) < 3.0, "Curse costs 30 and curses the piano for 6 s")
	await _wait(SETTLE_SECONDS)
	hud = _last(0, "hud")
	_check(String(hud.get("reasons", {}).get("haunt1", "")).begins_with("Haunting lock:"), "After a haunting the shared lock shows on the phone: \"%s\"" % hud.get("reasons", {}).get("haunt1", ""))
	_check(hud.get("target") != "Grand piano", "A cursed item is not a target again, so curses never stack")
	await _wait_until(func() -> bool: return ghost.shared_lock_left <= 0.0, SETTINGS.HAUNT_SHARED_LOCK + 1.0)
	await _wait(SETTLE_SECONDS)
	hud = _last(0, "hud")
	_check(String(hud.get("reasons", {}).get("haunt3", "")).begins_with("Cooldown:") and hud.get("ok", {}).get("haunt1") == true, "Then Curse shows its own cooldown (\"%s\") and House Shake is ready" % hud.get("reasons", {}).get("haunt3", ""))


func _check_curse_slowdown() -> void:
	# A mover carrying a cursed light item moves 30% slower until the curse ends; the phone shows the seconds.
	var mover_b: CharacterBody3D = playground.movers[1]
	var item: Node = null
	for candidate: Node in get_nodes_in_group("loot"):
		if candidate.weight_class == SETTINGS.LIGHT:
			item = candidate
	if item == null:
		for candidate: Node in get_nodes_in_group("loot"):
			if candidate.weight_class != SETTINGS.TWO_PERSON:
				item = candidate
	# Open ground in front of the house, where seeded loot never spawns, so nothing else can be bumped or grabbed.
	_place(mover_b, Vector3(-5.0, MOVER_HEIGHT, 7.0), Vector3.RIGHT)
	item.global_position = Vector3(-5.0 + SETTINGS.HOLD_DISTANCE, SETTINGS.LOOT_SIZES[item.loot_kind].y / 2.0 + 0.03, 7.0)
	item.linear_velocity = Vector3.ZERO
	await _wait(SETTLE_SECONDS)
	_send(1, {"type": "btn", "b": "grab", "down": true})
	await _wait(SETTLE_SECONDS)
	_check(mover_b.held_item == item, "Phone 2 picks up the %s" % item.item_name)
	item.curse()
	var normal_speed: float = SETTINGS.MOVER_SPEED * SETTINGS.CARRY_SPEEDS[item.weight_class]
	_set_stick(1, Vector2.RIGHT)
	await _wait(0.4)
	_check(absf(mover_b.velocity.x - normal_speed * SETTINGS.CURSE_CARRY_RATIO) < TOLERANCE, "Carrying a cursed item is 30%% slower (%.2f m/s)" % mover_b.velocity.x)
	_set_stick(1, Vector2.ZERO)
	await _wait(SETTLE_SECONDS)
	_check(int(_last(1, "hud").get("cursed", 0)) > 0, "The mover's phone shows the curse's remaining seconds")
	await _wait_until(func() -> bool: return item.curse_left <= 0.0, SETTINGS.CURSE_DURATION + 1.0)
	_set_stick(1, Vector2.LEFT)
	await _wait(0.4)
	_check(absf(mover_b.velocity.x + normal_speed) < TOLERANCE, "When the curse ends, carrying speed is back to normal (%.2f m/s)" % mover_b.velocity.x)
	_set_stick(1, Vector2.ZERO)
	_send(1, {"type": "btn", "b": "grab", "down": false})
	await _wait(SETTLE_SECONDS)


# --- Scoring ---
func _check_exact_boundary() -> void:
	# Exactly 55% delivered and exactly 45% lost: the movers win once every item is accounted for.
	_set_boundary_values()
	var piano: Node = _piano()
	piano.global_position = playground.arena.truck.global_position + Vector3.UP * 0.6
	piano.linear_velocity = Vector3.ZERO
	_check(playground.arena.truck.try_bank(piano), "The piano banks in the truck")
	for item: Node in _loose_loot():
		item._lose_value(item.value)
	await _wait_for_phase("result")
	var result: Dictionary = game.result
	_check(result.get("moversWon") == true and result.get("banked") == BOUNDARY_PIANO and result.get("lost") == BOUNDARY_START - BOUNDARY_PIANO, "Exactly 55%% delivered with exactly 45%% lost is a movers' win (%s)" % result.get("reason", ""))
	# The mover banked nothing themselves; their stars and bonus goal pay on top of the win bonus (decision 123).
	var medals: float = result.get("stars", 0) * SETTINGS.STAR_POINTS + (SETTINGS.GOAL_POINTS if result.goal.get("state") == "met" else 0.0)
	var ghost_goal: float = SETTINGS.GHOST_GOAL_POINTS if result.ghostGoal.get("state") == "met" else 0.0
	_check(result.get("stars") == 1, "Exactly the target earns one star")
	_check(is_equal_approx(game.round_points.get(1, -1.0), SETTINGS.MOVER_WIN_BONUS + medals) and is_equal_approx(game.round_points.get(0, -1.0), 4.5 + ghost_goal), "Points: the mover gets the win bonus and medals, the ghost 1 per ₹100 lost (%.1f, %.1f)" % [game.round_points.get(1, -1.0), game.round_points.get(0, -1.0)])
	_check(paused and not router.input_enabled, "The result freezes play")
	await _wait(INPUT_SECONDS)
	_check(_last(1, "match").get("phase") == "result" and _last(1, "result").get("moversWon") == true, "Phones receive the result")
	var frozen: Dictionary = game.result.duplicate()
	game._evaluate_round()
	_check(game.result == frozen, "The result is evaluated once and then frozen")


func _check_restart() -> void:
	var scores_before: Dictionary = game.scores.duplicate()
	await _key(KEY_R)
	_check(game.phase == "reveal" and game.ghost_slot == 0, "R restarts the round with the same roles")
	_check(_layout() == fresh_layout, "Restart rebuilds the same seeded layout with original values")
	_check(roundi(game.scores.get(0, 0.0)) == 0 and roundi(game.scores.get(1, 0.0)) == 0 and scores_before.get(1, 0.0) > 0.0, "Restart replaces the attempt's score instead of adding to it")
	await _wait_for_phase("live")


func _check_early_loss() -> void:
	# Losing even ₹1 more than 45% makes one mover's target impossible, so the ghost wins at once.
	_set_boundary_values()
	for item: Node in _loose_loot():
		if item.weight_class != SETTINGS.TWO_PERSON:
			item._lose_value(item.value)
	await _wait(INPUT_SECONDS)
	_check(game.phase == "live", "Exactly 45% lost does not end the round")
	_piano()._lose_value(1)
	await _wait_for_phase("result")
	_check(game.result.get("moversWon") == false and String(game.result.get("reason", "")).contains("45%"), "One rupee past the 45%% limit ends it for the ghost (%s)" % game.result.get("reason", ""))
	var ghost_goal: float = SETTINGS.GHOST_GOAL_POINTS if game.result.ghostGoal.get("state") == "met" else 0.0 # Decision 123.
	_check(absf(game.round_points.get(0, 0.0) - (4.51 + SETTINGS.GHOST_WIN_BONUS + ghost_goal)) < 0.01, "The ghost scores the loss plus the win bonus (%.2f)" % game.round_points.get(0, 0.0))


func _check_rotation_and_timeout() -> void:
	await _key(KEY_ENTER)
	await _wait(INPUT_SECONDS)
	_check(game.round_index == 1 and game.ghost_slot == 1, "Enter starts round 2 with the ghost passed to phone 2")
	_check(_last(0, "role").get("role") == "mover" and _last(1, "role").get("role") == "ghost", "Phones swap roles for round 2")
	await _wait_for_phase("live")
	game.seconds_left = 0.3
	await _wait_for_phase("result")
	_check(game.result.get("moversWon") == false and game.result.get("reason") == "Time is up.", "When time runs out short of the target, the ghost wins")


func _check_disconnect() -> void:
	await _key(KEY_ENTER)
	await _wait_for_phase("live")
	clients[1].close()
	await _wait_for_phase("paused")
	_check(game.phase == "paused" and paused and String(game.pause_reason).contains("Bilal"), "A missing phone pauses the round: \"%s\"" % game.pause_reason)
	var frozen_time: float = game.seconds_left
	await _wait(1.0)
	_check(is_equal_approx(game.seconds_left, frozen_time), "The timer stops while paused")
	_check(_last(0, "match").get("phase") == "paused", "The other phone shows the pause")
	await _reconnect_phone(1)
	await _wait_for_phase("live")
	_check(game.phase == "live" and _last(1, "role").get("role") == "mover", "Rejoining with the same browser resumes the round with the same role")

	clients[1].close()
	await _wait_for_phase("paused")
	await _key(KEY_L)
	_check(game.phase == "lobby" and game.participants.is_empty() and net.accept_new_players, "L cancels to the lobby without scoring the round")
	await _reconnect_phone(1)
	await _wait(SETTLE_SECONDS)
	_check(_last(1, "match").get("phase") == "lobby", "Phones are back in the lobby")


func _check_full_match() -> void:
	for index: int in range(2):
		_send(index, {"type": "ready"})
	await _wait(SETTLE_SECONDS)
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE) # Skip the intro cutscene.
	for round_number: int in range(4):
		await _wait_for_phase("live")
		_check(game.ghost_slot == game.participants[round_number % 2], "Round %d: the ghost is phone %d" % [round_number + 1, game.ghost_slot + 1])
		game.seconds_left = 0.2
		await _wait_for_phase("result")
		await _key(KEY_ENTER)
	await _wait(INPUT_SECONDS)
	_check(game.phase == "final" and _last(0, "final").has("standings") and _last(0, "match").get("phase") == "final", "After 4 rounds the final standings show on the host and phones")
	var rows: Array = game.standings()
	_check(rows.size() == 2 and rows[0].points >= rows[1].points, "Standings are sorted by points")
	await _key(KEY_ENTER)
	_check(game.phase == "lobby", "Enter on the final screen returns to the lobby")


# --- Scenario helpers ---
func _set_boundary_values() -> void:
	# Rebuild this round's values so the 55% target and 45% limit are exact whole numbers.
	for item: Node in get_nodes_in_group("loot"):
		var value: int = BOUNDARY_PIANO if item.weight_class == SETTINGS.TWO_PERSON else BOUNDARY_SMALL
		item.value = value
		item.initial_value = value
	game.starting_value = BOUNDARY_START


func _piano() -> Node:
	for item: Node in get_nodes_in_group("loot"):
		if item.weight_class == SETTINGS.TWO_PERSON:
			return item
	return null


func _loose_loot() -> Array[Node]:
	var items: Array[Node] = []
	for item: Node in get_nodes_in_group("loot"):
		if not item.finished:
			items.append(item)
	return items


func _layout() -> Array:
	var rows: Array = []
	for item: Node in get_nodes_in_group("loot"):
		rows.append([item.loot_kind, item.value, item.position.snapped(Vector3.ONE * 0.01)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))
	return rows


func _place(target: CharacterBody3D, location: Vector3, direction: Vector3) -> void:
	target.position = location
	target.velocity = Vector3.ZERO
	target.facing = direction
	target._update_hold_point()


func _rupees(amount: int) -> String:
	return "₹%d" % amount


func _wait_for_phase(phase: String) -> void:
	await _wait_until(func() -> bool: return game.phase == phase, PHASE_TIMEOUT)


func _wait_until(condition: Callable, seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await _frame()


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frame()
	await _frame()


func _tap(index: int, button: String) -> void:
	_send(index, {"type": "btn", "b": button, "down": true})
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "btn", "b": button, "down": false})
	await _wait(INPUT_SECONDS)


# --- Phone helpers ---
func _connect_phone(player_name: String) -> void:
	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	clients.append(client)
	inboxes.append([])
	sticks.append(Vector2.ZERO)
	pids.append("")
	secrets.append("")
	var index: int = clients.size() - 1
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "hello", "name": player_name, "key": net.session_key})
	await _wait(INPUT_SECONDS * 2.0)
	pids[index] = _last(index, "welcome").get("pid", "")
	secrets[index] = _last(index, "welcome").get("secret", "")


func _reconnect_phone(index: int) -> void:
	# The same browser rejoining: a new socket that says hello with the stored player id and secret.
	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	clients[index] = client
	inboxes[index].clear()
	await _wait(INPUT_SECONDS)
	_send(index, {"type": "hello", "name": "Bilal", "key": net.session_key, "pid": pids[index], "secret": secrets[index]})
	await _wait(INPUT_SECONDS * 2.0)


func _last(index: int, message_type: String) -> Dictionary:
	for position: int in range(inboxes[index].size() - 1, -1, -1):
		if inboxes[index][position].get("type") == message_type:
			return inboxes[index][position]
	return {}


func _set_stick(index: int, direction: Vector2) -> void:
	sticks[index] = direction
	var screen: Vector2 = router.world_to_stick(direction) # Sticks are screen-relative.
	_send(index, {"type": "in", "x": screen.x, "y": screen.y})


func _wait(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await _frame()


func _frame() -> void:
	# Every frame: read host messages and keep each phone's heartbeat (its current stick) flowing.
	var send_heartbeat: bool = Time.get_ticks_msec() >= next_heartbeat
	for index: int in range(clients.size()):
		var client: WebSocketPeer = clients[index]
		client.poll()
		while client.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(client.get_packet().get_string_from_utf8())
			if message is Dictionary:
				inboxes[index].append(message)
		if send_heartbeat:
			var screen: Vector2 = router.world_to_stick(sticks[index]) # Sticks are screen-relative.
			_send(index, {"type": "in", "x": screen.x, "y": screen.y})
	if send_heartbeat:
		next_heartbeat = Time.get_ticks_msec() + int(1000.0 / SETTINGS.INPUT_RATE)
	await process_frame


func _send(index: int, message: Dictionary) -> void:
	if clients[index].get_ready_state() == WebSocketPeer.STATE_OPEN:
		clients[index].send_text(JSON.stringify(message))


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _check_host_pause() -> void:
	game.pause_by_host()
	var time_before: float = game.seconds_left
	await _wait(INPUT_SECONDS)
	_check(game.phase == "paused" and paused and game.seconds_left == time_before, "Host pause freezes simulation and timer")
	game._players_changed()
	_check(game.phase == "paused", "Connected phones do not bypass the host pause")
	game.resume_by_host()
	_check(game.phase == "live" and not paused, "Host resume restores live play")
	_check(game.room_items.size() == get_nodes_in_group("loot").size(), "Room ledger tracks every spawned item")
