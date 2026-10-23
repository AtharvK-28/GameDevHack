# Rug inside the front door. Possessed, YANK jerks it along its forward axis: movers standing on it tumble and
# anything loose on it slides away at YANK_SPEED. It has no collision, so it never trips anyone just walking.
extends Node3D

# --- Rug state ---
var item_name: String = "Rug"
var rug_mesh := MeshInstance3D.new()
var area_shape := BoxShape3D.new()
var yanking: bool = false

# --- Setup ---
func _ready() -> void:
	add_to_group("furniture")
	var box := BoxMesh.new()
	box.size = Vector3(Balance.RUG_SIZE.x, Balance.RUG_THICKNESS, Balance.RUG_SIZE.y)
	rug_mesh.mesh = box
	rug_mesh.position.y = Balance.RUG_THICKNESS / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.RUG_COLOUR
	rug_mesh.material_override = material
	add_child(rug_mesh)
	area_shape.size = Vector3(Balance.RUG_SIZE.x, Balance.YANK_HEIGHT, Balance.RUG_SIZE.y)


# --- Yanking ---
func can_act() -> bool:
	return not yanking


func act() -> void:
	var direction: Vector3 = -global_basis.z
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = area_shape
	query.transform = Transform3D(global_basis, global_position + Vector3.UP * Balance.YANK_HEIGHT / 2.0)
	query.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, Balance.QUERY_LIMIT):
		var body: Object = hit.collider
		if body is Node and body.is_in_group("movers"):
			body.tumble(direction)
		elif body is RigidBody3D and not body.freeze:
			body.sleeping = false
			body.linear_velocity = Vector3(direction.x * Balance.YANK_SPEED, body.linear_velocity.y, direction.z * Balance.YANK_SPEED)
	_jerk()


func _jerk() -> void:
	# The rug jerks forward, then settles back where it lay.
	yanking = true
	var rest: Vector3 = rug_mesh.position
	var tween := create_tween()
	tween.tween_property(rug_mesh, "position", rest + Vector3.FORWARD * Balance.YANK_SHIFT, Balance.YANK_TIME)
	tween.tween_property(rug_mesh, "position", rest, Balance.YANK_RETURN_TIME)
	tween.tween_callback(func() -> void: yanking = false)
