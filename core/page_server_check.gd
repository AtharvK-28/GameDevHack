# Checks the built-in phone page server: real HTTP requests over TCP to the running host, the content types the
# page needs, and that nothing outside controller/ can be fetched.
extends SceneTree

const SETTINGS := preload("res://autoload/Balance.gd")
const HOST: String = "127.0.0.1"
const REPLY_TIMEOUT_MS: int = 3000

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# Taken from the tree rather than the autoload identifier, which only exists once the editor has cached it.
	var page_server: Node = root.get_node("PageServer")
	_check(page_server.listen_error == OK, "The page server is listening on port %d" % SETTINGS.WEB_PORT)

	# --- The page and every file it is made of ---
	var index: Dictionary = await _fetch("/")
	_check(index.status == "200", "A bare / serves the page")
	_check(index.type.begins_with("text/html"), "The page is served as HTML")
	_check(index.body.to_lower().contains("<html"), "The page body is the real index.html")
	_check(index.length == index.body.to_utf8_buffer().size(), "Content-Length matches the body")

	for path: String in ["/index.html", "/controller.js", "/style.css", "/nipplejs.min.js", "/settings.json", "/fonts/baloo2_variable.ttf"]:
		var reply: Dictionary = await _fetch(path)
		_check(reply.status == "200" and reply.length > 0, "%s is served" % path)

	_check((await _fetch("/controller.js")).type.begins_with("text/javascript"), "Scripts are served as JavaScript")
	_check((await _fetch("/style.css")).type.begins_with("text/css"), "Styles are served as CSS")
	_check((await _fetch("/settings.json")).type.begins_with("application/json"), "Controller settings are served as JSON")
	_check((await _fetch("/fonts/baloo2_variable.ttf")).type.begins_with("font/ttf"), "The page font is served")

	# The phone reads its tuning from this file, so an empty or broken one would strand every controller.
	var settings: Dictionary = await _fetch("/settings.json")
	_check(JSON.parse_string(settings.body) != null, "The served controller settings parse as JSON")

	# --- Nothing else on the laptop is reachable ---
	for path: String in ["/missing.html", "/../project.godot", "/..%2fproject.godot", "/fonts/../../project.godot", "/autoload/Net.gd"]:
		_check((await _fetch(path)).status == "404", "%s is refused" % path)

	_check(page_server.file_for("/../project.godot").is_empty(), "A climbing path resolves to nothing")
	_check(page_server.file_for("/style.css") == "res://controller/style.css", "An ordinary path resolves inside controller/")
	_check(page_server.file_for("/") == "res://controller/index.html", "A bare / resolves to the page")

	var refused: Dictionary = await _fetch_post("/")
	_check(refused.status == "405", "Anything but GET is refused")

	# --- The play socket is untouched ---
	_check(root.get_node("Net").listen_error == OK, "The WebSocket port is still open alongside the page server")
	_check(SETTINGS.WEB_PORT != SETTINGS.SOCKET_PORT, "The page and the socket use their own ports")

	print("PAGE SERVER CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Helpers ---
func _fetch(path: String) -> Dictionary:
	return await _request("GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" % [path, HOST])


func _fetch_post(path: String) -> Dictionary:
	return await _request("POST %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" % [path, HOST])


func _request(request: String) -> Dictionary:
	var stream := StreamPeerTCP.new()
	var empty := {"status": "", "type": "", "length": 0, "body": ""}
	if stream.connect_to_host(HOST, SETTINGS.WEB_PORT) != OK:
		return empty

	var started: int = Time.get_ticks_msec()
	while stream.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		stream.poll()
		await process_frame
		if Time.get_ticks_msec() - started > REPLY_TIMEOUT_MS:
			return empty
	if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return empty

	stream.put_data(request.to_utf8_buffer())
	var raw := PackedByteArray()
	while Time.get_ticks_msec() - started < REPLY_TIMEOUT_MS:
		stream.poll()
		var available: int = stream.get_available_bytes()
		if available > 0:
			var chunk: Array = stream.get_data(available)
			if chunk[0] == OK:
				raw.append_array(chunk[1])
		elif stream.get_status() != StreamPeerTCP.STATUS_CONNECTED and not raw.is_empty():
			break
		await process_frame

	var text: String = raw.get_string_from_utf8()
	var split: int = text.find("\r\n\r\n")
	if split < 0:
		return empty
	var head: String = text.substr(0, split)
	return {
		"status": head.get_slice("\r\n", 0).get_slice(" ", 1),
		"type": _header(head, "content-type"),
		"length": int(_header(head, "content-length")),
		"body": text.substr(split + 4),
	}


func _header(head: String, name: String) -> String:
	for line: String in head.split("\r\n"):
		if line.to_lower().begins_with(name + ":"):
			return line.substr(name.length() + 1).strip_edges()
	return ""


func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
