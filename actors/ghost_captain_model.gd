# The Ghost Ship's ghost: a drowned captain, built here from simple low-poly shapes so the model is
# the project's own. He has no rig and no clips, so this script does the animating itself: hovering,
# turning to face his travel, leaning into it, a swaying tentacle beard, and the pop, shake and tumble
# that the ghost's actions need. A ghost-green edge says he is the ghost.
class_name GhostCaptainModel
extends GhostAvatar

const SHADER := preload("res://assets/shaders/ghost_apparition.gdshader")

# --- State ---
var body: Node3D # Every part hangs off this, dropped so he hovers upright over the deck.
var materials: Array[ShaderMaterial] = [] # One per part, so the shimmer reaches all of him.
var beard: Array[Node3D] = [] # Tentacle pivots, swayed every frame.
var action: String = "" # "", "emerge", "cast" or "eject".
var action_left: float = 0.0
var dizzy_left: float = 0.0 # Wobbles for this long after being blasted out of a prop.
var lean: float = 0.0 # Current forward lean, eased toward his speed.
var sway_time: float = 0.0


# --- Setup ---
func _ready() -> void:
	body = Node3D.new()
	body.name = "Body"
	body.position.y = Balance.CAPTAIN_DROP
	add_child(body)
	_build()


func _build() -> void:
	# Heights are from the tip of his tail; he stands 2.0 m to the hat's crown, over the 1.6 m movers.
	# A wispy tail where legs would be.
	_part(_cylinder(0.40, 0.04, 0.75), Vector3(0, 0.38, 0), Balance.CAPTAIN_TAIL_COLOUR)
	# Long coat, belt and buckle, and two rows of gold buttons down the front.
	_part(_cylinder(0.30, 0.42, 0.78), Vector3(0, 1.0, 0), Balance.CAPTAIN_COAT_COLOUR)
	_part(_cylinder(0.37, 0.37, 0.08), Vector3(0, 0.86, 0), Balance.CAPTAIN_HAT_COLOUR)
	_part(_box(Vector3(0.12, 0.1, 0.04)), Vector3(0, 0.86, 0.37), Balance.CAPTAIN_TRIM_COLOUR)
	for row: int in range(3):
		for side: float in [-0.1, 0.1]:
			_part(_sphere(0.035), Vector3(side, 1.02 + row * 0.11, 0.34 - row * 0.02), Balance.CAPTAIN_TRIM_COLOUR)
	# Gold epaulettes, sleeves and pale hands; the left hand holds a lantern.
	for side: float in [-1.0, 1.0]:
		_part(_cylinder(0.12, 0.12, 0.05), Vector3(side * 0.3, 1.38, 0), Balance.CAPTAIN_TRIM_COLOUR)
		var arm: MeshInstance3D = _part(_capsule(0.08, 0.6), Vector3(side * 0.4, 1.12, 0.05), Balance.CAPTAIN_COAT_COLOUR)
		arm.rotation = Vector3(-0.3, 0, side * 0.35)
		_part(_sphere(0.075), Vector3(side * 0.5, 0.86, 0.14), Balance.CAPTAIN_SKIN_COLOUR)
	_part(_box(Vector3(0.14, 0.18, 0.14)), Vector3(-0.5, 0.72, 0.16), Balance.CAPTAIN_LANTERN_COLOUR)
	_part(_cylinder(0.05, 0.09, 0.05), Vector3(-0.5, 0.835, 0.16), Balance.CAPTAIN_HAT_COLOUR)
	# Head, glowing eyes and a beard of tentacles that sway on their own.
	_part(_sphere(0.21), Vector3(0, 1.58, 0), Balance.CAPTAIN_SKIN_COLOUR)
	for side: float in [-0.08, 0.08]:
		_part(_sphere(0.04), Vector3(side, 1.62, 0.18), Balance.CAPTAIN_EYE_COLOUR)
	for index: int in range(5):
		var pivot := Node3D.new()
		pivot.position = Vector3((index - 2) * 0.07, 1.46, 0.24 - absf(index - 2) * 0.03)
		body.add_child(pivot)
		beard.append(pivot)
		var length: float = 0.4 - absf(index - 2) * 0.07
		_part(_capsule(0.04, length), Vector3(0, -length * 0.5, 0), Balance.CAPTAIN_BEARD_COLOUR, pivot)
	# Tricorn hat: a three-cornered brim with a crown, a gold band and a skull badge.
	var brim: MeshInstance3D = _part(_cylinder(0.48, 0.48, 0.07, 3), Vector3(0, 1.79, 0), Balance.CAPTAIN_HAT_COLOUR)
	brim.rotation.y = PI # One corner points forward.
	_part(_cylinder(0.17, 0.2, 0.2), Vector3(0, 1.9, 0), Balance.CAPTAIN_HAT_COLOUR)
	_part(_cylinder(0.205, 0.205, 0.04), Vector3(0, 1.83, 0), Balance.CAPTAIN_TRIM_COLOUR)
	_part(_sphere(0.05), Vector3(0, 1.9, 0.19), Color.WHITE)


func _part(mesh: Mesh, at: Vector3, colour: Color, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # A shadow would give him away.
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"base_colour", colour)
	material.set_shader_parameter(&"tint_amount", Balance.CAPTAIN_TINT_AMOUNT)
	material.set_shader_parameter(&"rim_colour", Balance.CAPTAIN_RIM_COLOUR)
	material.set_shader_parameter(&"rim_glow", Balance.CAPTAIN_RIM_GLOW)
	material.set_shader_parameter(&"rim_power", Balance.CAPTAIN_RIM_POWER)
	material.set_shader_parameter(&"self_glow", Balance.CAPTAIN_SELF_GLOW)
	material.set_shader_parameter(&"rim_opacity", Balance.CAPTAIN_RIM_OPACITY)
	part.material_override = material
	materials.append(material)
	(parent if parent != null else body).add_child(part)
	return part


func _cylinder(top: float, bottom: float, height: float, sides: int = 8) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 2
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


# --- Continuous state ---
func update_motion(velocity: Vector3, delta: float) -> void:
	# An action owns his pose while it plays, so travel never fights it.
	if action != "":
		return

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = flat.length()
	if speed > Balance.CAPTAIN_MOVE_THRESHOLD:
		var facing: float = atan2(flat.x, flat.z) + Balance.CAPTAIN_FACING_OFFSET
		rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-Balance.CAPTAIN_TURN_RATE * delta))

	var wanted: float = Balance.CAPTAIN_LEAN * minf(1.0, speed / Balance.WISP_SPEED)
	lean = lerpf(lean, wanted, 1.0 - exp(-Balance.CAPTAIN_LEAN_RATE * delta))


func is_busy() -> bool:
	return action != ""


func apply_shimmer(colour: Color, alpha: float) -> void:
	# The wisp's own shimmer drives his opacity, so he fades in step with the Mansion ghost, and its
	# frozen tint washes him out after an exorcism.
	var opacity: float = remap(alpha, Balance.WISP_ALPHA_MIN, Balance.WISP_ALPHA_MAX, Balance.CAPTAIN_ALPHA_MIN, Balance.CAPTAIN_ALPHA_MAX)
	# His own sea-green wash normally; the wisp's frozen tint takes over after an exorcism.
	var frozen: bool = colour == Balance.WISP_FROZEN_COLOUR
	var tint: Color = colour if frozen else Balance.CAPTAIN_TINT_COLOUR
	for material: ShaderMaterial in materials:
		material.set_shader_parameter(&"opacity", opacity)
		material.set_shader_parameter(&"tint", tint)
		material.set_shader_parameter(&"tint_amount", Balance.CAPTAIN_FROZEN_TINT_AMOUNT if frozen else Balance.CAPTAIN_TINT_AMOUNT)


# --- Ghost actions ---
func play_emerge() -> void:
	_start("emerge", Balance.CAPTAIN_EMERGE_TIME)


func play_cast() -> void:
	_start("cast", Balance.CAPTAIN_CAST_TIME)


func play_exorcised(stun_seconds: float = 1.0) -> void:
	dizzy_left = maxf(stun_seconds - Balance.CAPTAIN_EJECT_TIME, 0.1)
	_start("eject", Balance.CAPTAIN_EJECT_TIME)


# --- Animation ---
func _process(delta: float) -> void:
	sway_time += delta

	if action != "":
		action_left -= delta
		if action_left <= 0.0:
			action = ""
	elif dizzy_left > 0.0:
		dizzy_left -= delta

	_pose()


func _pose() -> void:
	# One place decides how he sits: the idle sway and travel lean, plus any action playing over them.
	var tilt_x: float = lean
	var tilt_z: float = sin(TAU * Balance.CAPTAIN_SWAY_RATE * sway_time) * Balance.CAPTAIN_SWAY_ANGLE
	var spin: float = 0.0
	var swell: float = 1.0

	match action:
		"emerge":
			# Pops out of the prop, swelling past full size and settling back.
			var progress: float = 1.0 - action_left / Balance.CAPTAIN_EMERGE_TIME
			swell = 1.0 + Balance.CAPTAIN_EMERGE_OVERSHOOT * sin(PI * progress)
		"cast":
			tilt_x += Balance.CAPTAIN_LEAN
			tilt_z += sin(TAU * Balance.CAPTAIN_CAST_SHAKE_RATE * sway_time) * Balance.CAPTAIN_CAST_SHAKE
		"eject":
			# Blasted out and tumbling, straightening up as he slows.
			var progress: float = 1.0 - action_left / Balance.CAPTAIN_EJECT_TIME
			spin = TAU * Balance.CAPTAIN_EJECT_SPINS * progress
			tilt_x += Balance.CAPTAIN_LEAN * 2.0 * (1.0 - progress)
		_:
			if dizzy_left > 0.0:
				tilt_z += sin(TAU * Balance.CAPTAIN_DIZZY_RATE * sway_time) * Balance.CAPTAIN_DIZZY_ANGLE

	body.rotation = Vector3(tilt_x, spin, tilt_z)
	body.scale = Vector3.ONE * swell

	# The beard trails behind his lean and sways on its own.
	for index: int in range(beard.size()):
		var phase: float = TAU * Balance.CAPTAIN_BEARD_RATE * sway_time + index * 1.1
		beard[index].rotation = Vector3(sin(phase) * Balance.CAPTAIN_BEARD_SWAY * 0.5 - Balance.CAPTAIN_BEARD_TILT - lean, 0.0, cos(phase) * Balance.CAPTAIN_BEARD_SWAY)


# --- Helpers ---
func _start(name: String, length: float) -> void:
	action = name
	action_left = length
