# Ecto Slime, in every arena: for SLIME_TRAIL_TIME after casting, the ghost leaves slime patches along its path.
# Each patch lasts SLIME_PATCH_LIFETIME; movers on slime keep their momentum and steer poorly. The trail itself is
# the warning, and walking around it is the counter.
class_name EctoSlime
extends Haunting

# --- Trail state ---
var last_patch := Vector3.INF

# --- Setup ---
func _init() -> void:
	label = "SLIME"
	cost = Balance.SLIME_COST
	cooldown = Balance.SLIME_COOLDOWN
	warning_time = 0.0
	run_time = Balance.SLIME_TRAIL_TIME


# --- Haunting hooks ---
func run() -> void:
	last_patch = Vector3.INF


func running(_delta: float) -> void:
	# The ghost's position follows a possessed prop too, so slime can trail behind a haunted crate.
	var at := Vector3(ghost.global_position.x, 0.0, ghost.global_position.z)
	if last_patch == Vector3.INF or at.distance_to(last_patch) >= Balance.SLIME_PATCH_SPACING:
		_drop_patch(at)


func _drop_patch(at: Vector3) -> void:
	last_patch = at
	var disc := CylinderMesh.new()
	disc.top_radius = Balance.SLIME_PATCH_RADIUS
	disc.bottom_radius = Balance.SLIME_PATCH_RADIUS
	disc.height = Balance.DECAL_THICKNESS
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Balance.SLIME_COLOUR
	var patch := MeshInstance3D.new()
	patch.mesh = disc
	patch.material_override = material
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.add_to_group("slime")
	ghost.get_parent().add_child(patch) # Patches outlive the ghost's role.
	patch.global_position = Vector3(at.x, Balance.DECAL_HEIGHT, at.z)
	var tween := patch.create_tween()
	tween.tween_interval(Balance.SLIME_PATCH_LIFETIME - Balance.SLIME_FADE_TIME)
	tween.tween_property(material, "albedo_color:a", 0.0, Balance.SLIME_FADE_TIME)
	tween.tween_callback(patch.queue_free)
