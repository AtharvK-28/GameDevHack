# Renders the map select picture of each playable house (assets/ui/maps/<name>.png): the arena at dusk from the
# party camera's angle. Needs a window, so run it without --headless:
#   godot --path . --script res://tools/make_map_previews.gd
extends SceneTree

# --- Settings ---
const MAPS: Dictionary = {"mansion": "res://arenas/Mansion.tscn"}
const PICTURE_SIZE := Vector2i(512, 512)
const CAMERA_PITCH: float = 50.0 # Degrees down.
const CAMERA_DISTANCE: float = 23.0 # Metres from the arena's centre.
const SETTLE_FRAMES: int = 20 # Frames for the arena to build and its lights to settle.

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_name: String in MAPS:
		var viewport := SubViewport.new()
		viewport.size = PICTURE_SIZE
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var arena: Node3D = load(MAPS[map_name]).instantiate()
		viewport.add_child(arena)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.current = true
		for frame: int in range(SETTLE_FRAMES):
			await process_frame
		var bounds: Rect2 = arena.camera_bounds()
		var centre := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
		var yaw: float = deg_to_rad(-40.0)
		var pitch: float = deg_to_rad(CAMERA_PITCH)
		camera.look_at_from_position(centre + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * CAMERA_DISTANCE, centre)
		for frame: int in range(SETTLE_FRAMES):
			await process_frame
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/maps/%s.png" % map_name))
		print("saved %s preview" % map_name)
		viewport.queue_free()
	quit()
