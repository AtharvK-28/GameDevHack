# The goat (Museum of Mostly Real Things, decision 136): the running gag, on show in a case as "Goat, 2026 (on loan)".
# It bleats every few seconds while carried, and a knock only makes it bleat: it is alive, so it never loses value.
# Rescuing it (banking it at the van) is one of the Museum's bonus goals.
class_name MuseumGoat
extends Loot

var bleat_left: float = 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	if not is_held():
		bleat_left = minf(bleat_left, Balance.GOAT_BLEAT_GAP.x)
		return
	bleat_left -= delta
	if bleat_left <= 0.0:
		bleat_left = randf_range(Balance.GOAT_BLEAT_GAP.x, Balance.GOAT_BLEAT_GAP.y)
		_bleat()


func _lose_value(_loss: int) -> void:
	_bleat() # A knock, never a loss.


func _bleat() -> void:
	show_popup("MEHHH!", Balance.GOAT_BLEAT_COLOUR)
	Sfx.play("goat", randf_range(0.95, 1.15), Balance.GOAT_BLEAT_DB)
