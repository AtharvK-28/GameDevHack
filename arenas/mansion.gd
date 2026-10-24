# The Old Mansion, built from arenas/layouts/mansion_layout.json (the floor plan in mansion-layout.svg).
# The builder makes the house; this script sets the dusk mood (environment and moonlight), spawns the round's loot
# from the furniture catalog onto the layout's role-tagged spawn spots. Decor, lamps and possessable furniture
# live in arenas/dressing/MansionDressing.tscn; the surroundings in MansionEnvironment.
extends Node3D

# --- Scene resources ---
const LAYOUT_PATH: String = "res://arenas/layouts/mansion_layout.json"
const LOOT_SCENE := preload("res://props/Loot.tscn")

# --- Arena identity ---
const ARENA_NAME: String = "Old Mansion"
const SIGNATURE_HAUNTING := preload("res://hauntings/HouseShake.gd")

# --- Round settings, set by Main before the arena enters the tree ---
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0

var layout: Dictionary
var truck: Area3D

# --- Setup ---
func _ready() -> void:
	layout = ArenaBuilder.load_layout(LAYOUT_PATH)
	truck = ArenaBuilder.build(self, layout)
	_build_mood()
	_spawn_loot()


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


# --- Spawning ---
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
		loot.catalog_item = item
		loot.position = ArenaBuilder.point_of(spot, item.footprint.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
		# "lean" tips the top back toward the wall behind, so a painting rests against it.
		loot.rotation = Vector3(-deg_to_rad(spot.get("lean", 0.0)), deg_to_rad(spot.get("yaw", 0.0)), 0.0)
		add_child(loot)


func _spawn(scene: PackedScene, location: Vector3) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = location
	add_child(prop)
