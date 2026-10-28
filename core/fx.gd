# Comic effects: short particle bursts (dust, sparks, shards, sparkles, ghost puffs) and the ghost's trail.
# Visual only; nothing here touches physics. Every number lives in Balance (FX_*).
class_name Fx
extends RefCounted

enum Kind { DUST, SPARKS, SHARDS, SPARKLE, GHOST_PUFF } # Indexes Balance.FX_BURSTS.

static var dot_texture: Texture2D # Built once, shared by every effect.


static func burst(at: Vector3, kind: Kind, parent: Node, amount_scale: float = 1.0) -> void:
	# A one-shot burst at a world position; it frees itself once its particles are gone.
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	DisasterCam.note_burst(at, kind, amount_scale)
	var settings: Dictionary = Balance.FX_BURSTS[kind]
	var particles := _particles(settings.colour, settings.size, settings.lifetime, settings.get("glow", false))
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = maxi(1, roundi(settings.amount * amount_scale))
	particles.direction = Vector3.UP
	particles.spread = settings.spread
	particles.initial_velocity_min = settings.speed * 0.5
	particles.initial_velocity_max = settings.speed
	particles.gravity = Vector3.DOWN * settings.gravity
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = settings.radius
	parent.add_child(particles)
	particles.global_position = at
	particles.restart() # Starts the one-shot cycle cleanly in the frame it is added.
	particles.finished.connect(particles.queue_free)


static func trail(colour: Color) -> CPUParticles3D:
	# A continuous trail of soft glowing puffs left in world space; set emitting while the owner moves.
	var particles := _particles(colour, Balance.FX_TRAIL_SIZE, Balance.FX_TRAIL_LIFETIME, true)
	particles.amount = Balance.FX_TRAIL_AMOUNT
	particles.local_coords = false # Puffs stay where they were left, so moving draws a line.
	particles.gravity = Vector3.UP * Balance.FX_TRAIL_RISE
	particles.initial_velocity_max = Balance.FX_TRAIL_DRIFT
	particles.spread = 180.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = Balance.FX_TRAIL_RADIUS
	particles.emitting = false
	return particles


static func _particles(colour: Color, size: float, lifetime: float, glow: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.lifetime = lifetime
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	if glow:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = Balance.FX_GLOW_ENERGY
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Fade out and shrink over each particle's life.
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	particles.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.35))
	particles.scale_amount_curve = shrink
	return particles


static func _soft_dot() -> Texture2D:
	# A round, soft-edged dot shared by every effect.
	if dot_texture != null:
		return dot_texture
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var falloff := Gradient.new()
	falloff.set_color(0, Color.WHITE)
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	falloff.add_point(0.55, Color(1.0, 1.0, 1.0, 0.85))
	dot.gradient = falloff
	dot.width = 64
	dot.height = 64
	dot_texture = dot
	return dot
