# The title screen: the game's name over the Mansion idling at dusk, with Play, Options, Credits and Quit.
# Built on Maaack's MainMenu (addons/maaacks_game_template). Play opens the map select instead of starting
# straight away; choosing a house loads the match (the game scene in Project Settings).
extends MainMenu

## The map select opened by Play.
@export var map_select_scene: PackedScene

# --- Setup ---
func _ready() -> void:
	super._ready()
	$Logo.modulate = Balance.UI_GHOST


# --- Menu actions ---
func new_game() -> void:
	var map_select: Node = _open_sub_menu(map_select_scene)
	map_select.map_chosen.connect(_on_map_chosen)


func _on_map_chosen(_arena_path: String) -> void:
	UiMotion.cover(load_game_scene) # The wipe slides away once the match scene is showing.
