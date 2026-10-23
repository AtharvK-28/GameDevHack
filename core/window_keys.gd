# Host window key: F11 switches the shared screen between fullscreen and a window.
# Keeps working while the world is paused between rounds.
extends Node

# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- Keys ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


static func toggle_fullscreen() -> void:
	var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
