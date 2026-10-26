# Round end, as a comic page: a stamped DELIVERED! or GHOSTED!, the reason on a caption, stat tiles for delivered,
# target and lost value, and each player's row with their role and points counting up.
# Host keys: Enter for the next round (or the final results), R to restart this round, L for the lobby.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var stamp_holder := CenterContainer.new() # Holds this round's stamp, rebuilt each time.
var reason_label: Label
var tiles := HBoxContainer.new()
var points_list := GridContainer.new() # Two columns for three or more players, so four rows fit the screen.
var next_button: Button
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
	if not visible:
		return
	match Style.pressed_key(event):
		KEY_ENTER, KEY_KP_ENTER:
			Game.next_round()
		KEY_R:
			Game.restart_round()
		KEY_L:
			Game.return_to_lobby()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Refresh ---
func _refresh() -> void:
	visible = Game.phase == "result"
	if not visible or Game.result.is_empty():
		shown = false
		return
	if shown:
		return # Built once per result, so the stamp and count-up play once.
	shown = true
	var movers_won: bool = Game.result.moversWon
	for child: Node in stamp_holder.get_children():
		child.queue_free()
	var stamp := Style.stamp("DELIVERED!" if movers_won else "GHOSTED!", Balance.UI_MONEY if movers_won else Balance.UI_GHOST, Balance.COMIC_TITLE_SIZE)
	stamp_holder.add_child(stamp)
	Style.slam(stamp)
	reason_label.text = Game.result.reason

	var starting: int = maxi(1, Game.result.starting)
	var percent: int = floori(100.0 * Game.result.banked / starting)
	for tile: Node in tiles.get_children():
		tile.queue_free()
	tiles.add_child(_tile("DELIVERED", "%d%%" % percent, Loot.rupees(Game.result.banked), Balance.UI_GHOST if percent >= Balance.DELIVERY_PERCENT else Balance.UI_MONEY))
	tiles.add_child(_tile("TARGET", "%d%%" % Balance.DELIVERY_PERCENT, Loot.rupees(ceili(starting * Balance.DELIVERY_PERCENT / 100.0)), Balance.UI_TEXT))
	tiles.add_child(_tile("LOST", Loot.rupees(Game.result.lost), "of %s" % Loot.rupees(starting), Balance.UI_DANGER))

	for row: Node in points_list.get_children():
		row.queue_free()
	points_list.columns = 1 if Game.participants.size() <= 2 else 2
	for slot: int in Game.participants:
		points_list.add_child(_player_row(slot))
	var last: bool = Game.round_index + 1 >= Game.round_count
	next_button.text = "FINAL RESULTS" if last else "NEXT ROUND"


func _tile(title: String, big: String, small: String, colour: Color) -> Control:
	var tile := Style.ink_panel(Balance.RESULT_TILE_WIDTH, Balance.UI_PANEL_MARGIN / 2)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	tile.add_child(rows)
	rows.add_child(Style.label(title, Balance.UI_SMALL_SIZE, Balance.UI_MUTED))
	var value := Style.lettering(big, Balance.COMIC_HEADING_SIZE, colour)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	rows.add_child(value)
	rows.add_child(Style.label(small, Balance.UI_SMALL_SIZE, Balance.UI_TEXT))
	return tile


func _player_row(slot: int) -> Control:
	# A row per player: their figure (glowing if they were the ghost), name and role, round points counting up,
	# and their match total.
	var ghost: bool = slot == Game.ghost_slot
	var pill := Style.ink_panel(Balance.RESULT_ROW_WIDTH, Balance.UI_PANEL_MARGIN / 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	pill.add_child(row)
	row.add_child(Style.mover_figure(Style.player_colour(slot), Balance.RESULT_FIGURE, ghost))
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	var name_line := Style.label(Style.player_name(slot), Balance.UI_BODY_SIZE, Style.player_colour(slot))
	name_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.add_child(name_line)
	var award: Dictionary = Game.award_for(slot, Game.result.get("awards", []))
	var role := Style.label("Ghost" if ghost else "Mover", Balance.UI_SMALL_SIZE, Balance.UI_GHOST if ghost else Balance.UI_MUTED)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not award.is_empty():
		role.text += " · " + award.detail
	role.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.add_child(role)
	if not award.is_empty():
		who.add_child(_award_title(award.title))
	var gained: int = roundi(Game.round_points.get(slot, 0.0))
	var points := Style.lettering("+0", Balance.COMIC_HEADING_SIZE, Balance.UI_MONEY)
	points.autowrap_mode = TextServer.AUTOWRAP_OFF
	points.custom_minimum_size.x = Balance.RESULT_FIGURE * 2.5
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(points)
	points.create_tween().tween_method(func(shown_points: int) -> void: points.text = "+%d" % shown_points, 0, gained, Balance.COUNT_UP_TIME)
	var total := Style.label("total %d" % roundi(Game.scores.get(slot, 0.0)), Balance.UI_SMALL_SIZE, Balance.UI_MUTED)
	total.autowrap_mode = TextServer.AUTOWRAP_OFF
	total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(total)
	return pill



func _award_title(title: String) -> Control:
	# A funny award in comic lettering, stamped on a moment after the row appears.
	var line := Style.lettering(title, Balance.UI_BODY_SIZE, Balance.UI_MONEY)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.modulate.a = 0.0
	var appear: Tween = line.create_tween()
	appear.tween_interval(Balance.COUNT_UP_TIME)
	appear.tween_property(line, "modulate:a", 1.0, 0.25)
	return line


# --- Layout ---
func _build() -> void:
	add_child(Style.backdrop())
	var rows := Style.column()
	rows.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	rows.add_child(stamp_holder)
	var caption := Style.caption(0.0, Balance.UI_PANEL_MARGIN / 2)
	caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reason_label = Style.ink_label("", Balance.UI_BODY_SIZE)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.add_child(reason_label)
	rows.add_child(caption)
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	rows.add_child(tiles)
	points_list.add_theme_constant_override("h_separation", Balance.UI_PANEL_MARGIN)
	points_list.add_theme_constant_override("v_separation", Balance.HOST_ROW_GAP)
	points_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(points_list)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	rows.add_child(controls)
	var next := Style.action("NEXT ROUND", "Enter", Game.next_round)
	next_button = next.get_child(1)
	controls.add_child(next)
	controls.add_child(Style.action("RESTART", "R", Game.restart_round))
	controls.add_child(Style.action("LOBBY", "L", Game.return_to_lobby))
	var holder := CenterContainer.new() # Not Style.centre: the stamp and count-up animate on their own.
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rows)
	add_child(holder)
