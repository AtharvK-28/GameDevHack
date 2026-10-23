# Builds the game's UI theme (assets/ui/ghosted_theme.tres) from Kenney UI Pack pieces in assets/ui/kenney/,
# tinted to the palette in Balance's UI section, with Baloo 2 as the only font. It also draws the small ghost
# icon (assets/ui/icons/ghost.png) that the Kenney packs lack. Run after changing the palette or sizes, with the
# images already imported:
#   godot --headless --path . --script res://tools/make_ui_theme.gd
extends SceneTree

# --- Paths ---
const SETTINGS := preload("res://autoload/Balance.gd")
const KENNEY: String = "res://assets/ui/kenney/"
const FONT_PATH: String = "res://assets/fonts/baloo2_variable.ttf"
const THEME_PATH: String = "res://assets/ui/ghosted_theme.tres"
const GHOST_ICON_PATH: String = "res://assets/ui/icons/ghost.png"

# --- Kenney piece geometry (pixels in the source images) ---
const CORNER: int = 10 # Rounded corner and rim, kept unstretched.
const DEPTH: int = 4 # The darker bottom edge of "depth" pieces; it vanishes when pressed.

# --- Spacing inside controls (base pixels) ---
const BUTTON_PADDING := Vector2i(24, 10)
const HUD_PADDING := Vector2i(12, 8)
const TAB_PADDING := Vector2i(18, 8)
const FOCUS_RADIUS: int = 10
const BAR_RADIUS: int = 6
const ICON_SIZE: int = 100 # The ghost icon, matching Kenney's 2x game icons.

# --- Setup ---
func _initialize() -> void:
	_draw_ghost_icon()
	var theme := Theme.new()
	var body: FontVariation = _font(SETTINGS.UI_FONT_WEIGHT)
	var title: FontVariation = _font(SETTINGS.UI_TITLE_WEIGHT)
	theme.default_font = body
	theme.default_font_size = SETTINGS.UI_BODY_SIZE
	_labels(theme, title)
	_buttons(theme)
	_panels(theme)
	_bars_and_sliders(theme)
	_toggles(theme)
	_tabs_and_lists(theme)
	var error: Error = ResourceSaver.save(theme, THEME_PATH)
	print("UI theme saved: %s" % error_string(error))
	quit()


# --- Fonts and labels ---
func _font(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(FONT_PATH)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _labels(theme: Theme, title: FontVariation) -> void:
	theme.set_color("font_color", "Label", SETTINGS.UI_TEXT)
	theme.set_color("font_outline_color", "Label", SETTINGS.UI_OUTLINE)
	var variations: Dictionary = {
		"TitleLabel": [SETTINGS.UI_TITLE_SIZE, SETTINGS.UI_TEXT, true],
		"HeadingLabel": [SETTINGS.UI_HEADING_SIZE, SETTINGS.UI_TEXT, true],
		"MutedLabel": [SETTINGS.UI_SMALL_SIZE, SETTINGS.UI_MUTED, false],
		"MoneyLabel": [SETTINGS.UI_BODY_SIZE, SETTINGS.UI_MONEY, false],
		"GhostLabel": [SETTINGS.UI_BODY_SIZE, SETTINGS.UI_GHOST, false],
		"HudLabel": [SETTINGS.UI_BODY_SIZE, SETTINGS.UI_TEXT, false],
	}
	for variation: String in variations:
		var values: Array = variations[variation]
		theme.set_type_variation(variation, "Label")
		theme.set_font_size("font_size", variation, values[0])
		theme.set_color("font_color", variation, values[1])
		if values[2]:
			theme.set_font("font", variation, title)
	theme.set_constant("outline_size", "TitleLabel", SETTINGS.UI_OUTLINE_SIZE)
	theme.set_constant("outline_size", "HudLabel", SETTINGS.UI_OUTLINE_SIZE)


# --- Buttons ---
func _buttons(theme: Theme) -> void:
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		_button_styles(theme, type, SETTINGS.UI_BUTTON, SETTINGS.UI_BUTTON_HOVER, SETTINGS.UI_TEXT)
	# The main action on a screen (Play, Start): ghost green with dark text.
	theme.set_type_variation("PrimaryButton", "Button")
	_button_styles(theme, "PrimaryButton", SETTINGS.UI_GHOST.darkened(0.15), SETTINGS.UI_GHOST, SETTINGS.UI_NIGHT)
	# Big square tiles (map select).
	theme.set_type_variation("TileButton", "Button")
	theme.set_stylebox("normal", "TileButton", _piece("button_square_depth_flat.png", SETTINGS.UI_PANEL.lightened(0.08), true, Vector2i(SETTINGS.UI_PANEL_MARGIN, SETTINGS.UI_PANEL_MARGIN)))
	theme.set_stylebox("hover", "TileButton", _piece("button_square_depth_flat.png", SETTINGS.UI_BUTTON, true, Vector2i(SETTINGS.UI_PANEL_MARGIN, SETTINGS.UI_PANEL_MARGIN)))
	theme.set_stylebox("pressed", "TileButton", _piece("button_square_flat.png", SETTINGS.UI_BUTTON, false, Vector2i(SETTINGS.UI_PANEL_MARGIN, SETTINGS.UI_PANEL_MARGIN)))
	theme.set_stylebox("disabled", "TileButton", _piece("button_square_depth_flat.png", SETTINGS.UI_PANEL.darkened(0.2), true, Vector2i(SETTINGS.UI_PANEL_MARGIN, SETTINGS.UI_PANEL_MARGIN)))
	theme.set_stylebox("focus", "TileButton", _focus_ring())
	theme.set_color("font_disabled_color", "TileButton", SETTINGS.UI_MUTED)


func _button_styles(theme: Theme, type: String, base: Color, hover: Color, text: Color) -> void:
	theme.set_stylebox("normal", type, _piece("button_rectangle_depth_flat.png", base, true, BUTTON_PADDING))
	theme.set_stylebox("hover", type, _piece("button_rectangle_depth_flat.png", hover, true, BUTTON_PADDING))
	theme.set_stylebox("pressed", type, _piece("button_rectangle_flat.png", base, false, BUTTON_PADDING))
	theme.set_stylebox("hover_pressed", type, _piece("button_rectangle_flat.png", hover, false, BUTTON_PADDING))
	theme.set_stylebox("disabled", type, _piece("button_rectangle_depth_flat.png", Color(base.darkened(0.45), 0.8), true, BUTTON_PADDING))
	theme.set_stylebox("focus", type, _focus_ring())
	theme.set_font_size("font_size", type, SETTINGS.UI_BUTTON_SIZE)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, SETTINGS.UI_MUTED)


# --- Panels ---
func _panels(theme: Theme) -> void:
	var panel_padding := Vector2i(SETTINGS.UI_PANEL_MARGIN, SETTINGS.UI_PANEL_MARGIN)
	var menu_panel: StyleBoxTexture = _piece("button_square_flat.png", Color(SETTINGS.UI_PANEL, SETTINGS.UI_PANEL_ALPHA), false, panel_padding)
	for type: String in ["PanelContainer", "Panel", "TooltipPanel", "PopupPanel"]:
		theme.set_stylebox("panel", type, menu_panel)
	theme.set_stylebox("embedded_border", "Window", menu_panel)
	# HUD panels: more see-through and tighter, so the game shows around them.
	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", _piece("button_square_flat.png", Color(SETTINGS.UI_PANEL, SETTINGS.UI_HUD_ALPHA), false, HUD_PADDING))
	# Cards inside panels (lobby slots, totals rows).
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _piece("button_square_depth_flat.png", SETTINGS.UI_PANEL.lightened(0.1), true, panel_padding))


# --- Bars and sliders ---
func _bars_and_sliders(theme: Theme) -> void:
	var track: StyleBoxTexture = _piece("slide_horizontal_grey.png", SETTINGS.UI_NIGHT.lightened(0.15), false, Vector2i.ZERO, 6)
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", _rounded(SETTINGS.UI_GHOST, BAR_RADIUS))
	theme.set_color("font_color", "ProgressBar", SETTINGS.UI_TEXT)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _piece("slide_horizontal_grey.png", SETTINGS.UI_GHOST, false, Vector2i.ZERO, 6))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _piece("slide_horizontal_grey.png", SETTINGS.UI_GHOST.lightened(0.2), false, Vector2i.ZERO, 6))
	for icon: String in ["grabber", "grabber_highlight"]:
		theme.set_icon(icon, "HSlider", load(KENNEY + "slide_hangle.png"))
	theme.set_stylebox("focus", "HSlider", _focus_ring())
	theme.set_stylebox("scroll", "VScrollBar", _rounded(SETTINGS.UI_NIGHT, BAR_RADIUS))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		theme.set_stylebox(state, "VScrollBar", _rounded(SETTINGS.UI_BUTTON_HOVER, BAR_RADIUS))


# --- Check boxes and toggles ---
func _toggles(theme: Theme) -> void:
	for type: String in ["CheckBox", "CheckButton"]:
		theme.set_icon("checked", type, load(KENNEY + "check_square_grey_checkmark.png"))
		theme.set_icon("unchecked", type, load(KENNEY + "check_square_grey.png"))
		theme.set_icon("checked_disabled", type, load(KENNEY + "check_square_grey_checkmark.png"))
		theme.set_icon("unchecked_disabled", type, load(KENNEY + "check_square_grey.png"))
		theme.set_stylebox("focus", type, _focus_ring())
		theme.set_font_size("font_size", type, SETTINGS.UI_BODY_SIZE)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, SETTINGS.UI_TEXT)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			theme.set_stylebox(state, type, StyleBoxEmpty.new())


# --- Tabs, menus, lists and text fields ---
func _tabs_and_lists(theme: Theme) -> void:
	for type: String in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, _piece("button_rectangle_flat.png", SETTINGS.UI_BUTTON_HOVER, false, TAB_PADDING))
		theme.set_stylebox("tab_unselected", type, _piece("button_rectangle_flat.png", SETTINGS.UI_BUTTON.darkened(0.25), false, TAB_PADDING))
		theme.set_stylebox("tab_hovered", type, _piece("button_rectangle_flat.png", SETTINGS.UI_BUTTON, false, TAB_PADDING))
		theme.set_stylebox("tab_focus", type, _focus_ring())
		theme.set_color("font_selected_color", type, SETTINGS.UI_TEXT)
		theme.set_color("font_unselected_color", type, SETTINGS.UI_MUTED)
		theme.set_color("font_hovered_color", type, SETTINGS.UI_TEXT)
		theme.set_font_size("font_size", type, SETTINGS.UI_BODY_SIZE)
	theme.set_stylebox("panel", "TabContainer", _piece("button_square_flat.png", Color(SETTINGS.UI_PANEL, SETTINGS.UI_PANEL_ALPHA), false, Vector2i(SETTINGS.UI_PANEL_MARGIN, SETTINGS.UI_PANEL_MARGIN)))
	theme.set_stylebox("panel", "PopupMenu", _piece("button_square_flat.png", SETTINGS.UI_PANEL, false, HUD_PADDING))
	theme.set_stylebox("hover", "PopupMenu", _rounded(SETTINGS.UI_BUTTON, BAR_RADIUS))
	theme.set_color("font_color", "PopupMenu", SETTINGS.UI_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", SETTINGS.UI_TEXT)
	theme.set_font_size("font_size", "PopupMenu", SETTINGS.UI_BODY_SIZE)
	theme.set_stylebox("normal", "LineEdit", _piece("input_rectangle.png", Color.WHITE, false, BUTTON_PADDING))
	theme.set_stylebox("focus", "LineEdit", _focus_ring())
	theme.set_color("font_color", "LineEdit", SETTINGS.UI_NIGHT)
	theme.set_color("caret_color", "LineEdit", SETTINGS.UI_NIGHT)


# --- Style helpers ---
func _piece(file: String, tint: Color, has_depth: bool, padding: Vector2i, corner: int = CORNER) -> StyleBoxTexture:
	# A Kenney piece as a nine-slice, tinted. Depth pieces keep their bottom edge and pad the text above it.
	var box := StyleBoxTexture.new()
	box.texture = load(KENNEY + file)
	box.texture_margin_left = corner
	box.texture_margin_right = corner
	box.texture_margin_top = corner
	box.texture_margin_bottom = corner + (DEPTH if has_depth else 0)
	box.modulate_color = tint
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y + (0 if has_depth else DEPTH / 2)
	box.content_margin_bottom = padding.y + (DEPTH if has_depth else DEPTH / 2)
	return box


func _rounded(colour: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	return box


func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = SETTINGS.UI_GHOST
	ring.set_border_width_all(SETTINGS.UI_FOCUS_WIDTH)
	ring.set_corner_radius_all(FOCUS_RADIUS)
	ring.set_expand_margin_all(SETTINGS.UI_FOCUS_WIDTH)
	return ring


# --- Ghost icon ---
func _draw_ghost_icon() -> void:
	# A white ghost (round head, wavy hem, two eye holes), drawn at 4× and shrunk for smooth edges.
	var scale: int = 4
	var size: int = ICON_SIZE * scale
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in range(size):
		for x: int in range(size):
			var point := Vector2(x, y) / scale
			var head: bool = point.distance_to(Vector2(50, 44)) < 34.0 and point.y <= 44.0
			var body: bool = point.x >= 16.0 and point.x <= 84.0 and point.y >= 44.0 and point.y <= 80.0
			var hem: bool = false
			for bump: int in range(3):
				hem = hem or point.distance_to(Vector2(27.3 + bump * 22.7, 80.0)) < 11.4
			var eye: bool = point.distance_to(Vector2(39, 44)) < 7.0 or point.distance_to(Vector2(61, 44)) < 7.0
			if (head or body or hem) and not eye:
				image.set_pixel(x, y, Color.WHITE)
	image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(GHOST_ICON_PATH))
