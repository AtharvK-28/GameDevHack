# Comic edge HUD: a punch-clock timer, the truck meter (cargo filling toward the 70% flag) with a cracking-vase
# damage meter, room item status, delivery notices and player chips. Panels sit at the screen edges so the centre
# stays clear; the screen edges pulse red near the loss limit. Holding Tab shows the full totals, Esc opens the
# pause menu.
extends Control

const Style := preload("res://screens/screen_style.gd")
var timer_card: Control
var timer_label: Label
var dial: Control
var round_seconds: float = 1.0 # The round's starting time, for the dial's sweep.
var truck_meter: Control
var delivered_label: Label
var vase: Control
var lost_label: Label
var room_label: Label
var discs: Control
var refresh_left: float = 0.0
var pause_menu: Control
var chip_labels: Dictionary = {}
var energy_ring: Control
var chip_slots: Array[int] = []
var chip_ghost_slot: int = -1
var chips: VBoxContainer
var toasts: VBoxContainer
var totals: Control
var totals_label: Label
var pause_box: Control
var pause_label: Label
var toast_entries: Array[Dictionary] = []
var previous_phase: String = ""
var generator_label: Label
var danger: Control
var clock_time: float = 0.0 # Seconds since start, for the wobble and the red pulse.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.use_theme(self)
	danger = Control.new()
	danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger.draw.connect(_draw_danger)
	add_child(danger)

	var timer := _card(Control.PRESET_CENTER_TOP, 0.0)
	timer_card = timer.get_parent()
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	timer.add_child(timer_row)
	dial = Control.new()
	dial.custom_minimum_size = Vector2.ONE * Balance.HUD_DIAL_SIZE
	dial.draw.connect(_draw_dial)
	timer_row.add_child(dial)
	timer_label = Style.lettering("2:30", Balance.COMIC_TITLE_SIZE)
	timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_row.add_child(timer_label)

	var truck := _card(Control.PRESET_TOP_RIGHT, Balance.HUD_CARD_WIDTH)
	var heading := Style.lettering("THE TRUCK", Balance.COMIC_LABEL_SIZE)
	heading.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	truck.add_child(heading)
	truck_meter = Control.new()
	truck_meter.custom_minimum_size = Balance.HUD_TRUCK_SIZE
	truck_meter.draw.connect(_draw_truck)
	truck.add_child(truck_meter)
	delivered_label = _label(truck, "", Balance.UI_BODY_SIZE)
	delivered_label.modulate = Balance.UI_MONEY
	var damage := HBoxContainer.new()
	damage.alignment = BoxContainer.ALIGNMENT_CENTER
	damage.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	truck.add_child(damage)
	vase = Control.new()
	vase.custom_minimum_size = Balance.HUD_VASE_SIZE
	vase.draw.connect(_draw_vase)
	damage.add_child(vase)
	lost_label = Style.label("", Balance.UI_SMALL_SIZE, Balance.UI_DANGER)
	lost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	damage.add_child(lost_label)
	generator_label = _label(truck, "", Balance.UI_SMALL_SIZE)
	generator_label.modulate = Balance.GENERATOR_COLOUR

	var room := _card(Control.PRESET_TOP_LEFT, 200.0)
	room_label = _label(room, "Main room", Balance.UI_BODY_SIZE)
	discs = Control.new()
	discs.custom_minimum_size = Balance.HUD_ROOM_SIZE
	discs.draw.connect(_draw_room)
	room.add_child(discs)
	chips = VBoxContainer.new() # Player chips stand on their own at the bottom right, without a card.
	chips.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.set_meta("edge_preset", Control.PRESET_BOTTOM_RIGHT)
	add_child(chips)
	toasts = VBoxContainer.new()
	toasts.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_meta("edge_preset", Control.PRESET_BOTTOM_LEFT)
	add_child(toasts)

	var box := Style.ink_panel(Balance.HOST_PANEL_WIDTH)
	totals_label = Style.label("", Balance.UI_BODY_SIZE)
	box.add_child(totals_label)
	totals = Style.centre(box)
	add_child(totals)
	var pause_panel := Style.caption(Balance.HOST_PANEL_WIDTH)
	var pause_rows := Style.column()
	pause_panel.add_child(pause_rows)
	var paused_title := Style.lettering("PAUSED", Balance.COMIC_TITLE_SIZE, Balance.COMIC_INK)
	paused_title.add_theme_constant_override("outline_size", 0)
	pause_rows.add_child(paused_title)
	pause_label = Style.ink_label("", Balance.UI_HEADING_SIZE)
	pause_rows.add_child(pause_label)
	pause_box = Style.centre(pause_panel)
	add_child(pause_box)
	Game.delivery_notice.connect(_delivered)
	resized.connect(_layout_cards)

func _card(preset: int, width: float) -> VBoxContainer:
	var panel := Style.ink_panel(width, Balance.HUD_PANEL_PADDING, Color(Balance.UI_PANEL, Balance.UI_HUD_ALPHA))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_meta("edge_preset", preset)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", Balance.HUD_ROW_GAP)
	panel.add_child(column)
	return column


func _position_card(panel: Control, preset: int) -> void:
	var margin: float = Balance.UI_SCREEN_MARGIN
	var screen: Vector2 = size
	var x: float = margin
	var y: float = margin
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]:
		x = screen.x - margin - panel.size.x
	elif preset == Control.PRESET_CENTER_TOP:
		x = (screen.x - panel.size.x) / 2.0
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]:
		y = screen.y - margin - panel.size.y
	panel.position = Vector2(x, y)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Style.label(text, font_size)
	parent.add_child(label)
	return label

func _process(delta: float) -> void:
	clock_time += delta
	if visible:
		_animate(delta)
	refresh_left -= delta
	if refresh_left > 0.0:
		return
	var elapsed: float = 1.0 / Balance.HUD_RATE - refresh_left
	refresh_left = 1.0 / Balance.HUD_RATE
	visible = Game.phase in ["live", "paused"]
	if Game.phase != previous_phase:
		if Game.phase == "reveal":
			toast_entries.clear()
			round_seconds = maxf(1.0, Game.seconds_left)
		previous_phase = Game.phase
	if not visible:
		return
	_layout_cards()
	round_seconds = maxf(round_seconds, Game.seconds_left)
	timer_label.text = Style.clock(Game.seconds_left)
	timer_label.add_theme_color_override("font_color", Balance.UI_DANGER if Game.seconds_left <= Balance.HUD_WARNING_SECONDS else Balance.UI_TEXT)
	dial.queue_redraw()
	delivered_label.text = "%s / %s" % [Loot.rupees(Game.banked_value), Loot.rupees(Game.target_value())]
	truck_meter.queue_redraw()
	lost_label.text = "Lost %s / %s" % [Loot.rupees(Game.lost_value), Loot.rupees(Game.loss_limit())]
	vase.queue_redraw()
	var generator: Node = Game.host.arena.get("generator") if is_instance_valid(Game.host) else null
	generator_label.visible = is_instance_valid(generator)
	if generator_label.visible:
		generator_label.text = "Generator ON" if generator.powered else "Generator batteries %d/%d" % [generator.delivered, Balance.BATTERY_COUNT]
	_refresh_room()
	if chip_slots != Game.participants or chip_ghost_slot != Game.ghost_slot:
		_build_chips()
	var lines: PackedStringArray = []
	for slot: int in Game.participants:
		var points: int = roundi(Game.live_points(slot))
		chip_labels[slot].text = "%s  %d" % [Style.player_name(slot), points]
		lines.append("%s%s · %d" % ["GHOST · " if slot == Game.ghost_slot else "", Style.player_name(slot), points])
	if is_instance_valid(energy_ring):
		energy_ring.queue_redraw()
	_clear(toasts)
	for entry: Dictionary in toast_entries.duplicate():
		entry.left -= elapsed if Game.phase == "live" else 0.0
		if entry.left <= 0.0:
			toast_entries.erase(entry)
		else:
			toasts.add_child(_toast(entry))
	totals.visible = Input.is_physical_key_pressed(KEY_TAB)
	totals_label.text = "TOTALS · %s\nDelivered %s / %s\nLost %s / %s\n\n%s" % [Style.clock(Game.seconds_left), Loot.rupees(Game.banked_value), Loot.rupees(Game.target_value()), Loot.rupees(Game.lost_value), Loot.rupees(Game.loss_limit()), "\n".join(lines)]
	pause_box.visible = Game.phase == "paused" and not Game.host_paused
	pause_label.text = "%s\nL: cancel to lobby" % Game.pause_reason


func _animate(_delta: float) -> void:
	# Every frame: the timer card rocks in the last stretch, and the red edges pulse near the loss limit.
	var late: bool = Game.phase == "live" and Game.seconds_left <= Balance.HUD_WARNING_SECONDS
	timer_card.pivot_offset = timer_card.size / 2.0
	timer_card.rotation_degrees = sin(clock_time * Balance.HUD_WOBBLE_RATE) * Balance.HUD_WOBBLE_DEGREES if late else 0.0
	danger.visible = _loss_fraction() >= Balance.HUD_DANGER_FRACTION
	if danger.visible:
		danger.queue_redraw()


func _loss_fraction() -> float:
	return float(Game.lost_value) / maxi(1, Game.loss_limit())


func _build_chips() -> void:
	_clear(chips)
	chip_slots = Game.participants.duplicate()
	chip_ghost_slot = Game.ghost_slot
	chip_labels.clear()
	energy_ring = null
	for slot: int in chip_slots:
		var pill := Style.chip(slot, "", Balance.UI_BODY_SIZE)
		var row: HBoxContainer = pill.get_child(0)
		chip_labels[slot] = row.get_child(1)
		if slot == Game.ghost_slot:
			energy_ring = Control.new()
			energy_ring.custom_minimum_size = Vector2.ONE * Balance.HUD_ENERGY_RING
			energy_ring.draw.connect(_draw_energy)
			row.add_child(energy_ring)
		chips.add_child(pill)


func _toast(entry: Dictionary) -> Control:
	# A delivery notice in comic style: DELIVERED! and the value, then the item and who carried it; it floats up
	# and fades in its last second.
	var card := Style.ink_panel(0.0, Balance.HUD_PANEL_PADDING, Color(Balance.UI_PANEL, Balance.UI_HUD_ALPHA))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	card.add_child(rows)
	var headline := Style.lettering("DELIVERED!  +%s" % Loot.rupees(entry.value), Balance.COMIC_LABEL_SIZE, Balance.UI_MONEY)
	headline.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	headline.autowrap_mode = TextServer.AUTOWRAP_OFF
	rows.add_child(headline)
	var detail := Style.label(entry.detail, Balance.UI_SMALL_SIZE, Balance.UI_TEXT)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	rows.add_child(detail)
	card.modulate.a = minf(1.0, entry.left)
	return card

func _refresh_room() -> void:
	var votes: Dictionary = {}
	var selected: String = "Outside"
	var most: int = 0
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		if not mover.visible:
			continue
		var room: String = Game.room_at(mover.global_position)
		votes[room] = votes.get(room, 0) + 1
		if votes[room] > most:
			most = votes[room]
			selected = room
	var delivered: int = 0
	var states: PackedStringArray = []
	for item: Dictionary in Game.room_items.values():
		if item.room != selected:
			continue
		delivered += int(item.state == "delivered")
		states.append("●" if item.state == "delivered" else "×" if item.state == "broken" else "○")
	room_label.text = "%s · %d / %d" % [selected, delivered, states.size()]
	discs.set_meta("states", states)
	discs.set_meta("delivered", delivered)
	discs.queue_redraw()

func _delivered(value: int, item_name: String, slots: Array[int]) -> void:
	var names: PackedStringArray = []
	for slot: int in slots:
		if slot in Game.participants:
			names.append(Style.player_name(slot))
	var detail: String = item_name if names.is_empty() else "%s · %s" % [item_name, " + ".join(names)]
	toast_entries.push_front({"value": value, "detail": detail, "left": Balance.HUD_TOAST_SECONDS})
	while toast_entries.size() > Balance.HUD_TOAST_LIMIT:
		toast_entries.pop_back()

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if Game.phase in ["live", "reveal"] and Style.pressed_key(event) == KEY_ESCAPE:
		Game.pause_by_host()
		pause_menu = load("res://menus/windows/pause_menu.tscn").instantiate()
		get_parent().add_child(pause_menu)
		get_viewport().set_input_as_handled()
	if visible and Game.phase == "paused" and Style.pressed_key(event) == KEY_L:
		Game.return_to_lobby()


# --- Drawn meters ---
func _draw_dial() -> void:
	# A punch-clock face: paper with an ink rim, the time left swept in colour, and a hand at the sweep's end.
	var radius: float = Balance.HUD_DIAL_SIZE / 2.0 - Balance.COMIC_BORDER
	var centre := Vector2.ONE * Balance.HUD_DIAL_SIZE / 2.0
	var left: float = clampf(Game.seconds_left / round_seconds, 0.0, 1.0)
	var colour: Color = Balance.UI_DANGER if Game.seconds_left <= Balance.HUD_WARNING_SECONDS else Balance.UI_GHOST
	dial.draw_circle(centre, radius, Balance.COMIC_PAPER)
	if left > 0.0: # A thick arc rather than a pie polygon, which fails to triangulate when it is a full circle.
		dial.draw_arc(centre, radius / 2.0, -PI / 2.0, -PI / 2.0 + TAU * left, Balance.HUD_RING_SEGMENTS, Color(colour, 0.85), radius)
	for tick: int in 12:
		var direction := Vector2.from_angle(TAU * tick / 12.0)
		dial.draw_line(centre + direction * radius * 0.78, centre + direction * radius, Balance.COMIC_INK, 2.0)
	dial.draw_line(centre, centre + Vector2.from_angle(-PI / 2.0 + TAU * left) * radius * 0.9, Balance.COMIC_INK, 3.0, true)
	dial.draw_arc(centre, radius, 0.0, TAU, Balance.HUD_RING_SEGMENTS, Balance.COMIC_INK, Balance.COMIC_BORDER, true)


func _draw_truck() -> void:
	# A side-on truck: the cargo box fills with gold as value is delivered; a flag marks the 70% target.
	var size_now: Vector2 = Balance.HUD_TRUCK_SIZE
	var ink: Color = Balance.COMIC_INK
	var wheel: float = size_now.y * 0.15
	var cargo := Rect2(2.0, 4.0, size_now.x * 0.72, size_now.y - wheel * 2.0 - 6.0)
	var cab := Rect2(cargo.end.x + 3.0, cargo.position.y + cargo.size.y * 0.3, size_now.x - cargo.end.x - 6.0, cargo.size.y * 0.7)
	var filled: float = clampf(float(Game.banked_value) / maxi(1, Game.starting_value), 0.0, 1.0)
	truck_meter.draw_rect(cargo, Color(Balance.UI_NIGHT, 0.85))
	truck_meter.draw_rect(Rect2(cargo.position, Vector2(cargo.size.x * filled, cargo.size.y)), Balance.UI_MONEY)
	truck_meter.draw_rect(cargo, ink, false, Balance.COMIC_BORDER)
	truck_meter.draw_rect(cab, Balance.UI_BUTTON)
	truck_meter.draw_rect(Rect2(cab.position + Vector2(cab.size.x * 0.45, 4.0), Vector2(cab.size.x * 0.4, cab.size.y * 0.4)), Balance.UI_MUTED) # Window.
	truck_meter.draw_rect(cab, ink, false, Balance.COMIC_BORDER)
	for x: float in [cargo.position.x + cargo.size.x * 0.22, cargo.position.x + cargo.size.x * 0.78, cab.position.x + cab.size.x * 0.5]:
		var hub := Vector2(x, size_now.y - wheel - 1.0)
		truck_meter.draw_circle(hub, wheel, ink)
		truck_meter.draw_circle(hub, wheel * 0.45, Balance.UI_MUTED)
	# The target flag: a pole through the cargo at the delivery percentage, with a pennant above it.
	var pole_x: float = cargo.position.x + cargo.size.x * Balance.DELIVERY_PERCENT / 100.0
	var flag_colour: Color = Balance.UI_GHOST if filled * 100.0 >= Balance.DELIVERY_PERCENT else Balance.UI_TEXT
	truck_meter.draw_line(Vector2(pole_x, cargo.position.y - 2.0), Vector2(pole_x, cargo.end.y), ink, 3.0)
	truck_meter.draw_line(Vector2(pole_x, cargo.position.y), Vector2(pole_x, cargo.end.y), flag_colour, 1.5)
	truck_meter.draw_colored_polygon(PackedVector2Array([Vector2(pole_x, cargo.position.y + 2.0), Vector2(pole_x + 14.0, cargo.position.y + 7.0), Vector2(pole_x, cargo.position.y + 12.0)]), flag_colour)


func _draw_vase() -> void:
	# A vase silhouette that gains a crack for each quarter of the loss limit, and shatters past it.
	var w: float = Balance.HUD_VASE_SIZE.x
	var h: float = Balance.HUD_VASE_SIZE.y
	var outline := PackedVector2Array([
		Vector2(w * 0.35, 0.0), Vector2(w * 0.65, 0.0), Vector2(w * 0.6, h * 0.18), Vector2(w * 0.95, h * 0.5),
		Vector2(w * 0.75, h), Vector2(w * 0.25, h), Vector2(w * 0.05, h * 0.5), Vector2(w * 0.4, h * 0.18),
	])
	var fraction: float = _loss_fraction()
	var broken: bool = fraction > 1.0
	vase.draw_colored_polygon(outline, Balance.UI_DANGER.darkened(0.3) if broken else Balance.COMIC_PAPER)
	var closed := outline.duplicate()
	closed.append(outline[0])
	vase.draw_polyline(closed, Balance.COMIC_INK, 2.0, true)
	var cracks: int = mini(Balance.HUD_VASE_CRACKS, floori(fraction * Balance.HUD_VASE_CRACKS))
	var paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(w * 0.5, h * 0.2), Vector2(w * 0.42, h * 0.45), Vector2(w * 0.55, h * 0.62)]),
		PackedVector2Array([Vector2(w * 0.85, h * 0.45), Vector2(w * 0.62, h * 0.55), Vector2(w * 0.68, h * 0.8)]),
		PackedVector2Array([Vector2(w * 0.15, h * 0.5), Vector2(w * 0.35, h * 0.65), Vector2(w * 0.3, h * 0.92)]),
		PackedVector2Array([Vector2(w * 0.55, h * 0.62), Vector2(w * 0.5, h * 0.8), Vector2(w * 0.58, h * 0.98)]),
	]
	for index: int in cracks:
		vase.draw_polyline(paths[index], Balance.COMIC_INK, 2.0, true)


func _draw_energy() -> void:
	# The ghost's chip: a little ghost glyph inside a ring that drains with its energy.
	var size_now: float = Balance.HUD_ENERGY_RING
	var centre := Vector2.ONE * size_now / 2.0
	var radius: float = size_now / 2.0 - 3.0
	var ghost: Node3D = Game.ghost()
	var energy: float = ghost.energy / Balance.ENERGY_MAX if ghost != null else 0.0
	energy_ring.draw_arc(centre, radius, 0.0, TAU, Balance.HUD_RING_SEGMENTS, Color(Balance.UI_MUTED, 0.4), 4.0, true)
	if energy > 0.0:
		energy_ring.draw_arc(centre, radius, -PI / 2.0, -PI / 2.0 + TAU * energy, Balance.HUD_RING_SEGMENTS, Balance.UI_GHOST, 4.0, true)
	var body := radius * 0.55
	energy_ring.draw_circle(centre - Vector2(0.0, body * 0.2), body, Balance.UI_GHOST)
	energy_ring.draw_rect(Rect2(centre.x - body, centre.y - body * 0.2, body * 2.0, body), Balance.UI_GHOST)
	for side: float in [-0.35, 0.35]:
		energy_ring.draw_circle(centre + Vector2(side * body, -body * 0.3), body * 0.18, Balance.COMIC_INK)


func _draw_danger() -> void:
	# Red glow creeping in from all four edges, pulsing, once losses near the limit.
	var strength: float = (0.55 + 0.45 * sin(clock_time * Balance.HUD_DANGER_RATE)) * 0.6
	var red := Color(Balance.UI_DANGER, strength)
	var clear := Color(Balance.UI_DANGER, 0.0)
	var reach: float = Balance.HUD_DANGER_WIDTH
	var w: float = size.x
	var h: float = size.y
	var edges: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - reach, reach), Vector2(reach, reach)]),
		PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - reach, h - reach), Vector2(w - reach, reach)]),
		PackedVector2Array([Vector2(w, h), Vector2(0, h), Vector2(reach, h - reach), Vector2(w - reach, h - reach)]),
		PackedVector2Array([Vector2(0, h), Vector2(0, 0), Vector2(reach, reach), Vector2(reach, h - reach)]),
	]
	for edge: PackedVector2Array in edges:
		danger.draw_polygon(edge, PackedColorArray([red, red, clear, clear]))


# Ring and per-item marks share the selected room's original loot ledger.
func _draw_room() -> void:
	var states: PackedStringArray = discs.get_meta("states", PackedStringArray())
	var centre := Vector2(Balance.HUD_RING_RADIUS + Balance.HUD_RING_WIDTH, discs.size.y / 2.0)
	discs.draw_arc(centre, Balance.HUD_RING_RADIUS, 0.0, TAU, Balance.HUD_RING_SEGMENTS, Balance.UI_MUTED, Balance.HUD_RING_WIDTH, true)
	var fraction: float = float(discs.get_meta("delivered", 0)) / maxi(1, states.size())
	if fraction > 0.0:
		discs.draw_arc(centre, Balance.HUD_RING_RADIUS, -PI / 2.0, TAU * fraction - PI / 2.0, Balance.HUD_RING_SEGMENTS, Balance.UI_GHOST, Balance.HUD_RING_WIDTH, true)
	for index: int in states.size():
		var point := Vector2(centre.x * 2.0 + Balance.HUD_DISC_STEP * (index % Balance.HUD_DISC_COLUMNS + 1), centre.y + (index / Balance.HUD_DISC_COLUMNS) * Balance.HUD_DISC_STEP)
		var colour: Color = Balance.UI_GHOST if states[index] == "●" else Balance.UI_DANGER if states[index] == "×" else Balance.UI_MUTED
		discs.draw_circle(point, Balance.HUD_DISC_RADIUS, colour, states[index] != "○", Balance.HUD_DISC_STROKE, true)
		if states[index] == "×":
			var cross := Vector2.ONE * Balance.HUD_DISC_RADIUS
			discs.draw_line(point - cross, point + cross, Balance.UI_NIGHT, Balance.HUD_DISC_STROKE, true)
			discs.draw_line(point + Vector2(-cross.x, cross.y), point + Vector2(cross.x, -cross.y), Balance.UI_NIGHT, Balance.HUD_DISC_STROKE, true)


func _layout_cards() -> void:
	for child: Node in get_children():
		if child.has_meta("edge_preset"):
			child.reset_size()
			_position_card(child, child.get_meta("edge_preset"))
