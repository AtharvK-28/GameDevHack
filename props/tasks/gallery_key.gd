# The gallery key (decision 158): step one of the Mansion's mission. A light, indestructible carryable hidden at
# one of Balance.MISSION_KEY_SPOTS, picked by seed. Only a mover's release inside the fuse cupboard delivers it.
# The ghost cannot possess it and cannot pick it up: the key is the one thing in the round it may not touch, so a
# mission can never be soft-locked. It can still be knocked about by a shoved prop, and it comes home if it escapes.
extends "res://props/tasks/battery.gd"

var mission: Mission # Set by the arena, so finding the key reports its own step.

# --- Look and weight ---
func _configure() -> void:
	item_name = "Gallery key"
	item_size = Balance.MISSION_KEY_SIZE
	weight_class = Balance.LIGHT # One mover can run with it; the ghost's job is to stop them arriving.


func _build_model(model: Node3D) -> void:
	# A long bow and a toothed bit, so it reads as a key from the camera rather than as another crate.
	_part(model, Vector3(item_size.x, item_size.y, item_size.z * 0.3), Vector3(0, 0, item_size.z * 0.3), Balance.MISSION_KEY_COLOUR)
	_part(model, Vector3(item_size.x * 0.3, item_size.y, item_size.z * 0.8), Vector3.ZERO, Balance.MISSION_KEY_COLOUR)
	_part(model, Vector3(item_size.x * 0.75, item_size.y, item_size.z * 0.18), Vector3(item_size.x * 0.2, 0, -item_size.z * 0.3), Balance.MISSION_KEY_COLOUR)


func _label_text() -> String:
	return "KEY"


func _label_colour() -> Color:
	return Balance.MISSION_KEY_COLOUR


# --- Step one is finding it, so picking it up is what finishes that step ---
func try_grab(mover: CharacterBody3D, target: Node3D, slot: int) -> bool:
	var took: bool = super(mover, target, slot)
	if took and mission != null:
		mission.complete("key")
	return took
