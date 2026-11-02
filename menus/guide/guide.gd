# How to play: getting a phone into the game, then what each role's phone does, as three numbered pictures with a
# short line for every control (menus/guide/controller_diagram.gd draws them). Back or Escape returns to the home
# menu. The pictures mirror the real phone layout, so what a player reads here is what their thumbs will find.
extends Control

const DIAGRAM := preload("res://menus/guide/controller_diagram.gd")

# --- The three columns ---
const JOIN_STEPS: Array[String] = [
	"Same Wi-Fi as the big screen.",
	"Scan its QR, or open the link it shows.",
	"Name, game code, JOIN, then READY.",
]
const MOVER_STEPS: Array[String] = [
	"Stick walks you.",
	"Hold GRAB to carry it to the truck.",
	"Let go with the stick pushed to throw it.",
	"BRACE to plant your feet.",
	"Shout to the crew.",
]
const GHOST_STEPS: Array[String] = [
	"Stick flies you, through walls.",
	"POSSESS a prop. LEAVE refills energy.",
	"ACTION is that prop's own move.",
	"The big one is the map's haunting.",
	"HEX a phone. CURSE a carrier.",
]
const FOOTER: String = "Movers win by banking 55-65% of the loot (by crew size) in time; wreck over a third and the ghost wins early. ACTION is whatever the ghost wears: SHOVE a sofa, SLAM a door, DROP a chandelier, YANK a rug, ROLL a barrel. Side tasks weaken the ghost: batteries, oil cans, fakes."

# --- Setup ---
func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Balance.UI_PANEL_MARGIN)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN / 2)
	margin.add_child(column)
	column.add_child(_label("How to play", &"HeadingLabel"))
	column.add_child(_label("2-4 phones are the controllers | One of you is the ghost | The roles swap every round", &"MutedLabel"))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	columns.add_child(_card("GET YOUR PHONE IN", DIAGRAM.Picture.JOIN, Color(Balance.PLAYER_COLOURS[1]), JOIN_STEPS))
	columns.add_child(_card("YOU'RE A MOVER", DIAGRAM.Picture.MOVER, Color(Balance.PLAYER_COLOURS[0]), MOVER_STEPS))
	columns.add_child(_card("YOU'RE THE GHOST", DIAGRAM.Picture.GHOST, Balance.UI_GHOST, GHOST_STEPS))

	column.add_child(_label(FOOTER, &"MutedLabel"))

	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(hide)
	column.add_child(back)
	back.grab_focus.call_deferred()


# --- Navigation ---
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


# --- Helpers ---
func _card(title: String, picture: int, colour: Color, steps: Array[String]) -> PanelContainer:
	# One column: its heading, its picture, then one numbered line per badge in that picture.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN / 3)
	panel.add_child(inside)

	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", colour)
	heading.add_theme_font_size_override("font_size", Balance.GUIDE_TITLE_FONT_SIZE)
	inside.add_child(heading)

	var drawing: Control = DIAGRAM.new(picture, colour)
	drawing.custom_minimum_size = Vector2(0.0, Balance.GUIDE_DIAGRAM_HEIGHT)
	drawing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inside.add_child(drawing)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lines: Array[String] = []
	for index: int in steps.size():
		lines.append("[b]%d.[/b]  %s" % [index + 1, steps[index]])
	text.text = "\n".join(lines)
	for size: StringName in [&"normal_font_size", &"bold_font_size"]:
		text.add_theme_font_size_override(size, Balance.GUIDE_ROLE_FONT_SIZE)
	inside.add_child(text)
	return panel


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
