# Compact edge HUD: timer, room item status, truck totals, delivery notices and live player points. Panels sit
# at the screen edges so the centre stays clear; holding Tab shows the full totals, Esc opens the pause menu.
extends Control

const Style := preload("res://screens/screen_style.gd")
var timer_label: Label
var delivered_label: Label
var delivered_bar: ProgressBar
var lost_label: Label
var room_label: Label
var discs: Control
var refresh_left: float = 0.0
var pause_menu: Control
var chip_labels: Dictionary = {}
var energy_bar: ProgressBar
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer := _card(Control.PRESET_CENTER_TOP, 100.0)
	timer_label = _label(timer, "2:30", Balance.HUD_TIMER_SIZE)
	var truck := _card(Control.PRESET_TOP_RIGHT, Balance.HUD_CARD_WIDTH)
	_label(truck, "TRUCK · TARGET 70%", Balance.UI_SMALL_SIZE)
	delivered_label = _label(truck, "", Balance.UI_BODY_SIZE)
	delivered_label.modulate = Balance.UI_MONEY
	delivered_bar = ProgressBar.new()
	delivered_bar.show_percentage = false
	delivered_bar.custom_minimum_size.y = Balance.HUD_BAR_SIZE.y
	truck.add_child(delivered_bar)
	var tick := ColorRect.new()
	tick.color = Balance.UI_MONEY
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delivered_bar.add_child(tick)
	tick.anchor_left = 0.7
	tick.anchor_right = 0.7
	tick.anchor_bottom = 1.0
	tick.offset_right = Balance.HUD_MARKER_WIDTH
	lost_label = _label(truck, "", Balance.UI_SMALL_SIZE)
	lost_label.modulate = Balance.UI_DANGER
	generator_label = _label(truck, "", Balance.UI_SMALL_SIZE)
	generator_label.modulate = Balance.GENERATOR_COLOUR
	var room := _card(Control.PRESET_TOP_LEFT, 200.0)
	room_label = _label(room, "Main room", Balance.UI_BODY_SIZE)
	discs = Control.new()
	discs.custom_minimum_size = Balance.HUD_ROOM_SIZE
	discs.draw.connect(_draw_room)
	room.add_child(discs)
	chips = _card(Control.PRESET_BOTTOM_RIGHT, Balance.HUD_CARD_WIDTH)
	toasts = _card(Control.PRESET_BOTTOM_LEFT, Balance.HUD_CARD_WIDTH)
	var box := Style.panel(Balance.HOST_PANEL_WIDTH)
	totals_label = Style.label("", Balance.UI_BODY_SIZE)
	box.add_child(totals_label)
	totals = Style.centre(box)
	add_child(totals)
	var pause_panel := Style.panel(Balance.HOST_PANEL_WIDTH)
	pause_label = Style.label("", Balance.UI_HEADING_SIZE)
	pause_panel.add_child(pause_label)
	pause_box = Style.centre(pause_panel)
	add_child(pause_box)
	Game.delivery_notice.connect(_delivered)

func _card(preset: int, width: float) -> VBoxContainer:
	var panel := Style.panel(width, Balance.HUD_PANEL_PADDING)
	panel.remove_theme_stylebox_override("panel")
	panel.theme_type_variation = &"HudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_meta("edge_preset", preset)
	if not resized.is_connected(_layout_cards):
		resized.connect(_layout_cards)
	var column := VBoxContainer.new()
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
	refresh_left -= delta
	if refresh_left > 0.0:
		return
	var elapsed: float = 1.0 / Balance.HUD_RATE - refresh_left
	refresh_left = 1.0 / Balance.HUD_RATE
	visible = Game.phase in ["live", "paused"]
	if Game.phase != previous_phase:
		if Game.phase == "reveal":
			toast_entries.clear()
		previous_phase = Game.phase
	if not visible:
		return
	_layout_cards()
	timer_label.text = Style.clock(Game.seconds_left)
	timer_label.modulate = Balance.UI_MONEY if Game.seconds_left <= Balance.HUD_WARNING_SECONDS else Color.WHITE
	delivered_label.text = "%s / %s" % [Loot.rupees(Game.banked_value), Loot.rupees(Game.target_value())]
	delivered_bar.value = 100.0 * Game.banked_value / maxi(1, Game.starting_value)
	lost_label.text = "Lost %s / %s" % [Loot.rupees(Game.lost_value), Loot.rupees(Game.loss_limit())]
	var generator: Node = Game.host.arena.get("generator") if is_instance_valid(Game.host) else null
	generator_label.visible = is_instance_valid(generator)
	if generator_label.visible:
		generator_label.text = "Generator ON" if generator.powered else "Generator batteries %d/%d" % [generator.delivered, Balance.BATTERY_COUNT]
	_refresh_room()
	if chip_slots != Game.participants or chip_ghost_slot != Game.ghost_slot:
		_clear(chips)
		chip_slots = Game.participants.duplicate()
		chip_ghost_slot = Game.ghost_slot
		chip_labels.clear()
		for slot: int in chip_slots:
			chip_labels[slot] = _label(chips, "", Balance.UI_BODY_SIZE)
			chip_labels[slot].modulate = Style.player_colour(slot)
		energy_bar = ProgressBar.new()
		energy_bar.show_percentage = false
		energy_bar.custom_minimum_size.y = Balance.HUD_ENERGY_BAR_SIZE.y
		chips.add_child(energy_bar)
		chips.move_child(energy_bar, maxi(0, chip_slots.find(Game.ghost_slot)) + 1)
	var lines: PackedStringArray = []
	for slot: int in Game.participants:
		var points: String = "%s%s · %d" % ["GHOST · " if slot == Game.ghost_slot else "", Style.player_name(slot), roundi(Game.live_points(slot))]
		chip_labels[slot].text = points
		lines.append(points)
	if is_instance_valid(energy_bar):
		energy_bar.visible = Game.ghost() != null
		if energy_bar.visible:
			energy_bar.value = Game.ghost().energy
	_clear(toasts)
	for entry: Dictionary in toast_entries.duplicate():
		entry.left -= elapsed if Game.phase == "live" else 0.0
		if entry.left <= 0.0:
			toast_entries.erase(entry)
		else:
			var notice := _label(toasts, entry.text, Balance.UI_BODY_SIZE)
			notice.modulate = Color(Balance.UI_MONEY, minf(1.0, entry.left))
	toasts.get_parent().visible = not toast_entries.is_empty()
	totals.visible = Input.is_physical_key_pressed(KEY_TAB)
	totals_label.text = "TOTALS · %s\nDelivered %s / %s\nLost %s / %s\n\n%s" % [Style.clock(Game.seconds_left), Loot.rupees(Game.banked_value), Loot.rupees(Game.target_value()), Loot.rupees(Game.lost_value), Loot.rupees(Game.loss_limit()), "\n".join(lines)]
	pause_box.visible = Game.phase == "paused" and not Game.host_paused
	pause_label.text = "PAUSED\n%s\nL: cancel to lobby" % Game.pause_reason

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
	toast_entries.push_front({"text": "+%s · %s\n%s" % [Loot.rupees(value), item_name, " + ".join(names)], "left": Balance.HUD_TOAST_SECONDS})
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
		var colour: Color = Balance.UI_GHOST if states[index] == "\u25cf" else Balance.UI_DANGER if states[index] == "\u00d7" else Balance.UI_MUTED
		discs.draw_circle(point, Balance.HUD_DISC_RADIUS, colour, states[index] != "\u25cb", Balance.HUD_DISC_STROKE, true)
		if states[index] == "\u00d7":
			var cross := Vector2.ONE * Balance.HUD_DISC_RADIUS
			discs.draw_line(point - cross, point + cross, Balance.UI_NIGHT, Balance.HUD_DISC_STROKE, true)
			discs.draw_line(point + Vector2(-cross.x, cross.y), point + Vector2(cross.x, -cross.y), Balance.UI_NIGHT, Balance.HUD_DISC_STROKE, true)


func _layout_cards() -> void:
	for child: Node in get_children():
		if child.has_meta("edge_preset"):
			child.reset_size()
			_position_card(child, child.get_meta("edge_preset"))
