class_name GhostModel
extends Node3D
## Drives an instanced ghost.glb: animations, face expressions (blend shapes),
## the glowing body and aura shaders, the spec's 25–45% opacity shimmer and a trailing-particle wisp.
## Put this on a Node3D inside GhostWisp.tscn and instance ghost.glb as its child.

const ANIM_PREFIX := "ghost_"
const LOOPING: Array[String] = ["idle", "move", "laugh", "stunned"]
const EXPRESSIONS: Array[StringName] = [&"Laugh", &"Grin", &"Squint", &"Stunned"]
const BODY_MATERIAL := "Ghost_Body"
const AURA_MATERIAL := "Ghost_Aura"
const MOVE_THRESHOLD := 0.3
## Wisp speed (m/s) at which "move" plays at 1.0x. The spec's wisp moves at 7 m/s.
const MOVE_ANIM_SPEED := 7.0
const BLEND_TIME := 0.15
## Where the trail emits from, near the tail tip (model space).
const TRAIL_OFFSET := Vector3(0.45, -0.45, 0.0)

@export var body_shader: Shader = preload("res://assets/shaders/ghost_body.gdshader")
@export var aura_shader: Shader = preload("res://assets/shaders/ghost_aura.gdshader")
## Overall tint for the glow: body core, rim and aura.
@export var glow_colour := Color(0.4, 0.8, 1.0):
	set(value):
		glow_colour = value
		_apply_glow_colour()
@export_range(0.0, 1.0) var opacity_min := 0.25
@export_range(0.0, 1.0) var opacity_max := 0.45
## Shimmer cycles per second.
@export var shimmer_speed := 1.2
## How fast faces blend between expressions (per second).
@export var expression_speed := 8.0
@export var trail_enabled := true

var _player: AnimationPlayer
var _mesh: MeshInstance3D
var _body_material: ShaderMaterial
var _aura_material: ShaderMaterial
var _trail: CPUParticles3D
var _names := {}  # base name ("idle") -> imported animation name
var _expression: StringName = &""
var _action := ""
var _action_timer := 0.0
var _pending_stun := 0.0
var _time := 0.0


func _ready() -> void:
	_player = find_children("*", "AnimationPlayer", true, false)[0]
	_mesh = find_children("*", "MeshInstance3D", true, false)[0]
	for anim_name in _player.get_animation_list():
		var base := anim_name.trim_prefix(ANIM_PREFIX).trim_suffix("-loop").trim_suffix("_loop")
		_names[base] = anim_name
		if base in LOOPING:
			_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_animation_finished)
	_setup_materials()
	if trail_enabled:
		_make_trail()
	_play("idle")


func _process(delta: float) -> void:
	_time += delta
	if _body_material:
		var wave := 0.5 + 0.5 * sin(_time * TAU * shimmer_speed) * cos(_time * TAU * shimmer_speed * 0.37)
		_body_material.set_shader_parameter(&"opacity", lerpf(opacity_min, opacity_max, wave))
	for shape in EXPRESSIONS:
		var index := _mesh.find_blend_shape_by_name(shape)
		if index < 0:
			continue
		var target := 1.0 if shape == _expression else 0.0
		var value := _mesh.get_blend_shape_value(index)
		_mesh.set_blend_shape_value(index, move_toward(value, target, expression_speed * delta))
	if _action_timer > 0.0:
		_action_timer -= delta
		if _action_timer <= 0.0:
			_end_action()


#region Continuous state
## Call every frame from the wisp while it is free (not possessing).
func update_motion(velocity: Vector3, delta: float) -> void:
	if _action != "" or not visible:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed > MOVE_THRESHOLD:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 1.0 - exp(-10.0 * delta))
		_play("move", clampf(speed / MOVE_ANIM_SPEED, 0.6, 1.6))
		_expression = &"Grin"
	else:
		_play("idle")
		_expression = &""


func is_busy() -> bool:
	return _action != ""
#endregion


#region Ghost actions
## Dives into the prop (0.5 s), then hides. Show again with play_emerge() or play_exorcised().
func play_possess() -> void:
	_start_action("possess", &"Squint")


## Leaving a prop: pops out with an overshoot (0.5 s).
func play_emerge() -> void:
	visible = true
	_start_action("emerge", &"Grin")


## Haunting, Curse or a prop action button (0.8 s).
func play_cast() -> void:
	_start_action("cast", &"Grin")


## Cackle, e.g. after something shatters.
func play_laugh(seconds := 1.5) -> void:
	_start_action("laugh", &"Laugh", seconds)


## Waves a claw at the movers (1 s).
func play_taunt() -> void:
	_start_action("taunt", &"Grin")


## Exorcism: blasted out of the prop (0.6 s), then dizzy until stun_seconds have passed.
func play_exorcised(stun_seconds := 1.0) -> void:
	visible = true
	_pending_stun = maxf(stun_seconds - _length("ejected"), 0.1)
	_start_action("ejected", &"Stunned")
#endregion


func _start_action(base: String, expression: StringName, seconds := 0.0) -> void:
	if not _names.has(base):
		return
	_action = base
	_expression = expression
	_action_timer = seconds
	_player.speed_scale = 1.0
	if _player.current_animation == _names[base]:
		_player.stop()
	_player.play(_names[base], BLEND_TIME)
	if _trail:
		_trail.emitting = base != "possess"


func _end_action() -> void:
	_action = ""
	_action_timer = 0.0
	_expression = &""
	_play("idle")


func _on_animation_finished(_anim_name: StringName) -> void:
	match _action:
		"possess":
			_action = ""
			visible = false
		"ejected":
			_start_action("stunned", &"Stunned", _pending_stun)
		"":
			pass
		_:
			if _action_timer <= 0.0:
				_end_action()


func _play(base: String, speed_scale := 1.0) -> void:
	var anim_name: String = _names.get(base, "")
	if anim_name == "":
		return
	if _player.current_animation != anim_name:
		_player.play(anim_name, BLEND_TIME)
	_player.speed_scale = speed_scale
	if _trail:
		_trail.emitting = true


func _length(base: String) -> float:
	return _player.get_animation(_names[base]).length if _names.has(base) else 0.0


## Swaps the imported body and aura materials for the glow shaders.
func _setup_materials() -> void:
	for i in _mesh.mesh.get_surface_count():
		var source := _mesh.mesh.surface_get_material(i)
		if source == null:
			continue
		if source.resource_name == BODY_MATERIAL:
			_body_material = ShaderMaterial.new()
			_body_material.shader = body_shader
			_mesh.set_surface_override_material(i, _body_material)
		elif source.resource_name == AURA_MATERIAL:
			_aura_material = ShaderMaterial.new()
			_aura_material.shader = aura_shader
			_mesh.set_surface_override_material(i, _aura_material)
	_apply_glow_colour()


func _apply_glow_colour() -> void:
	if _body_material:
		_body_material.set_shader_parameter(&"core_colour", glow_colour.darkened(0.1))
		_body_material.set_shader_parameter(&"rim_colour", glow_colour.lerp(Color.WHITE, 0.6))
	if _aura_material:
		_aura_material.set_shader_parameter(&"glow_colour", glow_colour)


func _make_trail() -> void:
	_trail = CPUParticles3D.new()
	_trail.amount = 24
	_trail.lifetime = 0.8
	_trail.local_coords = false
	_trail.position = TRAIL_OFFSET
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 0.15
	_trail.direction = Vector3.DOWN
	_trail.spread = 35.0
	_trail.initial_velocity_min = 0.1
	_trail.initial_velocity_max = 0.3
	_trail.gravity = Vector3(0.0, 0.25, 0.0)
	_trail.scale_amount_min = 0.6
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	_trail.scale_amount_curve = shrink
	var fade := Gradient.new()
	fade.set_color(0, Color(0.7, 0.95, 1.0, 0.6))
	fade.set_color(1, Color(0.6, 0.5, 1.0, 0.0))
	_trail.color_ramp = fade
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = material
	_trail.mesh = sphere
	add_child(_trail)
