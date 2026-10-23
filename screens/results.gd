# Final results: the match standings by total points (awards come later). Enter returns everyone to the lobby.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var winner_label: Label
var standings_list := VBoxContainer.new()

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Style.pressed_key(event) in [KEY_ENTER, KEY_KP_ENTER, KEY_L]:
		Game.return_to_lobby()
		get_viewport().set_input_as_handled()


# --- Refresh ---
func _refresh() -> void:
	visible = Game.phase == "final"
	if not visible:
		return
	var rows: Array[Dictionary] = Game.standings()
	winner_label.text = "%s WINS THE MATCH" % String(rows[0].name).to_upper() if not rows.is_empty() else ""
	for row: Node in standings_list.get_children():
		row.queue_free()
	for place: int in range(rows.size()):
		var entry: Dictionary = rows[place]
		standings_list.add_child(Style.label("%d.  %s   %d points" % [place + 1, entry.name, roundi(entry.points)], Balance.HOST_FONT_SIZE, Style.player_colour(entry.slot)))


# --- Layout ---
func _build() -> void:
	var box := Style.panel(Balance.HOST_PANEL_WIDTH)
	var rows := Style.column()
	box.add_child(rows)
	rows.add_child(Style.label("FINAL STANDINGS", Balance.HOST_FONT_SIZE, Balance.HOST_MUTED_COLOUR))
	winner_label = Style.label("", Balance.HOST_TITLE_SIZE, Balance.HOST_ACCENT_COLOUR)
	rows.add_child(winner_label)
	rows.add_child(standings_list)
	var again := Style.button("BACK TO THE LOBBY  (Enter)")
	again.pressed.connect(Game.return_to_lobby)
	rows.add_child(again)
	add_child(Style.centre(box))
