# Role reveal: the round number, who the ghost is, who the movers are, and the 3 s countdown to live play.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var round_label: Label
var ghost_label: Label
var movers_label: Label
var countdown_label: Label

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if visible:
		countdown_label.text = str(maxi(1, ceili(Game.reveal_left)))


# --- Refresh ---
func _refresh() -> void:
	visible = Game.phase in ["setup", "reveal"]
	if not visible:
		return
	round_label.text = "ROUND %d OF %d · %s" % [Game.round_index + 1, Game.round_count, Game.arena_name().to_upper()]
	ghost_label.text = "%s IS THE GHOST\nBreak everything." % Style.player_name(Game.ghost_slot).to_upper()
	var movers: PackedStringArray = []
	for slot: int in Game.participants:
		if slot != Game.ghost_slot:
			movers.append(Style.player_name(slot))
	movers_label.text = "MOVERS: %s\nCarry it to the truck. Don't break it." % ", ".join(movers)


# --- Layout ---
func _build() -> void:
	var box := Style.panel(Balance.HOST_PANEL_WIDTH)
	var rows := Style.column()
	box.add_child(rows)
	round_label = Style.label("", Balance.HOST_FONT_SIZE, Balance.HOST_MUTED_COLOUR)
	rows.add_child(round_label)
	ghost_label = Style.label("", Balance.HOST_TITLE_SIZE, Balance.HOST_GHOST_COLOUR)
	rows.add_child(ghost_label)
	movers_label = Style.label("", Balance.HOST_FONT_SIZE)
	rows.add_child(movers_label)
	countdown_label = Style.label("3", Balance.HOST_COUNTDOWN_SIZE, Balance.HOST_ACCENT_COLOUR)
	rows.add_child(countdown_label)
	add_child(Style.centre(box))
