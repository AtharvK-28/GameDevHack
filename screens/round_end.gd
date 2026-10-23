# Round end: the winner and why, delivered and lost value, and each player's points.
# Host keys: Enter for the next round (or the final results), R to restart this round, L for the lobby.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var headline: Label
var reason_label: Label
var totals_label: Label
var points_list := VBoxContainer.new()
var next_button: Button

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		return
	var movers_won: bool = Game.result.moversWon
	headline.text = "MOVERS WIN" if movers_won else "THE GHOST WINS"
	headline.add_theme_color_override("font_color", Balance.BANK_COLOUR if movers_won else Balance.HOST_GHOST_COLOUR)
	reason_label.text = Game.result.reason
	var starting: int = maxi(1, Game.result.starting)
	totals_label.text = "Delivered %s of %s (%d%%, target %d%%) · Lost %s" % [Loot.rupees(Game.result.banked), Loot.rupees(Game.result.starting), floori(100.0 * Game.result.banked / starting), Balance.DELIVERY_PERCENT, Loot.rupees(Game.result.lost)]
	for row: Node in points_list.get_children():
		row.queue_free()
	for slot: int in Game.participants:
		var role: String = "ghost" if slot == Game.ghost_slot else "mover"
		var line := Style.label("%s (%s)   +%d   total %d" % [Style.player_name(slot), role, roundi(Game.round_points.get(slot, 0.0)), roundi(Game.scores.get(slot, 0.0))], Balance.HOST_FONT_SIZE, Style.player_colour(slot))
		points_list.add_child(line)
	var last: bool = Game.round_index + 1 >= Game.round_count
	next_button.text = "FINAL RESULTS  (Enter)" if last else "NEXT ROUND  (Enter)"


# --- Layout ---
func _build() -> void:
	var box := Style.panel(Balance.HOST_PANEL_WIDTH)
	var rows := Style.column()
	box.add_child(rows)
	headline = Style.label("", Balance.HOST_TITLE_SIZE)
	rows.add_child(headline)
	reason_label = Style.label("", Balance.HOST_FONT_SIZE)
	rows.add_child(reason_label)
	totals_label = Style.label("", Balance.HOST_SMALL_SIZE, Balance.HOST_MUTED_COLOUR)
	rows.add_child(totals_label)
	rows.add_child(points_list)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	rows.add_child(controls)
	next_button = Style.button("NEXT ROUND  (Enter)")
	next_button.pressed.connect(Game.next_round)
	controls.add_child(next_button)
	var restart := Style.button("RESTART ROUND  (R)")
	restart.pressed.connect(Game.restart_round)
	controls.add_child(restart)
	var lobby := Style.button("LOBBY  (L)")
	lobby.pressed.connect(Game.return_to_lobby)
	controls.add_child(lobby)
	add_child(Style.centre(box))
