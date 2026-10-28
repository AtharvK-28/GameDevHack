# The Museum's animatronic T-Rex (decision 132): a life-size exhibit in the Jurassic Hall, and Bahadur's favourite
# toy. Furniture the ghost possesses like the sofa: the stick walks it (it turns to face where it goes and plays its
# walk), and SHOVE is a charge, with its attack and a roar. Movers cannot carry it. The model is Quaternius's
# animated T-Rex (CC0), fitted to ANIMATRONIC_HEIGHT; its collider is a square box, so turning never snags it.
extends RigidBody3D

const MODEL_PATH: String = "res://assets/models/museum/polypizza/trex.glb"

var item_name: String = "Animatronic T-Rex"
var item_size: Vector3 = Balance.ANIMATRONIC_SIZE
var weight_class: int = Balance.HEAVY
var model: Node3D
var player: AnimationPlayer
var clips: Dictionary = {} # "Idle", "Walk", "Attack" -> the model's animation names.
var was_launched: bool = false
var attack_left: float = 0.0

func _ready() -> void:
	add_to_group("furniture")
	mass = Balance.WEIGHT_MASSES[weight_class]
	collision_layer = Balance.LOOT_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	linear_damp = Balance.LOOT_LINEAR_DAMP
	axis_lock_angular_x = true # It never tips or spins; only its look turns to face where it walks.
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = Balance.LOOT_FRICTION
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = item_size
	collision.shape = box
	add_child(collision)
	model = load(MODEL_PATH).instantiate()
	var bounds: AABB = MuseumKit.bounds(model)
	var fit: float = Balance.ANIMATRONIC_HEIGHT / bounds.size.y
	model.scale *= fit
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * fit - Vector3.UP * item_size.y / 2.0
	var pivot := Node3D.new() # Turns the model to face its travel.
	pivot.name = "Facing"
	pivot.rotation.y = deg_to_rad(Balance.ANIMATRONIC_START_YAW)
	pivot.add_child(model)
	add_child(pivot)
	ComicLook.apply(model, true)
	ComicLook.tint(model, Balance.ANIMATRONIC_TINT)
	player = model.find_children("*", "AnimationPlayer", true, false)[0]
	for animation: String in player.get_animation_list():
		for clip: String in ["Idle", "Walk", "Attack"]:
			if animation.ends_with("_" + clip):
				clips[clip] = animation
	_play("Idle")


func _physics_process(delta: float) -> void:
	var flat := Vector2(linear_velocity.x, linear_velocity.z)
	var possession: Node = get_node_or_null("Possessable")
	var launched: bool = possession != null and possession.launched
	if launched and not was_launched:
		# SHOVE: it charges with its jaws open and a roar.
		attack_left = Balance.ANIMATRONIC_ATTACK_SECONDS
		_play("Attack")
		Sfx.play("roar", 1.0, Balance.ANIMATRONIC_ROAR_DB)
		get_tree().call_group("party_camera", "shake", Balance.ANIMATRONIC_ROAR_TRAUMA)
	was_launched = launched
	attack_left = maxf(0.0, attack_left - delta)
	if flat.length() > Balance.ANIMATRONIC_TURN_SPEED:
		var facing: Node3D = $Facing
		var wanted: float = atan2(flat.x, flat.y) + deg_to_rad(Balance.ANIMATRONIC_FACING_OFFSET)
		facing.rotation.y = lerp_angle(facing.rotation.y, wanted, minf(1.0, delta * Balance.ANIMATRONIC_TURN_RATE))
	if attack_left <= 0.0:
		_play("Walk" if flat.length() > Balance.ANIMATRONIC_TURN_SPEED else "Idle")
		player.speed_scale = clampf(flat.length() / Balance.ANIMATRONIC_WALK_PACE, 0.6, 2.0) if player.current_animation == clips.get("Walk", "") else 1.0


func _play(clip: String) -> void:
	var animation: String = clips.get(clip, "")
	if animation.is_empty() or player.current_animation == animation:
		return
	player.play(animation, 0.2)
