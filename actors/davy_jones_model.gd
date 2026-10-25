# The Ghost Ship's ghost: Davy Jones. The model is a single static pose with no rig and no clips,
# so this script does the animating itself: hovering, turning to face his travel, leaning into it,
# and the pop, shake and tumble that the ghost's actions need. He keeps his own textures and gains
# a ghost-green edge, so he reads as himself and still reads as the ghost.
class_name DavyJonesModel
extends GhostAvatar

const SHADER := preload("res://assets/shaders/ghost_apparition.gdshader")

# --- State ---
var body: Node3D # The instanced model, scaled and dropped so he hovers upright over the deck.
var materials: Array[ShaderMaterial] = [] # One per surface, so the shimmer reaches all of him.
var action: String = "" # "", "emerge", "cast" or "eject".
var action_left: float = 0.0
var dizzy_left: float = 0.0 # Wobbles for this long after being blasted out of a prop.
var lean: float = 0.0 # Current forward lean, eased toward his speed.
var sway_time: float = 0.0


# --- Setup ---
func _ready() -> void:
	body = load(Balance.DAVY_MODEL_PATH).instantiate()
	body.scale = Vector3.ONE * Balance.DAVY_MODEL_SCALE
	body.position.y = Balance.DAVY_DROP
	add_child(body)

	for part: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # A shadow would give him away.
		_ghost_surfaces(part)


func _ghost_surfaces(part: MeshInstance3D) -> void:
	# Every surface keeps its own texture and gains the apparition shader over the top.
	for surface: int in range(part.mesh.get_surface_count()):
		var source: BaseMaterial3D = part.mesh.surface_get_material(surface)
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter(&"albedo_texture", source.albedo_texture if source != null else null)
		material.set_shader_parameter(&"tint_amount", Balance.DAVY_TINT_AMOUNT)
		material.set_shader_parameter(&"rim_colour", Balance.DAVY_RIM_COLOUR)
		material.set_shader_parameter(&"rim_glow", Balance.DAVY_RIM_GLOW)
		material.set_shader_parameter(&"rim_power", Balance.DAVY_RIM_POWER)
		material.set_shader_parameter(&"self_glow", Balance.DAVY_SELF_GLOW)
		material.set_shader_parameter(&"rim_opacity", Balance.DAVY_RIM_OPACITY)
		part.set_surface_override_material(surface, material)
		materials.append(material)


# --- Continuous state ---
func update_motion(velocity: Vector3, delta: float) -> void:
	# An action owns his pose while it plays, so travel never fights it.
	if action != "":
		return

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = flat.length()
	if speed > Balance.DAVY_MOVE_THRESHOLD:
		var facing: float = atan2(flat.x, flat.z) + Balance.DAVY_FACING_OFFSET
		rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-Balance.DAVY_TURN_RATE * delta))

	var wanted: float = Balance.DAVY_LEAN * minf(1.0, speed / Balance.WISP_SPEED)
	lean = lerpf(lean, wanted, 1.0 - exp(-Balance.DAVY_LEAN_RATE * delta))


func is_busy() -> bool:
	return action != ""


func apply_shimmer(colour: Color, alpha: float) -> void:
	# The wisp's own shimmer drives his opacity, so he fades in step with the Mansion ghost, and its
	# frozen tint washes him out after an exorcism.
	var opacity: float = remap(alpha, Balance.WISP_ALPHA_MIN, Balance.WISP_ALPHA_MAX, Balance.DAVY_ALPHA_MIN, Balance.DAVY_ALPHA_MAX)
	# His own sea-green wash normally; the wisp's frozen tint takes over after an exorcism.
	var frozen: bool = colour == Balance.WISP_FROZEN_COLOUR
	var tint: Color = colour if frozen else Balance.DAVY_TINT_COLOUR
	for material: ShaderMaterial in materials:
		material.set_shader_parameter(&"opacity", opacity)
		material.set_shader_parameter(&"tint", tint)
		material.set_shader_parameter(&"tint_amount", Balance.DAVY_FROZEN_TINT_AMOUNT if frozen else Balance.DAVY_TINT_AMOUNT)


# --- Ghost actions ---
func play_emerge() -> void:
	_start("emerge", Balance.DAVY_EMERGE_TIME)


func play_cast() -> void:
	_start("cast", Balance.DAVY_CAST_TIME)


func play_exorcised(stun_seconds: float = 1.0) -> void:
	dizzy_left = maxf(stun_seconds - Balance.DAVY_EJECT_TIME, 0.1)
	_start("eject", Balance.DAVY_EJECT_TIME)


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
	var tilt_z: float = sin(TAU * Balance.DAVY_SWAY_RATE * sway_time) * Balance.DAVY_SWAY_ANGLE
	var spin: float = 0.0
	var swell: float = 1.0

	match action:
		"emerge":
			# Pops out of the prop, swelling past full size and settling back.
			var progress: float = 1.0 - action_left / Balance.DAVY_EMERGE_TIME
			swell = 1.0 + Balance.DAVY_EMERGE_OVERSHOOT * sin(PI * progress)
		"cast":
			tilt_x += Balance.DAVY_LEAN
			tilt_z += sin(TAU * Balance.DAVY_CAST_SHAKE_RATE * sway_time) * Balance.DAVY_CAST_SHAKE
		"eject":
			# Blasted out and tumbling, straightening up as he slows.
			var progress: float = 1.0 - action_left / Balance.DAVY_EJECT_TIME
			spin = TAU * Balance.DAVY_EJECT_SPINS * progress
			tilt_x += Balance.DAVY_LEAN * 2.0 * (1.0 - progress)
		_:
			if dizzy_left > 0.0:
				tilt_z += sin(TAU * Balance.DAVY_DIZZY_RATE * sway_time) * Balance.DAVY_DIZZY_ANGLE

	body.rotation = Vector3(tilt_x, spin, tilt_z)
	body.scale = Vector3.ONE * Balance.DAVY_MODEL_SCALE * swell


# --- Helpers ---
func _start(name: String, length: float) -> void:
	action = name
	action_left = length
