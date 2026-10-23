# Lobby: a QR code and link for phones to join, the crew with their ready state, and START for the host.
# Shown while Game is in the "lobby" phase; Enter starts once at least two phones are ready.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var crew_list := VBoxContainer.new()
var status_label: Label
var start_button: Button

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Style.pressed_key(event) in [KEY_ENTER, KEY_KP_ENTER]:
		Game.start_match()
		get_viewport().set_input_as_handled()


# --- Refresh ---
func _refresh() -> void:
	visible = Game.phase == "lobby"
	if not visible:
		return
	for row: Node in crew_list.get_children():
		row.queue_free()
	var ready_count: int = 0
	for player: Dictionary in Net.players:
		var online: bool = player.socket != null
		var state: String = "READY" if player.ready and online else ("JOINED" if online else "OFFLINE")
		if player.ready and online:
			ready_count += 1
		var row := Style.label("%s   %s" % [player.name, state], Balance.HOST_FONT_SIZE, Style.player_colour(player.slot) if online else Balance.HOST_MUTED_COLOUR)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		crew_list.add_child(row)
	if Net.players.is_empty():
		var hint := Style.label("Waiting for phones…", Balance.HOST_FONT_SIZE, Balance.HOST_MUTED_COLOUR)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		crew_list.add_child(hint)

	start_button.disabled = not Game.can_start()
	if Net.listen_error != OK:
		status_label.text = "Port %d is busy. Close the other game window, then restart." % Balance.SOCKET_PORT
	elif ready_count < 2:
		status_label.text = "2–4 players: each phone taps Ready (%d ready)" % ready_count
	else:
		status_label.text = "%d players · %d rounds · Press Enter to start" % [ready_count, Balance.MATCH_ROUNDS[ready_count - 2]]


# --- Layout ---
func _build() -> void:
	var box := Style.panel(Balance.HOST_PANEL_WIDTH)
	var rows := Style.column()
	box.add_child(rows)
	rows.add_child(Style.label("GHOSTED MOVERS", Balance.HOST_TITLE_SIZE, Balance.HOST_ACCENT_COLOUR))
	rows.add_child(Style.label("Carry it to the truck. Don't break it.", Balance.HOST_FONT_SIZE))

	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", Balance.HOST_PANEL_PADDING * 2)
	halves.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(halves)

	# Left: scan to join.
	var join := Style.column()
	halves.add_child(join)
	var urls: PackedStringArray = _join_urls()
	var code := TextureRect.new()
	code.custom_minimum_size = Vector2.ONE * Balance.QR_DISPLAY_SIZE
	code.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	code.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	code.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not urls.is_empty():
		var matrix: Array[PackedByteArray] = QrCode.encode(urls[0])
		code.texture = ImageTexture.create_from_image(QrCode.to_image(matrix, Balance.QR_MODULE_PIXELS, Balance.QR_QUIET_MODULES))
	join.add_child(code)
	join.add_child(Style.label("Scan, or open:", Balance.HOST_SMALL_SIZE, Balance.HOST_MUTED_COLOUR))
	var link := Style.label(urls[0] if not urls.is_empty() else "No network found", Balance.HOST_FONT_SIZE, Balance.HOST_ACCENT_COLOUR)
	link.autowrap_mode = TextServer.AUTOWRAP_OFF # The link must read as one line.
	join.add_child(link)
	if urls.size() > 1:
		join.add_child(Style.label("Also: " + " · ".join(urls.slice(1)), Balance.HOST_SMALL_SIZE, Balance.HOST_MUTED_COLOUR))

	# Right: the crew and the start control.
	var crew := Style.column()
	crew.custom_minimum_size.x = Balance.HOST_CREW_WIDTH
	halves.add_child(crew)
	crew.add_child(Style.label("CREW", Balance.HOST_FONT_SIZE, Balance.HOST_MUTED_COLOUR))
	crew.add_child(crew_list)
	status_label = Style.label("", Balance.HOST_SMALL_SIZE)
	crew.add_child(status_label)
	start_button = Style.button("START MATCH  (Enter)")
	start_button.pressed.connect(Game.start_match)
	crew.add_child(start_button)
	add_child(Style.centre(box))


func _join_urls() -> PackedStringArray:
	# Private IPv4 addresses first, since phones join over the local Wi-Fi.
	var preferred: PackedStringArray = []
	var others: PackedStringArray = []
	for address: String in IP.get_local_addresses():
		if not address.contains(".") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var url: String = "http://%s:%d" % [address, Balance.WEB_PORT]
		if address.begins_with("192.168.") or address.begins_with("10.") or _is_private_172(address):
			preferred.append(url)
		else:
			others.append(url)
	return preferred + others


func _is_private_172(address: String) -> bool:
	var parts: PackedStringArray = address.split(".")
	return parts.size() == 4 and parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31
