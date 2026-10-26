# The Ghost Ship's task item: a lamp-oil can. It carries like a battery but is lighter, and only a mover's
# release at an unlit lantern post delivers it.
extends "res://props/tasks/battery.gd"


# --- Look ---
func _configure() -> void:
	item_name = "Oil Can"
	item_size = Balance.OIL_CAN_SIZE
	weight_class = Balance.MEDIUM


func _build_model(model: Node3D) -> void:
	# A squat red can with a dark band, a carry handle and a spout, readable from the party camera.
	_part(model, item_size * Vector3(1.0, 0.85, 1.0), Vector3(0, -item_size.y * 0.075, 0), Balance.OIL_CAN_COLOUR)
	_part(model, item_size * Vector3(1.03, 0.12, 1.03), Vector3(0, item_size.y * 0.05, 0), Balance.SHIP_METAL_COLOUR)
	_part(model, item_size * Vector3(0.6, 0.1, 0.15), Vector3(0, item_size.y * 0.45, 0), Balance.SHIP_METAL_COLOUR)
	_part(model, item_size * Vector3(0.18, 0.3, 0.18), Vector3(item_size.x * 0.3, item_size.y * 0.42, item_size.z * 0.25), Balance.SHIP_GOLD_COLOUR)


func _label_text() -> String:
	return "OIL"


func _label_colour() -> Color:
	return Balance.LANTERN_LIT_COLOUR
