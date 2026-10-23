# Behind the title and map select: the Mansion at dusk in its own small world, with a camera slowly circling it.
# A dimming layer on top keeps the menu readable.
extends SubViewportContainer

const MANSION := preload("res://arenas/Mansion.tscn")

var arena: Node3D
var camera := Camera3D.new()
var angle: float = 0.0

# --- Setup ---
func _ready() -> void:
	arena = MANSION.instantiate()
	$SubViewport.add_child(arena)
	$SubViewport.add_child(camera)
	camera.current = true
	$Dim.color = Color(Balance.UI_NIGHT, Balance.TITLE_DIM)
	angle = deg_to_rad(Balance.CAMERA_YAW)


# --- Orbit ---
func _process(delta: float) -> void:
	angle += deg_to_rad(Balance.TITLE_ORBIT_SPEED) * delta
	var bounds: Rect2 = arena.camera_bounds()
	var centre := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	var pitch: float = deg_to_rad(Balance.TITLE_CAMERA_PITCH)
	var back := Vector3(sin(angle) * cos(pitch), sin(pitch), cos(angle) * cos(pitch))
	camera.look_at_from_position(centre + back * Balance.TITLE_CAMERA_DISTANCE, centre)
