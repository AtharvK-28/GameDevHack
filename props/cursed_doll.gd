# The cursed doll (Old Mansion, decision 140), in every round: put it down anywhere but the van and, after a few
# seconds, it giggles and walks back to the spot it was taken from, waddling and facing where it goes. Picking it up
# stops it; banking it ends it. It walks like the mummy's hand crawls (props/mummy_hand.gd), only faster.
class_name CursedDoll
extends MummyHand

func _ready() -> void:
	super()
	wait = Balance.DOLL_WAIT
	speed = Balance.DOLL_WALK_SPEED
	axis_lock_angular_x = true # It walks upright.
	axis_lock_angular_z = true


func _physics_process(delta: float) -> void:
	super(delta)
	if not crawling and model != null:
		model.rotation.z = 0.0 # Stands still again.


func _set_off() -> void:
	show_popup("hee hee hee…", Balance.DOLL_COLOUR)
	Sfx.play("giggle", randf_range(0.95, 1.05), Balance.DOLL_GIGGLE_DB)


func _step(step_velocity: Vector2) -> void:
	if model != null:
		model.rotation.y = atan2(step_velocity.x, step_velocity.y)
		model.rotation.z = sin(idle_time * TAU * Balance.DOLL_WADDLE_RATE) * deg_to_rad(Balance.DOLL_WADDLE_ANGLE)
