# A camera-facing wall: solid until the party camera reports that it hides a player, then see-through
# (ARENA_SEE_THROUGH_ALPHA) for as long as it does, plus WALL_FADE_HOLD seconds so it never flickers.
# Every mesh on it (both faces, trim, arch) fades together; its collider never changes.
class_name FadeWall
extends StaticBody3D

# --- State ---
var box: AABB # World-space bounds, for the camera's line test; set by the arena builder.
var alpha: float = 1.0
var hold: float = 0.0

# --- Setup ---
func _ready() -> void:
	add_to_group("fade_walls")


# --- Fading ---
func update_fade(hiding: bool, delta: float) -> void:
	hold = Balance.WALL_FADE_HOLD if hiding else maxf(0.0, hold - delta)
	var target: float = Balance.ARENA_SEE_THROUGH_ALPHA if hold > 0.0 else 1.0
	var step: float = (1.0 - Balance.ARENA_SEE_THROUGH_ALPHA) * delta / Balance.WALL_FADE_TIME
	var next_alpha: float = move_toward(alpha, target, step)
	if next_alpha == alpha:
		return
	alpha = next_alpha
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = mesh.material_override
		material.albedo_color.a = alpha
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
