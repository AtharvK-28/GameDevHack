# The dinosaur egg (Museum of Mostly Real Things, decision 137): fragile, and full. When it breaks, a baby raptor
# hatches where it lay and runs from anyone who comes near: catch it and it is worth carrying out too.
class_name DinoEgg
extends Loot

const HATCHLING := preload("res://props/catalog/museum_hatchling/baby_raptor.tres")

func _lose_value(loss: int) -> void:
	var where: Vector3 = global_position
	super(loss)
	if value == 0:
		_hatch.call_deferred(where)


func _hatch(where: Vector3) -> void:
	var arena: Node = get_parent()
	if arena == null:
		return
	var baby: RigidBody3D = load("res://props/Loot.tscn").instantiate()
	baby.set_script(HATCHLING.loot_script)
	baby.catalog_item = HATCHLING
	arena.add_child(baby)
	baby.global_position = Vector3(where.x, maxf(where.y, HATCHLING.footprint.y / 2.0 + 0.05), where.z)
	baby.show_popup("IT HATCHED!", Balance.REPLICA_LABEL_COLOUR)
	Sfx.play("squawk", 0.8, Balance.PARROT_SQUAWK_DB)
	print("The dinosaur egg hatched a baby raptor")
