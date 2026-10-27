# The Captain's parrot (decision 127): Ghost Ship loot with a personality. It rides calmly in a walking mover's
# hands, but a carrier who keeps running gets a SQUAWK! warning, then it flies off to another perch on the ship.
# Anything that would cost an ordinary item value (a hard knock, a throw, the sea) makes it fly off instead: it is
# alive, so it never loses value. Perches are ship-space points in the layout's spawns.perches.
class_name Parrot
extends Loot

# --- Flight state ---
var rush: float = 0.0 # Seconds the carrier has kept up a run.
var warned: bool = false
var flying: bool = false
var flight_time: float = 0.0
var flight_from := Vector3.ZERO # World point it took off from.
var perch := Vector3.ZERO # Ship-space point it is flying to.
var wings: Array[Node3D] = []
var perches_random := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	var arena: Node = get_parent()
	perches_random.seed = (arena.spawn_seed if "spawn_seed" in arena else 0) + Balance.PARROT_SEED_OFFSET
	if model != null:
		for name: String in ["WingLeft", "WingRight"]:
			var wing: Node3D = model.find_child(name, true, false)
			if wing != null:
				wings.append(wing)


# --- Carrying ---
func _physics_process(delta: float) -> void:
	super(delta)
	if flying:
		_fly(delta)
		return
	if not is_held():
		rush = 0.0
		warned = false
		return
	var full: float = holder.movement_speed()
	var speed: float = Vector2(holder.velocity.x, holder.velocity.z).length()
	if full > 0.0 and speed >= full * Balance.PARROT_CALM_RATIO:
		rush += delta
	else:
		rush = 0.0
		warned = false
	if rush >= Balance.PARROT_WARN_SECONDS and not warned:
		warned = true
		show_popup("SQUAWK!", Balance.PARROT_WARN_COLOUR)
		Sfx.play("squawk", 1.0, Balance.PARROT_SQUAWK_DB)
		var player := Net.player_for_slot(last_carrier_slot)
		if not player.is_empty():
			Net.send_to_player(player, {"type": "buzz", "ms": Balance.PARROT_WARN_BUZZ_MS})
	if rush >= Balance.PARROT_WARN_SECONDS + Balance.PARROT_ESCAPE_SECONDS:
		escape("Ran with it")


func release(throw_velocity: Vector3 = Vector3.ZERO, by: CharacterBody3D = null) -> void:
	if throw_velocity.is_zero_approx():
		super(throw_velocity, by)
	elif is_held() and not finished:
		escape("Thrown") # It refuses to be thrown.


func grab_point_for(mover: CharacterBody3D) -> Vector3:
	return Vector3.INF if flying else super(mover)


func try_grab(mover: CharacterBody3D, target: Node3D, slot: int) -> bool:
	return false if flying else super(mover, target, slot)


func is_spent() -> bool:
	return flying # The ghost cannot possess it in the air.


# --- What hurts other loot makes it fly ---
func apply_impact(speed: float, was_thrown: bool = false) -> void:
	var threshold: float = Balance.THROWN_DAMAGE_SPEED_THRESHOLD if was_thrown or thrown else Balance.DAMAGE_SPEED_THRESHOLD
	if not finished and not flying and speed > threshold:
		escape("Knocked at %.1f m/s" % speed)


func _lose_value(_loss: int) -> void:
	if not flying:
		escape("Fell in the sea") # The Ship drowns sunk loot through here; a parrot just flies back.


# --- Flight ---
func escape(reason: String) -> void:
	if finished or flying:
		return
	_detach()
	var possession: Node = get_node_or_null("Possessable")
	if possession != null and possession.is_possessed():
		possession.ghost.leave()
	flying = true
	flight_time = 0.0
	rush = 0.0
	warned = false
	thrown = false
	flight_from = global_position
	perch = _pick_perch()
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	show_popup("FLEW OFF!", Balance.PARROT_WARN_COLOUR)
	Sfx.play("squawk", Balance.PARROT_ESCAPE_PITCH, Balance.PARROT_SQUAWK_DB)
	print("%s flew off (%s)" % [item_name, reason])


func _fly(delta: float) -> void:
	flight_time += delta
	var share: float = minf(flight_time / Balance.PARROT_FLIGHT_SECONDS, 1.0)
	var to: Vector3 = _world_point(perch)
	var point: Vector3 = flight_from.lerp(to, share) + Vector3.UP * sin(share * PI) * Balance.PARROT_FLIGHT_HEIGHT
	var heading := Vector3(to.x - flight_from.x, 0.0, to.z - flight_from.z)
	if heading.length() > 0.01:
		global_basis = Basis.looking_at(heading, Vector3.UP, true)
	global_position = point
	var flap: float = sin(flight_time * TAU * Balance.PARROT_FLAP_RATE) * deg_to_rad(Balance.PARROT_FLAP_ANGLE)
	for index: int in wings.size():
		wings[index].rotation.z = flap * (1.0 if index == 0 else -1.0)
	if share >= 1.0:
		_land()


func _land() -> void:
	flying = false
	for wing: Node3D in wings:
		wing.rotation.z = 0.0
	freeze = false
	collision_layer = Balance.LOOT_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	previous_contacts.clear()
	jiggle(Balance.JIGGLE_GRAB)
	print("%s landed" % item_name)


func _pick_perch() -> Vector3:
	# A random free perch far enough away to be a chase; any far perch when all are taken.
	var arena: Node = get_parent()
	var perches: Array = arena.layout.spawns.get("perches", []) if "layout" in arena else []
	var far: Array[Vector3] = []
	var free: Array[Vector3] = []
	for spot: Dictionary in perches:
		var point: Vector3 = ArenaBuilder.point_of(spot, item_size.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
		if _world_point(point).distance_to(global_position) < Balance.PARROT_MIN_HOP:
			continue
		far.append(point)
		if _perch_clear(_world_point(point)):
			free.append(point)
	var choices: Array[Vector3] = free if not free.is_empty() else far
	if choices.is_empty():
		return _ship_point(global_position) # No perches: it flutters up and lands where it was.
	return choices[perches_random.randi_range(0, choices.size() - 1)]


func _perch_clear(point: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = Balance.PARROT_PERCH_CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point
	query.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# Perches ride the ship, so a flight aims at where the perch is now.
func _world_point(ship_point: Vector3) -> Vector3:
	var arena: Node = get_parent()
	return arena.from_ship(ship_point) if arena.has_method("from_ship") else ship_point


func _ship_point(world_point: Vector3) -> Vector3:
	var arena: Node = get_parent()
	return arena.to_ship(world_point) if arena.has_method("to_ship") else world_point
