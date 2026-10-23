# Chandelier hanging over the main lane. Possessed, DROP makes it creak for CHANDELIER_CREAK_TIME while a floor
# marker shows where it will land, then it falls. One use: afterwards it lies on the floor as debris.
extends RigidBody3D

signal dropped
signal landed

enum State { HANGING, CREAKING, FALLING, DOWN }

# --- Look (optional) ---
@export var model_scene: PackedScene # Replaces the plain bowl (the Mansion's brass chandelier); the chain stays.

# --- Chandelier state ---
var item_name: String = "Chandelier"
var weight_class: int = Balance.HEAVY
var state: State = State.HANGING
var state_time: float = 0.0
var body_mesh := MeshInstance3D.new()
var chain := MeshInstance3D.new()
var marker := MeshInstance3D.new()

# --- Setup ---
func _ready() -> void:
	add_to_group("furniture")
	mass = Balance.WEIGHT_MASSES[weight_class]
	freeze = true
	collision_layer = Balance.LOOT_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	linear_damp = Balance.LOOT_LINEAR_DAMP
	angular_damp = Balance.LOOT_ANGULAR_DAMP
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = Balance.LOOT_FRICTION
	physics_material_override.bounce = Balance.LOOT_BOUNCE
	_build_body()
	_build_marker()


# --- Dropping ---
func can_act() -> bool:
	return state == State.HANGING


func act() -> void:
	state = State.CREAKING
	state_time = 0.0
	marker.show()


func is_spent() -> bool:
	return state == State.FALLING or state == State.DOWN


func _physics_process(delta: float) -> void:
	state_time += delta
	if state == State.CREAKING:
		body_mesh.rotation.x = sin(TAU * Balance.CHANDELIER_WOBBLE_RATE * state_time) * deg_to_rad(Balance.CHANDELIER_WOBBLE_ANGLE)
		if state_time >= Balance.CHANDELIER_CREAK_TIME:
			_fall()
	elif state == State.FALLING and state_time >= Balance.CHANDELIER_SETTLE_TIME and absf(linear_velocity.y) < Balance.LANDED_SPEED:
		state = State.DOWN
		print("The chandelier landed")
		landed.emit()


func _fall() -> void:
	# Committed once DROP is pressed: it falls even if the ghost was exorcised during the creak.
	state = State.FALLING
	state_time = 0.0
	body_mesh.rotation = Vector3.ZERO
	marker.hide()
	chain.hide()
	freeze = false
	sleeping = false
	print("The chandelier falls")
	dropped.emit()


# --- Visual helpers ---
func _build_body() -> void:
	var radius: float = Balance.CHANDELIER_SIZE.x / 2.0
	var height: float = Balance.CHANDELIER_SIZE.y
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	add_child(collision)

	# A wide-topped bowl of candles; the chain hangs from the mesh so only the bowl is outlined.
	var bowl := CylinderMesh.new()
	bowl.top_radius = radius
	bowl.bottom_radius = radius / 2.0
	bowl.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.CHANDELIER_COLOUR
	if model_scene != null:
		var model: Node3D = model_scene.instantiate()
		model.position.y = -height / 2.0 # Models are bottom-centred.
		body_mesh.add_child(model)
	else:
		body_mesh.mesh = bowl
		body_mesh.material_override = material
	add_child(body_mesh)
	var link := CylinderMesh.new()
	link.top_radius = Balance.CHANDELIER_CHAIN_RADIUS
	link.bottom_radius = Balance.CHANDELIER_CHAIN_RADIUS
	link.height = Balance.CHANDELIER_CHAIN_LENGTH
	chain.mesh = link
	chain.material_override = material
	chain.position.y = (height + Balance.CHANDELIER_CHAIN_LENGTH) / 2.0
	body_mesh.add_child(chain)


func _build_marker() -> void:
	# A red disc on the floor below, shown during the creak.
	var disc := CylinderMesh.new()
	disc.top_radius = Balance.CHANDELIER_SIZE.x / 2.0
	disc.bottom_radius = Balance.CHANDELIER_SIZE.x / 2.0
	disc.height = Balance.DECAL_THICKNESS
	marker.mesh = disc
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Balance.MARKER_COLOUR
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.top_level = true
	add_child(marker)
	marker.global_position = Vector3(global_position.x, Balance.DECAL_HEIGHT, global_position.z)
	marker.hide()
