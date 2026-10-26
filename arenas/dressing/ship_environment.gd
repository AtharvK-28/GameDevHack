# Blue night ocean, fog, lighthouse, distant life and weather; independent of rebuilt deck geometry.
extends Node3D

# --- Environment state ---
var environment: Environment
var moon: DirectionalLight3D
var moon_ratio: float = 1.0 # Raised once the lanterns are lit, and kept through lightning.
var elapsed: float = 0.0
var lightning_left: float = 0.0
var lightning_time: float = 0.0
var lighthouse: Node3D
var creatures: Node3D
var ambience: Array[AudioStreamPlayer] = []
var next_call: float = 0.0

# --- Setup ---
func _ready() -> void:
	_build_mood()
	_build_ocean()
	_build_horizon()
	_build_mist()
	_build_ambience()
	lightning_left = randf_range(Balance.SHIP_LIGHTNING_INTERVAL.x, Balance.SHIP_LIGHTNING_INTERVAL.y)
	next_call = Balance.SHIP_AMBIENT_CALL_INTERVAL


func _build_mood() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Balance.SHIP_BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Balance.SHIP_LANTERN_COLOUR
	environment.ambient_light_energy = Balance.SHIP_AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.fog_enabled = true
	environment.fog_density = 1.0
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Balance.SHIP_BACKGROUND
	environment.fog_depth_begin = Balance.SHIP_FOG_BEGIN
	environment.fog_depth_end = Balance.SHIP_FOG_END
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)
	moon = DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Balance.SHIP_LANTERN_COLOUR
	moon.light_energy = Balance.SHIP_MOON_ENERGY
	moon.rotation_degrees = Balance.MOON_ROTATION
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = Balance.MOON_SHADOW_DISTANCE
	add_child(moon)


func _build_ocean() -> void:
	# A square ring leaves a real hole for the dense near grid: no overlapping water surfaces.
	var half: float = Balance.SHIP_NEAR_WATER_SIZE / 2.0
	var far_half: float = Balance.SHIP_OCEAN_SIZE / 2.0
	_water_patch(Vector2.ZERO, Vector2.ONE * Balance.SHIP_NEAR_WATER_SIZE, true)
	var side: float = far_half - half
	_water_patch(Vector2(0, -(half + side / 2.0)), Vector2(Balance.SHIP_OCEAN_SIZE, side), false)
	_water_patch(Vector2(0, half + side / 2.0), Vector2(Balance.SHIP_OCEAN_SIZE, side), false)
	_water_patch(Vector2(-(half + side / 2.0), 0), Vector2(side, Balance.SHIP_NEAR_WATER_SIZE), false)
	_water_patch(Vector2(half + side / 2.0, 0), Vector2(side, Balance.SHIP_NEAR_WATER_SIZE), false)


func _water_patch(offset: Vector2, size: Vector2, dense: bool) -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = Balance.SHIP_WATER_SUBDIVISIONS if dense else 0
	plane.subdivide_depth = Balance.SHIP_WATER_SUBDIVISIONS if dense else 0
	mesh.mesh = plane
	mesh.position = Vector3(13 + offset.x, Balance.SHIP_WATER_Y, 8 + offset.y)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water := ShaderMaterial.new()
	water.shader = load("res://assets/shaders/ship_water.gdshader")
	water.set_shader_parameter("near_water", dense)
	water.set_shader_parameter("water_colour", Balance.SHIP_WATER_COLOUR)
	water.set_shader_parameter("wave_height", Balance.SHIP_WAVE_HEIGHT)
	water.set_shader_parameter("wave_speed", Balance.SHIP_WAVE_SPEED)
	mesh.material_override = water
	add_child(mesh)


func _build_horizon() -> void:
	lighthouse = Node3D.new()
	lighthouse.position = Balance.SHIP_LIGHTHOUSE_SPOT
	add_child(lighthouse)
	ShipVisuals.kit(lighthouse, "tower-complete-small", Vector3.ZERO, Balance.SHIP_LIGHTHOUSE_SCALE)
	var beam := SpotLight3D.new()
	beam.position.y = Balance.SHIP_LIGHTHOUSE_HEIGHT
	beam.light_color = Balance.SHIP_LANTERN_COLOUR
	beam.light_energy = Balance.SHIP_LIGHTHOUSE_ENERGY
	beam.spot_range = Balance.SHIP_LIGHTHOUSE_RANGE
	beam.spot_angle = Balance.SHIP_LIGHTHOUSE_ANGLE
	beam.shadow_enabled = false
	lighthouse.add_child(beam)
	creatures = Node3D.new()
	creatures.position = Balance.SHIP_TENTACLE_SPOT
	add_child(creatures)
	var parts: Array = []
	for index: int in range(Balance.SHIP_TENTACLE_SEGMENTS):
		var y: float = index * Balance.SHIP_TENTACLE_STEP
		var width: float = 0.9 - index * 0.08
		parts.append([Vector3(width, 0.6, width), Vector3(sin(index * 0.6), y, 0), Vector3(0, 0, sin(index * 0.7) * 0.3)])
	ShipVisuals.blocks(creatures, parts, Balance.SHIP_TENTACLE_COLOUR)
	ShipVisuals.kit(self, "boat-row-large", Vector3(-12, Balance.SHIP_WATER_Y + 0.1, 25), 0.7)
	var birds: Array = []
	for index: int in range(6):
		var position := Vector3(4 + index * 0.2, 5.4, -1)
		birds.append([Vector3(0.25, 0.1, 0.13), position])
	ShipVisuals.blocks(self, birds, Balance.SHIP_SAIL_COLOUR)


# --- Weather and distant life ---
func _process(delta: float) -> void:
	elapsed += delta
	lighthouse.rotation.y = elapsed * Balance.SHIP_LIGHTHOUSE_TURN_SPEED
	creatures.position.y = Balance.SHIP_TENTACLE_SPOT.y + sin(elapsed * Balance.SHIP_CREATURE_SPEED) * Balance.SHIP_CREATURE_BOB
	lightning_left -= delta
	lightning_time = maxf(0.0, lightning_time - delta)
	if _haunting_active():
		lightning_time = 0.0
	elif lightning_left <= 0.0:
		flash_lightning()
	moon.light_energy = Balance.SHIP_LIGHTNING_ENERGY if lightning_time > 0.0 else Balance.SHIP_MOON_ENERGY * moon_ratio
	next_call -= delta
	if next_call <= 0.0:
		next_call = Balance.SHIP_AMBIENT_CALL_INTERVAL
		_play_call()


func flash_lightning() -> void:
	if _haunting_active():
		return
	lightning_time = Balance.SHIP_LIGHTNING_DURATION
	lightning_left = randf_range(Balance.SHIP_LIGHTNING_INTERVAL.x, Balance.SHIP_LIGHTNING_INTERVAL.y)


func _haunting_active() -> bool:
	for ghost: Node in get_tree().get_nodes_in_group("ghosts"):
		for haunting: Haunting in ghost.hauntings:
			if haunting.is_active():
				return true
	return false


# --- Quiet sea ambience ---
func _build_ambience() -> void:
	for sound: String in ["waves", "creaks", "rope"]:
		var path: String = "res://assets/audio/ship/%s.ogg" % sound
		if not ResourceLoader.exists(path):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.volume_db = Balance.SHIP_AMBIENT_DB
		player.bus = "SFX"
		add_child(player)
		player.finished.connect(player.play)
		player.play()
		ambience.append(player)


func _play_call() -> void:
	var path: String = "res://assets/audio/ship/%s.ogg" % ("gulls" if randi() % 3 else "foghorn")
	if ResourceLoader.exists(path):
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.volume_db = Balance.SHIP_AMBIENT_DB
		player.bus = "SFX"
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()


func _build_mist() -> void:
	# Thin moving banks stay below deck height, so warnings and valuables remain clear.
	var fog := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Balance.SHIP_MIST_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(Balance.SHIP_LANTERN_COLOUR, Balance.SHIP_MIST_ALPHA)
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	texture.gradient = gradient
	material.albedo_texture = texture
	quad.material = material
	fog.mesh = quad
	fog.position = Balance.SHIP_MIST_POSITION
	fog.amount = Balance.SHIP_MIST_AMOUNT
	fog.lifetime = Balance.SHIP_MIST_LIFETIME
	fog.preprocess = Balance.SHIP_MIST_LIFETIME
	fog.gravity = Vector3.ZERO
	fog.direction = Vector3.RIGHT
	fog.initial_velocity_min = Balance.SHIP_MIST_SPEED.x
	fog.initial_velocity_max = Balance.SHIP_MIST_SPEED.y
	fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fog.emission_box_extents = Balance.SHIP_MIST_EXTENTS
	fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fog)
