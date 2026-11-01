# Base for anything a mover can pick up: the spring carry, upright wobble, throws and contact impacts.
# Goofy physics: the item's look (never its collider) jiggles on impacts, grabs and throws, and light items bounce.
# Subclasses set item_name, item_size and weight_class before calling super() in _ready(), set visual to the node
# that jiggles, and call update_jiggle() and update_reach_outline() every frame.
# The reach shell (decision 149) tells movers what they can pick up: a faint rim on any grabbable with a player
# nearby, and a bright pulsing rim in the player's own colour on the one item their GRAB would take.
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

# --- Jiggle state ---
var visual: Node3D
var visual_scale := Vector3.ONE
var jiggle_amount: float = 0.0 # Fraction of size; positive is shorter and wider.
var jiggle_velocity: float = 0.0

# --- Reach shell state (decision 149) ---
const SHELL_NAME := "ReachShell"
var reach_outline := StandardMaterial3D.new()
var outline_meshes: Array[MeshInstance3D] = [] # Collected from visual, so every subclass gets the shell for free.
var reach_slot: int = -1 # The slot whose GRAB would take this item, or -1 for nobody.
var reach_time: float = 0.0 # Drives the target shell's pulse.
var shell_meshes: Array[MeshInstance3D] = [] # The shell itself, one per visible mesh.

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
	physics_material_override.bounce = Balance.LIGHT_LOOT_BOUNCE if weight_class == Balance.LIGHT else Balance.LOOT_BOUNCE
	_build_reach_outline()


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
		if speed > Balance.JIGGLE_MIN_SPEED:
			jiggle.call_deferred(Balance.JIGGLE_MAX * minf(speed / Balance.JIGGLE_FULL_SPEED, 1.0))
		_on_impact.call_deferred(speed, thrown) # Whether it was thrown, before landing slows it and clears that.
	previous_contacts = contacts


func _on_contact(_normal: Vector3) -> void:
	pass # Loot uses this to notice floor contact while dragging.


func _on_impact(_speed: float, _was_thrown: bool = false) -> void:
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
	jiggle(Balance.JIGGLE_GRAB)
	print("Player %d grabbed %s" % [slot + 1, item_name])
	return true


func release(throw_velocity: Vector3 = Vector3.ZERO, _by: CharacterBody3D = null) -> void:
	if finished or not is_held():
		return
	_detach()
	# Only putting an item down can deliver it; THROW must still launch it inside a zone.
	if throw_velocity.is_zero_approx() and _on_released():
		return
	if not throw_velocity.is_zero_approx():
		thrown = true
		apply_central_impulse(throw_velocity * mass)
		jiggle(Balance.JIGGLE_THROW)
	print("Released %s" % item_name)


func release_for_rescue(_by: CharacterBody3D) -> void:
	# An involuntary water drop must never count as a delivery.
	_detach()


func _on_released() -> bool:
	return false # Loot banks here; returns true when the item has left play.


func _detach() -> void:
	if is_instance_valid(holder):
		remove_collision_exception_with(holder)
	holder = null
	hold_target = null
	can_sleep = true


# --- Jiggle (goofy physics) ---
func set_visual(node: Node3D) -> void:
	visual = node
	visual_scale = node.scale
	outline_meshes.clear()
	if node is MeshInstance3D:
		outline_meshes.append(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		outline_meshes.append(mesh)
	_build_shells()


# --- Reach shell (decision 149) ---
# The shell is its own set of meshes, one per visible mesh, grown slightly and drawn inside out so only its far
# side shows as a rim. It cannot use material_overlay: a Possessable child already dresses these same meshes with
# the ghost's outline and glow, and the two would overwrite each other every frame.
func mark_in_reach(slot: int) -> void:
	# Called by the mover whose GRAB would take this item; -1 clears it.
	reach_slot = slot


func can_be_grabbed() -> bool:
	return not finished and not haunted and not is_held()


func update_reach_outline(delta: float) -> void:
	# Subclasses call this every frame.
	reach_time += delta
	var target: bool = reach_slot >= 0 and can_be_grabbed()
	var shown: bool = target or (can_be_grabbed() and _player_nearby())
	for shell: MeshInstance3D in shell_meshes:
		shell.visible = shown
	if not shown:
		return

	# Faint and neutral means "this is loot"; bright and in your colour means "your GRAB takes this one". A
	# two-person item uses one shared colour instead, so "it takes two of you" reads without reading anything.
	var colour: Color = Balance.REACH_IDLE_COLOUR
	var alpha: float = Balance.REACH_IDLE_ALPHA
	if target:
		colour = Balance.REACH_TEAM_COLOUR if weight_class == Balance.TWO_PERSON else Color(Balance.PLAYER_COLOURS[reach_slot % Balance.PLAYER_COLOURS.size()])
		var pulse: float = 0.5 + 0.5 * sin(TAU * Balance.REACH_PULSE_RATE * reach_time)
		alpha = Balance.REACH_TARGET_ALPHA * (1.0 - Balance.REACH_PULSE_DEPTH * pulse)
	reach_outline.albedo_color = Color(colour, alpha)


func _build_reach_outline() -> void:
	reach_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reach_outline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reach_outline.albedo_color = Color(Balance.REACH_IDLE_COLOUR, Balance.REACH_IDLE_ALPHA)
	reach_outline.grow = true
	reach_outline.grow_amount = Balance.REACH_OUTLINE_GROW
	reach_outline.cull_mode = BaseMaterial3D.CULL_FRONT # Only the shell's far side draws, so it reads as a rim.


func _build_shells() -> void:
	# One shell per visible mesh, parented to it so it follows every jiggle and spin for free. Hidden until a
	# player is near, so a tidy room costs nothing.
	for mesh: MeshInstance3D in outline_meshes:
		if mesh.mesh == null:
			continue
		var shell := MeshInstance3D.new()
		shell.name = SHELL_NAME # Possessable skips these when it collects the prop's own meshes.
		shell.mesh = mesh.mesh
		shell.material_override = reach_outline
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.visible = false
		mesh.add_child(shell)
		shell_meshes.append(shell)


func _player_nearby() -> bool:
	# The same reach the price tags use, so a tidy room only lights up the loot you have walked over to.
	for player: Node3D in get_tree().get_nodes_in_group("movers"):
		if player.is_visible_in_tree() and player.global_position.distance_to(global_position) <= Balance.PRICE_SHOW_DISTANCE:
			return true
	return false


func jiggle(amount: float) -> void:
	# Kick the look into a squash (positive) or stretch (negative); update_jiggle springs it back.
	jiggle_amount = amount * Balance.GOOFINESS
	jiggle_velocity = 0.0


func update_jiggle(delta: float) -> void:
	if visual == null:
		return
	jiggle_velocity += (-jiggle_amount * Balance.JIGGLE_STIFFNESS - jiggle_velocity * Balance.JIGGLE_DAMPING) * delta
	jiggle_amount += jiggle_velocity * delta
	visual.scale = visual_scale * Vector3(1.0 + jiggle_amount / 2.0, 1.0 - jiggle_amount, 1.0 + jiggle_amount / 2.0)
