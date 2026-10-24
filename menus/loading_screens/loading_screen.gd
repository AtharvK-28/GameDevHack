# The loading screen: the team's comic art full screen, with a real progress bar across the bottom (where the art's
# own mock-up bar was), "LOADING: 78%" in comic lettering, and a rotating gameplay tip. Built on Maaack's
# LoadingScreen, which drives %ProgressBar and %ProgressLabel from the scene loader.
extends LoadingScreen

const ART := preload("res://assets/ui/loading/loading_art.jpg")
const Style := preload("res://screens/screen_style.gd")

var tip_label: Label
var tip_index: int = 0
var tip_left: float = 0.0


func _ready() -> void:
	super()
	var control: Control = $Control
	Style.use_theme(control) # A CanvasLayer's controls don't inherit the window's theme.
	$Control/BackPanel.hide()
	$Control/BackgroundColor.color = Balance.UI_NIGHT # Behind the art, in case the window is wider than it.
	var art: TextureRect = $Control/BackgroundTextureRect
	art.texture = ART
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_style_bar(control)
	tip_index = randi() % Balance.LOADING_TIPS.size()
	_show_tip()


func _style_bar(control: Control) -> void:
	# The bar runs along the bottom edge; the label sits on it, the tip just above it.
	var rows: VBoxContainer = $Control/VBoxContainer
	rows.add_theme_constant_override("separation", 0)
	rows.anchor_top = 1.0
	rows.anchor_bottom = 1.0
	rows.offset_left = 0.0
	rows.offset_right = 0.0
	rows.offset_top = -Balance.LOADING_BAR_HEIGHT
	rows.offset_bottom = 0.0
	var bar: ProgressBar = %ProgressBar
	bar.custom_minimum_size.y = Balance.LOADING_BAR_HEIGHT
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(Balance.COMIC_INK, 0.85)
	track.border_color = Balance.COMIC_INK
	track.border_width_top = Balance.COMIC_BORDER
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Balance.LOADING_BAR_COLOUR
	fill.border_color = Balance.LOADING_BAR_COLOUR.lightened(0.35)
	fill.border_width_top = Balance.COMIC_BORDER * 2 # A lighter top edge, like the art's mock-up bar.
	bar.add_theme_stylebox_override("fill", fill)
	# The label sits over the middle of the bar instead of above it.
	var label: Label = %ProgressLabel
	label.reparent(bar, false)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load(Balance.COMIC_FONT_PATH))
	label.add_theme_font_size_override("font_size", Balance.LOADING_LABEL_SIZE)
	label.add_theme_color_override("font_color", Balance.UI_TEXT)
	label.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Balance.COMIC_INK)
	# A tip on a parchment caption, bottom left, just above the bar.
	var caption := Style.caption(0.0, Balance.UI_PANEL_MARGIN / 2)
	tip_label = Style.ink_label("", Balance.UI_BODY_SIZE)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.add_child(tip_label)
	control.add_child(caption)
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.offset_left = Balance.UI_SCREEN_MARGIN
	caption.offset_bottom = -Balance.LOADING_BAR_HEIGHT - Balance.UI_SCREEN_MARGIN


func _process(delta: float) -> void:
	super(delta)
	tip_left -= delta
	if tip_left <= 0.0:
		tip_index = (tip_index + 1) % Balance.LOADING_TIPS.size()
		_show_tip()


func _show_tip() -> void:
	tip_left = Balance.LOADING_TIP_SECONDS
	if tip_label != null:
		tip_label.text = "TIP: " + Balance.LOADING_TIPS[tip_index]


func get_progress_message() -> String:
	# "LOADING: 78%" while loading; the template's own messages once it stalls or finishes.
	if not _scene_loading_complete and _stall_stage == StallStage.STARTED:
		return "LOADING: %d%%" % roundi(_scene_loading_progress * 100.0)
	return super().to_upper()
