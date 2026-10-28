# Final results: a podium for the top three (blocks rise in turn, then the winner is crowned), anyone else listed
# below, and the way back to the lobby. Enter returns everyone to the lobby.
extends Control

const Style := preload("res://screens/screen_style.gd")
const PLACE_ORDER: Array[int] = [1, 0, 2] # Podium columns left to right: second, first, third.

# --- Display state ---
var winner_label: Label
var podium := HBoxContainer.new()
var others := VBoxContainer.new()
var shown: bool = false

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.use_theme(self)
	_build()
	Game.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Style.pressed_key(event) in [KEY_ENTER, KEY_KP_ENTER, KEY_L]:
		Game.return_to_lobby()
		get_viewport().set_input_as_handled()


# --- Refresh ---
func _refresh() -> void:
	visible = Game.phase == "final" and Game.replay.is_empty() # The Disaster Cam reel plays first.
	if not visible:
		shown = false
		return
	if shown:
		return # Built once, so the podium rises once.
	shown = true
	var rows: Array[Dictionary] = Game.standings()
	winner_label.text = "%s WINS THE MATCH!" % Style.short_name(String(rows[0].name)).to_upper() if not rows.is_empty() else ""
	for child: Node in podium.get_children() + others.get_children():
		child.queue_free()
	for place: int in PLACE_ORDER:
		if place < rows.size():
			podium.add_child(_column(rows[place], place))
	for place: int in range(3, rows.size()):
		var entry: Dictionary = rows[place]
		others.add_child(Style.chip(entry.slot, "%d.  %s   %d points" % [place + 1, Style.short_name(String(entry.name)), roundi(entry.points)]))


func _column(entry: Dictionary, place: int) -> Control:
	# One podium place: the player's name and points over their figure (crowned in first), standing on a block in
	# their colour with the place number. The block rises from the floor, third place first.
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 0)
	column.custom_minimum_size.x = Balance.PODIUM_WIDTH
	var colour: Color = Style.player_colour(entry.slot)
	var name_line := Style.label(Style.short_name(String(entry.name)), Balance.UI_BODY_SIZE, colour)
	name_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(name_line)
	column.add_child(Style.label("%d points" % roundi(entry.points), Balance.UI_SMALL_SIZE, Balance.UI_TEXT))
	var award: Dictionary = Game.award_for(int(entry.slot), Game.awards_for(Game.match_stats))
	if not award.is_empty():
		var title := Style.lettering(award.title, Balance.UI_BODY_SIZE, Balance.UI_MONEY)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		column.add_child(title)
		column.add_child(Style.label(award.detail, Balance.UI_SMALL_SIZE, Balance.UI_MUTED))
	if place == 0:
		var crown := _crown()
		crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(crown)
	var figure := Style.mover_figure(colour, Balance.PODIUM_FIGURE)
	figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(figure)

	var block := PanelContainer.new()
	block.add_theme_stylebox_override("panel", Style.comic_box(colour, 0, 0))
	block.custom_minimum_size = Vector2(Balance.PODIUM_WIDTH, 0.0)
	block.clip_contents = true
	var number := Style.lettering(str(place + 1), Balance.COMIC_TITLE_SIZE, Balance.UI_TEXT)
	number.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	block.add_child(number)
	column.add_child(block)
	var delay: float = (2 - place) * Balance.PODIUM_STAGGER
	var rise: Tween = block.create_tween()
	rise.tween_interval(delay)
	rise.tween_property(block, "custom_minimum_size:y", Balance.PODIUM_HEIGHTS[place], Balance.PODIUM_RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return column


func _crown() -> Control:
	# A gold crown that drops onto the winner once the podium has risen.
	var crown := Control.new()
	crown.custom_minimum_size = Vector2(Balance.PODIUM_FIGURE * 0.6, Balance.PODIUM_FIGURE * 0.4)
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crown.draw.connect(func() -> void:
		var w: float = crown.custom_minimum_size.x
		var h: float = crown.custom_minimum_size.y
		var points := PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.3), Vector2(w * 0.25, h * 0.6), Vector2(w * 0.5, 0), Vector2(w * 0.75, h * 0.6), Vector2(w, h * 0.3), Vector2(w, h)])
		crown.draw_colored_polygon(points, Balance.UI_MONEY)
		points.append(points[0])
		crown.draw_polyline(points, Balance.COMIC_INK, 2.0, true)
	)
	crown.modulate.a = 0.0
	var drop: Tween = crown.create_tween()
	drop.tween_interval(2.0 * Balance.PODIUM_STAGGER + Balance.PODIUM_RISE_TIME)
	drop.tween_property(crown, "modulate:a", 1.0, Balance.COMIC_STAMP_TIME)
	return crown


# --- Layout ---
func _build() -> void:
	add_child(Style.backdrop())
	var rows := Style.column()
	rows.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	var caption := Style.caption(0.0, Balance.UI_PANEL_MARGIN / 2)
	caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := Style.lettering("FINAL STANDINGS", Balance.COMIC_LABEL_SIZE, Balance.COMIC_INK)
	title.add_theme_constant_override("outline_size", 0)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.add_child(title)
	rows.add_child(caption)
	winner_label = Style.lettering("", Balance.COMIC_TITLE_SIZE, Balance.UI_MONEY)
	winner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rows.add_child(winner_label)
	podium.alignment = BoxContainer.ALIGNMENT_CENTER
	podium.add_theme_constant_override("separation", 0)
	rows.add_child(podium)
	others.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	others.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(others)
	rows.add_child(Style.action("BACK TO THE LOBBY", "Enter", Game.return_to_lobby))
	var holder := CenterContainer.new() # Not Style.centre: the podium animates on its own.
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rows)
	add_child(holder)
