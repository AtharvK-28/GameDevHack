# The cat, once it has leapt out of its box (decision 140): it runs from anyone who comes near, like the Museum's
# baby raptor, in its own body built from shapes. It is alive and lands on its feet, so a knock only makes it hiss.
class_name MansionCat
extends BabyRaptor

func _build_runner() -> Node3D:
	return model # The catalog model, already in place; it has no animations.


func _on_dash() -> void:
	if randf() < Balance.CAT_DASH_MEOW_CHANCE:
		Sfx.play("meow", randf_range(1.05, 1.3), Balance.CAT_MEOW_DB)


func apply_impact(speed: float, _was_thrown: bool = false) -> void:
	if not finished and speed > Balance.THROWN_DAMAGE_SPEED_THRESHOLD:
		_lose_value(0) # Lands on its feet: no crash, just a hiss.


func _lose_value(_loss: int) -> void:
	show_popup("HSSS!", Balance.CAT_COLOUR) # A knock, never a loss.
