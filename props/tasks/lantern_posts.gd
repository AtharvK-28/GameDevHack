# Light the Lanterns, the Ghost Ship's task: two posts on the salvage tug and one on the quarterdeck. A mover's release of an oil can
# inside an unlit post's mark lights that post, once. Lighting all three weakens the ghost for the round, the
# same deal as the Mansion's generator, so the shared HUD, phones and ghost read this through the same fields.
extends Node3D

signal powered_on

const TASK_NAME: String = "Lanterns"
const TASK_ITEM: String = "Oil Can"

# --- Task state ---
var delivered: int = 0
var powered: bool = false
var total: int = Balance.LANTERN_COUNT
var lit: Array[bool] = []
var posts: Array[Vector3] = [] # Each post's mark centre, in this node's space.
var flames: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []

# --- Setup ---
func _ready() -> void:
	for at: Vector3 in Balance.LANTERN_POST_SPOTS:
		_build_post(at)


func _build_post(at: Vector3) -> void:
	posts.append(at)
	lit.append(false)
	var mark := MeshInstance3D.new()
	var pad := BoxMesh.new()
	pad.size = Vector3(Balance.LANTERN_ZONE_SIZE.x, Balance.DELIVERY_LIFT, Balance.LANTERN_ZONE_SIZE.z)
	mark.mesh = pad
	mark.position = at + Vector3.UP * Balance.DELIVERY_LIFT
	mark.material_override = _material(Color(Balance.LANTERN_LIT_COLOUR, 0.3))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	# A pole, an arm and a hanging lantern beside the mark; the lantern's glass is dark until lit.
	var base: Vector3 = at + Vector3(0, 0, -Balance.LANTERN_ZONE_SIZE.z / 2.0)
	_block(Vector3(0.12, Balance.LANTERN_POST_HEIGHT, 0.12), base + Vector3.UP * Balance.LANTERN_POST_HEIGHT / 2.0, Balance.SHIP_METAL_COLOUR)
	_block(Vector3(0.08, 0.08, 0.45), base + Vector3(0, Balance.LANTERN_POST_HEIGHT - 0.04, 0.2), Balance.SHIP_METAL_COLOUR)
	var lantern_at: Vector3 = base + Vector3(0, Balance.LANTERN_POST_HEIGHT - 0.3, 0.4)
	_block(Vector3(0.34, 0.06, 0.34), lantern_at + Vector3.UP * 0.22, Balance.SHIP_METAL_COLOUR)
	var flame: MeshInstance3D = _block(Vector3(0.34, 0.44, 0.34), lantern_at, Balance.LANTERN_DARK_COLOUR)
	flames.append(flame)
	var collider := StaticBody3D.new()
	collider.collision_layer = Balance.WORLD_LAYER
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(0.12, Balance.LANTERN_POST_HEIGHT, 0.12)
	shape.position = base + Vector3.UP * Balance.LANTERN_POST_HEIGHT / 2.0
	collider.add_child(shape)
	add_child(collider)
	var label := Label3D.new() # Painted on the deck in comic lettering, turned to read from the camera.
	label.font = load(Balance.COMIC_FONT_PATH)
	label.font_size = Balance.PRICE_FONT_SIZE
	label.pixel_size = Balance.FLOOR_LABEL_PIXEL_SIZE * 0.7
	label.outline_size = Balance.LABEL_OUTLINE
	label.outline_modulate = Balance.COMIC_INK
	label.modulate = Color(Balance.LANTERN_LIT_COLOUR.lightened(0.4), Balance.FLOOR_LABEL_ALPHA)
	label.position = at + Vector3.UP * Balance.FLOOR_LABEL_HEIGHT
	add_child(label)
	label.set_deferred("global_rotation_degrees", Vector3(-90.0, Balance.SHIP_CAMERA_YAW, 0.0)) # After the arena places the posts.
	labels.append(label)
	_refresh_post(posts.size() - 1)


# --- Delivery ---
func post_at(point: Vector3) -> int:
	# The unlit post whose mark holds this point, or -1.
	var local: Vector3 = to_local(point)
	var half: Vector3 = Balance.LANTERN_ZONE_SIZE / 2.0
	for index: int in posts.size():
		var offset: Vector3 = local - posts[index]
		if not lit[index] and absf(offset.x) <= half.x and absf(offset.z) <= half.z and offset.y >= 0.0 and offset.y <= Balance.LANTERN_ZONE_SIZE.y:
			return index
	return -1


func contains_point(point: Vector3) -> bool:
	return post_at(point) >= 0


func try_deliver(can: Carryable) -> bool:
	if powered or can.finished or can.is_held() or not can.is_in_group("task_batteries") or can.generator != self:
		return false
	var index: int = post_at(can.global_position)
	if index < 0:
		return false
	can.finished = true
	can.collision_layer = 0
	can.collision_mask = 0
	can.hide()
	can.queue_free()
	lit[index] = true
	delivered += 1
	powered = delivered == total
	_refresh_post(index)
	Sfx.play("bank")
	Fx.burst(to_global(flames[index].position), Fx.Kind.SPARKLE, get_parent())
	print("Lantern lit: %d/%d" % [delivered, total])
	if powered:
		powered_on.emit()
	return true


# --- Shared task wording for the HUD and phones ---
func hud_text() -> String:
	return "Lanterns lit" if powered else "Lanterns %d/%d" % [delivered, total]


# --- Feedback ---
func _refresh_post(index: int) -> void:
	labels[index].text = "LIT!" if lit[index] else "OIL\nHERE"
	flames[index].material_override = _material(Balance.LANTERN_LIT_COLOUR, lit[index])


func _block(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _material(colour)
	add_child(mesh)
	return mesh


func _material(colour: Color, glowing: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glowing:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = Balance.LANTERN_GLOW
	return material
