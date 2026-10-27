# The moon rock (Museum of Mostly Real Things): thrown, it drifts down in low gravity, so it is the one safe throw
# in the Museum. Everything else about it is ordinary loot; the floatiness ends at its first landing.
class_name MoonRock
extends Loot

func release(throw_velocity: Vector3 = Vector3.ZERO, by: CharacterBody3D = null) -> void:
	super(throw_velocity, by)
	if thrown:
		gravity_scale = Balance.MOON_ROCK_GRAVITY


func apply_impact(speed: float, was_thrown: bool = false) -> void:
	if gravity_scale < 1.0:
		gravity_scale = 1.0 # Back to Earth.
		was_thrown = false # A moon-rock landing counts as a plain bump, not a hard throw.
		thrown = false
	super(speed, was_thrown)
