# Integration check: real WebSockets exercise the running host and capsule movement.
extends SceneTree

# --- Test settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const WAIT_SECONDS: float = 0.15
const CONNECT_TIMEOUT_SECONDS: float = 3.0
const TEST_NAMES: Array[String] = ["Amber", "Blue", "Pink", "Green"]

# --- Test state ---
var clients: Array[WebSocketPeer] = []
var inboxes: Array[Array] = []
var failures: int = 0
var net: Node
var router: Node
var playground: Node

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


# --- Integration scenarios ---
func _run() -> void:
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	_check(net.listen_error == OK, "WebSocket port available")
	if net.listen_error != OK:
		quit(1)
		return
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	for slot: int in range(SETTINGS.MAX_PLAYERS):
		await _connect_client()
		_send(slot, {"type": "hello", "name": TEST_NAMES[slot]})
		await _pump(WAIT_SECONDS)
		var welcome := _find_message(slot, "welcome")
		_check(welcome.get("slot", -1) == slot, "Client %d gets a distinct slot" % slot)
		_send(slot, {"type": "ready"})
	await _pump(WAIT_SECONDS)
	_check(net.players.size() == SETTINGS.MAX_PLAYERS, "Four players registered")
	for slot: int in range(SETTINGS.MAX_PLAYERS):
		_check(_find_message(slot, "role").get("role") == "mover", "Ready client receives mover controls")

	await _check_movement()
	await _check_validation_and_timeout()
	await _check_reconnect_and_capacity()
	await _check_keyboard()
	for client: WebSocketPeer in clients:
		client.close()
	await _pump(WAIT_SECONDS)
	print("PLUMBING CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _check_movement() -> void:
	var movers: Array[Node] = []
	for child: Node in playground.get_children():
		if child is CharacterBody3D:
			movers.append(child)
	var starts: Array[Vector3] = []
	for mover: Node3D in movers:
		starts.append(mover.position)
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for slot: int in range(SETTINGS.MAX_PLAYERS):
		_send(slot, {"type": "in", "x": directions[slot].x, "y": directions[slot].y})
	await _pump(WAIT_SECONDS)
	for slot: int in range(SETTINGS.MAX_PLAYERS):
		var displacement: Vector3 = movers[slot].position - starts[slot]
		_check(Vector2(displacement.x, displacement.z).dot(directions[slot]) > 0.1, "Capsule %d moves in its own direction" % slot)
		_send(slot, {"type": "in", "x": 0, "y": 0})
	await _pump(WAIT_SECONDS)


func _check_validation_and_timeout() -> void:
	clients[0].send_text("not-json")
	_send(0, {"type": "in", "x": "bad", "y": []})
	_send(0, {"type": "btn", "b": "grab", "down": "yes"})
	_send(0, {"type": "unrecognised"})
	await _pump(WAIT_SECONDS)
	var player: Dictionary = net.player_for_slot(0)
	_check(player.direction == Vector2.ZERO and not player.buttons.get("grab", false), "Malformed messages do not change input")
	_send(0, {"type": "in", "x": 100, "y": 100})
	_send(0, {"type": "btn", "b": "grab", "down": true})
	await _pump(WAIT_SECONDS)
	_check(is_equal_approx(player.direction.length(), 1.0), "Joystick magnitude is clamped")
	_check(player.buttons.get("grab", false), "Held button reaches host")
	await _pump(SETTINGS.INPUT_TIMEOUT_MS / 1000.0 + WAIT_SECONDS)
	_check(player.direction == Vector2.ZERO and player.buttons.is_empty(), "500 ms dead-man switch clears movement and buttons")
	_send(0, {"type": "btn", "b": "grab", "down": true})
	await _pump(WAIT_SECONDS)
	_check(player.buttons.is_empty(), "Buttons cannot revive a timed-out controller")
	_send(0, {"type": "in", "x": 0, "y": 0})
	_send(0, {"type": "btn", "b": "throw", "down": true})
	_send(0, {"type": "btn", "b": "throw", "down": false})
	var saw_tap: bool = false
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000)
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		var snapshot = router.for_slot(0)
		if snapshot.pressed.get("throw", false) and snapshot.released.get("throw", false):
			saw_tap = true
	_check(saw_tap, "A press and release in one tick preserve the tap")


func _check_reconnect_and_capacity() -> void:
	var player: Dictionary = net.player_for_slot(1)
	var pid: String = player.pid
	player.points = 75
	_send(1, {"type": "in", "x": 1, "y": 0})
	_send(1, {"type": "btn", "b": "grab", "down": true})
	await _pump(WAIT_SECONDS)
	clients[1].close()
	await _pump(WAIT_SECONDS)
	_check(player.socket == null and player.direction == Vector2.ZERO and player.buttons.is_empty(), "Disconnect immediately clears held input")
	await _connect_client()
	var reconnect_index: int = clients.size() - 1
	_send(reconnect_index, {"type": "hello", "name": "Blue", "pid": pid})
	await _pump(WAIT_SECONDS)
	_check(_find_message(reconnect_index, "welcome").get("slot") == 1, "Reconnect restores the same slot")
	_check(_find_message(reconnect_index, "role").get("role") == "mover" and player.points == 75, "Reconnect preserves role and points")
	_check(player.direction == Vector2.ZERO and player.buttons.is_empty(), "Reconnect starts with released controls")
	await _connect_client()
	var extra_index: int = clients.size() - 1
	_send(extra_index, {"type": "hello", "name": "Fifth"})
	await _pump(WAIT_SECONDS)
	_check(clients[extra_index].get_close_code() == 1008 and net.players.size() == 4, "Fifth player cannot claim another slot")


func _check_keyboard() -> void:
	clients[0].close()
	await _pump(WAIT_SECONDS)
	router.selected_slot = 0
	router.has_focus = true
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	await _pump(WAIT_SECONDS)
	_check(router.for_slot(0).direction == Vector2.RIGHT, "Keyboard fallback moves an unconnected slot")
	event.pressed = false
	Input.parse_input_event(event)
	await _pump(WAIT_SECONDS)
	_check(router.for_slot(0).direction == Vector2.ZERO, "Keyboard release stops movement")
	var grab := InputEventKey.new()
	grab.physical_keycode = KEY_SPACE
	grab.pressed = true
	Input.parse_input_event(grab)
	await _pump(WAIT_SECONDS)
	_check(router.for_slot(0).buttons.get("grab", false), "Keyboard grab is held")
	router._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _pump(WAIT_SECONDS)
	_check(router.for_slot(0).buttons.is_empty(), "Losing window focus releases keyboard buttons")
	grab.pressed = false
	Input.parse_input_event(grab)


# --- Socket and assertion helpers ---
func _connect_client() -> void:
	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	clients.append(client)
	inboxes.append([])
	var deadline: int = Time.get_ticks_msec() + int(CONNECT_TIMEOUT_SECONDS * 1000)
	while client.get_ready_state() == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() < deadline:
		await _pump(0.01)
	_check(client.get_ready_state() == WebSocketPeer.STATE_OPEN, "WebSocket handshake completed")


func _pump(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		for index: int in range(clients.size()):
			var client: WebSocketPeer = clients[index]
			client.poll()
			while client.get_available_packet_count() > 0:
				var message: Variant = JSON.parse_string(client.get_packet().get_string_from_utf8())
				if message is Dictionary:
					inboxes[index].append(message)
		await process_frame


func _send(index: int, message: Dictionary) -> void:
	clients[index].send_text(JSON.stringify(message))


func _find_message(index: int, type: String) -> Dictionary:
	for message: Dictionary in inboxes[index]:
		if message.get("type") == type:
			return message
	return {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
