# The mummy's hand (Museum of Mostly Real Things, decision 136): put it down anywhere but the van and, after a few
# seconds, it crawls back toward the spot it was taken from, slowly, its fingers scrabbling. Picking it up stops it;
# banking it ends it. Otherwise ordinary light loot. The Mansion's cursed doll walks home the same way
# (props/cursed_doll.gd).
class_name MummyHand
extends Loot

var home := Vector3.ZERO
var idle_time: float = 0.0
var crawling: bool = false
var wait: float = Balance.MUMMY_WAIT
var speed: float = Balance.MUMMY_CRAWL_SPEED

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
	if idle_time < wait:
		return
	if not crawling:
		crawling = true
		_set_off()
	var step: Vector2 = gap.normalized() * speed
	linear_velocity = Vector3(step.x, linear_velocity.y, step.y)
	_step(step)


func _set_off() -> void:
	show_popup("*scrabble scrabble*", Balance.MUMMY_COLOUR)


func _step(_step_velocity: Vector2) -> void:
	jiggle(Balance.JIGGLE_GRAB * 0.5 * sin(idle_time * 18.0))
