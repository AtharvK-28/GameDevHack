# Moves a player and owns one grab at a time; loot applies the carry spring.
extends CharacterBody3D

# --- Player state ---
var slot: int = 0
var facing := Vector3.FORWARD
var held_item: Loot
var grab_released: bool = true
var name_label := Label3D.new()
var hold_point: Marker3D
var facing_marker := MeshInstance3D.new()

# --- Setup ---
func _ready() -> void:
	add_to_group("movers")
	collision_layer = Balance.MOVER_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	hold_point = $HoldPoint
	_build_capsule()
	_build_facing_marker()
	name_label.position.y = Balance.LABEL_HEIGHT
	name_label.font_size = Balance.LABEL_FONT_SIZE
	name_label.pixel_size = Balance.LABEL_PIXEL_SIZE
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(name_label)
	_update_hold_point()


# --- Movement and controls ---
func _physics_process(delta: float) -> void:
	var player_input: InputRouter.PlayerInput = InputRouter.for_slot(slot)
	if not is_instance_valid(held_item) or held_item.finished:
		held_item = null
	var direction: Vector2 = player_input.direction
	if player_input.buttons.get("brace", false):
		direction = Vector2.ZERO
	if not direction.is_zero_approx():
		# Swing the facing round instead of snapping, so a carried item is never yanked across.
		var current_angle: float = atan2(facing.x, facing.z)
		var target_angle: float = atan2(direction.x, direction.y)
		var angle: float = rotate_toward(current_angle, target_angle, Balance.TURN_SPEED * delta)
		facing = Vector3(sin(angle), 0.0, cos(angle))
	_update_hold_point()
	_handle_carry_input(player_input)
	var speed: float = movement_speed()
	velocity.x = direction.x * speed
	velocity.z = direction.y * speed
	if not is_on_floor():
		velocity.y -= Balance.GRAVITY * delta
	move_and_slide()
	var edge: float = Balance.FLOOR_SIZE / 2.0 - Balance.CAPSULE_RADIUS
	position.x = clampf(position.x, -edge, edge)
	position.z = clampf(position.z, -edge, edge)
	var player := Net.player_for_slot(slot)
	name_label.text = "%d · %s" % [slot + 1, player.get("name", "Unclaimed")]


func movement_speed() -> float:
	if is_instance_valid(held_item) and not held_item.finished:
		return Balance.MOVER_SPEED * Balance.CARRY_SPEEDS[held_item.loot_kind]
	return Balance.MOVER_SPEED


func _handle_carry_input(input: InputRouter.PlayerInput) -> void:
	var grabbing: bool = input.buttons.get("grab", false)
	if not grabbing:
		grab_released = true
		if is_instance_valid(held_item):
			held_item.release()
			held_item = null
		return
	if input.pressed.get("throw", false) and is_instance_valid(held_item):
		if held_item.loot_kind == 0:
			held_item.release(facing * Balance.THROW_SPEED + Vector3.UP * Balance.THROW_LIFT)
			held_item = null
			grab_released = false # Holding GRAB must not catch the item just thrown.
		return
	if not is_instance_valid(held_item) and grab_released:
		var candidate := _nearest_loot()
		if candidate != null and candidate.try_grab(self, hold_point, slot):
			held_item = candidate


# --- Grab selection ---
func _nearest_loot() -> Loot:
	var nearest: Loot
	var nearest_distance: float = Balance.GRAB_RANGE
	for item: Loot in get_tree().get_nodes_in_group("loot"):
		if item.finished or is_instance_valid(item.holder):
			continue
		var offset: Vector3 = item.global_position - global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance: float = offset.length()
		if distance > nearest_distance or horizontal.normalized().dot(facing) < cos(deg_to_rad(Balance.GRAB_HALF_ANGLE)):
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position, item.global_position, Balance.WORLD_LAYER)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		nearest = item
		nearest_distance = distance
	return nearest


func _update_hold_point() -> void:
	# The hold point marks the bottom of the carried item, a fixed gap above the floor.
	var clearance: float = Balance.CARRY_CLEARANCE - Balance.CAPSULE_HEIGHT / 2.0
	hold_point.position = facing * Balance.HOLD_DISTANCE + Vector3.UP * clearance
	facing_marker.position = facing * Balance.FACING_MARKER_DISTANCE


# --- Visual helpers ---
func _build_capsule() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = Balance.CAPSULE_RADIUS
	shape.height = Balance.CAPSULE_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var capsule := CapsuleMesh.new()
	capsule.radius = Balance.CAPSULE_RADIUS
	capsule.height = Balance.CAPSULE_HEIGHT
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(Balance.PLAYER_COLOURS[slot])
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.material_override = material
	add_child(mesh)



func _build_facing_marker() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Balance.FACING_MARKER_SIZE
	facing_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("183a38")
	facing_marker.material_override = material
	add_child(facing_marker)
