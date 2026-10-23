# The Old Mansion, built from arenas/layouts/mansion_layout.json (the floor plan in mansion-layout.svg).
# The builder makes the house; this script sets the dusk mood (environment and moonlight) and places the loot,
# piano and flashlights on the layout's spawn spots. Decor and lamps live in arenas/dressing/MansionDressing.tscn.
extends Node3D

# --- Scene resources ---
const LAYOUT_PATH: String = "res://arenas/layouts/mansion_layout.json"
const LOOT_SCENES: Array[PackedScene] = [
	preload("res://props/loot/Vase.tscn"), preload("res://props/loot/TV.tscn"), preload("res://props/loot/Clock.tscn"),
]
const PIANO := preload("res://props/loot/Piano.tscn")
const PIANO_KIND: int = 3
const FLASHLIGHT := preload("res://props/Flashlight.tscn")

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
	_spawn(PIANO, ArenaBuilder.point_of(layout.spawns.piano, Balance.LOOT_SIZES[PIANO_KIND].y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE))
	var flashlights: int = 2 if demo_mode and player_count == 4 else 1
	for index: int in range(flashlights):
		var spot: Dictionary = layout.spawns.flashlights[index]
		_spawn(FLASHLIGHT, ArenaBuilder.point_of(spot, Balance.FLASHLIGHT_SIZE.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE))


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
	add_child(moon)


# --- Spawning ---
func _spawn_loot() -> void:
	# A round gets 6/9/12 items (counting the piano) on shuffled spots; outside a match, every spot gets one.
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed
	var spots: Array = layout.spawns.loot.duplicate()
	for index: int in range(spots.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var saved: Variant = spots[index]
		spots[index] = spots[other]
		spots[other] = saved
	var count: int = Balance.LOOT_COUNTS[player_count - 2] - 1 if demo_mode else spots.size()
	for index: int in range(mini(count, spots.size())):
		var kind: int = random.randi_range(0, LOOT_SCENES.size() - 1)
		_spawn(LOOT_SCENES[kind], ArenaBuilder.point_of(spots[index], Balance.LOOT_SIZES[kind].y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE))


func _spawn(scene: PackedScene, location: Vector3) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = location
	add_child(prop)
