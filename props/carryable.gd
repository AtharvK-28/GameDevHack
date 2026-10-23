# Base for anything a mover can pick up: the spring carry, upright wobble, throws and contact impacts.
# Subclasses set item_name, item_size and weight_class before calling super() in _ready().
class_name Carryable
extends RigidBody3D

# --- Carry state ---
var item_name: String = ""
var item_size := Vector3.ONE
var weight_class: int = Balance.LIGHT
var holder: CharacterBody3D
var hold_target: Node3D
var last_carrier_slot: int = -1
var finished: bool = false
var thrown: bool = false
var haunted: bool = false # Set by a Possessable while the ghost is inside; a haunted item cannot be grabbed.
var previous_velocity := Vector3.ZERO
var previous_spin := Vector3.ZERO
var previous_contacts: Dictionary = {}

# --- Setup ---
func _ready() -> void:
	add_to_group("carryables")
	mass = Balance.WEIGHT_MASSES[weight_class]
	collision_layer = Balance.LOOT_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	continuous_cd = weight_class == Balance.LIGHT
	max_contacts_reported = Balance.LOOT_CONTACT_LIMIT
	linear_damp = Balance.LOOT_LINEAR_DAMP
	angular_damp = Balance.LOOT_ANGULAR_DAMP
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = Balance.LOOT_FRICTION
	physics_material_override.bounce = Balance.LOOT_BOUNCE


# --- Physics ---
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if finished:
		return
	_check_contacts(state)
	if is_held():
		_apply_carry(state)
	state.linear_velocity = state.linear_velocity.limit_length(Balance.LOOT_MAX_SPEED)
	state.angular_velocity = state.angular_velocity.limit_length(Balance.LOOT_MAX_SPIN)
	if thrown and state.linear_velocity.length() < Balance.TUMBLE_HIT_SPEED:
		thrown = false
	previous_velocity = state.linear_velocity
	previous_spin = state.angular_velocity


func _apply_carry(state: PhysicsDirectBodyState3D) -> void:
	var local_grip := Vector3.UP * item_size.y * Balance.GRIP_HEIGHT_RATIO
	var grip_offset: Vector3 = state.transform.basis * local_grip
	var grip_position: Vector3 = state.transform.origin + grip_offset
	var target: Vector3 = carry_target() + local_grip
	var grip_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(grip_offset)
	var stretch: Vector3 = (target - grip_position).limit_length(Balance.CARRY_MAX_STRETCH)
	var acceleration: Vector3 = stretch * Balance.CARRY_STIFFNESS
	acceleration -= (grip_velocity - holder.velocity) * Balance.CARRY_DAMPING
	state.apply_force((acceleration * mass).limit_length(Balance.CARRY_MAX_FORCE), grip_offset)
	# Support the weight at the centre, leaving the spring free to swing the item.
	state.apply_central_force((-state.total_gravity * mass).limit_length(Balance.CARRY_MAX_FORCE))
	_apply_upright(state)


func _apply_upright(state: PhysicsDirectBodyState3D) -> void:
	# Turn the item back upright, so it wobbles while carried instead of tumbling over.
	var tilt_axis: Vector3 = state.transform.basis.y.normalized().cross(Vector3.UP)
	var angular_acceleration: Vector3 = tilt_axis * Balance.CARRY_UPRIGHT_STIFFNESS
	angular_acceleration -= state.angular_velocity * Balance.CARRY_UPRIGHT_DAMPING
	state.apply_torque(state.inverse_inertia_tensor.inverse() * angular_acceleration)


func carry_target() -> Vector3:
	# Where the item's centre settles while carried.
	return hold_target.global_position + Vector3.UP * item_size.y / 2.0


func _check_contacts(state: PhysicsDirectBodyState3D) -> void:
	# Each collider counts once when contact begins, at its strongest closing speed.
	var contacts: Dictionary = {}
	var colliders: Dictionary = {}
	for index: int in range(state.get_contact_count()):
		var collider_id: int = state.get_contact_collider_id(index)
		var normal: Vector3 = state.get_contact_local_normal(index)
		var offset: Vector3 = state.get_contact_local_position(index) - state.transform.origin
		var incoming: Vector3 = previous_velocity + previous_spin.cross(offset)
		var other_velocity: Vector3 = state.get_contact_collider_velocity_at_position(index)
		var collider: Object = state.get_contact_collider_object(index)
		if collider is CharacterBody3D:
			# A mover's reported velocity includes being shoved out of the item; use its own walking velocity.
			other_velocity = collider.velocity
		var closing_speed: float = maxf(0.0, -(incoming - other_velocity).dot(normal))
		contacts[collider_id] = maxf(contacts.get(collider_id, 0.0), closing_speed)
		colliders[collider_id] = collider
		_on_contact(normal)
	for collider_id: int in contacts:
		if previous_contacts.has(collider_id):
			continue
		var speed: float = contacts[collider_id]
		var collider: Object = colliders[collider_id]
		if thrown and speed > Balance.TUMBLE_HIT_SPEED and collider is Node and collider.is_in_group("movers"):
			collider.tumble.call_deferred(previous_velocity)
		_on_impact.call_deferred(speed)
	previous_contacts = contacts


func _on_contact(_normal: Vector3) -> void:
	pass # Loot uses this to notice floor contact while dragging.


func _on_impact(_speed: float) -> void:
	pass # Loot turns impacts into damage.


# --- Grabbing and releasing ---
func carry_speed_ratio() -> float:
	return 1.0


func is_held() -> bool:
	return is_instance_valid(holder) and is_instance_valid(hold_target)


func is_held_by(mover: CharacterBody3D) -> bool:
	return holder == mover


func can_throw() -> bool:
	return weight_class == Balance.LIGHT


func grab_point_for(_mover: CharacterBody3D) -> Vector3:
	# Where a mover reaches to grab this item; Vector3.INF when nothing is free.
	return Vector3.INF if finished or haunted or is_held() else global_position


func try_grab(mover: CharacterBody3D, target: Node3D, slot: int) -> bool:
	if finished or haunted or is_held():
		return false
	holder = mover
	hold_target = target
	last_carrier_slot = slot
	thrown = false
	add_collision_exception_with(mover)
	can_sleep = false
	sleeping = false
	print("Player %d grabbed %s" % [slot + 1, item_name])
	return true


func release(throw_velocity: Vector3 = Vector3.ZERO, _by: CharacterBody3D = null) -> void:
	if finished or not is_held():
		return
	_detach()
	if _on_released():
		return
	if not throw_velocity.is_zero_approx():
		thrown = true
		apply_central_impulse(throw_velocity * mass)
	print("Released %s" % item_name)


func _on_released() -> bool:
	return false # Loot banks here; returns true when the item has left play.


func _detach() -> void:
	if is_instance_valid(holder):
		remove_collision_exception_with(holder)
	holder = null
	hold_target = null
	can_sleep = true
