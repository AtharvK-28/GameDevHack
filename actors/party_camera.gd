# The shared screen's camera: a three-quarter dollhouse view, its angles set in Balance (CAMERA_ANGLE, CAMERA_YAW).
# With follow_movers on, it eases toward the centre of the movers in play and the ghost, and pulls back far
# enough to frame them all (12–26 m), clamped to the arena. Shake (trauma² × noise) is only raised by abilities such as House Shake.
# Camera-facing walls (FadeWall) turn see-through while the line from the camera to a player passes through them.
extends Camera3D

# --- Settings ---
var follow_movers: bool = false # Off for the fixed regression view; the match turns it on.
var bounds: Rect2 = Balance.CAMERA_BOUNDS # The x/z area the focus may move within; set from the arena.

# --- Framing and shake state ---
var focus: Vector3 = Balance.CAMERA_TARGET
var distance: float = Balance.CAMERA_DISTANCE
var trauma: float = 0.0
var noise := FastNoiseLite.new()
var time: float = 0.0

# --- Setup ---
func _ready() -> void:
	add_to_group("party_camera")
	process_mode = Node.PROCESS_MODE_ALWAYS # Keeps easing while the match is paused between rounds.
	noise.frequency = 1.0 # Sampled at CAMERA_SHAKE_FREQUENCY units per second.
	current = true
	_place(Vector3.ZERO, 0.0)


# --- Shake ---
func shake(amount: float) -> void:
	# Raise the trauma to at least this much, 0 to 1; it then fades at TRAUMA_DECAY per second.
	trauma = clampf(maxf(trauma, amount), 0.0, 1.0)


# --- Following ---
func _process(delta: float) -> void:
	time += delta
	trauma = maxf(0.0, trauma - Balance.TRAUMA_DECAY * delta)
	if follow_movers:
		var framing: Array = _framing()
		var blend: float = 1.0 - exp(-Balance.CAMERA_FOLLOW_RATE * delta)
		focus = focus.lerp(framing[0], blend)
		distance = lerpf(distance, framing[1], blend)

	# Shake: shake = trauma² × noise, as a small offset and roll.
	var strength: float = trauma * trauma
	var sample: float = time * Balance.CAMERA_SHAKE_FREQUENCY
	var offset := Vector3(noise.get_noise_2d(sample, 0.0), noise.get_noise_2d(sample, 100.0), 0.0) * Balance.CAMERA_SHAKE_OFFSET * strength
	var roll: float = noise.get_noise_2d(sample, 200.0) * deg_to_rad(Balance.CAMERA_SHAKE_ROLL) * strength
	_place(offset, roll)
	_update_wall_fade(delta)


func snap() -> void:
	# Jump straight to the framing, for the start of a round.
	if follow_movers:
		var framing: Array = _framing()
		focus = framing[0]
		distance = framing[1]
	_place(Vector3.ZERO, 0.0)


func _player_points() -> Array[Vector3]:
	# Every mover in play, and the ghost: where the wisp is, or the prop it is hiding in.
	var points: Array[Vector3] = []
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		points.append(mover.global_position)
	for ghost: Node3D in get_tree().get_nodes_in_group("ghosts"):
		points.append(ghost.possessing.global_position if is_instance_valid(ghost.possessing) else ghost.global_position)
	return points


func _framing() -> Array:
	# [focus point, distance]: the players' centre, pulled back until all of them fit with some padding.
	var points: Array[Vector3] = _player_points()
	if points.is_empty():
		return [Balance.CAMERA_TARGET, Balance.CAMERA_DISTANCE]
	var centre := Vector3.ZERO
	for point: Vector3 in points:
		centre += point
	centre /= points.size()
	var spread: float = 0.0
	for point: Vector3 in points:
		spread = maxf(spread, Vector2(point.x - centre.x, point.z - centre.z).length())
	var half_view: float = tan(deg_to_rad(fov / 2.0)) * Balance.CAMERA_SAFE_VIEW
	var needed: float = (spread + Balance.CAMERA_FRAME_PADDING) / half_view
	centre.x = clampf(centre.x, bounds.position.x, bounds.end.x)
	centre.z = clampf(centre.z, bounds.position.y, bounds.end.y)
	centre.y = 0.0
	return [centre, clampf(needed, Balance.CAMERA_MIN_DISTANCE, Balance.CAMERA_MAX_DISTANCE)]


# --- Wall fade ---
func _update_wall_fade(delta: float) -> void:
	# A wall hides a player when the line from the camera to their head or feet passes through it.
	var points: Array[Vector3] = _player_points()
	var reach := Vector3.UP * Balance.WALL_FADE_REACH
	for wall: FadeWall in get_tree().get_nodes_in_group("fade_walls"):
		var hiding: bool = false
		for point: Vector3 in points:
			if wall.box.intersects_segment(global_position, point + reach) or wall.box.intersects_segment(global_position, point - reach):
				hiding = true
				break
		wall.update_fade(hiding, delta)


func _place(offset: Vector3, roll: float) -> void:
	var pitch: float = deg_to_rad(Balance.CAMERA_ANGLE)
	var yaw: float = deg_to_rad(Balance.CAMERA_YAW)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	look_at_from_position(focus + back * distance, focus)
	transform = transform.translated_local(offset).rotated_local(Vector3.BACK, roll)
