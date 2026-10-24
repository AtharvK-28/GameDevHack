# The title screen: the game's name over the Mansion idling at dusk, with Play, Guide, Options, Credits and Quit.
# Built on Maaack's MainMenu (addons/maaacks_game_template). Play opens the map select instead of starting
# straight away; choosing a house loads the match (the game scene in Project Settings).
extends MainMenu

## The map select opened by Play.
@export var map_select_scene: PackedScene
const GUIDE_SCENE := preload("res://menus/guide/guide.tscn")

# --- Setup ---
func _ready() -> void:
	super._ready()
	# Headless checks can leave a tiny saved window; keep the home menu usable when returning to a display.
	if DisplayServer.get_name() != "headless":
		var base_size := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
		get_window().min_size = base_size
		get_window().size = get_window().size.max(base_size)
	_comic_title()
	# A sub menu (map select, options, credits) gets the screen to itself.
	sub_menu_opened.connect(_show_title.bind(false))
	sub_menu_closed.connect(_show_title.bind(true))
	%GuideButton.pressed.connect(func() -> void: _open_sub_menu(GUIDE_SCENE))


func _comic_title() -> void:
	# The title in the intro's comic lettering, gold with a thick ink outline. It stands alone: no logo above it.
	var title: Label = $MenuContainer/TitleMargin/TitleContainer/TitleLabel
	title.add_theme_font_override("font", load(Balance.COMIC_FONT_PATH))
	title.add_theme_font_size_override("font_size", Balance.MENU_TITLE_SIZE)
	title.add_theme_color_override("font_color", Balance.UI_MONEY)
	title.add_theme_constant_override("outline_size", Balance.COMIC_OUTLINE_SIZE + 4)
	title.add_theme_color_override("font_outline_color", Balance.COMIC_INK)
	$Logo.hide()


# --- Menu actions ---
func new_game() -> void:
	var map_select: Node = _open_sub_menu(map_select_scene)
	map_select.map_chosen.connect(_on_map_chosen)


func _on_map_chosen(_arena_path: String) -> void:
	UiMotion.cover(load_game_scene) # The wipe slides away once the match scene is showing.


func _show_title(shown: bool) -> void:
	%MenuContainer.visible = shown
	if shown:
		%NewGameButton.grab_focus.call_deferred()
