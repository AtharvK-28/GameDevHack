# Hosts browser WebSockets and preserves player identities for reconnects.
# Security: every host start (and every "New join code") makes a random 128-bit session key, carried in the QR
# link, and a short join code for typing in. A socket must send a hello with the key or the code within
# AUTH_TIMEOUT_MS. Each player gets a pid and a 128-bit secret; a rejoin needs both. Oversized messages and
# message floods disconnect, and an address that keeps guessing codes is locked out for a while.
extends Node

signal players_changed
signal role_changed(slot: int)
signal session_changed

# --- Protocol constants ---
const BUTTONS: Array[String] = ["grab", "throw", "brace", "possess", "action", "haunt1", "haunt2", "haunt3"]
const CLOSE_TIMED_OUT: int = 4001
const CLOSE_NEW_LOBBY: int = 4002
const CLOSE_DENIED: int = 4003
const CLOSE_RATE: int = 4008
const CLOSE_TOO_BIG: int = 4009
const CLOSE_MATCH: int = 4010
const CLOSE_FULL: int = 4011
const CLOSE_LOCKED: int = 4012

# --- Session state ---
var server := TCPServer.new()
var peers: Array[Dictionary] = []
var players: Array[Dictionary] = []
var listen_error: Error = OK
var accept_new_players: bool = true
var session_key: String = ""
var join_code: String = ""
var failed_attempts: Dictionary = {} # Address → {"count", "since", "locked_until"} in msec.

# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_new_session()
	listen_error = server.listen(Balance.SOCKET_PORT)
	if listen_error != OK:
		push_error("Controller port %d unavailable: %s" % [Balance.SOCKET_PORT, error_string(listen_error)])
		return
	print("Controllers: WebSocket listening on port %d" % Balance.SOCKET_PORT)


# --- Connection and input loop ---
func _process(_delta: float) -> void:
	_accept_connections()
	for connection: Dictionary in peers.duplicate():
		var socket: WebSocketPeer = connection.socket
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_disconnect(connection)
			continue
		if connection.pid.is_empty() and Time.get_ticks_msec() - connection.started > Balance.AUTH_TIMEOUT_MS:
			_drop(connection, CLOSE_TIMED_OUT, "Join timed out")
			continue
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			if connection.pid.is_empty() and _is_locked_out(connection.address):
				_drop(connection, CLOSE_LOCKED, "Too many wrong codes. Wait 60 seconds, then try again.")
				continue
			_read_messages(connection)

	for player: Dictionary in players:
		if Time.get_ticks_msec() - player.last_input > Balance.INPUT_TIMEOUT_MS:
			_reset_input(player)


func _exit_tree() -> void:
	for connection: Dictionary in peers:
		var socket: WebSocketPeer = connection.socket
		socket.close()
	server.stop()


# --- Public session access ---
func join_url(address: String) -> String:
	# The QR link: the key rides after "#", so it never reaches the phone page's web server.
	return "http://%s:%d/#k=%s" % [address, Balance.WEB_PORT, session_key]


func rotate_session() -> void:
	# A new key and code; everyone is disconnected and must scan again. Lobby only.
	if not accept_new_players:
		return
	for connection: Dictionary in peers.duplicate():
		_drop(connection, CLOSE_NEW_LOBBY, "The host started a new lobby. Scan the new code.")
	players.clear()
	_new_session()
	players_changed.emit()


# --- Public player access ---
func player_for_slot(slot: int) -> Dictionary:
	for player: Dictionary in players:
		if player.slot == slot:
			return player
	return {}


func send_to_player(player: Dictionary, message: Dictionary) -> void:
	var socket: WebSocketPeer = player.get("socket")
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))


func set_role(slot: int, role: String, arena: String) -> void:
	var player := player_for_slot(slot)
	if player.is_empty():
		return
	_reset_input(player)
	player.role = role
	player.arena = arena
	send_to_player(player, {"type": "role", "role": role, "arena": arena})
	role_changed.emit(slot)


# --- Connection helpers ---
func _accept_connections() -> void:
	while server.is_connection_available():
		var stream := server.take_connection()
		var address: String = stream.get_connected_host()
		if _pending_count() >= Balance.MAX_PENDING_PEERS:
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		if socket.accept_stream(stream) == OK:
			peers.append({"socket": socket, "pid": "", "address": address, "started": Time.get_ticks_msec(),
				"tokens": Balance.RATE_LIMIT_BURST, "refilled": Time.get_ticks_msec()})


func _read_messages(connection: Dictionary) -> void:
	var socket: WebSocketPeer = connection.socket
	var processed: int = 0
	while socket.get_available_packet_count() > 0 and processed < Balance.MAX_PACKETS_PER_FRAME:
		var packet := socket.get_packet()
		processed += 1
		if packet.size() > Balance.MAX_MESSAGE_BYTES:
			_drop(connection, CLOSE_TOO_BIG, "Message too large")
			return
		if not _take_token(connection):
			_drop(connection, CLOSE_RATE, "Too many messages")
			return
		if not socket.was_string_packet():
			continue
		var parser := JSON.new()
		if parser.parse(packet.get_string_from_utf8()) != OK:
			continue
		if parser.data is Dictionary:
			_handle_message(connection, parser.data)
		if connection not in peers:
			return # The message closed this socket.


func _take_token(connection: Dictionary) -> bool:
	# Token bucket: refills at RATE_LIMIT_PER_SECOND up to RATE_LIMIT_BURST; each message spends one.
	var now: int = Time.get_ticks_msec()
	var refill: float = (now - connection.refilled) / 1000.0 * Balance.RATE_LIMIT_PER_SECOND
	connection.tokens = minf(Balance.RATE_LIMIT_BURST, connection.tokens + refill)
	connection.refilled = now
	connection.tokens -= 1.0
	return connection.tokens >= 0.0


func _handle_message(connection: Dictionary, message: Dictionary) -> void:
	if connection.pid.is_empty():
		if message.get("type") == "hello":
			_join(connection, message)
		return
	var player := _player_for_pid(connection.pid)
	if player.is_empty() or player.socket != connection.socket:
		return
	match message.get("type"):
		"ready":
			player.ready = true
			_broadcast_lobby()
		"in":
			_set_direction(player, message)
		"btn":
			_set_button(player, message)


func _join(connection: Dictionary, message: Dictionary) -> void:
	if not _has_valid_key(message):
		_record_failure(connection.address)
		_drop(connection, CLOSE_DENIED, "Wrong game code. Scan the QR code on the big screen.")
		return
	if not message.get("name") is String:
		return
	var player_name: String = message.name.strip_edges().replace("\n", " ").replace("\r", " ").left(Balance.MAX_NAME_LENGTH)
	if player_name.is_empty():
		return

	var player: Dictionary = {}
	if message.get("pid") is String:
		player = _player_for_pid(message.pid)
	if not player.is_empty() and not _same(str(message.get("secret", "")), player.secret):
		# Someone else's pid without its secret: refuse, and leave the real player untouched.
		_record_failure(connection.address)
		_drop(connection, CLOSE_DENIED, "That player is already taken.")
		return
	if player.is_empty():
		if not accept_new_players:
			_drop(connection, CLOSE_MATCH, "Match in progress. Only players already in this match can rejoin.")
			return
		if players.size() >= Balance.MAX_PLAYERS:
			_free_offline_slot() # In the lobby, a new phone may take an offline phone's slot.
		if players.size() >= Balance.MAX_PLAYERS:
			_drop(connection, CLOSE_FULL, "All four players are connected. Wait for a free slot.")
			return
		player = _new_player(player_name)
		players.append(player)
	else:
		var previous_socket: WebSocketPeer = player.socket
		if previous_socket != null:
			previous_socket.close(1000, "Rejoined from another connection")
		_reset_input(player)
	player.socket = connection.socket
	connection.pid = player.pid
	player.last_input = Time.get_ticks_msec()
	send_to_player(player, {"type": "welcome", "pid": player.pid, "secret": player.secret, "key": session_key, "slot": player.slot, "colour": player.colour})
	_broadcast_lobby()
	if not player.role.is_empty():
		send_to_player(player, {"type": "role", "role": player.role, "arena": player.arena})
	print("Controller joined slot %d: %s" % [player.slot + 1, player.name])


func _drop(connection: Dictionary, code: int, reason: String) -> void:
	var socket: WebSocketPeer = connection.socket
	socket.close(code, reason)
	_disconnect(connection)


func _disconnect(connection: Dictionary) -> void:
	peers.erase(connection)
	var player := _player_for_pid(connection.pid)
	if player.is_empty() or player.socket != connection.socket:
		return
	player.socket = null
	_reset_input(player)
	print("Controller disconnected from slot %d" % (player.slot + 1))
	_broadcast_lobby()


func _pending_count() -> int:
	var count: int = 0
	for connection: Dictionary in peers:
		if connection.pid.is_empty():
			count += 1
	return count


# --- Key and code helpers ---
func _new_session() -> void:
	var crypto := Crypto.new()
	session_key = crypto.generate_random_bytes(Balance.SESSION_KEY_BYTES).hex_encode()
	var letters: String = Balance.JOIN_CODE_LETTERS
	var code_bytes: PackedByteArray = crypto.generate_random_bytes(Balance.JOIN_CODE_LENGTH)
	join_code = ""
	for value: int in code_bytes:
		join_code += letters[value % letters.length()]
	session_changed.emit()


func _has_valid_key(message: Dictionary) -> bool:
	if message.get("key") is String and _same(message.key, session_key):
		return true
	return message.get("code") is String and _same(String(message.code).strip_edges().to_upper(), join_code)


func _same(a: String, b: String) -> bool:
	# Compares in constant time, so timing reveals nothing about the key or a secret.
	var left: PackedByteArray = a.to_utf8_buffer()
	var right: PackedByteArray = b.to_utf8_buffer()
	if left.size() != right.size() or right.is_empty():
		return false
	var difference: int = 0
	for index: int in range(left.size()):
		difference |= left[index] ^ right[index]
	return difference == 0


func _record_failure(address: String) -> void:
	var now: int = Time.get_ticks_msec()
	var entry: Dictionary = failed_attempts.get(address, {"count": 0, "since": now, "locked_until": 0})
	if now - entry.since > Balance.CODE_LOCKOUT_WINDOW_MS:
		entry = {"count": 0, "since": now, "locked_until": 0}
	entry.count += 1
	if entry.count >= Balance.CODE_LOCKOUT_FAILURES:
		entry.locked_until = now + Balance.CODE_LOCKOUT_MS
		print("Locked out %s for %d s after %d wrong codes" % [address, Balance.CODE_LOCKOUT_MS / 1000, entry.count])
	failed_attempts[address] = entry


func _is_locked_out(address: String) -> bool:
	return Time.get_ticks_msec() < failed_attempts.get(address, {}).get("locked_until", 0)


# --- Input helpers ---
func _set_direction(player: Dictionary, message: Dictionary) -> void:
	var x: Variant = message.get("x")
	var y: Variant = message.get("y")
	if not _is_number(x) or not _is_number(y):
		return
	player.direction = Vector2(clampf(x, -1.0, 1.0), clampf(y, -1.0, 1.0)).limit_length()
	player.last_input = Time.get_ticks_msec()


func _set_button(player: Dictionary, message: Dictionary) -> void:
	var button: Variant = message.get("b")
	var down: Variant = message.get("down")
	if not button is String or button not in BUTTONS or not down is bool:
		return
	if Time.get_ticks_msec() - player.last_input > Balance.INPUT_TIMEOUT_MS:
		return
	if player.buttons.get(button, false) == down:
		return
	player.buttons[button] = down
	if down:
		player.pressed[button] = true
	else:
		player.released[button] = true


func _reset_input(player: Dictionary) -> void:
	player.direction = Vector2.ZERO
	player.pressed.clear()
	for button: String in player.buttons:
		if player.buttons[button]:
			player.released[button] = true
	player.buttons.clear()


# --- Registry helpers ---
func _free_offline_slot() -> void:
	# Outside a match, slots are only kept for phones that are still connected.
	if not accept_new_players:
		return
	for player: Dictionary in players:
		if player.socket == null:
			print("Slot %d freed: %s is offline" % [player.slot + 1, player.name])
			players.erase(player)
			return


func _new_player(player_name: String) -> Dictionary:
	# The lowest free slot, so slots stay stable when an offline phone's place is reused.
	var slot: int = 0
	while not player_for_slot(slot).is_empty():
		slot += 1
	var crypto := Crypto.new()
	return {
		"pid": crypto.generate_random_bytes(16).hex_encode(),
		"secret": crypto.generate_random_bytes(Balance.PLAYER_SECRET_BYTES).hex_encode(),
		"slot": slot, "name": player_name, "colour": Balance.PLAYER_COLOURS[slot],
		"ready": false, "role": "", "arena": "", "points": 0, "socket": null,
		"direction": Vector2.ZERO, "buttons": {}, "pressed": {}, "released": {},
		"last_input": Time.get_ticks_msec(),
	}


func _player_for_pid(pid: String) -> Dictionary:
	for player: Dictionary in players:
		if player.pid == pid:
			return player
	return {}


func _broadcast_lobby() -> void:
	var visible_players: Array[Dictionary] = []
	for player: Dictionary in players:
		if player.socket != null:
			visible_players.append({"name": player.name, "colour": player.colour, "ready": player.ready})
	for player: Dictionary in players:
		send_to_player(player, {"type": "lobby", "players": visible_players})
	players_changed.emit()


func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
