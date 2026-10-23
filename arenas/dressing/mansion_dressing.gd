# The Old Mansion's hand-placed dressing: decor, lamps and the grounds around the plot. It is its own scene,
# instanced into Mansion.tscn, so rebuilding the layout never wipes it. Lamp colours and strengths come from
# Balance (by group), so only positions live in the scene; only the moon casts shadows.
extends Node3D

# --- Setup ---
func _ready() -> void:
	_set_lamps("ceiling_lamps", Balance.LAMP_COLOUR, Balance.LAMP_ENERGY, Balance.LAMP_RANGE)
	_set_lamps("fires", Balance.FIRE_COLOUR, Balance.FIRE_ENERGY, Balance.FIRE_RANGE)
	_set_lamps("lanterns", Balance.LANTERN_COLOUR, Balance.LANTERN_ENERGY, Balance.LANTERN_RANGE)


# --- Helpers ---
func _set_lamps(group: String, colour: Color, energy: float, light_range: float) -> void:
	for lamp: OmniLight3D in find_children("*", "OmniLight3D"):
		if lamp.is_in_group(group):
			lamp.light_color = colour
			lamp.light_energy = energy
			lamp.omni_range = light_range
			lamp.shadow_enabled = false
