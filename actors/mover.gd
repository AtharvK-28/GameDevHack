# Moves a player and owns one grab at a time; the carried item applies its own spring.
# On a two-person handle the mover follows its handle and its stick steers the item instead.
# A tumble drops whatever is held and lies the mover down for TUMBLE_DURATION seconds. On slime the mover keeps
# its momentum. While its player is the ghost, the mover is out of play.
extends CharacterBody3D

signal tumbled(slot: int)

# --- Player state ---
var slot: int = 0
var facing := Vector3.FORWARD
var stick := Vector2.ZERO # This frame's movement input; zero while bracing or down.
var bracing: bool = false
var in_play: bool = true
var held_item: Carryable
var grab_released: bool = true
var tumble_time_left: float = 0.0
var pose_tween: Tween
var name_label := Label3D.new()
var hold_point: Marker3D
var body_pivot := Node3D.new()
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
	if is_instance_valid(held_item) and (held_item.finished or not held_item.is_held_by(self)):
		held_item = null

	stick = player_input.direction
	bracing = player_input.buttons.get("brace", false)
	if bracing or is_tumbling():
		stick = Vector2.ZERO
	if is_tumbling():
		tumble_time_left -= delta
		if not player_input.buttons.get("grab", false):
			grab_released = true # Letting go while down allows a fresh grab after standing.
		if not is_tumbling():
			_stand_up()
	else:
		_handle_carry_input(player_input)

	if _on_team_handle():
		_follow_handle()
	else:
		_turn_toward_stick(delta)
		_walk(delta)
	_update_hold_point()
	if not is_on_floor():
		velocity.y -= Balance.GRAVITY * delta
	move_and_slide()

	var edge: float = Balance.FLOOR_SIZE / 2.0 - Balance.CAPSULE_RADIUS
	position.x = clampf(position.x, -edge, edge)
	position.z = clampf(position.z, -edge, edge)
	var player := Net.player_for_slot(slot)
	name_label.text = "%d · %s" % [slot + 1, player.get("name", "Unclaimed")]


func movement_speed() -> float:
	if is_instance_valid(held_item):
		return Balance.MOVER_SPEED * Balance.CARRY_SPEEDS[held_item.weight_class] * held_item.carry_speed_ratio()
	return Balance.MOVER_SPEED


func carry_stick() -> Vector3:
	# The stick as a world direction; two-person items read this to steer.
	return Vector3(stick.x, 0.0, stick.y)


func _walk(delta: float) -> void:
	var target: Vector3 = carry_stick() * movement_speed()
	if on_slime():
		# Slime keeps the mover's momentum: the stick only nudges the slide.
		var grip: float = 1.0 - exp(-Balance.SLIME_GRIP * delta)
		velocity.x = lerpf(velocity.x, target.x, grip)
		velocity.z = lerpf(velocity.z, target.z, grip)
	else:
		velocity.x = target.x
		velocity.z = target.z


func on_slime() -> bool:
	for patch: Node3D in get_tree().get_nodes_in_group("slime"):
		var offset: Vector3 = patch.global_position - global_position
		if Vector2(offset.x, offset.z).length() < Balance.SLIME_PATCH_RADIUS:
			return true
	return false


# --- House Shake queries ---
func is_bracing() -> bool:
	return bracing


func is_moving() -> bool:
	# Pushing the stick, or sliding: on slime, or pulled along by a two-person handle.
	return not stick.is_zero_approx() or Vector2(velocity.x, velocity.z).length() > Balance.SHAKE_MOVING_SPEED


# --- The ghost's slot ---
func set_in_play(active: bool) -> void:
	# While this player is the ghost, the mover leaves the board: no collisions, input, hauntings or tumbles.
	if not active:
		_let_go()
		tumble_time_left = 0.0
		if pose_tween != null:
			pose_tween.kill()
		body_pivot.quaternion = Quaternion.IDENTITY
		facing_marker.show()
		remove_from_group("movers")
	else:
		add_to_group("movers")
	in_play = active
	visible = active
	velocity = Vector3.ZERO
	stick = Vector2.ZERO
	bracing = false
	collision_layer = Balance.MOVER_LAYER if active else 0
	collision_mask = (Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER) if active else 0
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func reset_for_round(location: Vector3, playing: bool) -> void:
	# Hands empty, standing up, facing the house, at a fresh spot; out of play if this player is not a mover.
	set_in_play(false)
	position = location
	facing = Vector3.FORWARD
	grab_released = true
	_update_hold_point()
	if playing:
		set_in_play(true)


func _turn_toward_stick(delta: float) -> void:
	if stick.is_zero_approx():
		return
	# Swing the facing round instead of snapping, so a carried item is never yanked across.
	var current_angle: float = atan2(facing.x, facing.z)
	var target_angle: float = atan2(stick.x, stick.y)
	var angle: float = rotate_toward(current_angle, target_angle, Balance.TURN_SPEED * delta)
	facing = Vector3(sin(angle), 0.0, cos(angle))


func _handle_carry_input(input: InputRouter.PlayerInput) -> void:
	var grabbing: bool = input.buttons.get("grab", false)
	if not grabbing:
		grab_released = true
		_let_go()
		return
	if input.pressed.get("throw", false) and is_instance_valid(held_item):
		if held_item.can_throw():
			held_item.release(facing * Balance.THROW_SPEED + Vector3.UP * Balance.THROW_LIFT, self)
			held_item = null
			grab_released = false # Holding GRAB must not catch the item just thrown.
		return
	if not is_instance_valid(held_item) and grab_released:
		var candidate := _nearest_carryable()
		if candidate != null and candidate.try_grab(self, hold_point, slot):
			held_item = candidate


func _let_go() -> void:
	if is_instance_valid(held_item):
		held_item.release(Vector3.ZERO, self)
	held_item = null


# --- Two-person handles ---
func _on_team_handle() -> bool:
	return is_instance_valid(held_item) and held_item.weight_class == Balance.TWO_PERSON


func _follow_handle() -> void:
	# Keep to our spot at the handle; let go if the item drags us too far off it.
	var gap: Vector3 = held_item.stand_point_for(self) - global_position
	gap.y = 0.0
	if gap.length() > Balance.TEAM_LEASH:
		print("Player %d lost their grip on the %s" % [slot + 1, held_item.item_name])
		_let_go()
		grab_released = false
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var follow: Vector3 = (gap * Balance.TEAM_FOLLOW_GAIN).limit_length(Balance.MOVER_SPEED)
	velocity.x = follow.x
	velocity.z = follow.z
	var to_item: Vector3 = held_item.global_position - global_position
	to_item.y = 0.0
	if to_item.length() > 0.01:
		facing = to_item.normalized()


# --- Tumbling ---
func is_tumbling() -> bool:
	return tumble_time_left > 0.0


func tumble(push: Vector3 = Vector3.ZERO) -> void:
	# Fall in the push direction (or forward), drop whatever we hold, and lie still for a moment.
	if is_tumbling():
		return
	_let_go()
	grab_released = false # Getting up must not instantly re-grab.
	tumble_time_left = Balance.TUMBLE_DURATION
	velocity = Vector3.ZERO
	var fall_direction := Vector3(push.x, 0.0, push.z)
	fall_direction = fall_direction.normalized() if fall_direction.length() > 0.01 else facing
	pose_tween = create_tween()
	pose_tween.tween_property(body_pivot, "quaternion", Quaternion(Vector3.UP.cross(fall_direction).normalized(), PI / 2.0), Balance.TUMBLE_FALL_TIME)
	facing_marker.hide()
	tumbled.emit(slot)
	var player := Net.player_for_slot(slot)
	if not player.is_empty():
		Net.send_to_player(player, {"type": "buzz", "ms": Balance.TUMBLE_BUZZ_MS})
	print("Player %d tumbled" % (slot + 1))


func _stand_up() -> void:
	pose_tween = create_tween()
	pose_tween.tween_property(body_pivot, "quaternion", Quaternion.IDENTITY, Balance.TUMBLE_FALL_TIME)
	facing_marker.show()


# --- Grab selection ---
func _nearest_carryable() -> Carryable:
	var nearest: Carryable
	var nearest_distance: float = Balance.GRAB_RANGE
	for item: Carryable in get_tree().get_nodes_in_group("carryables"):
		var point: Vector3 = item.grab_point_for(self)
		if point == Vector3.INF:
			continue
		var offset: Vector3 = point - global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance: float = offset.length()
		if distance > nearest_distance or horizontal.normalized().dot(facing) < cos(deg_to_rad(Balance.GRAB_HALF_ANGLE)):
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position, point, Balance.WORLD_LAYER)
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

	# The visible capsule hangs from a pivot one radius above the feet, so a tumble lays it on the floor.
	body_pivot.position.y = Balance.CAPSULE_RADIUS - Balance.CAPSULE_HEIGHT / 2.0
	add_child(body_pivot)
	var capsule := CapsuleMesh.new()
	capsule.radius = Balance.CAPSULE_RADIUS
	capsule.height = Balance.CAPSULE_HEIGHT
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(Balance.PLAYER_COLOURS[slot])
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.material_override = material
	mesh.position.y = Balance.CAPSULE_HEIGHT / 2.0 - Balance.CAPSULE_RADIUS
	body_pivot.add_child(mesh)


func _build_facing_marker() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Balance.FACING_MARKER_SIZE
	facing_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("183a38")
	facing_marker.material_override = material
	add_child(facing_marker)
