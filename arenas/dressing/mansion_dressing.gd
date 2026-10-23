# The Old Mansion's hand-placed dressing inside the plot: decor and lamps. It is its own scene, instanced into
# Mansion.tscn, so rebuilding the layout never wipes it. Lamp and flame strengths come from Balance (by group),
# so only positions live in the scene; only the moon casts shadows. Decor colours are muted toward grey so
# nothing looks like loot. Everything outside the plot lives in MansionEnvironment.tscn.
extends Node3D

# --- Setup ---
func _ready() -> void:
	_set_lamps("ceiling_lamps", Balance.LAMP_COLOUR, Balance.LAMP_ENERGY, Balance.LAMP_RANGE)
	_set_lamps("fires", Balance.FIRE_COLOUR, Balance.FIRE_ENERGY, Balance.FIRE_RANGE)
	_set_lamps("lanterns", Balance.LANTERN_COLOUR, Balance.LANTERN_ENERGY, Balance.LANTERN_RANGE)
	for flame: MeshInstance3D in find_children("*", "MeshInstance3D"):
		if flame.is_in_group("flames"):
			flame.material_override.emission = Balance.FIRE_COLOUR
			flame.material_override.emission_energy_multiplier = Balance.FLAME_GLOW_ENERGY
	for body: StaticBody3D in find_children("*", "StaticBody3D"):
		body.collision_layer = Balance.WORLD_LAYER
		body.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	ArenaBuilder.mute_colours(self)


# --- Helpers ---
func _set_lamps(group: String, colour: Color, energy: float, light_range: float) -> void:
	for lamp: OmniLight3D in find_children("*", "OmniLight3D"):
		if lamp.is_in_group(group):
			lamp.add_to_group("flicker_lamps")
			lamp.light_color = colour
			lamp.light_energy = energy
			lamp.omni_range = light_range
			lamp.shadow_enabled = false
