# Lobby, styled as the moving company's clock-in board: the job sheet with the QR code and link on the left, a
# time card per player slot on the right (CLOCKED IN is stamped on when a phone readies up), and START for the host.
# Shown while Game is in the "lobby" phase; Enter starts once at least two phones are ready.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var card_grid := GridContainer.new()
var status_label: Label
var start_button: Button
var qr_texture: TextureRect
var join_label: Label
var join_address: String = ""
var roster_signature: String = ""
var ready_slots: Array[int] = [] # Slots shown as clocked in, so only new ones get the stamp slam.

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.use_theme(self)
	_build()
	Game.changed.connect(_refresh)
	Net.session_changed.connect(_refresh_join)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Style.pressed_key(event) in [KEY_ENTER, KEY_KP_ENTER]:
		Game.start_match()
		get_viewport().set_input_as_handled()


# --- Refresh ---
func _refresh() -> void:
	visible = Game.phase == "lobby"
	if not visible:
		ready_slots.clear() # Everyone is stamped in afresh next time the lobby shows.
		roster_signature = ""
		return
	var roster: Array = []
	for player: Dictionary in Net.players:
		roster.append([player.slot, player.name, player.ready, player.socket != null])
	var signature: String = JSON.stringify(roster)
	if signature == roster_signature:
		return
	roster_signature = signature
	for card: Node in card_grid.get_children():
		card.queue_free()
	var now_ready: Array[int] = []
	for slot: int in Balance.MAX_PLAYERS:
		var player: Dictionary = Net.player_for_slot(slot)
		var online: bool = not player.is_empty() and player.socket != null
		if online and player.ready:
			now_ready.append(slot)
		card_grid.add_child(_time_card(slot, player, online, slot in now_ready and slot not in ready_slots))
	ready_slots = now_ready

	start_button.disabled = not Game.can_start()
	if Net.listen_error != OK:
		status_label.text = "Port %d is busy. Close the other game window, then restart." % Balance.SOCKET_PORT
	elif PageServer.listen_error != OK:
		status_label.text = "PHONE PAGE COULDN'T START: ports %d–%d are in use. Close what uses them, then restart." % [Balance.WEB_PORT, Balance.WEB_PORT + Balance.WEB_PORT_TRIES - 1]
	elif now_ready.size() < 2:
		status_label.text = "2–4 movers: each phone taps Ready (%d clocked in)" % now_ready.size()
	else:
		status_label.text = "%d movers · %d rounds · the job starts on Enter" % [now_ready.size(), Balance.MATCH_ROUNDS[now_ready.size() - 2]]


# --- Time cards ---
func _time_card(slot: int, player: Dictionary, online: bool, slam: bool) -> Control:
	var colour: Color = Style.player_colour(slot)
	var joined: bool = not player.is_empty()
	var card: PanelContainer
	if joined:
		card = Style.ink_panel(0.0, Balance.UI_PANEL_MARGIN / 2)
		if not online:
			card.modulate.a = Balance.LOBBY_PULSE_ALPHA # Offline: kept dim until the phone returns.
	else:
		card = PanelContainer.new() # An empty slot: a dashed outline, gently pulsing.
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(Balance.UI_PANEL_MARGIN / 2)
		card.add_theme_stylebox_override("panel", empty)
		card.draw.connect(_draw_dashes.bind(card, colour))
		var pulse := card.create_tween().set_loops()
		pulse.tween_property(card, "modulate:a", Balance.LOBBY_PULSE_ALPHA, Balance.LOBBY_PULSE_SECONDS)
		pulse.tween_property(card, "modulate:a", 1.0, Balance.LOBBY_PULSE_SECONDS)
	card.custom_minimum_size = Balance.TIME_CARD_SIZE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	card.add_child(row)
	row.add_child(Style.mover_figure(colour if joined else Balance.UI_MUTED, Balance.TIME_CARD_FIGURE))
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 0)
	row.add_child(lines)
	var tag := Style.lettering("MOVER #%d" % (slot + 1), Balance.UI_SMALL_SIZE, colour)
	tag.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lines.add_child(tag)
	var name_line := Style.label(Style.short_name(player.name) if joined else "Waiting for a mover…", Balance.UI_BODY_SIZE if joined else Balance.UI_SMALL_SIZE, Balance.UI_TEXT if joined else Balance.UI_MUTED)
	name_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	lines.add_child(name_line)
	if joined and not (online and player.ready):
		var state := Style.label("Phone offline" if not online else "Tap Ready on your phone", Balance.UI_SMALL_SIZE, Balance.UI_MUTED)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		state.autowrap_mode = TextServer.AUTOWRAP_OFF
		lines.add_child(state)
	if online and player.ready:
		var stamp := Style.stamp("CLOCKED IN", Balance.UI_GHOST, Balance.COMIC_LABEL_SIZE)
		lines.add_child(stamp)
		if slam:
			Style.slam(stamp)
	return card


func _draw_dashes(card: Control, colour: Color) -> void:
	var rect := Rect2(Vector2.ONE * 2.0, card.size - Vector2.ONE * 4.0)
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side: int in 4:
		card.draw_dashed_line(corners[side], corners[(side + 1) % 4], Color(colour, 0.8), Balance.COMIC_BORDER, 10.0)


# --- Layout ---
func _build() -> void:
	add_child(Style.backdrop())
	var rows := Style.column()
	rows.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	var title := Style.lettering("GHOSTED MOVERS", Balance.COMIC_TITLE_SIZE, Balance.UI_MONEY)
	rows.add_child(title)

	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN * 2)
	halves.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(halves)
	halves.add_child(_build_job_sheet())

	# Right: the time cards, the status line and START.
	var crew := Style.column()
	halves.add_child(crew)
	var heading := Style.lettering("TIME CARDS", Balance.COMIC_LABEL_SIZE, Balance.UI_TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	crew.add_child(heading)
	card_grid.columns = 2
	card_grid.add_theme_constant_override("h_separation", Balance.UI_PANEL_MARGIN)
	card_grid.add_theme_constant_override("v_separation", Balance.UI_PANEL_MARGIN)
	crew.add_child(card_grid)
	status_label = Style.label("", Balance.UI_SMALL_SIZE, Balance.UI_MUTED)
	crew.add_child(status_label)
	var start := Style.action("START THE JOB", "Enter", Game.start_match)
	start_button = start.get_child(1)
	crew.add_child(start)

	var hint := Style.label("F11: fullscreen or window", Balance.UI_SMALL_SIZE, Balance.UI_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(Balance.UI_SCREEN_MARGIN))
	add_child(Style.centre(rows))
	add_child(hint)


func _build_job_sheet() -> Control:
	# Left: the job sheet, a parchment clipboard with the QR code, the link and the join code.
	var sheet := Style.caption(0.0, Balance.UI_PANEL_MARGIN)
	var join := Style.column()
	sheet.add_child(join)
	var heading := Style.lettering("JOB SHEET", Balance.COMIC_LABEL_SIZE, Balance.COMIC_INK)
	heading.add_theme_constant_override("outline_size", 0)
	join.add_child(heading)
	join.add_child(Style.ink_label("Scan to clock in", Balance.UI_SMALL_SIZE))
	var urls: PackedStringArray = _join_urls()
	var code := TextureRect.new()
	qr_texture = code
	code.custom_minimum_size = Vector2.ONE * Balance.LOBBY_QR_SIZE
	code.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	code.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	code.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not urls.is_empty():
		join_address = urls[0].trim_prefix("http://").get_slice(":", 0)
		var matrix: Array[PackedByteArray] = QrCode.encode(Net.join_url(join_address))
		code.texture = ImageTexture.create_from_image(QrCode.to_image(matrix, Balance.QR_MODULE_PIXELS, Balance.QR_QUIET_MODULES))
	join.add_child(code)
	var link := Style.ink_label(urls[0] if not urls.is_empty() else "No network found", Balance.UI_SMALL_SIZE)
	link.autowrap_mode = TextServer.AUTOWRAP_OFF # The link must read as one line.
	join.add_child(link)
	join_label = Style.lettering("CODE  " + Net.join_code, Balance.COMIC_LABEL_SIZE, Balance.UI_GHOST)
	join_label.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	join.add_child(join_label)
	var rotate := Style.button("New join code")
	rotate.tooltip_text = "Disconnect everyone and invalidate the old QR code"
	rotate.pressed.connect(Net.rotate_session)
	join.add_child(rotate)
	if urls.size() > 1:
		join.add_child(Style.ink_label("Also: " + " · ".join(urls.slice(1)), Balance.UI_SMALL_SIZE))
	return sheet


func _join_urls() -> PackedStringArray:
	# Private IPv4 addresses first, since phones join over the local Wi-Fi.
	var preferred: PackedStringArray = []
	var others: PackedStringArray = []
	for address: String in IP.get_local_addresses():
		if not address.contains(".") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var url: String = "http://%s:%d" % [address, PageServer.port]
		if address.begins_with("192.168.") or address.begins_with("10.") or _is_private_172(address):
			preferred.append(url)
		else:
			others.append(url)
	return preferred + others


func _is_private_172(address: String) -> bool:
	var parts: PackedStringArray = address.split(".")
	return parts.size() == 4 and parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31


func _refresh_join() -> void:
	if join_label == null or join_address.is_empty():
		return
	join_label.text = "CODE  " + Net.join_code
	qr_texture.texture = ImageTexture.create_from_image(QrCode.to_image(QrCode.encode(Net.join_url(join_address)), Balance.QR_MODULE_PIXELS, Balance.QR_QUIET_MODULES))
