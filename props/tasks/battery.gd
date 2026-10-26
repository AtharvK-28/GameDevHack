# A heavy, indestructible task carryable. Only a mover's release inside its generator zone delivers it.
# The Ship's oil can extends this with its own look and weight; "generator" is whichever task zone it feeds.
extends Carryable

# --- Task state ---
var generator: Node3D
var arena: Node3D
var spawn_position: Vector3
var label: Label3D

# --- Setup ---
func _ready() -> void:
	_configure()
	super()
	add_to_group("task_batteries")
	spawn_position = position
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = item_size
	collision.shape = box
	add_child(collision)
	var model := Node3D.new()
	add_child(model)
	set_visual(model)
	_build_model(model)
	label = Label3D.new()
	label.text = _label_text()
	label.font_size = Balance.PRICE_FONT_SIZE
	label.pixel_size = Balance.TASK_LABEL_PIXEL_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = _label_colour()
	label.position.y = item_size.y
	add_child(label)


# --- Look, overridden by other task items ---
func _configure() -> void:
	item_name = "Generator Battery"
	item_size = Balance.BATTERY_SIZE
	weight_class = Balance.HEAVY


func _build_model(model: Node3D) -> void:
	_part(model, item_size, Vector3.ZERO, Balance.BATTERY_METAL)
	_part(model, item_size * Vector3(1.02, 0.55, 1.02), Vector3.ZERO, Balance.BATTERY_COLOUR)
	# A raised carry handle and two terminals give the battery a clear silhouette.
	_part(model, item_size * Vector3(0.5, 0.12, 0.18), Vector3(0, item_size.y * 0.65, 0), Balance.BATTERY_METAL)
	for side: float in [-1.0, 1.0]:
		_part(model, item_size * Vector3(0.12, 0.2, 0.2), Vector3(side * item_size.x * 0.3, item_size.y * 0.5, 0), Balance.GENERATOR_COLOUR)


func _label_text() -> String:
	return "BATTERY"


func _label_colour() -> Color:
	return Balance.GENERATOR_COLOUR


# --- Carry and delivery ---
func _process(delta: float) -> void:
	update_jiggle(delta)


func _physics_process(_delta: float) -> void:
	# A task must remain completable even if a physics mishap sends a battery below the map.
	var outside: bool = is_instance_valid(arena) and not arena.mover_bounds().has_point(Vector2(position.x, position.z))
	if not finished and (global_position.y < Balance.BATTERY_RECOVERY_DEPTH or outside):
		_detach()
		position = spawn_position
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		rotation = Vector3.ZERO
		print("Recovered %s at its spawn" % item_name)


func _on_released() -> bool:
	return is_instance_valid(generator) and generator.try_deliver(self)


# --- Model helpers ---
func _part(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material_override = material
	parent.add_child(mesh)
