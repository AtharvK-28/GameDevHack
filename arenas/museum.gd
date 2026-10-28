# The Museum of Mostly Real Things, built from arenas/layouts/museum_layout.json: six galleries round a grand hall,
# a laser hall shortcut and a lobby, with the crew's van at the loading dock. The builder makes the building; this
# script sets the after-hours mood (cold gallery lights in the dark) and spawns the round's loot from the catalog's
# museum pool onto the layout's role-tagged spots. Exhibits and pedestals live in arenas/dressing/MuseumDressing.tscn.
extends Node3D

# --- Scene resources ---
const LAYOUT_PATH: String = "res://arenas/layouts/museum_layout.json"
const LOOT_SCENE := preload("res://props/Loot.tscn")

# --- Arena identity ---
const ARENA_NAME: String = "Museum of Mostly Real Things"
const SIGNATURE_HAUNTING := preload("res://hauntings/JaagteRaho.gd")
const GHOST_AVATAR := preload("res://actors/ghost_watchman_model.gd") # Bahadur, the night watchman.

signal caught_in_beam(slot: int) # A mover moved in Bahadur's torch beam; the round's goals and awards count it.

# --- Round settings, set by Main before the arena enters the tree ---
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0

var layout: Dictionary
var truck: Area3D
var generator: Node3D # The swap-the-fakes task arrives in Museum stage C.
var gallery_lights: Dictionary = {} # Light -> its full energy; JAAGTE RAHO! dims these, never the street or the van.
var ambient_energy: float = 0.0

# --- Setup ---
func _ready() -> void:
	layout = ArenaBuilder.load_layout(LAYOUT_PATH)
	truck = ArenaBuilder.build(self, layout)
	_build_mood()
	_spawn_loot()
	_collect_gallery_lights.call_deferred() # After the dressing has hung its spotlights.


# --- Arena interface (shared with the other arenas) ---
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


func floor_height_at(_point: Vector3) -> float:
	return 0.0 # One floor throughout; exhibits stand on pedestals, never on raised rooms.


func room_at(world_point: Vector3) -> String:
	for room: Dictionary in layout.rooms:
		if ArenaBuilder.rect_of(room.rect).has_point(Vector2(world_point.x, world_point.z)):
			return room.name
	return ""


# --- Mood ---
func _build_mood() -> void:
	# After hours: a dark blue-grey night outside, low ambient light, one moon for shadows and a cold white light
	# over each gallery, so exhibits read bright against the dark.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Balance.MUSEUM_BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Balance.MUSEUM_AMBIENT_COLOUR
	environment.ambient_light_energy = Balance.MUSEUM_AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = Balance.MOOD_EXPOSURE
	environment.glow_enabled = true
	environment.glow_intensity = Balance.MOOD_GLOW_INTENSITY
	environment.glow_hdr_threshold = Balance.MOOD_GLOW_THRESHOLD
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Balance.MUSEUM_BACKGROUND
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
	moon.light_energy = Balance.MUSEUM_MOON_ENERGY
	moon.rotation_degrees = Balance.MOON_ROTATION
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = Balance.MOON_SHADOW_DISTANCE
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)

	for room: Dictionary in layout.rooms:
		var rect: Rect2 = ArenaBuilder.rect_of(room.rect)
		var lamp := OmniLight3D.new()
		lamp.name = "Light-" + room.id
		lamp.position = Vector3(rect.get_center().x, Balance.MUSEUM_LIGHT_HEIGHT, rect.get_center().y)
		lamp.light_color = Balance.MUSEUM_OUTSIDE_LIGHT_COLOUR if room.get("outdoors", false) else Balance.MUSEUM_LIGHT_COLOUR
		lamp.light_energy = Balance.MUSEUM_LIGHT_ENERGY
		lamp.omni_range = maxf(rect.size.x, rect.size.y) * Balance.MUSEUM_LIGHT_REACH
		lamp.shadow_enabled = false
		add_child(lamp)


# --- Lights out (JAAGTE RAHO!) ---
func _collect_gallery_lights() -> void:
	ambient_energy = $WorldEnvironment.environment.ambient_light_energy
	for light: Light3D in find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D or get_node("MuseumEnvironment").is_ancestor_of(light) or light.name == "Light-room-loading-dock" or light.name == "Light-room-forecourt":
			continue
		gallery_lights[light] = light.light_energy


func set_darkness(amount: float) -> void:
	# 0 is the museum as normal, 1 is lights out: the galleries keep only a trace of light, and so does the sky.
	var keep: float = lerpf(1.0, Balance.JAAGTE_LIGHT_LEFT, amount)
	for light: Light3D in gallery_lights:
		if is_instance_valid(light):
			light.light_energy = gallery_lights[light] * keep
	$WorldEnvironment.environment.ambient_light_energy = ambient_energy * keep
	$Moonlight.light_energy = Balance.MUSEUM_MOON_ENERGY * lerpf(1.0, Balance.JAAGTE_MOON_LEFT, amount)
	$WorldEnvironment.environment.tonemap_exposure = Balance.MOOD_EXPOSURE * lerpf(1.0, Balance.JAAGTE_EXPOSURE_LEFT, amount)


# --- Spawning ---
func _spawn_loot() -> void:
	# The round's loot from the catalog's museum pool, each on a spot that suits it (a mask in Egypt, a crystal in
	# the Jurassic Hall): 6/9/12 items with exactly one skull in a match; outside one, the whole pool.
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed
	var total: int = Balance.LOOT_COUNTS[player_count - 2] if demo_mode else -1
	var heavy_limit: int = Balance.HEAVY_LOOT_LIMITS[player_count - 2] if demo_mode else -1
	for placement: Dictionary in Catalog.pick_loot(&"museum", layout.spawns.loot, total, heavy_limit, random):
		var item: CatalogItem = placement.item
		var spot: Dictionary = placement.spot
		var loot: RigidBody3D = LOOT_SCENE.instantiate()
		if item.loot_script != null:
			loot.set_script(item.loot_script) # Before catalog_item: swapping the script resets its properties.
		loot.catalog_item = item
		loot.position = ArenaBuilder.point_of(spot, item.footprint.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
		loot.rotation.y = deg_to_rad(spot.get("yaw", 0.0))
		add_child(loot)
