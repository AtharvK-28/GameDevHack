# Parlour door, hinged at one jamb and resting open into the main room. Possessed, SLAM swings it shut and holds
# it locked for DOOR_LOCK_TIME, then it reopens. Movers in the swing tumble; loot in the way stops the door and
# takes one hit at the door's speed where it stands.
extends AnimatableBody3D

enum State { OPEN, SLAMMING, LOCKED, REOPENING }

# --- Look and size (optional) ---
@export var model_scene: PackedScene # Replaces the plain panel; hinged at its origin, reaching along -X.
@export var panel_height: float = 0.0 # Metres; 0 keeps the greybox partition's height.

# --- Door state ---
var item_name: String = "Parlour door"
var state: State = State.OPEN
var angle: float = Balance.DOOR_OPEN_ANGLE # Degrees from shut.
var lock_left: float = 0.0
var panel_size: Vector3
var panel_shape := BoxShape3D.new()
var swept: Array[Node] = [] # Movers this slam has already knocked over.

# --- Setup ---
func _ready() -> void:
	add_to_group("furniture")
	sync_to_physics = true
	collision_layer = Balance.WORLD_LAYER
	collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	var height: float = panel_height if panel_height > 0.0 else Balance.PARLOUR_WALL_HEIGHT
	panel_size = Vector3(Balance.PARLOUR_DOOR_WIDTH - Balance.DOOR_GAP, height, Balance.DOOR_THICKNESS)
	panel_shape.size = panel_size
	var collision := CollisionShape3D.new()
	collision.shape = panel_shape
	collision.position = _panel_centre()
	add_child(collision)
	if model_scene != null:
		add_child(model_scene.instantiate())
	else:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = panel_size
		mesh.mesh = box
		mesh.position = _panel_centre()
		var material := StandardMaterial3D.new()
		material.albedo_color = Balance.DOOR_COLOUR
		mesh.material_override = material
		add_child(mesh)
	rotation.y = deg_to_rad(angle)


# --- Slamming ---
func can_act() -> bool:
	return state == State.OPEN


func act() -> void:
	state = State.SLAMMING
	swept.clear()


func is_shut() -> bool:
	return state == State.LOCKED and angle <= 0.0


func _physics_process(delta: float) -> void:
	match state:
		State.SLAMMING:
			_swing_shut(delta)
		State.LOCKED:
			lock_left -= delta
			if lock_left <= 0.0:
				state = State.REOPENING
		State.REOPENING:
			# Loot in the swing holds the door, rather than being shoved; movers are simply nudged aside.
			var next: float = minf(Balance.DOOR_OPEN_ANGLE, angle + Balance.DOOR_OPEN_ANGLE / Balance.DOOR_REOPEN_TIME * delta)
			if _overlapping(next, Balance.LOOT_LAYER).is_empty():
				angle = next
				if angle >= Balance.DOOR_OPEN_ANGLE:
					state = State.OPEN
	rotation.y = deg_to_rad(angle)


func _swing_shut(delta: float) -> void:
	var next: float = maxf(0.0, angle - Balance.DOOR_OPEN_ANGLE / Balance.DOOR_SLAM_TIME * delta)
	for mover: Node in _overlapping(next, Balance.MOVER_LAYER):
		if mover.is_in_group("movers") and mover not in swept:
			swept.append(mover)
			mover.tumble(_swing_direction(next))
	var blockers: Array[Node] = _overlapping(next, Balance.LOOT_LAYER)
	if not blockers.is_empty():
		# Loot stops the door short; each item in the way takes one hit.
		for item: Node in blockers:
			if item.has_method("apply_impact"):
				item.apply_impact(_speed_at(item))
		print("The door slammed into the %s" % blockers[0].get("item_name"))
		_lock()
		return
	angle = next
	if angle <= 0.0:
		_lock()


func _lock() -> void:
	state = State.LOCKED
	lock_left = Balance.DOOR_LOCK_TIME


# --- Geometry helpers ---
func _speed_at(item: Node3D) -> float:
	# The panel's speed where the item stands: the slam's turn rate times its distance from the hinge.
	var offset: Vector3 = item.global_position - global_position
	var radius: float = minf(Vector2(offset.x, offset.z).length(), panel_size.x)
	return deg_to_rad(Balance.DOOR_OPEN_ANGLE / Balance.DOOR_SLAM_TIME) * radius


func _swing_direction(at_angle: float) -> Vector3:
	# The way the panel moves as it shuts.
	var radians: float = deg_to_rad(at_angle)
	return -Vector3(sin(radians), 0.0, cos(radians))


func _overlapping(at_angle: float, mask: int) -> Array[Node]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = panel_shape
	query.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(at_angle)), global_position) * Transform3D(Basis(), _panel_centre())
	query.collision_mask = mask
	var exclude: Array[RID] = [get_rid()]
	query.exclude = exclude
	var found: Array[Node] = []
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, Balance.QUERY_LIMIT):
		if hit.collider is Node and hit.collider not in found:
			found.append(hit.collider)
	return found


func _panel_centre() -> Vector3:
	# The panel reaches from the hinge along local -X.
	return Vector3(-panel_size.x / 2.0, panel_size.y / 2.0, 0.0)
