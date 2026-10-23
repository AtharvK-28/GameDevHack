# Hosts browser WebSockets and preserves player identities for reconnects.
extends Node

signal players_changed
signal role_changed(slot: int)

# --- Protocol constants ---
const BUTTONS: Array[String] = ["grab", "throw", "brace", "possess", "action", "haunt1", "haunt2", "haunt3"]

# --- Session state ---
var server := TCPServer.new()
var peers: Array[Dictionary] = []
var players: Array[Dictionary] = []
var listen_error: Error = OK
var accept_new_players: bool = true

# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		if connection.pid.is_empty() and Time.get_ticks_msec() - connection.started > Balance.JOIN_TIMEOUT_MS:
			socket.close(1008, "Join timed out")
			_disconnect(connection)
			continue
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_read_messages(connection)

	for player: Dictionary in players:
		if Time.get_ticks_msec() - player.last_input > Balance.INPUT_TIMEOUT_MS:
			_reset_input(player)


func _exit_tree() -> void:
	for connection: Dictionary in peers:
		var socket: WebSocketPeer = connection.socket
		socket.close()
	server.stop()


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
		if peers.size() >= Balance.MAX_PENDING_PEERS:
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		if socket.accept_stream(stream) == OK:
			peers.append({"socket": socket, "pid": "", "started": Time.get_ticks_msec()})


func _read_messages(connection: Dictionary) -> void:
	var socket: WebSocketPeer = connection.socket
	var processed: int = 0
	while socket.get_available_packet_count() > 0 and processed < Balance.MAX_PACKETS_PER_FRAME:
		var packet := socket.get_packet()
		processed += 1
		if not socket.was_string_packet() or packet.size() > Balance.MAX_PACKET_BYTES:
			continue
		var parser := JSON.new()
		if parser.parse(packet.get_string_from_utf8()) != OK:
			continue
		if parser.data is Dictionary:
			_handle_message(connection, parser.data)


func _handle_message(connection: Dictionary, message: Dictionary) -> void:
	if message.get("type") == "hello" and connection.pid.is_empty():
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
	if not message.get("name") is String:
		return
	var player_name: String = message.name.strip_edges().replace("\n", " ").replace("\r", " ").left(Balance.MAX_NAME_LENGTH)
	if player_name.is_empty():
		return
	var player: Dictionary = {}
	if message.get("pid") is String:
		player = _player_for_pid(message.pid)
	if player.is_empty():
		if not accept_new_players:
			connection.socket.close(1008, "Match in progress. Rejoin with your original browser or wait for the lobby.")
			return
		if players.size() >= Balance.MAX_PLAYERS:
			var rejected: WebSocketPeer = connection.socket
			rejected.close(1008, "All four slots are reserved. Rejoin with your original browser.")
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
	send_to_player(player, {"type": "welcome", "pid": player.pid, "slot": player.slot, "colour": player.colour})
	_broadcast_lobby()
	if not player.role.is_empty():
		send_to_player(player, {"type": "role", "role": player.role, "arena": player.arena})
	print("Controller joined slot %d: %s" % [player.slot + 1, player.name])


func _disconnect(connection: Dictionary) -> void:
	peers.erase(connection)
	var player := _player_for_pid(connection.pid)
	if player.is_empty() or player.socket != connection.socket:
		return
	player.socket = null
	_reset_input(player)
	print("Controller disconnected from slot %d" % (player.slot + 1))
	_broadcast_lobby()


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
func _new_player(player_name: String) -> Dictionary:
	var slot: int = players.size()
	return {
		"pid": Crypto.new().generate_random_bytes(16).hex_encode(),
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
