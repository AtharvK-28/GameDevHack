# Banks released loot once, using its centre position at the moment of release.
# Two shapes: a box (the greybox truck), or, when radius is set, a green half-circle on this node's −X side,
# placed at a truck's tailgate so loot dropped anywhere behind the truck counts as delivered.
extends Area3D

signal banked(value: int, carrier_slot: int)
signal delivery_notice(value: int, item_name: String, slots: Array[int], item_id: int)
signal delivered(value: int, carrier_slots: Array[int])

# --- Shape, set by the arena before the zone enters the tree ---
var zone_size: Vector3
var radius: float = 0.0 # Above zero: a half-circle of this radius instead of a box.

# --- Bank state ---
var banked_value: int = 0
var banked_items: int = 0

# --- Setup ---
func _ready() -> void:
	add_to_group("truck_zones")
	if zone_size == Vector3.ZERO:
		zone_size = Balance.TRUCK_SIZE # Arenas built from data set their own size first.
	collision_layer = 0
	collision_mask = Balance.LOOT_LAYER
	if radius > 0.0:
		_build_half_circle()
	else:
		_build_box()
	# Painted on the ground like a loading-bay marking, in comic lettering, turned to read from the camera.
	var sign_label := Label3D.new()
	sign_label.text = "LOAD THE\nTRUCK!"
	sign_label.font = load(Balance.COMIC_FONT_PATH)
	sign_label.font_size = Balance.PRICE_FONT_SIZE
	sign_label.pixel_size = Balance.FLOOR_LABEL_PIXEL_SIZE
	sign_label.outline_size = Balance.LABEL_OUTLINE
	sign_label.outline_modulate = Balance.COMIC_INK
	sign_label.modulate = Color(Color.WHITE, Balance.FLOOR_LABEL_ALPHA)
	add_child(sign_label)
	sign_label.set_deferred("global_rotation_degrees", Vector3(-90.0, Balance.CAMERA_YAW, 0.0)) # After the arena places the zone.
	sign_label.position = Vector3(-radius / 2.0, Balance.FLOOR_LABEL_HEIGHT, 0.0) if radius > 0.0 else Vector3(0.0, Balance.FLOOR_LABEL_HEIGHT, 0.0)


# --- Banking ---
func try_bank(item: Loot) -> bool:
	if item.finished or item.is_held() or not contains_point(item.global_position):
		return false
	var amount: int = item.value
	var carrier_slot: int = item.last_carrier_slot
	var slots: Array[int] = item.delivery_slots.duplicate()
	if slots.is_empty():
		slots.append(carrier_slot)
	delivery_notice.emit(amount, item.item_name, slots, item.get_instance_id())
	Fx.burst(item.global_position, Fx.Kind.SPARKLE, item.get_parent())
	item.retire("KA-CHING!\n+" + Loot.rupees(amount), Balance.BANK_COLOUR)
	banked_value += amount
	banked_items += 1
	banked.emit(amount, carrier_slot)
	delivered.emit(amount, slots)
	Sfx.banked(amount)
	print("Banked ₹%d. Truck total: ₹%d" % [amount, banked_value])
	return true


func contains_point(point: Vector3) -> bool:
	var local_point: Vector3 = to_local(point)
	if local_point.y < 0.0 or local_point.y > zone_size.y:
		return false
	if radius > 0.0:
		return local_point.x <= 0.0 and Vector2(local_point.x, local_point.z).length() <= radius
	return absf(local_point.x) <= zone_size.x / 2.0 and absf(local_point.z) <= zone_size.z / 2.0


# --- Visual helpers ---
func _build_box() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = zone_size
	collision.shape = shape
	collision.position.y = zone_size.y / 2.0
	add_child(collision)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(zone_size.x, Balance.FLOOR_THICKNESS, zone_size.z)
	floor_mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.BANK_COLOUR
	floor_mesh.material_override = material
	add_child(floor_mesh)


func _build_half_circle() -> void:
	# A cylinder shape for the area (banking itself uses contains_point), and a flat green half-disc on the ground.
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = zone_size.y
	collision.shape = shape
	collision.position.y = zone_size.y / 2.0
	add_child(collision)
	var lift: float = Balance.DELIVERY_LIFT
	var vertices := PackedVector3Array()
	for step: int in range(Balance.DELIVERY_SEGMENTS):
		var from: float = PI / 2.0 + PI * step / Balance.DELIVERY_SEGMENTS
		var to: float = PI / 2.0 + PI * (step + 1) / Balance.DELIVERY_SEGMENTS
		vertices.append(Vector3.UP * lift)
		vertices.append(Vector3(cos(to) * radius, lift, -sin(to) * radius))
		vertices.append(Vector3(cos(from) * radius, lift, -sin(from) * radius))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.DELIVERY_COLOUR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
