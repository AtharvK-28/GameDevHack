# The mummy's hand (Museum of Mostly Real Things, decision 136): put it down anywhere but the van and, after a few
# seconds, it crawls back toward the spot it was taken from, slowly, its fingers scrabbling. Picking it up stops it;
# banking it ends it. Otherwise ordinary light loot.
class_name MummyHand
extends Loot

var home := Vector3.ZERO
var idle_time: float = 0.0
var crawling: bool = false

func _ready() -> void:
	super()
	home = position


func _physics_process(delta: float) -> void:
	super(delta)
	if finished or is_held() or thrown:
		idle_time = 0.0
		crawling = false
		return
	var arena_home: Vector3 = (get_parent() as Node3D).to_global(home) if get_parent() is Node3D else home
	var gap := Vector2(arena_home.x - global_position.x, arena_home.z - global_position.z)
	if gap.length() < Balance.MUMMY_HOME_RADIUS:
		crawling = false
		return
	idle_time += delta
	if idle_time < Balance.MUMMY_WAIT:
		return
	if not crawling:
		crawling = true
		show_popup("*scrabble scrabble*", Balance.MUMMY_COLOUR)
	var step: Vector2 = gap.normalized() * Balance.MUMMY_CRAWL_SPEED
	linear_velocity = Vector3(step.x, linear_velocity.y, step.y)
	jiggle(Balance.JIGGLE_GRAB * 0.5 * sin(idle_time * 18.0))
