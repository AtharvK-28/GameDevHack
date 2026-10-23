# Live HUD on the shared screen: round timer, delivered value against the 70% target, value lost against the
# 30% limit, and the ghost's energy (a tell everyone can see). While a phone is missing it shows the pause
# overlay; L then cancels back to the lobby without scoring the round.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var timer_label: Label
var delivered_bar := ProgressBar.new()
var target_marker := ColorRect.new()
var delivered_label: Label
var lost_label: Label
var ghost_panel: PanelContainer
var ghost_label: Label
var ghost_bar := ProgressBar.new()
var pause_box: CenterContainer
var pause_label: Label

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_round_panel()
	_build_ghost_panel()
	_build_pause_overlay()
	Game.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Game.phase == "paused" and Style.pressed_key(event) == KEY_L:
		Game.return_to_lobby()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	timer_label.text = Style.clock(Game.seconds_left)
	var starting: int = maxi(1, Game.starting_value)
	delivered_bar.value = 100.0 * Game.banked_value / starting
	delivered_label.text = "DELIVERED %s of %s · TARGET %s" % [Loot.rupees(Game.banked_value), Loot.rupees(Game.starting_value), Loot.rupees(Game.target_value())]
	lost_label.text = "LOST %s · GHOST WINS ABOVE %s" % [Loot.rupees(Game.lost_value), Loot.rupees(Game.loss_limit())]
	var ghost: Node3D = Game.ghost()
	ghost_panel.visible = ghost != null
	if ghost != null:
		ghost_bar.value = ghost.energy
		ghost_label.text = "GHOST ENERGY %d" % floori(ghost.energy)


# --- Refresh ---
func _refresh() -> void:
	visible = Game.phase in ["live", "paused"]
	pause_box.visible = Game.phase == "paused"
	if pause_box.visible:
		pause_label.text = "PAUSED\n%s\n\nPress L to cancel to the lobby (this round scores nothing)" % Game.pause_reason


# --- Layout ---
func _build_round_panel() -> void:
	var box := Style.panel(0.0)
	var rows := Style.column()
	box.add_child(rows)
	timer_label = Style.label("2:30", Balance.HOST_TITLE_SIZE)
	rows.add_child(timer_label)

	# The bar shows delivered value; a white tick marks the 70% target.
	var track := Control.new()
	track.custom_minimum_size = Balance.HUD_BAR_SIZE
	rows.add_child(track)
	delivered_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delivered_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Balance.BANK_COLOUR
	delivered_bar.add_theme_stylebox_override("fill", fill)
	track.add_child(delivered_bar)
	target_marker.color = Balance.HOST_TEXT_COLOUR
	target_marker.size = Vector2(Balance.HUD_MARKER_WIDTH, Balance.HUD_BAR_SIZE.y + Balance.HUD_MARKER_OVERHANG * 2.0)
	target_marker.position = Vector2(Balance.HUD_BAR_SIZE.x * Balance.DELIVERY_PERCENT / 100.0, -Balance.HUD_MARKER_OVERHANG)
	track.add_child(target_marker)

	delivered_label = Style.label("", Balance.HOST_SMALL_SIZE)
	rows.add_child(delivered_label)
	lost_label = Style.label("", Balance.HOST_SMALL_SIZE, Balance.DAMAGE_COLOUR)
	rows.add_child(lost_label)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(Balance.HUD_MARGIN))
	add_child(box)


func _build_ghost_panel() -> void:
	ghost_panel = Style.panel(0.0)
	var rows := Style.column()
	ghost_panel.add_child(rows)
	ghost_label = Style.label("", Balance.HOST_SMALL_SIZE, Balance.HOST_GHOST_COLOUR)
	rows.add_child(ghost_label)
	ghost_bar.max_value = Balance.ENERGY_MAX
	ghost_bar.show_percentage = false
	ghost_bar.custom_minimum_size = Vector2(Balance.GHOST_PANEL_WIDTH, Balance.HUD_FONT_SIZE)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Balance.POSSESS_COLOUR
	ghost_bar.add_theme_stylebox_override("fill", fill)
	rows.add_child(ghost_bar)
	ghost_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ghost_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, int(Balance.HUD_MARGIN))
	add_child(ghost_panel)


func _build_pause_overlay() -> void:
	var box := Style.panel(Balance.HOST_PANEL_WIDTH)
	pause_label = Style.label("", Balance.HOST_FONT_SIZE)
	box.add_child(pause_label)
	pause_box = Style.centre(box)
	add_child(pause_box)
