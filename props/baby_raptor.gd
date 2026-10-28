# The baby raptor that hatches from the dinosaur egg (decision 137): light loot that will not sit still. Loose, it
# scampers away from any mover who comes within BABY_SCARE_DISTANCE, in short dashes, playing its run; grabbed, it
# calms down. The model is Quaternius's velociraptor (CC0), fitted to BABY_HEIGHT. The Mansion's cat runs the same
# way in its own body (props/mansion_cat.gd).
class_name BabyRaptor
extends Loot

const MODEL_PATH: String = "res://assets/models/museum/polypizza/velociraptor.glb"

var raptor: Node3D # The body that turns to face each dash.
var player: AnimationPlayer
var clips: Dictionary = {}
var dash_left: float = 0.0
var rest_left: float = 0.0
var dash := Vector3.ZERO

func _ready() -> void:
	super()
	raptor = _build_runner()
	var players: Array[Node] = raptor.find_children("*", "AnimationPlayer", true, false)
	player = players[0] if not players.is_empty() else null
	if player != null:
		for animation: String in player.get_animation_list():
			for clip: String in ["Idle", "Run"]:
				if animation.ends_with("_" + clip):
					clips[clip] = animation
	_play("Idle")
	axis_lock_angular_x = true
	axis_lock_angular_z = true


func _build_runner() -> Node3D:
	var body: Node3D = load(MODEL_PATH).instantiate()
	var bounds: AABB = MuseumKit.bounds(body)
	var fit: float = Balance.BABY_HEIGHT / bounds.size.y
	body.scale *= fit
	body.position = Vector3(-bounds.get_center().x * fit, -bounds.position.y * fit - item_size.y / 2.0, -bounds.get_center().z * fit)
	add_child(body)
	ComicLook.apply(body, true)
	return body


func _physics_process(delta: float) -> void:
	super(delta)
	if finished:
		return
	rest_left = maxf(0.0, rest_left - delta)
	if is_held():
		dash_left = 0.0
		_play("Idle")
		return
	if dash_left > 0.0:
		dash_left -= delta
		linear_velocity = Vector3(dash.x, linear_velocity.y, dash.z)
		raptor.rotation.y = atan2(dash.x, dash.z)
		if dash_left <= 0.0:
			rest_left = Balance.BABY_REST
			_play("Idle")
		return
	if rest_left > 0.0:
		return
	# Anyone too close sets it off, away from them.
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		var away := Vector3(global_position.x - mover.global_position.x, 0.0, global_position.z - mover.global_position.z)
		if mover.get("in_play") and away.length() < Balance.BABY_SCARE_DISTANCE:
			dash = away.normalized() * Balance.BABY_SPEED
			dash_left = Balance.BABY_DASH_SECONDS
			_play("Run")
			_on_dash()
			return


func _on_dash() -> void:
	pass


func _play(clip: String) -> void:
	var animation: String = clips.get(clip, "")
	if player != null and not animation.is_empty() and player.current_animation != animation:
		player.play(animation, 0.15)
