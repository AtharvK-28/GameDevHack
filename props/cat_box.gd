# The cat in a box (Old Mansion, decision 140): a cardboard box with a ginger cat peeking out, in every round. Run
# with it and the cat grumbles (MRRROW?, and the carrier's phone buzzes); keep running and it leaps out, and so does
# a hard knock. The empty box keeps CAT_BOX_SHARE of the value; the cat takes the rest and scampers away from anyone
# who comes near (props/mansion_cat.gd), so someone has to catch it.
class_name CatBox
extends Loot

const CAT_ITEM: String = "res://props/catalog/mansion_cat/cat.tres"

var has_cat: bool = true
var rush: float = 0.0
var warned: bool = false

func _physics_process(delta: float) -> void:
	super(delta)
	if not has_cat or finished:
		return
	if not is_held() or not is_instance_valid(holder):
		rush = 0.0
		warned = false
		return
	var full: float = holder.movement_speed()
	var speed: float = Vector2(holder.velocity.x, holder.velocity.z).length()
	if full > 0.0 and speed >= full * Balance.PARROT_CALM_RATIO:
		rush += delta
	else:
		rush = 0.0
		warned = false
	if rush >= Balance.CAT_WARN_SECONDS and not warned:
		warned = true
		show_popup("MRRROW?", Balance.CAT_COLOUR)
		Sfx.play("meow", 0.85, Balance.CAT_MEOW_DB)
		var player := Net.player_for_slot(last_carrier_slot)
		if not player.is_empty():
			Net.send_to_player(player, {"type": "buzz", "ms": Balance.PARROT_WARN_BUZZ_MS})
	if rush >= Balance.CAT_WARN_SECONDS + Balance.CAT_ESCAPE_SECONDS:
		leap_out()


func apply_impact(speed: float, was_thrown: bool = false) -> void:
	if has_cat and not finished and speed > Balance.CAT_STARTLE_SPEED:
		leap_out.call_deferred() # Not inside the physics callback that reported the knock.
	super(speed, was_thrown)


func leap_out() -> void:
	if not has_cat or finished:
		return
	has_cat = false
	var cat_value: int = value - roundi(value * Balance.CAT_BOX_SHARE)
	value -= cat_value
	initial_value = value # The empty box is whole, not damaged; the round's total is unchanged.
	item_name = "Empty cat box"
	var peeking: Node3D = model.find_child("Cat", true, false) if model != null else null
	if peeking != null:
		peeking.hide()
	var entry: CatalogItem = load(CAT_ITEM)
	var cat: RigidBody3D = load("res://props/Loot.tscn").instantiate()
	cat.set_script(entry.loot_script)
	cat.catalog_item = entry
	get_parent().add_child(cat)
	cat.value = cat_value
	cat.initial_value = cat_value
	cat.global_position = global_position + Vector3.UP * (item_size.y / 2.0 + entry.footprint.y / 2.0 + 0.1)
	cat.show_popup("MRRAOW!", Balance.CAT_COLOUR)
	Sfx.play("meow", 1.15, Balance.CAT_MEOW_DB)
	print("The cat leapt out of its box")
