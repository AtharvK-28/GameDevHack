# The grandfather clock (Old Mansion, decision 140): bump it and it chimes, BONG! BONG!, loud enough to wake
# Seth-ji. Each chime gives the ghost energy and fails the bonus goal "Don't wake Seth-ji"; the mover who knocked it
# counts toward GRANDFATHER'S ALARM. Otherwise ordinary heavy loot.
class_name GrandfatherClock
extends Loot

var chime_rest: float = 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	chime_rest = maxf(0.0, chime_rest - delta)


func apply_impact(speed: float, was_thrown: bool = false) -> void:
	if not finished and speed > Balance.CLOCK_CHIME_SPEED and chime_rest <= 0.0:
		chime_rest = Balance.CLOCK_CHIME_REST
		show_popup("BONG! BONG!", Balance.CLOCK_COLOUR)
		Sfx.play("chime", 1.0, Balance.CLOCK_CHIME_DB)
		var arena: Node = get_parent()
		if arena.has_method("clock_chime"):
			arena.clock_chime(Balance.CLOCK_CHIME_ENERGY, last_carrier_slot if is_held() or thrown else -1)
	super(speed, was_thrown)
