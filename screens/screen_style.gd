# Shared look for the host's match screens: big, high-contrast text and panels that read on a projector.
extends RefCounted

# --- Building blocks ---
static func panel(min_width: float) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Balance.HOST_PANEL_COLOUR
	style.set_corner_radius_all(Balance.HOST_CORNER_RADIUS)
	style.set_content_margin_all(Balance.HOST_PANEL_PADDING)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size.x = min_width
	return box


static func column() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	return rows


static func label(text: String, size: int, colour: Color = Balance.HOST_TEXT_COLOUR) -> Label:
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", size)
	line.add_theme_color_override("font_color", colour)
	line.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	line.add_theme_color_override("font_outline_color", Balance.HOST_OUTLINE_COLOUR)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


static func button(text: String) -> Button:
	var press := Button.new()
	press.text = text
	press.add_theme_font_size_override("font_size", Balance.HOST_FONT_SIZE)
	press.focus_mode = Control.FOCUS_NONE # Keys go to the screen's own shortcuts, never to a focused button.
	return press


static func centre(child: Control) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(child)
	return holder


static func player_name(slot: int) -> String:
	var player: Dictionary = Net.player_for_slot(slot)
	return player.get("name", "Player %d" % (slot + 1))


static func player_colour(slot: int) -> Color:
	return Color(Balance.PLAYER_COLOURS[slot])


static func clock(seconds: float) -> String:
	var whole: int = ceili(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


static func pressed_key(event: InputEvent) -> Key:
	# The physical key of a fresh key press, or KEY_NONE.
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode
	return KEY_NONE
