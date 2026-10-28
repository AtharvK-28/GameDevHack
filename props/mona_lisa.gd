# Mona Lisa's cousin (Museum of Mostly Real Things, decision 136): a painting that screams when bumped. Any knock
# above a light touch makes it shriek, AAAAAH! over it, and it raises the museum's alarm, so a clumsy crew is heard.
# Otherwise ordinary loot, and it still loses value on a hard knock like any painting.
class_name MonaLisaCousin
extends Loot

var scream_rest: float = 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	scream_rest = maxf(0.0, scream_rest - delta)


func apply_impact(speed: float, was_thrown: bool = false) -> void:
	if not finished and speed > Balance.MONA_SCREAM_SPEED and scream_rest <= 0.0:
		scream_rest = Balance.MONA_SCREAM_REST
		show_popup("AAAAAH!", Balance.DAMAGE_COLOUR)
		Sfx.play("scream", 1.0, Balance.MONA_SCREAM_DB)
		var arena: Node = get_parent()
		if arena.has_method("raise_alarm"):
			arena.raise_alarm(Balance.MONA_ALARM, last_carrier_slot, Balance.ALARM_SCREAM)
	super(speed, was_thrown)
