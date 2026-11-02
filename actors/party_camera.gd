# The shared screen's camera: a three-quarter dollhouse view, its angles set in Balance (CAMERA_ANGLE, CAMERA_YAW).
# With follow_movers on, it eases toward the centre of the movers in play and pulls back far enough to frame them
# all (12–22 m), clamped to the arena; the ghost joins the framing only while it is near the crew. Shake
# (trauma² × noise) is only raised by abilities such as House Shake.
# Camera-facing walls (FadeWall) turn see-through while the line from the camera to a player passes through them.
extends Camera3D

# --- Settings ---
var arena_yaw: float = Balance.CAMERA_YAW
var pitch_degrees: float = Balance.CAMERA_ANGLE
var limit_overview: bool = false
var follow_movers: bool = false # Off for the fixed regression view; the match turns it on.
var bounds: Rect2 = Balance.CAMERA_BOUNDS # The x/z area the focus may move within; set from the arena.

# --- Framing and shake state ---
var focus: Vector3 = Balance.CAMERA_TARGET
var distance: float = Balance.CAMERA_DISTANCE
var trauma: float = 0.0
var noise := FastNoiseLite.new()
var time: float = 0.0
var punch_point := Vector3.ZERO # A big smash the camera is easing in on.
var punch_left: float = 0.0 # Real seconds left.

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



# --- Big smash ---
func punch_in(point: Vector3) -> void:
	punch_point = point
	punch_left = Balance.SMASH_SLOWMO_SECONDS * 2.0 # Holds a moment after the slow motion ends, then eases back.


# --- Following ---
func _process(delta: float) -> void:
	time += delta
	trauma = maxf(0.0, trauma - Balance.TRAUMA_DECAY * delta)
	if follow_movers:
		var framing: Array = _framing()
		var blend: float = 1.0 - exp(-Balance.CAMERA_FOLLOW_RATE * delta)
		if punch_left > 0.0:
			# Real time, so the slow motion doesn't slow the punch-in itself.
			var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
			punch_left -= real_delta
			blend = 1.0 - exp(-Balance.CAMERA_FOLLOW_RATE * 2.0 * real_delta)
			framing = [framing[0].lerp(Vector3(punch_point.x, 0.0, punch_point.z), Balance.SMASH_PUNCH_FOCUS), Balance.SMASH_PUNCH_DISTANCE]
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


func _mover_points() -> Array[Vector3]:
	# Every mover in play. The framing follows these; the ghost only joins when it is already close by.
	var points: Array[Vector3] = []
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		points.append(mover.global_position)
	return points


func _ghost_points() -> Array[Vector3]:
	# Where the wisp is, or the prop it is hiding in.
	var points: Array[Vector3] = []
	for ghost: Node3D in get_tree().get_nodes_in_group("ghosts"):
		points.append(ghost.possessing.global_position if is_instance_valid(ghost.possessing) else ghost.global_position)
	return points


func _centre(points: Array[Vector3]) -> Vector3:
	var centre := Vector3.ZERO
	for point: Vector3 in points:
		centre += point
	return centre / maxf(1.0, points.size())


func _spread(points: Array[Vector3], centre: Vector3) -> float:
	var spread: float = 0.0
	for point: Vector3 in points:
		spread = maxf(spread, Vector2(point.x - centre.x, point.z - centre.z).length())
	return spread


func _framing() -> Array:
	# [focus point, distance]: the centre of everyone being framed, pulled back until they fit with some padding.
	# The ghost counts as one of them only while it is within CAMERA_GHOST_CUSHION of the crew; a ghost in a far
	# corner used to force the whole arena into view and shrink everybody (decision 149).
	var points: Array[Vector3] = _mover_points()
	var have_movers: bool = not points.is_empty()
	if not have_movers:
		points = _ghost_points() # Ghost-only scenes still frame the ghost.
	if points.is_empty():
		var centre_2d: Vector2 = bounds.get_center()
		var overview: float = (bounds.size.length() / 2.0 + Balance.CAMERA_FRAME_PADDING) / (tan(deg_to_rad(fov / 2.0)) * Balance.CAMERA_SAFE_VIEW)
		if limit_overview:
			overview = clampf(overview, Balance.CAMERA_MIN_DISTANCE, Balance.CAMERA_MAX_DISTANCE)
		return [Vector3(centre_2d.x, 0.0, centre_2d.y), overview]
	# A ghost near the crew is framed like one of them; one prowling a far corner is left out of frame entirely,
	# rather than dragging the camera back until everybody is too small to tell apart.
	var crew_centre: Vector3 = _centre(points)
	var crew_spread: float = _spread(points, crew_centre)
	if have_movers:
		for ghost_point: Vector3 in _ghost_points():
			var reach: float = Vector2(ghost_point.x - crew_centre.x, ghost_point.z - crew_centre.z).length()
			if reach <= crew_spread + Balance.CAMERA_GHOST_CUSHION:
				points.append(ghost_point)

	var centre: Vector3 = _centre(points)
	var spread: float = _spread(points, centre)
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
	var pitch: float = deg_to_rad(pitch_degrees)
	var yaw: float = deg_to_rad(arena_yaw)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	look_at_from_position(focus + back * distance, focus)
	transform = transform.translated_local(offset).rotated_local(Vector3.BACK, roll)
