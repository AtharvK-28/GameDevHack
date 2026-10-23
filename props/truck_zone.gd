# Banks released loot once, using its centre position at the moment of release.
extends Area3D

signal banked(value: int, carrier_slot: int)
signal delivered(value: int, carrier_slots: Array[int])

# --- Bank state ---
var banked_value: int = 0
var banked_items: int = 0
var zone_size: Vector3

# --- Setup ---
func _ready() -> void:
	add_to_group("truck_zones")
	zone_size = Balance.TRUCK_SIZE
	collision_layer = 0
	collision_mask = Balance.LOOT_LAYER
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
	var sign_label := Label3D.new()
	sign_label.text = "TRUCK\nRelease GRAB here"
	sign_label.font_size = Balance.PRICE_FONT_SIZE
	sign_label.pixel_size = Balance.PRICE_PIXEL_SIZE
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.position = Vector3(0.0, Balance.PRICE_LABEL_HEIGHT, zone_size.z / 2.0)
	add_child(sign_label)


# --- Banking ---
func try_bank(item: Loot) -> bool:
	if item.finished or item.is_held() or not contains_point(item.global_position):
		return false
	var amount: int = item.value
	var carrier_slot: int = item.last_carrier_slot
	var slots: Array[int] = item.delivery_slots.duplicate()
	if slots.is_empty():
		slots.append(carrier_slot)
	item.retire("+" + Loot.rupees(amount), Balance.BANK_COLOUR)
	banked_value += amount
	banked_items += 1
	banked.emit(amount, carrier_slot)
	delivered.emit(amount, slots)
	Sfx.play("bank", Balance.BANK_LARGE_PITCH if amount >= Balance.BANK_LARGE_VALUE else 1.0)
	print("Banked ₹%d. Truck total: ₹%d" % [amount, banked_value])
	return true


func contains_point(point: Vector3) -> bool:
	var local_point: Vector3 = to_local(point)
	return absf(local_point.x) <= zone_size.x / 2.0 and absf(local_point.z) <= zone_size.z / 2.0 and local_point.y >= 0.0 and local_point.y <= zone_size.y
