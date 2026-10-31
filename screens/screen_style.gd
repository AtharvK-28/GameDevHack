# Shared look for the host's match screens: big, high-contrast text and panels that read on a projector.
extends RefCounted

const THEME_PATH: String = "res://assets/ui/ghosted_theme.tres"
const HALFTONE := preload("res://assets/shaders/halftone.gdshader")

# --- Building blocks ---
static func panel(min_width: float, padding: int = Balance.HOST_PANEL_PADDING) -> PanelContainer:
	var box := PanelContainer.new()
	var theme: Theme = load("res://assets/ui/ghosted_theme.tres")
	var style: StyleBox = theme.get_stylebox("panel", "PanelContainer").duplicate()
	style.set_content_margin_all(padding)
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
	line.add_theme_font_size_override("font_size", maxi(size, Balance.UI_SMALL_SIZE))
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
	press.focus_mode = Control.FOCUS_ALL
	return press


static func centre(child: Control) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(child)
	holder.visibility_changed.connect(func() -> void:
		if holder.is_visible_in_tree():
			UiMotion.pop_in(child)
	)
	return holder


# --- Comic style ---
static func use_theme(screen: Control) -> void:
	# The match screens sit under a CanvasLayer, so they get the game's theme (Baloo 2, Kenney buttons) directly.
	screen.theme = load(THEME_PATH)


static func backdrop() -> ColorRect:
	# Night tint with halftone dots, behind full screens so the game world doesn't fight the panels.
	var cover := ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = HALFTONE
	material.set_shader_parameter("tint", Color(Balance.UI_NIGHT, Balance.COMIC_BACKDROP_ALPHA))
	material.set_shader_parameter("dot_colour", Color(Balance.UI_MUTED, Balance.COMIC_DOT_ALPHA))
	material.set_shader_parameter("spacing", Balance.COMIC_DOT_SPACING)
	cover.material = material
	return cover


static func comic_box(colour: Color, padding: int = Balance.UI_PANEL_MARGIN, corner: int = Balance.COMIC_CORNER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = Balance.COMIC_INK
	style.set_border_width_all(Balance.COMIC_BORDER)
	style.set_corner_radius_all(corner)
	style.shadow_color = Color(Balance.COMIC_INK, Balance.COMIC_SHADOW_ALPHA)
	style.shadow_offset = Balance.COMIC_SHADOW
	style.set_content_margin_all(padding)
	return style


static func caption(min_width: float = 0.0, padding: int = Balance.UI_PANEL_MARGIN) -> PanelContainer:
	# A parchment narration box, like the intro's captions. Put ink_label() text on it.
	return _boxed(comic_box(Balance.COMIC_PAPER, padding), min_width)


static func ink_panel(min_width: float = 0.0, padding: int = Balance.UI_PANEL_MARGIN, colour: Color = Balance.UI_PANEL) -> PanelContainer:
	return _boxed(comic_box(colour, padding), min_width)


static func lettering(text: String, size: int, colour: Color = Balance.UI_TEXT) -> Label:
	# Comic lettering (Bangers) with a thick ink outline: headlines, stamps and event pop-ups.
	var line := label(text, size, colour)
	line.add_theme_font_override("font", load(Balance.COMIC_FONT_PATH))
	line.add_theme_constant_override("outline_size", Balance.COMIC_OUTLINE_SIZE)
	line.add_theme_color_override("font_outline_color", Balance.COMIC_INK)
	return line


static func ink_label(text: String, size: int) -> Label:
	# Dark text with no outline, for paper and bubbles.
	var line := label(text, size, Balance.COMIC_INK)
	line.add_theme_constant_override("outline_size", 0)
	return line


static func stamp(text: String, colour: Color, size: int = Balance.COMIC_HEADING_SIZE) -> Control:
	# A tilted rubber stamp: coloured lettering in a coloured frame. Containers reset rotation, so the stamp
	# turns inside a plain holder that takes its size. Animate it with slam().
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Balance.COMIC_INK, 0.55)
	style.border_color = colour
	style.set_border_width_all(Balance.COMIC_BORDER + 2)
	style.set_corner_radius_all(Balance.COMIC_CORNER)
	style.set_content_margin_all(Balance.UI_PANEL_MARGIN / 2)
	frame.add_theme_stylebox_override("panel", style)
	var line := lettering(text, size, colour)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF # The holder starts with no width; wrapping would stack letters.
	line.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	frame.add_child(line)
	frame.rotation_degrees = Balance.COMIC_STAMP_ANGLE
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	frame.resized.connect(func() -> void:
		holder.custom_minimum_size = frame.size
		frame.pivot_offset = frame.size / 2.0
	)
	return holder


static func slam(holder: Control) -> void:
	# A stamp() slams down: big and clear, then hard onto the page with a small bounce.
	var frame: Control = holder.get_child(0)
	frame.scale = Vector2.ONE * Balance.COMIC_STAMP_START
	frame.modulate.a = 0.0
	var tween: Tween = frame.create_tween().set_parallel()
	tween.tween_property(frame, "scale", Vector2.ONE, Balance.COMIC_STAMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(frame, "modulate:a", 1.0, Balance.COMIC_STAMP_TIME * 0.5)


static func bubble(bbcode: String, size: int = Balance.UI_BODY_SIZE, tail_right: bool = false) -> VBoxContainer:
	# A white speech bubble with its tail at the lower left, or lower right. The text is BBCode: [b]…[/b] is comic lettering and
	# [color=…] colours a name. The text node is the bubble's first child's child: get_child(0).get_child(0).
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := _boxed(comic_box(Color.WHITE, Balance.UI_PANEL_MARGIN, Balance.COMIC_BUBBLE_CORNER), 0.0)
	var words := RichTextLabel.new()
	words.bbcode_enabled = true
	words.fit_content = true
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.scroll_active = false
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_color_override("default_color", Balance.COMIC_INK)
	words.add_theme_font_size_override("normal_font_size", size)
	words.add_theme_font_size_override("bold_font_size", roundi(size * 1.4))
	words.add_theme_font_override("bold_font", load(Balance.COMIC_FONT_PATH))
	words.text = bbcode
	body.add_child(words)
	holder.add_child(body)
	var tail := Control.new()
	tail.custom_minimum_size.y = Balance.COMIC_TAIL_SIZE.y
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(func() -> void:
		var left: float = Balance.COMIC_BUBBLE_CORNER + 8.0
		var top: float = -Balance.COMIC_BORDER - 1.0 # Covers the bubble's bottom border.
		var points := PackedVector2Array([Vector2(left, top), Vector2(left + Balance.COMIC_TAIL_SIZE.x, top), Vector2(left - 6.0, Balance.COMIC_TAIL_SIZE.y)])
		if tail_right:
			for index: int in range(points.size()):
				points[index].x = tail.size.x - points[index].x
		tail.draw_colored_polygon(points, Color.WHITE)
		tail.draw_polyline(PackedVector2Array([points[1], points[2], points[0]]), Balance.COMIC_INK, Balance.COMIC_BORDER, true)
	)
	holder.add_child(tail)
	return holder


static func chip(slot: int, text: String, size: int = Balance.UI_BODY_SIZE) -> PanelContainer:
	# A player's pill: a thick stripe of their colour on the left, then their text. Extra children can be added
	# to the pill's row (get_child(0)).
	var pill := ink_panel(0.0, Balance.UI_PANEL_MARGIN / 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	pill.add_child(row)
	var stripe := ColorRect.new()
	stripe.color = player_colour(slot)
	stripe.custom_minimum_size.x = Balance.COMIC_BORDER * 3
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	var line := label(text, size, player_colour(slot))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	return pill


static func mover_figure(colour: Color, size: float, possessed: bool = false) -> Control:
	# A mover's head-and-shoulders silhouette in a cap, in the player's colour. A possessed mover (the ghost this
	# round) glows ghost green and has glowing eyes.
	var figure := Control.new()
	figure.custom_minimum_size = Vector2.ONE * size
	figure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.draw.connect(func() -> void:
		var s: float = size
		var ink: Color = Balance.COMIC_INK
		var head := Vector2(s * 0.5, s * 0.44)
		var radius: float = s * 0.2
		if possessed:
			figure.draw_circle(head + Vector2(0.0, s * 0.1), s * 0.5, Color(Balance.UI_GHOST, 0.22))
			figure.draw_circle(head + Vector2(0.0, s * 0.1), s * 0.38, Color(Balance.UI_GHOST, 0.25))
		# Shoulders in overalls: a rounded block in the player's colour with two darker straps.
		var body := StyleBoxFlat.new()
		body.bg_color = colour
		body.border_color = ink
		body.set_border_width_all(2)
		body.corner_radius_top_left = int(s * 0.18)
		body.corner_radius_top_right = int(s * 0.18)
		figure.draw_style_box(body, Rect2(s * 0.14, s * 0.66, s * 0.72, s * 0.34))
		for strap: float in [0.34, 0.62]:
			figure.draw_rect(Rect2(s * strap, s * 0.68, s * 0.06, s * 0.3), colour.darkened(0.35))
		figure.draw_circle(head, radius, Balance.MOVER_SKIN) # Face.
		figure.draw_arc(head, radius, 0.0, TAU, 24, ink, 2.0)
		# Cap: a dome over the top of the head and a brim to the right.
		var dome := PackedVector2Array()
		for step: int in 13:
			dome.append(head + Vector2.from_angle(PI + PI * step / 12.0) * (radius + 2.0))
		figure.draw_colored_polygon(dome, colour)
		figure.draw_polyline(dome, ink, 2.0, true)
		var brim := Rect2(head.x, head.y - s * 0.04, radius * 1.5, s * 0.07)
		figure.draw_rect(brim, colour.darkened(0.2))
		figure.draw_rect(brim, ink, false, 2.0)
		if possessed:
			for side: float in [-1.0, 1.0]:
				figure.draw_circle(head + Vector2(side * radius * 0.4, radius * 0.25), radius * 0.16, Balance.UI_GHOST)
	)
	return figure


static func star_row(stars: int, total: int, size: float) -> Control:
	# A row of drawn stars, the earned ones gold and the rest hollow (decision 123). Drawn, as the comic font has none.
	var row := Control.new()
	row.custom_minimum_size = Vector2(size * total + size * 0.2 * (total - 1), size)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(func() -> void:
		for index: int in total:
			var centre := Vector2(size * 0.5 + index * size * 1.2, size * 0.53)
			var points := PackedVector2Array()
			for corner: int in 10:
				var reach: float = size * (0.5 if corner % 2 == 0 else 0.21)
				points.append(centre + Vector2.from_angle(-PI / 2.0 + corner * PI / 5.0) * reach)
			if index < stars:
				row.draw_colored_polygon(points, Balance.UI_MONEY)
			points.append(points[0])
			row.draw_polyline(points, Balance.COMIC_INK if index < stars else Balance.UI_MUTED, Balance.COMIC_BORDER, true)
	)
	return row


static func goal_line(goal: Dictionary, label: String) -> String:
	# One bonus goal as a line of text: "BONUS: Nothing shatters · DONE".
	if goal.is_empty():
		return ""
	var state: String = {"met": " · DONE", "failed": " · MISSED"}.get(goal.get("state"), "")
	return "%s: %s%s" % [label, goal.text, state]


static func keycap(key: String) -> PanelContainer:
	var cap := _boxed(comic_box(Balance.COMIC_PAPER, 4, 4), 0.0)
	cap.get_theme_stylebox("panel").shadow_offset = Vector2(2.0, 3.0)
	var line := ink_label(key, Balance.KEYCAP_SIZE)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	cap.add_child(line)
	return cap


static func action(text: String, key: String, pressed: Callable) -> HBoxContainer:
	# A button with its keyboard key shown beside it as a keycap.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Balance.HOST_ROW_GAP)
	var cap := keycap(key)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var press := button(text)
	press.pressed.connect(pressed)
	row.add_child(press)
	return row


static func _boxed(style: StyleBox, min_width: float) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size.x = min_width
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


# --- Players ---
static func short_name(full: String) -> String:
	return full if full.length() <= Balance.NAME_MAX_CHARS else full.left(Balance.NAME_MAX_CHARS - 1) + "…"


static func player_name(slot: int) -> String:
	var player: Dictionary = Net.player_for_slot(slot)
	return short_name(player.get("name", "Player %d" % (slot + 1)))


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
