# Component that makes its parent prop hauntable. The ghost possesses it, steers it with the stick and triggers
# its ACTION; exorcise() kicks the ghost out with a stun (kept for map tasks that handicap the ghost). Sliders and hoppers are driven
# here. Doors, droppers and rugs provide can_act() and act() themselves.
class_name Possessable
extends Node3D

enum Kind { SLIDER, DOOR, DROPPER, HOPPER, RUG }

# --- Settings ---
@export var kind: Kind = Kind.SLIDER

# --- Possession state ---
var prop: Node3D
var ghost: Node3D # The ghost inside, or null.
var launched: bool = false # Set by SHOVE or DROP; hits on movers count until the prop slows below the tumble speed.
var launch_was_fast: bool = false
var previous_velocity := Vector3.ZERO # The prop's velocity going into the latest physics step.
var last_direction := Vector3.BACK # Where SHOVE goes when the stick is centred.
var drive_pause: float = 0.0
var hop_wait: float = 0.0
var highlighted: bool = false
var glow_time: float = 0.0
var meshes: Array[MeshInstance3D] = []
var overlay: Material
var outline := StandardMaterial3D.new()
var glow := StandardMaterial3D.new()
var drips := CPUParticles3D.new()

# --- Setup ---
func _ready() -> void:
	add_to_group("possessables")
	prop = get_parent()
	# The prop builds its meshes in its own _ready, which runs after this one.
	if prop.is_node_ready():
		_attach()
	else:
		prop.ready.connect(_attach, CONNECT_ONE_SHOT)


func _attach() -> void:
	# Outline the prop's own meshes, and sit at their centre so the flashlight aims at the middle of the prop.
	var bounds := AABB()
	for child: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		if not child.top_level and child.mesh != null:
			var mesh_bounds: AABB = prop.global_transform.affine_inverse() * child.global_transform * child.get_aabb()
			bounds = mesh_bounds if meshes.is_empty() else bounds.merge(mesh_bounds)
			meshes.append(child)
	position = bounds.get_center()
	if prop is RigidBody3D:
		prop.contact_monitor = true
		prop.max_contacts_reported = maxi(prop.max_contacts_reported, Balance.LOOT_CONTACT_LIMIT)
		prop.body_entered.connect(_on_body_entered)
	if prop.has_signal("dropped"):
		prop.dropped.connect(_on_prop_dropped)
	if prop.has_signal("landed"):
		prop.landed.connect(_on_prop_landed)
	_build_materials()
	_build_drips(bounds.size)
	_update_look()


# --- Physics ---
func _physics_process(_delta: float) -> void:
	if prop is RigidBody3D:
		var speed: float = prop.linear_velocity.length()
		if launched and (prop.sleeping or (launch_was_fast and speed < Balance.TUMBLE_HIT_SPEED)):
			launched = false
		launch_was_fast = speed >= Balance.TUMBLE_HIT_SPEED
		previous_velocity = prop.linear_velocity
	if is_possessed() and (_gone() or _in_truck()):
		ghost.leave() # No stun: the prop left play or reached the truck.
	_update_look()


func _on_body_entered(other: Node) -> void:
	if not (is_possessed() or launched) or not other.is_in_group("movers"):
		return
	# Only the prop's own speed toward the mover counts, so walking into a slow possessed prop never trips anyone.
	var toward: Vector3 = (other.global_position - prop.global_position).normalized()
	if previous_velocity.dot(toward) > Balance.TUMBLE_HIT_SPEED:
		other.tumble.call_deferred(previous_velocity)


# --- Possession ---
func is_possessed() -> bool:
	return is_instance_valid(ghost)


func exorcise() -> void:
	if is_possessed():
		ghost.exorcised_from(self)


func can_be_possessed() -> bool:
	if is_possessed() or _gone() or _in_truck():
		return false
	if prop.has_method("is_spent") and prop.is_spent():
		return false
	return not (prop is Carryable and prop.is_held())


func possess(by: Node3D) -> void:
	ghost = by
	drive_pause = 0.0
	hop_wait = 0.0
	if prop is Carryable:
		prop.haunted = true
	if prop is RigidBody3D:
		prop.can_sleep = false
		prop.sleeping = false
		if kind == Kind.SLIDER or kind == Kind.HOPPER:
			# Stay upright while the ghost steers; it can still turn.
			prop.axis_lock_angular_x = true
			prop.axis_lock_angular_z = true
	print("Ghost possessed the %s" % prop_name())
	_update_look()


func release() -> void:
	ghost = null
	if is_instance_valid(prop):
		if prop is Carryable:
			prop.haunted = false
		if prop is RigidBody3D:
			prop.can_sleep = true
			prop.axis_lock_angular_x = false
			prop.axis_lock_angular_z = false
		_update_look()


func reach_distance(point: Vector3) -> float:
	# Horizontal distance from a point to the prop's footprint; zero inside it.
	var bounds: AABB = footprint()
	var closest := Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.z, bounds.position.z, bounds.end.z))
	return closest.distance_to(Vector2(point.x, point.z))


func footprint() -> AABB:
	var bounds := AABB(global_position, Vector3.ZERO)
	for index: int in range(meshes.size()):
		var mesh_bounds: AABB = meshes[index].global_transform * meshes[index].get_aabb()
		bounds = mesh_bounds if index == 0 else bounds.merge(mesh_bounds)
	return bounds


func prop_name() -> String:
	return prop.item_name if "item_name" in prop else String(prop.name)


func set_highlighted(value: bool) -> void:
	highlighted = value
	_update_look()


# --- Stick and ACTION ---
func action_label() -> String:
	return Balance.ACTION_LABELS[kind]


func action_cost() -> int:
	return Balance.ACTION_COSTS[kind]


func can_act() -> bool:
	match kind:
		Kind.SLIDER:
			return drive_pause <= 0.0
		Kind.HOPPER:
			return true
	return prop.can_act()


func drive(stick: Vector2, delta: float) -> void:
	var direction := Vector3(stick.x, 0.0, stick.y)
	if not direction.is_zero_approx():
		last_direction = direction.normalized()
	if kind == Kind.SLIDER:
		_slide(direction, delta)
	elif kind == Kind.HOPPER:
		_hop(direction, delta)


func act(stick: Vector2) -> void:
	var direction := Vector3(stick.x, 0.0, stick.y)
	if not direction.is_zero_approx():
		last_direction = direction.normalized()
	print("Ghost used %s on the %s" % [action_label(), prop_name()])
	match kind:
		Kind.SLIDER:
			_shove()
		Kind.HOPPER:
			_stomp()
		_:
			prop.act()


func _slide(direction: Vector3, delta: float) -> void:
	var body := prop as RigidBody3D
	# The ghost holds most of the weight, so the prop glides instead of scraping along.
	body.apply_central_force(-body.get_gravity() * body.mass * Balance.POSSESS_SUPPORT)
	drive_pause = maxf(0.0, drive_pause - delta)
	if drive_pause > 0.0:
		return
	var target: Vector3 = direction * Balance.SLIDER_SPEED * _speed_factor()
	var current := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	var acceleration: Vector3 = ((target - current) * Balance.POSSESS_DRIVE_GAIN).limit_length(Balance.POSSESS_MAX_ACCELERATION)
	body.apply_central_force(acceleration * body.mass)


func _hop(direction: Vector3, delta: float) -> void:
	var body := prop as RigidBody3D
	hop_wait = maxf(0.0, hop_wait - delta)
	if direction.is_zero_approx() or hop_wait > 0.0 or absf(body.linear_velocity.y) > Balance.LANDED_SPEED:
		return
	body.linear_velocity = direction.normalized() * Balance.HOP_SPEED + Vector3.UP * Balance.HOP_LIFT
	previous_velocity = body.linear_velocity
	hop_wait = Balance.HOP_INTERVAL


func _shove() -> void:
	var body := prop as RigidBody3D
	var speed: float = Balance.SHOVE_SPEED * _speed_factor()
	body.linear_velocity = Vector3(last_direction.x * speed, body.linear_velocity.y, last_direction.z * speed)
	previous_velocity = body.linear_velocity # This frame's physics step may already reach a mover.
	launched = true
	drive_pause = Balance.SHOVE_DRIVE_PAUSE


func _stomp() -> void:
	for mover: Node in get_tree().get_nodes_in_group("movers"):
		var offset: Vector3 = mover.global_position - prop.global_position
		offset.y = 0.0
		if offset.length() <= Balance.STOMP_RADIUS:
			mover.tumble(offset)
	_show_shockwave()


func _speed_factor() -> float:
	return Balance.POSSESS_SPEED_FACTORS[prop.weight_class] if "weight_class" in prop else 1.0


func _on_prop_dropped() -> void:
	launched = true
	launch_was_fast = false


func _on_prop_landed() -> void:
	if is_possessed():
		ghost.leave() # A dropped chandelier is spent; the ghost pops out without a stun.
	_update_look()


# --- Rule helpers ---
func _gone() -> bool:
	return not is_instance_valid(prop) or (prop is Carryable and prop.finished)


func _in_truck() -> bool:
	for zone: Node in get_tree().get_nodes_in_group("truck_zones"):
		if zone.contains_point(prop.global_position):
			return true
	return false


# --- Visual helpers ---
func _process(delta: float) -> void:
	if not is_possessed():
		return
	glow_time += delta
	var pulse: float = 0.5 + 0.5 * sin(TAU * Balance.GLOW_PULSE_RATE * glow_time)
	glow.albedo_color.a = lerpf(Balance.GLOW_ALPHA_MIN, Balance.GLOW_ALPHA_MAX, pulse)


func _update_look() -> void:
	# Possessed props glow; props the ghost could take show an outline, brighter on the wisp's target.
	var wanted: Material = null
	if is_possessed():
		wanted = glow
	elif can_be_possessed():
		outline.albedo_color.a = Balance.OUTLINE_TARGET_ALPHA if highlighted else Balance.OUTLINE_IDLE_ALPHA
		wanted = outline
	if wanted != overlay:
		overlay = wanted
		for mesh: MeshInstance3D in meshes:
			mesh.material_overlay = wanted
	if drips.emitting != is_possessed():
		drips.emitting = is_possessed()


func _build_materials() -> void:
	for material: StandardMaterial3D in [outline, glow]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Balance.POSSESS_COLOUR
		material.grow = true
	outline.grow_amount = Balance.OUTLINE_GROW
	outline.cull_mode = BaseMaterial3D.CULL_FRONT # Only the shell's far side shows, as a rim round the prop.
	glow.grow_amount = Balance.GLOW_GROW


func _build_drips(size: Vector3) -> void:
	var drop := SphereMesh.new()
	drop.radius = Balance.DRIP_SIZE / 2.0
	drop.height = Balance.DRIP_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Balance.POSSESS_COLOUR
	drop.material = material
	drips.mesh = drop
	drips.amount = Balance.DRIP_AMOUNT
	drips.lifetime = Balance.DRIP_LIFETIME
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = size / 2.0
	drips.direction = Vector3.DOWN
	drips.gravity = Vector3.DOWN * Balance.GRAVITY
	drips.emitting = false
	add_child(drips)


func _show_shockwave() -> void:
	# A unit ring spreads out to the stomp radius and fades.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Balance.POSSESS_COLOUR
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prop.get_parent().add_child(ring)
	var arena: Node = prop.get_parent()
	var floor_height: float = arena.floor_height_at(prop.global_position) if arena.has_method("floor_height_at") else 0.0
	ring.global_position = Vector3(prop.global_position.x, floor_height + Balance.DECAL_HEIGHT, prop.global_position.z)
	var bounds: AABB = footprint()
	var start: float = maxf(bounds.size.x, bounds.size.z) / 2.0 # The ring starts at the prop's edge.
	ring.scale = Vector3(start, 1.0, start)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(Balance.STOMP_RADIUS, 1.0, Balance.STOMP_RADIUS), Balance.SHOCKWAVE_TIME)
	tween.tween_property(material, "albedo_color:a", 0.0, Balance.SHOCKWAVE_TIME)
	tween.chain().tween_callback(ring.queue_free)
