# The fish tank (Old Mansion, decision 140): run with it and it sloshes, spilling water and fish, FISH_SPILL_RATE of
# its value a second, down to FISH_TANK_FLOOR_SHARE (the empty tank). Walk it carefully and nothing spills. The
# water inside drains as it loses value.
class_name FishTank
extends Loot

var spill_exact: float = 0.0
var spill_unshown: int = 0
var spill_time: float = 0.0
var water: Node3D

func _ready() -> void:
	super()
	water = model.find_child("Water", true, false) if model != null else null


func _physics_process(delta: float) -> void:
	super(delta)
	spill_time += delta
	if finished:
		return
	var floor_value: int = ceili(initial_value * Balance.FISH_TANK_FLOOR_SHARE)
	if is_held() and is_instance_valid(holder) and value > floor_value:
		var full: float = holder.movement_speed()
		var speed: float = Vector2(holder.velocity.x, holder.velocity.z).length()
		if full > 0.0 and speed >= full * Balance.PARROT_CALM_RATIO:
			spill_exact += initial_value * Balance.FISH_SPILL_RATE * delta
			var loss: int = mini(value - floor_value, floori(spill_exact))
			spill_exact -= loss
			if loss > 0:
				spill_unshown += loss
				_lose_value(loss)
			jiggle(Balance.JIGGLE_GRAB * 0.4 * sin(spill_time * 14.0))
	if spill_unshown > 0 and spill_time >= Balance.FISH_SLOSH_GAP:
		show_popup("SLOSH!\n−" + rupees(spill_unshown), Balance.FISH_COLOUR)
		Sfx.play("slosh", randf_range(0.9, 1.1), Balance.FISH_SLOSH_DB)
		Fx.burst(global_position + Vector3.UP * item_size.y / 2.0, Fx.Kind.SPARKLE, get_parent(), 0.6)
		spill_unshown = 0
		spill_time = 0.0
	if water != null:
		var left: float = clampf(float(value - floor_value) / maxf(1.0, initial_value - floor_value), 0.0, 1.0)
		water.scale.y = lerpf(Balance.FISH_WATER_MIN, 1.0, left)
