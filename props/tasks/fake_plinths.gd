# Swap the Fakes, the Museum's task (decision 133): three marked plinths where a real exhibit used to be, on the
# skeleton's neck bracket, in the Art Gallery and in Egypt. A mover's release of a replica inside an empty plinth's
# mark swaps it in, once. Swapping all three weakens Bahadur for the round, the same deal as the Mansion's generator
# and the Ship's lanterns, so the shared HUD, phones and ghost read this through the same fields.
extends Node3D

signal powered_on

const TASK_NAME: String = "Fakes"
const TASK_ITEM: String = "Fake"

# --- Task state ---
var delivered: int = 0
var powered: bool = false
var total: int = Balance.REPLICA_COUNT
var filled: Array[bool] = []
var plinths: Array[Vector3] = []
var labels: Array[Label3D] = []

# --- Setup ---
func _ready() -> void:
	for at: Vector3 in Balance.FAKE_PLINTH_SPOTS:
		_build_plinth(at)


func _build_plinth(at: Vector3) -> void:
	plinths.append(at)
	filled.append(false)
	var mark := MeshInstance3D.new()
	var pad := BoxMesh.new()
	pad.size = Vector3(Balance.FAKE_ZONE_SIZE.x, Balance.DELIVERY_LIFT, Balance.FAKE_ZONE_SIZE.z)
	mark.mesh = pad
	mark.position = at + Vector3.UP * Balance.DELIVERY_LIFT
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(Balance.REPLICA_LABEL_COLOUR, 0.3)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.material_override = paint
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	var label := Label3D.new() # Lettering above the mark, facing the camera.
	label.font = load(Balance.COMIC_FONT_PATH)
	label.font_size = Balance.PRICE_FONT_SIZE
	label.pixel_size = Balance.FLOOR_LABEL_PIXEL_SIZE * 0.7
	label.outline_size = Balance.LABEL_OUTLINE
	label.outline_modulate = Balance.COMIC_INK
	label.modulate = Balance.REPLICA_LABEL_COLOUR.lightened(0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = at + Vector3.UP * Balance.FAKE_LABEL_HEIGHT
	add_child(label)
	labels.append(label)
	_refresh(plinths.size() - 1)


# --- Delivery ---
func plinth_at(point: Vector3) -> int:
	# The empty plinth whose mark holds this point, or -1.
	var local: Vector3 = to_local(point)
	var half: Vector3 = Balance.FAKE_ZONE_SIZE / 2.0
	for index: int in plinths.size():
		var offset: Vector3 = local - plinths[index]
		if not filled[index] and absf(offset.x) <= half.x and absf(offset.z) <= half.z and offset.y >= 0.0 and offset.y <= Balance.FAKE_ZONE_SIZE.y:
			return index
	return -1


func contains_point(point: Vector3) -> bool:
	return plinth_at(point) >= 0


func try_deliver(replica: Carryable) -> bool:
	if powered or replica.finished or replica.is_held() or not replica.is_in_group("task_batteries") or replica.generator != self:
		return false
	var index: int = plinth_at(replica.global_position)
	if index < 0:
		return false
	# The fake stays on show where it was put: frozen in place, out of play.
	replica.finished = true
	replica.freeze = true
	replica.collision_layer = 0
	replica.collision_mask = 0
	replica.remove_from_group("carryables")
	replica.label.hide()
	filled[index] = true
	delivered += 1
	powered = delivered == total
	_refresh(index)
	Sfx.play("bank")
	Fx.burst(replica.global_position, Fx.Kind.SPARKLE, get_parent())
	print("Fake swapped in: %d/%d" % [delivered, total])
	if powered:
		powered_on.emit()
	return true


# --- Shared task wording for the HUD and phones ---
func hud_text() -> String:
	return "Fakes swapped" if powered else "Fakes %d/%d" % [delivered, total]


func _refresh(index: int) -> void:
	labels[index].text = "LOOKS REAL!" if filled[index] else "FAKE\nHERE"
