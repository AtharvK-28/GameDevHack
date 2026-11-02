# The fuse cupboard under the stairs (decision 158): step two of the Mansion's mission. Releasing the gallery key
# inside it unlocks the cupboard and reveals the fuse box, which is step three. It accepts the key only while its
# own step is the one the crew is on, so nothing can be done out of order.
extends Area3D

signal opened

const ZONE_ALPHA: float = 0.3

# --- State ---
var mission: Mission
var open: bool = false
var label: Label3D
var door: MeshInstance3D

# --- Setup ---
func _ready() -> void:
	collision_layer = 0
	collision_mask = 0 # Delivery is checked when the key is released, never on body entry.
	var pad := MeshInstance3D.new()
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(Balance.MISSION_CUPBOARD_SIZE.x, Balance.DELIVERY_LIFT, Balance.MISSION_CUPBOARD_SIZE.z)
	pad.mesh = pad_box
	pad.position.y = Balance.DELIVERY_LIFT
	pad.material_override = _material(Color(Balance.MISSION_KEY_COLOUR, ZONE_ALPHA))
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pad)

	# A little panelled door in the understairs wall, which swings aside once the key turns.
	door = MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.9, 1.5, 0.08)
	door.mesh = door_box
	door.position = Vector3(0.0, door_box.size.y / 2.0, -Balance.MISSION_CUPBOARD_SIZE.z / 2.0)
	door.material_override = _material(Balance.FURNITURE_COLOURS[0])
	add_child(door)

	label = Label3D.new()
	label.font = load(Balance.COMIC_FONT_PATH)
	label.font_size = Balance.PRICE_FONT_SIZE
	label.pixel_size = Balance.TASK_LABEL_PIXEL_SIZE
	label.outline_size = Balance.LABEL_OUTLINE
	label.outline_modulate = Balance.COMIC_INK
	label.modulate = Balance.MISSION_KEY_COLOUR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = Balance.TASK_LABEL_HEIGHT
	add_child(label)
	_refresh()


# --- Delivery ---
func contains_point(point: Vector3) -> bool:
	var local: Vector3 = to_local(point)
	var half: Vector3 = Balance.MISSION_CUPBOARD_SIZE / 2.0
	return absf(local.x) <= half.x and absf(local.z) <= half.z and local.y >= 0.0 and local.y <= Balance.MISSION_CUPBOARD_SIZE.y


func try_deliver(key: Carryable) -> bool:
	if open or key.finished or key.is_held() or not contains_point(key.global_position):
		return false
	if mission == null or not mission.is_open("cupboard"):
		return false
	key.finished = true
	key.collision_layer = 0
	key.collision_mask = 0
	key.hide()
	key.queue_free()
	open = true
	mission.complete("cupboard")
	var swing := door.create_tween()
	swing.tween_property(door, "rotation:y", deg_to_rad(-100.0), 0.4)
	Sfx.play("creak", 1.2)
	_refresh()
	opened.emit()
	print("The fuse cupboard is open")
	return true


func hud_text() -> String:
	return "Fuse cupboard open" if open else "Fuse cupboard locked"


# --- Look ---
func _refresh() -> void:
	label.text = "FUSE BOX" if open else "LOCKED · NEEDS THE KEY"


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
