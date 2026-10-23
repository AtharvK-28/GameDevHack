# Spring-carried loot. Distinct physical impacts reduce its current rupee value.
class_name Loot
extends RigidBody3D

signal damaged(amount: int, remaining: int)
signal shattered(last_carrier_slot: int)

# --- Item settings ---
@export_enum("Vase", "TV", "Clock") var loot_kind: int = 0

# --- Carry and damage state ---
var item_name: String
var value: int
var initial_value: int
var fragility: int
var item_size: Vector3
var holder: CharacterBody3D
var hold_target: Node3D
var last_carrier_slot: int = -1
var finished: bool = false
var previous_velocity := Vector3.ZERO
var previous_spin := Vector3.ZERO
var previous_contacts: Dictionary = {}
var price_label := Label3D.new()

# --- Setup ---
func _ready() -> void:
	add_to_group("loot")
	item_name = Balance.LOOT_NAMES[loot_kind]
	initial_value = Balance.LOOT_VALUES[loot_kind]
	value = initial_value
	fragility = Balance.LOOT_FRAGILITIES[loot_kind]
	item_size = Balance.LOOT_SIZES[loot_kind]
	mass = Balance.LOOT_MASSES[loot_kind]
	collision_layer = Balance.LOOT_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	continuous_cd = loot_kind == 0
	max_contacts_reported = Balance.LOOT_CONTACT_LIMIT
	linear_damp = Balance.LOOT_LINEAR_DAMP
	angular_damp = Balance.LOOT_ANGULAR_DAMP
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = Balance.LOOT_FRICTION
	physics_material_override.bounce = Balance.LOOT_BOUNCE
	_build_shape()
	_build_price_label()


# --- Physics and feedback ---
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if finished:
		return
	_check_contacts(state)
	if is_instance_valid(holder) and is_instance_valid(hold_target):
		_apply_carry_spring(state)
	state.linear_velocity = state.linear_velocity.limit_length(Balance.LOOT_MAX_SPEED)
	state.angular_velocity = state.angular_velocity.limit_length(Balance.LOOT_MAX_SPIN)
	previous_velocity = state.linear_velocity
	previous_spin = state.angular_velocity


func _process(_delta: float) -> void:
	price_label.global_position = global_position + Vector3.UP * (item_size.y / 2.0 + Balance.PRICE_LABEL_HEIGHT)
	price_label.text = rupees(value)
	price_label.modulate = Color.WHITE.lerp(Balance.DAMAGE_COLOUR, 1.0 - float(value) / initial_value)


func _apply_carry_spring(state: PhysicsDirectBodyState3D) -> void:
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

	# Turn the item back upright, so it wobbles while carried instead of tumbling over.
	var tilt_axis: Vector3 = state.transform.basis.y.normalized().cross(Vector3.UP)
	var angular_acceleration: Vector3 = tilt_axis * Balance.CARRY_UPRIGHT_STIFFNESS
	angular_acceleration -= state.angular_velocity * Balance.CARRY_UPRIGHT_DAMPING
	state.apply_torque(state.inverse_inertia_tensor.inverse() * angular_acceleration)


func carry_target() -> Vector3:
	# Where the item's centre settles while carried.
	return hold_target.global_position + Vector3.UP * item_size.y / 2.0


func _check_contacts(state: PhysicsDirectBodyState3D) -> void:
	var contacts: Dictionary = {}
	for index: int in range(state.get_contact_count()):
		var collider_id: int = state.get_contact_collider_id(index)
		var normal: Vector3 = state.get_contact_local_normal(index)
		var offset: Vector3 = state.get_contact_local_position(index) - state.transform.origin
		var incoming: Vector3 = previous_velocity + previous_spin.cross(offset)
		var other_velocity: Vector3 = state.get_contact_collider_velocity_at_position(index)
		var closing_speed: float = maxf(0.0, -(incoming - other_velocity).dot(normal))
		contacts[collider_id] = maxf(contacts.get(collider_id, 0.0), closing_speed)
	for collider_id: int in contacts:
		if not previous_contacts.has(collider_id):
			apply_impact.call_deferred(contacts[collider_id])
	previous_contacts = contacts


# --- Carrying and item lifecycle ---
func try_grab(mover: CharacterBody3D, target: Node3D, slot: int) -> bool:
	if finished or is_instance_valid(holder):
		return false
	holder = mover
	hold_target = target
	last_carrier_slot = slot
	add_collision_exception_with(mover)
	can_sleep = false
	sleeping = false
	print("Player %d grabbed %s" % [slot + 1, item_name])
	return true


func release(throw_velocity: Vector3 = Vector3.ZERO) -> void:
	if finished or not is_instance_valid(holder):
		return
	_detach()
	for zone: Node in get_tree().get_nodes_in_group("truck_zones"):
		if zone.try_bank(self):
			return
	if not throw_velocity.is_zero_approx():
		apply_central_impulse(throw_velocity * mass)
	print("Released %s at ₹%d" % [item_name, value])


func apply_impact(speed: float) -> void:
	if finished or speed <= Balance.DAMAGE_SPEED_THRESHOLD:
		return
	var loss: int = mini(value, ceili(speed * fragility * Balance.DAMAGE_MULTIPLIER * value))
	value -= loss
	damaged.emit(loss, value)
	show_popup("−" + rupees(loss), Balance.DAMAGE_COLOUR)
	print("%s impact %.2f m/s: -₹%d, remaining ₹%d" % [item_name, speed, loss, value])
	if is_instance_valid(holder):
		var player := Net.player_for_slot(last_carrier_slot)
		if not player.is_empty():
			Net.send_to_player(player, {"type": "buzz", "ms": Balance.DAMAGE_BUZZ_MS})
	if value == 0:
		shattered.emit(last_carrier_slot)
		retire("SHATTERED", Balance.DAMAGE_COLOUR)


func retire(message: String, colour: Color) -> void:
	if finished:
		return
	finished = true
	_detach()
	show_popup(message, colour)
	remove_from_group("loot")
	hide()
	queue_free()


func _detach() -> void:
	if is_instance_valid(holder):
		remove_collision_exception_with(holder)
	holder = null
	hold_target = null
	can_sleep = true


# --- Visual helpers ---
func show_popup(message: String, colour: Color) -> void:
	var popup := Label3D.new()
	popup.text = message
	popup.modulate = colour
	popup.font_size = Balance.PRICE_FONT_SIZE
	popup.pixel_size = Balance.PRICE_PIXEL_SIZE
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	get_parent().add_child(popup)
	popup.global_position = price_label.global_position + Vector3.UP * Balance.VALUE_POPUP_START
	var tween := popup.create_tween().set_parallel()
	tween.tween_property(popup, "position:y", popup.position.y + Balance.VALUE_POPUP_RISE, Balance.VALUE_POPUP_LIFETIME)
	tween.tween_property(popup, "modulate:a", 0.0, Balance.VALUE_POPUP_LIFETIME)
	tween.chain().tween_callback(popup.queue_free)


static func rupees(amount: int) -> String:
	# Indian digit grouping, as in the spec: ₹1,200 and ₹1,20,000.
	var digits: String = str(amount)
	var grouped: String = digits.right(3)
	digits = digits.left(-3)
	while not digits.is_empty():
		grouped = digits.right(2) + "," + grouped
		digits = digits.left(-2)
	return "₹" + grouped


func _build_shape() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = item_size
	collision.shape = shape
	add_child(collision)
	var mesh := MeshInstance3D.new()
	if loot_kind == 0:
		var vase := CylinderMesh.new()
		vase.height = item_size.y
		vase.top_radius = item_size.x / 4.0
		vase.bottom_radius = item_size.x / 2.0
		mesh.mesh = vase
	else:
		var box := BoxMesh.new()
		box.size = item_size
		mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.LOOT_COLOURS[loot_kind]
	mesh.material_override = material
	add_child(mesh)


func _build_price_label() -> void:
	price_label.font_size = Balance.PRICE_FONT_SIZE
	price_label.pixel_size = Balance.PRICE_PIXEL_SIZE
	price_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	price_label.no_depth_test = true # Walls never hide a price.
	add_child(price_label)
	price_label.top_level = true
