# The mover's character model: picks the clip from the mover's existing state, matches playback speed to ground
# speed so feet don't slide, and paints the slot's colours. Adapted from assets/source/mover/MOVER_GUIDE.md.
# Goofy physics: the body leans into speeding up, stopping and turning, and squashes or stretches on grabs, throws,
# landings and bumps, each on a springy settle. It only shows state; it never changes gameplay. The front is +Z.
class_name MoverModel
extends Node3D

enum Carry { NONE, LIGHT, MEDIUM, HEAVY, TEAM, DRAG }

# --- Clip names ---
const CLIP_PREFIX: String = "mover_"
const TINTED_MATERIALS: Array[String] = ["Mover_Team", "Mover_TeamTrim", "Mover_TeamDark"] # Overalls, cuffs, seams.

# --- Animation state ---
var player: AnimationPlayer
var mesh: MeshInstance3D
var clips: Dictionary = {} # Base name ("run") -> imported clip name ("mover_run").
var one_shot: String = "" # The one-shot playing now, which locomotion waits for.
var queue: Array[String] = []
var queue_speed: float = 1.0

# --- Goofy state ---
var body: Node3D # The instanced character; leaning and squashing move it about the feet.
var lean := Vector2.ZERO # Degrees: x tips the top forward, y tips it toward -X (the model's right).
var lean_velocity := Vector2.ZERO
var squash: float = 0.0 # Fraction of height; positive is shorter and wider.
var squash_velocity: float = 0.0

# --- Setup ---
func setup(scene: PackedScene, overalls: Color) -> void:
	# Instance the model under this node, find its player and mesh, and paint the overalls.
	body = scene.instantiate()
	add_child(body)
	player = body.find_children("*", "AnimationPlayer", true, false)[0]
	mesh = body.find_children("*", "MeshInstance3D", true, false)[0]
	for clip: StringName in player.get_animation_list():
		clips[String(clip).trim_prefix(CLIP_PREFIX)] = clip
	player.animation_finished.connect(_on_animation_finished)
	_tint(overalls)
	reset()


func reset() -> void:
	# Back to standing idle, dropping any one-shot: used when a round starts or the mover leaves play.
	one_shot = ""
	queue.clear()
	lean = Vector2.ZERO
	lean_velocity = Vector2.ZERO
	squash = 0.0
	squash_velocity = 0.0
	if player != null:
		player.speed_scale = 1.0
		player.play(clips["idle"])


# --- Continuous state, every physics frame ---
func face(direction: Vector3) -> void:
	# The mover's facing already turns smoothly, so the model simply follows it.
	if Vector2(direction.x, direction.z).length() > 0.01:
		rotation.y = atan2(direction.x, direction.z)


func update_wobble(acceleration: Vector3, delta: float) -> void:
	# Lean toward the mover's acceleration (in the model's own frame) and let squash spring back to normal.
	if body == null:
		return
	var local: Vector3 = acceleration.rotated(Vector3.UP, -rotation.y)
	var target := Vector2(local.z, -local.x) / Balance.LEAN_FULL_ACCELERATION
	target = target.limit_length(1.0) * Balance.LEAN_MAX * Balance.GOOFINESS
	lean_velocity += ((target - lean) * Balance.LEAN_STIFFNESS - lean_velocity * Balance.LEAN_DAMPING) * delta
	lean += lean_velocity * delta
	squash_velocity += (-squash * Balance.SQUASH_STIFFNESS - squash_velocity * Balance.SQUASH_DAMPING) * delta
	squash += squash_velocity * delta

	var tilt := Basis.from_euler(Vector3(deg_to_rad(lean.x), 0.0, deg_to_rad(lean.y)))
	var stretch := Vector3(1.0 + squash / 2.0, 1.0 - squash, 1.0 + squash / 2.0)
	body.transform.basis = tilt * Basis.from_scale(stretch)


func squish(amount: float) -> void:
	# Positive squashes, negative stretches; the spring in update_wobble brings it back with a little overshoot.
	squash = amount * Balance.GOOFINESS
	squash_velocity = 0.0


func update_locomotion(speed: float, carry: Carry, braced: bool, sliding: bool) -> void:
	if player == null or one_shot != "":
		return
	var base: String = _locomotion_clip(speed, carry)
	if braced:
		base = "brace"
	elif sliding:
		base = "slime_slide"
	var speed_scale: float = 1.0
	if Balance.MODEL_NATURAL_SPEEDS.has(base):
		var natural: float = Balance.MODEL_NATURAL_SPEEDS[base] * Balance.MOVER_MODEL_SCALE
		speed_scale = clampf(speed / natural, Balance.MODEL_SPEED_SCALE_MIN, Balance.MODEL_SPEED_SCALE_MAX)
	_play(base, speed_scale)


func _locomotion_clip(speed: float, carry: Carry) -> String:
	var moving: bool = speed > Balance.MODEL_MOVE_THRESHOLD
	match carry:
		Carry.LIGHT, Carry.MEDIUM:
			return "carry_run" if moving else "carry_idle"
		Carry.HEAVY:
			return "carry_heavy_walk" if moving else "carry_heavy_idle"
		Carry.TEAM:
			return "team_carry_walk" if moving else "team_carry_idle"
		Carry.DRAG:
			return "drag" if moving else "team_carry_idle"
	if not moving:
		return "idle"
	return "run" if speed > Balance.MODEL_WALK_RUN_SWITCH else "walk"


# --- One-shots, at the moment the gameplay event happens ---
func play_grab() -> void:
	_play_once("grab", 1.0)


func play_throw() -> void:
	_play_once("throw", 1.0)


func play_bank() -> void:
	_play_once("bank_cheer", 1.0)


func play_tumble(duration: float) -> void:
	# Fall and get up together in the mover's down time, sped up to fit.
	var length: float = player.get_animation(clips["tumble"]).length + player.get_animation(clips["get_up"]).length
	_play_once("tumble", length / duration, ["get_up"])


func _play_once(base: String, speed_scale: float, then: Array[String] = []) -> void:
	if player == null:
		return
	one_shot = base
	queue = then.duplicate()
	queue_speed = speed_scale
	player.speed_scale = speed_scale
	if player.current_animation == clips[base]:
		player.stop()
	player.play(clips[base], Balance.MODEL_BLEND_TIME)


func _on_animation_finished(_clip: StringName) -> void:
	if one_shot == "":
		return
	if queue.is_empty():
		one_shot = ""
		return
	_play_once(queue.pop_front(), queue_speed, queue)


# --- Helpers ---
func _play(base: String, speed_scale: float) -> void:
	var clip: StringName = clips.get(base, StringName())
	if clip.is_empty():
		return
	if player.current_animation != clip:
		player.play(clip, Balance.MODEL_BLEND_TIME)
	player.speed_scale = speed_scale


func _tint(overalls: Color) -> void:
	# The overalls take the slot colour; trim is lighter and seams darker, as in the guide.
	var tints: Dictionary = {
		TINTED_MATERIALS[0]: overalls,
		TINTED_MATERIALS[1]: overalls.lightened(Balance.MODEL_TRIM_LIGHTEN),
		TINTED_MATERIALS[2]: overalls.darkened(Balance.MODEL_SEAM_DARKEN),
	}
	for index: int in range(mesh.mesh.get_surface_count()):
		var source: BaseMaterial3D = mesh.mesh.surface_get_material(index) as BaseMaterial3D
		if source == null or not tints.has(source.resource_name):
			continue
		var material: BaseMaterial3D = source.duplicate()
		material.albedo_color = tints[source.resource_name]
		mesh.set_surface_override_material(index, material)
