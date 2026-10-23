# Carryable flashlight. While held, its beam follows the holder's facing; a possessed prop kept in the
# beam for EXORCISE_TIME seconds is exorcised. Targets join the "possessables" group and expose
# is_possessed() and exorcise(); Phase 4's Possessable component provides them.
class_name Flashlight
extends Carryable

signal exorcised(target: Node)

# --- Beam state ---
var beam := SpotLight3D.new()
var exposure: Dictionary = {} # Target instance id -> seconds spent in the beam.

# --- Setup ---
func _ready() -> void:
	item_name = "Flashlight"
	item_size = Balance.FLASHLIGHT_SIZE
	weight_class = Balance.LIGHT
	add_to_group("flashlights")
	super()
	_build_body()
	_build_beam()


# --- Beam ---
func _physics_process(delta: float) -> void:
	var direction: Vector3 = beam_direction()
	beam.global_position = global_position
	beam.look_at(global_position + direction, Vector3.UP)
	_update_exposure(delta)


func beam_direction() -> Vector3:
	# Held: where the holder faces. Loose: along the torch's own forward axis.
	if is_held():
		return holder.facing
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


func in_beam(point: Vector3) -> bool:
	var offset: Vector3 = point - global_position
	if offset.length() > Balance.FLASHLIGHT_RANGE:
		return false
	if offset.normalized().dot(beam_direction()) < cos(deg_to_rad(Balance.FLASHLIGHT_HALF_ANGLE)):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position, point, Balance.WORLD_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_exposure(delta: float) -> void:
	# Only a held torch exorcises; a target that leaves the beam starts again from zero.
	if not is_held():
		exposure.clear()
		return
	var still_lit: Dictionary = {}
	for target: Node in get_tree().get_nodes_in_group("possessables"):
		if not target.is_possessed() or not in_beam(target.global_position):
			continue
		var id: int = target.get_instance_id()
		var seconds: float = exposure.get(id, 0.0) + delta
		if seconds >= Balance.EXORCISE_TIME:
			target.exorcise()
			exorcised.emit(target)
			print("Player %d exorcised %s" % [last_carrier_slot + 1, target.name])
			seconds = 0.0
		still_lit[id] = seconds
	exposure = still_lit


func _apply_carry(state: PhysicsDirectBodyState3D) -> void:
	super(state)
	# Swing the torch body round to point where the holder faces.
	var forward: Vector3 = -state.transform.basis.z
	var turn: float = Vector2(forward.x, forward.z).angle_to(Vector2(holder.facing.x, holder.facing.z))
	var angular_acceleration := Vector3.DOWN * turn * Balance.FLASHLIGHT_AIM_STIFFNESS
	state.apply_torque(state.inverse_inertia_tensor.inverse() * angular_acceleration)


# --- Visual helpers ---
func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = item_size
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	var torch := CylinderMesh.new()
	torch.height = item_size.z
	torch.top_radius = item_size.x / 2.0
	torch.bottom_radius = item_size.x / 3.0
	mesh.mesh = torch
	mesh.rotation.x = -PI / 2.0 # Lay the cylinder along -Z, wide end forward.
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.FLASHLIGHT_COLOUR
	mesh.material_override = material
	add_child(mesh)


func _build_beam() -> void:
	beam.spot_range = Balance.FLASHLIGHT_RANGE
	beam.spot_angle = Balance.FLASHLIGHT_HALF_ANGLE
	beam.light_energy = Balance.FLASHLIGHT_ENERGY
	beam.light_color = Balance.FLASHLIGHT_COLOUR
	add_child(beam)
	beam.top_level = true

	# A faint cone mesh makes the beam readable from across the room.
	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.height = Balance.FLASHLIGHT_RANGE
	cone_mesh.top_radius = item_size.x / 2.0
	cone_mesh.bottom_radius = Balance.FLASHLIGHT_RANGE * tan(deg_to_rad(Balance.FLASHLIGHT_HALF_ANGLE))
	cone.mesh = cone_mesh
	cone.rotation.x = PI / 2.0 # Narrow end at the torch, wide end along the beam (-Z).
	cone.position.z = -Balance.FLASHLIGHT_RANGE / 2.0
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(Balance.FLASHLIGHT_COLOUR, Balance.BEAM_CONE_ALPHA)
	cone.material_override = material
	beam.add_child(cone)
