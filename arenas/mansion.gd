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
const MISSION_SCRIPT := preload("res://core/mission.gd")
const KEY_SCRIPT := preload("res://props/tasks/gallery_key.gd")
const CUPBOARD_SCRIPT := preload("res://props/tasks/fuse_cupboard.gd")
const FUSE_SCRIPT := preload("res://props/tasks/fuse_box.gd")
const GATE_SCRIPT := preload("res://props/tasks/stair_gate.gd")

# --- Arena identity ---
const ARENA_NAME: String = "Old Mansion"
const SIGNATURE_HAUNTING := preload("res://hauntings/HouseShake.gd")
const GHOST_AVATAR := preload("res://actors/ghost_model.gd")

signal clock_chimed(slot: int) # The grandfather clock chimed; slot is the mover who knocked it, or -1.

# --- Round settings, set by Main before the arena enters the tree ---
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0
@export var mission_mode: bool = false # The Sabotage Showdown variant (decision 158) sets this in its own scene.

var layout: Dictionary
var truck: Area3D
var generator: Area3D
var mission: Mission
var fuse_box: Node3D
var stair_gate: StaticBody3D
var strongbox: Node3D

# --- Setup ---
func _ready() -> void:
	layout = ArenaBuilder.load_layout(LAYOUT_PATH)
	truck = ArenaBuilder.build(self, layout)
	_build_mood()
	_spawn_loot()
	# The mission replaces the Battery Run: one is a sequence the crew must finish, the other an optional errand,
	# and running both at once would give the crew two unrelated jobs and the ghost nothing to defend.
	if mission_mode:
		_spawn_mission()
	elif demo_mode:
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
	ComicLook.calm_background(environment) # Keeps the dusk grade but pulls the dressing back (decision 149).
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


# --- The Sabotage Showdown mission (decision 158) ---
func _spawn_mission() -> void:
	# Four steps, each shut until the one before it is done: find the key, open the fuse cupboard beside the
	# stairs, match the wires to restore power, then carry the strongbox down from the gallery.
	mission = MISSION_SCRIPT.new(Balance.MISSION_STEPS)
	add_child(mission)

	stair_gate = GATE_SCRIPT.new()
	stair_gate.position = Balance.MISSION_GATE_AT
	add_child(stair_gate)

	var cupboard: Area3D = CUPBOARD_SCRIPT.new()
	cupboard.mission = mission
	cupboard.position = Balance.MISSION_CUPBOARD_AT
	add_child(cupboard)

	fuse_box = FUSE_SCRIPT.new()
	fuse_box.mission = mission
	fuse_box.position = Balance.MISSION_FUSE_AT
	add_child(fuse_box)
	fuse_box.power_changed.connect(_on_power_changed)
	fuse_box.puzzle_wanted.connect(_on_puzzle_wanted)

	var key: RigidBody3D = KEY_SCRIPT.new()
	key.mission = mission
	key.generator = cupboard # The cupboard is this item's delivery zone, as a generator is a battery's.
	key.arena = self
	key.position = _key_spot() + Vector3.UP * (Balance.MISSION_KEY_SIZE.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
	key.add_to_group("mission_key")
	add_child(key)

	# The prize sits on the gallery, behind the gate. Its own pool keeps it out of the ordinary loot draw.
	strongbox = LOOT_SCENE.instantiate()
	strongbox.catalog_item = load("res://props/catalog/mansion/strongbox.tres")
	strongbox.position = Balance.MISSION_STRONGBOX_AT
	strongbox.add_to_group("mission_prize")
	add_child(strongbox)
	truck.banked.connect(_on_banked_for_mission)
	mission.finished.connect(_on_mission_finished)


func can_reach(point: Vector3) -> bool:
	# For the bots: the stairs and gallery are out of reach while the stair gate is shut.
	return not is_instance_valid(stair_gate) or not stair_gate.shut or is_zero_approx(floor_height_at(point))


func _key_spot() -> Vector3:
	# One spot a round, from its own seeded stream so the key never shifts the loot or the battery placement.
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed + Balance.MISSION_KEY_SEED_OFFSET
	var spots: Array[Vector3] = Balance.MISSION_KEY_SPOTS
	return spots[random.randi_range(0, spots.size() - 1)]


func _on_power_changed(on: bool) -> void:
	# Power is what the whole sequence is for: it opens the gate and lights the gallery, and the ghost cutting it
	# shuts the crew out again (or in, if someone is still upstairs).
	if is_instance_valid(stair_gate):
		stair_gate.set_shut(not on)
	var environment: Environment = $WorldEnvironment.environment
	var target: float = Balance.MOOD_AMBIENT_ENERGY * (Balance.GENERATOR_AMBIENT_RATIO if on else 1.0)
	var fade := create_tween()
	fade.tween_property(environment, "ambient_light_energy", target, Balance.GENERATOR_LIGHT_FADE)


func _on_puzzle_wanted(slot: int) -> void:
	# The fuse box is in the arena, but the puzzle talks to a phone, so Main runs it.
	var host: Node = get_parent()
	if host != null and host.has_method("_on_puzzle_wanted"):
		host._on_puzzle_wanted(slot)


func _on_mission_finished() -> void:
	# The crew got the strongbox out: the mission is the win condition in this mode, not the usual quota.
	print("Mission complete: the crew got the strongbox out")
	Game.finish_mission()


func _on_banked_for_mission(_value: int, _carrier_slot: int) -> void:
	# The last step is done when the strongbox itself reaches the truck, not when any loot does. The truck retires
	# the item and emits this in the same frame, so the strongbox is still valid here; a strongbox smashed earlier
	# has already been freed, and then no later delivery can finish the step for it.
	if mission == null:
		return
	if is_instance_valid(strongbox) and strongbox.finished:
		mission.complete("haul")
