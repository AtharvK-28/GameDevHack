# The delivery truck: the scanned pickup (assets/models/truck/truck.obj), turned square, scaled to the movers
# and placed so its tailgate sits at this node's origin facing −X, wheels on the ground. Two simple boxes
# (the bed and the cab) make it solid. Delivery happens in the TruckZone half-circle behind the tailgate.
extends StaticBody3D

# --- Setup ---
func _ready() -> void:
	collision_layer = Balance.WORLD_LAYER
	collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	_build_model()
	var bed := Vector3(Balance.TRUCK_BED_LENGTH, Balance.TRUCK_BED_HEIGHT, Balance.TRUCK_WIDTH)
	_add_box(bed, Vector3(bed.x / 2.0, bed.y / 2.0, 0.0))
	var cab_length: float = Balance.TRUCK_LENGTH - Balance.TRUCK_BED_LENGTH
	var cab := Vector3(cab_length, Balance.TRUCK_CAB_HEIGHT, Balance.TRUCK_WIDTH)
	_add_box(cab, Vector3(Balance.TRUCK_BED_LENGTH + cab_length / 2.0, cab.y / 2.0, 0.0))


func _build_model() -> void:
	# Rotate the scan's cab-to-tailgate line onto −X, scale it to TRUCK_LENGTH, then move its tailgate to the origin.
	var scale_factor: float = Balance.TRUCK_LENGTH / Balance.TRUCK_MODEL_LENGTH
	var turn: float = deg_to_rad(Balance.TRUCK_MODEL_HEADING) - PI
	var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * scale_factor)
	var origin: Vector3 = -(basis * Balance.TRUCK_MODEL_TAILGATE)
	origin.y = -Balance.TRUCK_MODEL_FLOOR * scale_factor - Balance.TRUCK_SINK
	var model := MeshInstance3D.new()
	model.mesh = load(Balance.TRUCK_MODEL_PATH)
	model.transform = Transform3D(basis, origin)
	add_child(model)


func _add_box(size: Vector3, centre: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	add_child(shape)
