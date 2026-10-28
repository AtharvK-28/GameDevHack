# The Museum's task items (decision 133): three cheap fakes the crew brought in the van, to leave on the plinths so
# the cameras see nothing missing. A cardboard T-Rex skull (for the skeleton's empty neck), a plaster bust and a
# painted brick passing for a gold bar. They carry like the Ship's oil cans; only a release on a fake plinth counts.
extends "res://props/tasks/battery.gd"

const KINDS: Array[String] = ["Cardboard skull", "Plaster bust", "Painted brick"]

var kind: int = 0 # Set by the arena before the replica enters the tree.

# --- Look ---
func _configure() -> void:
	item_name = KINDS[kind]
	item_size = Balance.REPLICA_SIZES[kind]
	weight_class = Balance.LIGHT if kind != 1 else Balance.MEDIUM


func _build_model(model: Node3D) -> void:
	match kind:
		0:
			# Brown cardboard folded into a skull: a box head, a jaw flap, drawn-on eyes and a zigzag of paper teeth.
			_part(model, item_size * Vector3(1.0, 0.7, 1.0), Vector3(0, item_size.y * 0.1, 0), Balance.REPLICA_CARDBOARD)
			_part(model, item_size * Vector3(0.9, 0.18, 0.9), Vector3(item_size.x * 0.05, -item_size.y * 0.38, 0), Balance.REPLICA_CARDBOARD.darkened(0.15))
			_part(model, item_size * Vector3(0.14, 0.18, 1.02), Vector3(-item_size.x * 0.15, item_size.y * 0.22, 0), Balance.REPLICA_INK)
			_part(model, item_size * Vector3(0.5, 0.06, 1.02), Vector3(item_size.x * 0.2, -item_size.y * 0.2, 0), Color.WHITE)
		1:
			# Chalky plaster: a block base, shoulders and a lumpy head, with a crack drawn down it.
			_part(model, item_size * Vector3(0.8, 0.2, 0.8), Vector3(0, -item_size.y * 0.4, 0), Balance.REPLICA_PLASTER.darkened(0.1))
			_part(model, item_size * Vector3(1.0, 0.35, 0.6), Vector3(0, -item_size.y * 0.13, 0), Balance.REPLICA_PLASTER)
			_part(model, item_size * Vector3(0.55, 0.42, 0.55), Vector3(0, item_size.y * 0.28, 0), Balance.REPLICA_PLASTER)
			_part(model, item_size * Vector3(0.04, 0.4, 0.57), Vector3(item_size.x * 0.08, item_size.y * 0.2, 0), Balance.REPLICA_INK)
		_:
			# A house brick, sprayed gold, which nobody will look at closely. Probably.
			_part(model, item_size, Vector3.ZERO, Balance.MUSEUM_GOLD)
			_part(model, item_size * Vector3(1.02, 0.25, 1.02), Vector3(0, -item_size.y * 0.38, 0), Balance.REPLICA_BRICK)


func _label_text() -> String:
	return "FAKE"


func _label_colour() -> Color:
	return Balance.REPLICA_LABEL_COLOUR
