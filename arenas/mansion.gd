# The Old Mansion, built from arenas/layouts/mansion_layout.json (the floor plan in mansion-layout.svg).
# The builder makes the house; this script sets the dusk mood (environment and moonlight), spawns the round's loot
# from the furniture catalog onto the layout's role-tagged spawn spots. Decor, lamps and possessable furniture
# live in arenas/dressing/MansionDressing.tscn; the surroundings in MansionEnvironment.
extends Node3D

# --- Scene resources ---
const LAYOUT_PATH: String = "res://arenas/layouts/mansion_layout.json"
const LOOT_SCENE := preload("res://props/Loot.tscn")
const BATTERY_SCENE := preload("res://props/tasks/battery.tscn")
const GENERATOR_SCENE := preload("res://props/tasks/generator_zone.tscn")

# --- Arena identity ---
const ARENA_NAME: String = "Old Mansion"
const SIGNATURE_HAUNTING := preload("res://hauntings/HouseShake.gd")
const GHOST_AVATAR := preload("res://actors/ghost_model.gd")

signal clock_chimed(slot: int) # The grandfather clock chimed; slot is the mover who knocked it, or -1.

# --- Round settings, set by Main before the arena enters the tree ---
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0

var layout: Dictionary
var truck: Area3D
var generator: Area3D

# --- Setup ---
func _ready() -> void:
	layout = ArenaBuilder.load_layout(LAYOUT_PATH)
	truck = ArenaBuilder.build(self, layout)
	_build_mood()
	_spawn_loot()
	if demo_mode:
		_spawn_battery_run()


# --- Arena interface (shared with the greybox) ---
func mover_spawn(slot: int) -> Vector3:
	var spot: Array = layout.spawns.movers[slot]
	return Vector3(spot[0], Balance.CAPSULE_HEIGHT / 2.0, spot[1])


func ghost_spawn() -> Vector3:
	return ArenaBuilder.point_of(layout.spawns.ghost, Balance.WISP_HEIGHT)


func camera_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.camera_bounds)


func ghost_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.ghost_bounds)


func mover_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.mover_bounds)


func floor_height_at(point: Vector3) -> float:
	# Query layout floors, never furniture tops; interpolate the stair ramp to avoid a jump at the gallery.
	var location := Vector2(point.x, point.z)
	for stairs: Dictionary in layout.stairs:
		var rect: Rect2 = ArenaBuilder.rect_of(stairs.rect)
		if rect.has_point(location):
			return stairs.rise * (1.0 - (point.z - rect.position.y) / rect.size.y)
	for room: Dictionary in layout.rooms:
		if ArenaBuilder.rect_of(room.rect).has_point(location):
			return room.floor
	return 0.0


# --- Mood ---
func _power_generator() -> void:
	# Brighten the existing ambient and moonlight instead of adding expensive shadow-casting lights.
	var environment: Environment = $WorldEnvironment.environment
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.set_parallel(true)
	tween.tween_property(environment, "ambient_light_energy", Balance.MOOD_AMBIENT_ENERGY * Balance.GENERATOR_AMBIENT_RATIO, Balance.GENERATOR_LIGHT_FADE)
	tween.tween_property($Moonlight, "light_energy", Balance.MOON_ENERGY * Balance.GENERATOR_MOON_RATIO, Balance.GENERATOR_LIGHT_FADE)
	for ghost: Node in get_tree().get_nodes_in_group("ghosts"):
		if ghost.arena == self:
			ghost.apply_generator_power()
	print("Generator powered: lights improved and ghost weakened for the round")


func _build_mood() -> void:
	# Dusk: a dark violet world fading into fog, low ambient light and one shadow-casting moon.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Balance.MOOD_BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Balance.MOOD_AMBIENT_COLOUR
	environment.ambient_light_energy = Balance.MOOD_AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = Balance.MOOD_EXPOSURE
	environment.adjustment_enabled = true # A punchier, Supercell-style grade over the dusk mood.
	environment.adjustment_contrast = Balance.MOOD_CONTRAST
	environment.adjustment_saturation = Balance.MOOD_SATURATION
	environment.adjustment_brightness = Balance.MOOD_BRIGHTNESS
	environment.glow_enabled = true
	environment.glow_intensity = Balance.MOOD_GLOW_INTENSITY
	environment.glow_hdr_threshold = Balance.MOOD_GLOW_THRESHOLD
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Balance.MOOD_BACKGROUND
	environment.fog_density = 1.0
	environment.fog_depth_begin = Balance.MOOD_FOG_BEGIN
	environment.fog_depth_end = Balance.MOOD_FOG_END
	environment.fog_depth_curve = Balance.MOOD_FOG_CURVE
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Balance.MOON_COLOUR
	moon.light_energy = Balance.MOON_ENERGY
	moon.rotation_degrees = Balance.MOON_ROTATION
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = Balance.MOON_SHADOW_DISTANCE
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS # Half the shadow passes of the default.
	add_child(moon)

	# The wood floors are tinted a little darker and cooler so loot stands out on them (STYLE.md focal hierarchy).
	# Set here rather than in the .tres, which tools/make_surface_textures.gd regenerates.
	var wood: StandardMaterial3D = load("res://assets/materials/surfaces/wood_planks.tres")
	wood.albedo_color = Balance.FLOOR_TINT

	# A warm pool of light over the front yard and driveway, where most of the carrying happens, so the playfield
	# reads brighter than the dark grounds around it (STYLE.md). No shadows: the moon casts those.
	var yard := OmniLight3D.new()
	yard.name = "YardLight"
	var path: Rect2 = ArenaBuilder.rect_of(layout.paths[0].rect)
	yard.position = Vector3(path.get_center().x, Balance.YARD_LIGHT_HEIGHT, path.get_center().y)
	yard.light_color = Balance.YARD_LIGHT_COLOUR
	yard.light_energy = Balance.YARD_LIGHT_ENERGY
	yard.omni_range = Balance.YARD_LIGHT_RANGE
	yard.shadow_enabled = false
	add_child(yard)


# --- Spawning ---
func battery_spots() -> Array:
	# Use a separate seeded stream so task placement never changes the loot selection.
	var spots: Array = layout.spawns.batteries.duplicate(true)
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed + Balance.BATTERY_SEED_OFFSET
	for index: int in range(spots.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var spot: Variant = spots[index]
		spots[index] = spots[other]
		spots[other] = spot
	return spots.slice(0, Balance.BATTERY_COUNT)


func _spawn_battery_run() -> void:
	generator = GENERATOR_SCENE.instantiate()
	generator.position = ArenaBuilder.point_of(layout.generator, 0.0)
	add_child(generator)
	generator.powered_on.connect(_power_generator)
	for spot: Dictionary in battery_spots():
		var battery: RigidBody3D = BATTERY_SCENE.instantiate()
		battery.generator = generator
		battery.arena = self
		battery.position = ArenaBuilder.point_of(spot, Balance.BATTERY_SIZE.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
		add_child(battery)


func _spawn_loot() -> void:
	# The round's loot from the catalog's Mansion pool, each on a spawn spot that suits it (a vase on a table, the
	# TV on its cabinet): 6/9/12 items with exactly one centrepiece in a match; outside one, the whole pool.
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed
	var total: int = Balance.LOOT_COUNTS[player_count - 2] if demo_mode else -1
	var heavy_limit: int = Balance.HEAVY_LOOT_LIMITS[player_count - 2] if demo_mode else -1
	for placement: Dictionary in Catalog.pick_loot(&"mansion", layout.spawns.loot, total, heavy_limit, random):
		var item: CatalogItem = placement.item
		var spot: Dictionary = placement.spot
		var loot: RigidBody3D = LOOT_SCENE.instantiate()
		if item.loot_script != null:
			loot.set_script(item.loot_script) # Before catalog_item: swapping the script resets its properties.
		loot.catalog_item = item
		loot.position = ArenaBuilder.point_of(spot, item.footprint.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
		# "lean" tips the top back toward the wall behind, so a painting rests against it.
		loot.rotation = Vector3(-deg_to_rad(spot.get("lean", 0.0)), deg_to_rad(spot.get("yaw", 0.0)), 0.0)
		add_child(loot)


func clock_chime(energy: float, slot: int) -> void:
	# The grandfather clock chimed (decision 140): Seth-ji stirs, a little stronger, and the round counts who did it.
	for ghost: Node in get_tree().get_nodes_in_group("ghosts"):
		if ghost.get("arena") == self:
			ghost.energy = minf(Balance.ENERGY_MAX, ghost.energy + energy)
	clock_chimed.emit(slot)


func _spawn(scene: PackedScene, location: Vector3) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = location
	add_child(prop)
