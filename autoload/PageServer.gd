# Serves the phone controller page over HTTP, so the laptop runs the game alone with no separate web server.
# A small read-only HTTP/1.1 GET handler: everything under controller/ is public by design, and nothing else on
# the laptop is reachable. The WebSocket that carries play stays on its own port in Net.gd.
extends Node

# --- Settings ---
const ROOT: String = "res://controller"
const INDEX: String = "index.html"
const HEAD_LIMIT: int = 4096 # Bytes of request head accepted before the request is refused.
const HEAD_TIMEOUT_MS: int = 4000 # A connection that never finishes its request is dropped.
const READ_CHUNK: int = 1024

# Content types for the files the phone page is made of. Anything else is refused rather than guessed.
const TYPES: Dictionary = {
	"html": "text/html; charset=utf-8",
	"js": "text/javascript; charset=utf-8",
	"css": "text/css; charset=utf-8",
	"json": "application/json; charset=utf-8",
	"txt": "text/plain; charset=utf-8",
	"ttf": "font/ttf",
}

# --- State ---
var server := TCPServer.new()
var listen_error: int = OK
var port: int = Balance.WEB_PORT # The port actually serving the page; every link to the page uses it.
var pending: Array[Dictionary] = [] # Connections whose request head has not arrived yet.


# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start()


# Listens on WEB_PORT, or the next free port after it when another program holds it (decision 126).
func start() -> void:
	stop()
	var last: int = Balance.WEB_PORT + Balance.WEB_PORT_TRIES - 1
	for candidate: int in range(Balance.WEB_PORT, last + 1):
		listen_error = server.listen(candidate)
		if listen_error == OK:
			port = candidate
			if port != Balance.WEB_PORT:
				push_warning("Phone page port %d is in use; serving on %d instead" % [Balance.WEB_PORT, port])
			print("Phone page: serving controller/ on port %d" % port)
			return
	port = Balance.WEB_PORT
	push_error("Phone page ports %d–%d unavailable: %s" % [Balance.WEB_PORT, last, error_string(listen_error)])


func stop() -> void:
	for connection: Dictionary in pending:
		connection.stream.disconnect_from_host()
	pending.clear()
	server.stop()


func _exit_tree() -> void:
	stop()


# --- Connection loop ---
func _process(_delta: float) -> void:
	while server.is_connection_available():
		pending.append({"stream": server.take_connection(), "started": Time.get_ticks_msec(), "head": PackedByteArray()})

	for connection: Dictionary in pending.duplicate():
		_advance(connection)


func _advance(connection: Dictionary) -> void:
	var stream: StreamPeerTCP = connection.stream
	stream.poll()
	if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		pending.erase(connection)
		return

	var available: int = stream.get_available_bytes()
	if available > 0:
		var chunk: Array = stream.get_data(mini(available, READ_CHUNK))
		if chunk[0] == OK:
			connection.head.append_array(chunk[1])

	var text: String = connection.head.get_string_from_utf8()
	if text.contains("\r\n\r\n"):
		pending.erase(connection)
		_handle(stream, text)
	elif connection.head.size() > HEAD_LIMIT:
		pending.erase(connection)
		_respond(stream, "431 Request Header Fields Too Large", "text/plain; charset=utf-8", PackedByteArray())
	elif Time.get_ticks_msec() - connection.started > HEAD_TIMEOUT_MS:
		pending.erase(connection)
		stream.disconnect_from_host()


# --- Requests ---
func _handle(stream: StreamPeerTCP, request: String) -> void:
	var line: String = request.get_slice("\r\n", 0)
	var parts: PackedStringArray = line.split(" ")
	if parts.size() < 2 or parts[0] != "GET":
		_respond(stream, "405 Method Not Allowed", "text/plain; charset=utf-8", "Only GET".to_utf8_buffer())
		return

	var path: String = file_for(parts[1])
	if path.is_empty() or not FileAccess.file_exists(path):
		_respond(stream, "404 Not Found", "text/plain; charset=utf-8", "Not found".to_utf8_buffer())
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_respond(stream, "404 Not Found", "text/plain; charset=utf-8", "Not found".to_utf8_buffer())
		return
	_respond(stream, "200 OK", TYPES[path.get_extension()], file.get_buffer(file.get_length()))


# The file a request path names, or "" when it names anything outside the phone page.
func file_for(target: String) -> String:
	var clean: String = target.get_slice("?", 0).get_slice("#", 0).uri_decode()
	if not clean.begins_with("/"):
		return ""
	if clean == "/":
		clean = "/" + INDEX
	# Nothing may climb out of controller/, and only the page's own file types are served.
	if clean.contains("..") or clean.contains("\\") or clean.contains(":"):
		return ""
	if not TYPES.has(clean.get_extension()):
		return ""
	return ROOT + clean


func _respond(stream: StreamPeerTCP, status: String, type: String, body: PackedByteArray) -> void:
	var head: String = "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [status, type, body.size()]
	stream.put_data(head.to_utf8_buffer() + body)
	stream.disconnect_from_host()
