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
	$Logo.modulate = Balance.UI_GHOST
	# A sub menu (map select, options, credits) gets the screen to itself.
	sub_menu_opened.connect(_show_title.bind(false))
	sub_menu_closed.connect(_show_title.bind(true))
	%GuideButton.pressed.connect(func() -> void: _open_sub_menu(GUIDE_SCENE))


# --- Menu actions ---
func new_game() -> void:
	var map_select: Node = _open_sub_menu(map_select_scene)
	map_select.map_chosen.connect(_on_map_chosen)


func _on_map_chosen(_arena_path: String) -> void:
	UiMotion.cover(load_game_scene) # The wipe slides away once the match scene is showing.


func _show_title(shown: bool) -> void:
	%MenuContainer.visible = shown
	$Logo.visible = shown
	if shown:
		%NewGameButton.grab_focus.call_deferred()
