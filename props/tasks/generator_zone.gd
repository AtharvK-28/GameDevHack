# Counts battery releases once. The third delivery powers the generator for the rest of this round.
extends Area3D

signal powered_on

# --- Task state ---
var delivered: int = 0
var powered: bool = false
var label: Label3D
var indicators: Array[MeshInstance3D] = []

# --- Setup ---
func _ready() -> void:
	collision_layer = 0
	collision_mask = 0 # Delivery is checked at release, never on body entry.
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Balance.GENERATOR_ZONE_SIZE.x, Balance.DELIVERY_LIFT, Balance.GENERATOR_ZONE_SIZE.z)
	floor_mesh.mesh = box
	floor_mesh.position.y = Balance.DELIVERY_LIFT
	floor_mesh.material_override = _material(Color(Balance.GENERATOR_COLOUR, 0.3))
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)
	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Balance.GENERATOR_BODY_SIZE
	body.mesh = body_box
	body.position = Vector3(0, body_box.size.y / 2.0, -Balance.GENERATOR_ZONE_SIZE.z / 2.0 - body_box.size.z / 2.0)
	body.material_override = _material(Balance.BATTERY_METAL)
	add_child(body)
	var collider := StaticBody3D.new()
	collider.collision_layer = Balance.WORLD_LAYER
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = body_box.size
	shape.position = body.position
	collider.add_child(shape)
	add_child(collider)
	for index: int in Balance.BATTERY_COUNT:
		var indicator := MeshInstance3D.new()
		var indicator_box := BoxMesh.new()
		indicator_box.size = body_box.size * Vector3(0.18, 0.12, 0.08)
		indicator.mesh = indicator_box
		indicator.position = body.position + Vector3((index - 1) * body_box.size.x / 3.0, body_box.size.y * 0.2, body_box.size.z / 2.0)
		indicator.material_override = _material(Balance.BATTERY_METAL)
		add_child(indicator)
		indicators.append(indicator)
	label = Label3D.new()
	label.font_size = Balance.PRICE_FONT_SIZE
	label.pixel_size = Balance.TASK_LABEL_PIXEL_SIZE
	label.position.y = Balance.TASK_LABEL_HEIGHT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Balance.GENERATOR_COLOUR
	add_child(label)
	_refresh()


# --- Delivery ---
func contains_point(point: Vector3) -> bool:
	var local: Vector3 = to_local(point)
	var half: Vector3 = Balance.GENERATOR_ZONE_SIZE / 2.0
	return absf(local.x) <= half.x and absf(local.z) <= half.z and local.y >= 0.0 and local.y <= Balance.GENERATOR_ZONE_SIZE.y


func try_deliver(battery: Carryable) -> bool:
	if powered or battery.finished or battery.is_held() or not battery.is_in_group("task_batteries") or battery.generator != self or not contains_point(battery.global_position):
		return false
	battery.finished = true
	battery.collision_layer = 0
	battery.collision_mask = 0
	battery.hide()
	battery.queue_free()
	delivered += 1
	powered = delivered == Balance.BATTERY_COUNT
	_refresh()
	Sfx.play("bank")
	print("Generator battery delivered: %d/%d" % [delivered, Balance.BATTERY_COUNT])
	if powered:
		powered_on.emit()
	return true


# --- Feedback ---
func _refresh() -> void:
	label.text = "GENERATOR POWERED\nGhost weakened" if powered else "GENERATOR %d/%d\nRelease batteries here" % [delivered, Balance.BATTERY_COUNT]
	for index: int in indicators.size():
		indicators[index].material_override = _material(Balance.GENERATOR_COLOUR if index < delivered else Balance.BATTERY_METAL)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
