# The Getaway (decision 147): the finale after a Museum match. Everyone is a mover on the back of the truck, keeping the
# gold on board while the game's ghosts attack in turn: Seth-ji's vases, the Captain's waves, Bahadur's searchlight.
# Whatever goes off the open tailgate is gone. Built in code; the truck stands still and the world scrolls past.
extends Node3D

const Style := preload("res://screens/screen_style.gd")
const LOOT_SCENE := preload("res://props/Loot.tscn")
const GOLD_SCRIPT := preload("res://props/gold_loot.gd")
const ENGINE_SOUND: String = "res://assets/audio/cutscene/engine_loop.ogg"

# --- Arena identity ---
const ARENA_NAME: String = "The Getaway"
const MUSIC_TRACK: String = "round_museum"

var spawn_seed: int = 0
var random := RandomNumberGenerator.new()

# --- Round state ---
var elapsed: float = 0.0
var stage: int = -1 # -1 before the first ghost; then 0 Seth-ji, 1 the Captain, 2 Bahadur.
var gold: Array[RigidBody3D] = []
var total_value: int = 0
var lost_value: int = 0
var pothole_left: float = Balance.GETAWAY_POTHOLE_INTERVAL
var vase_left: float = 0.0
var wave_left: float = 0.0
var wave_warning_left: float = 0.0
var beam_left: float = 0.0
var beam_rest: float = 0.0
var beam_time: float = 0.0
var beam_caught: Dictionary = {} # Mover -> seconds until the beam may catch them again.

# --- Scenery and effects ---
var scrolling: Array[Node3D] = [] # Everything that passes the truck; each wraps round from behind to ahead.
var ghosts: Array[Node3D] = [] # Seth-ji, the Captain and Bahadur, each shown on their stage.
var crest := MeshInstance3D.new() # The wave crossing the bed.
var pool := MeshInstance3D.new() # The searchlight's circle.
var overlay := CanvasLayer.new()
var banner: Label
var gold_label: Label
var clock_label: Label
var banner_left: float = 0.0

# --- Setup ---
func _ready() -> void:
	random.seed = spawn_seed
	_build_world()
	_build_truck()
	_build_scenery()
	_build_ghosts()
	_build_effects()
	_build_overlay()
	_spawn_gold()
	_start_engine()
	_show_banner("ALL HANDS: PROTECT THE GOLD!", Balance.GETAWAY_GRACE)
	Game.changed.connect(_on_game_changed)


func take_camera(camera: Camera3D) -> void:
	# A chase camera, fixed behind the truck and looking up the road.
	camera.follow_movers = false
	camera.arena_yaw = 0.0
	camera.pitch_degrees = Balance.GETAWAY_CAMERA_ANGLE
	camera.focus = Balance.GETAWAY_CAMERA_FOCUS
	camera.distance = Balance.GETAWAY_CAMERA_DISTANCE


# --- Arena interface (shared with the other arenas) ---
func mover_spawn(slot: int) -> Vector3:
	return Vector3((slot - (Balance.MAX_PLAYERS - 1) / 2.0) * Balance.GETAWAY_SPAWN_SPACING, Balance.CAPSULE_HEIGHT / 2.0, Balance.GETAWAY_SPAWN_Z)


func ghost_spawn() -> Vector3:
	return Vector3.UP


func camera_bounds() -> Rect2:
	return mover_bounds()


func ghost_bounds() -> Rect2:
	return mover_bounds()


func mover_bounds() -> Rect2:
	var half: Vector2 = Balance.GETAWAY_BED_HALF - Vector2.ONE * Balance.GETAWAY_MOVER_MARGIN
	return Rect2(-half, half * 2.0)


func gold_result() -> Dictionary:
	# What the crew got home: the loot still aboard, as rupees and 0 to 3 stars.
	var saved: int = 0
	for item: RigidBody3D in gold:
		if is_instance_valid(item) and not item.finished:
			saved += item.value
	var stars: int = 0
	for share: float in Balance.GETAWAY_STAR_SHARES:
		if saved >= total_value * share:
			stars += 1
	return {"saved": saved, "total": total_value, "stars": stars}


# --- Every frame ---
func _physics_process(delta: float) -> void:
	if Game.phase != "live":
		return
	elapsed += delta
	_update_stage()
	_slide_gold(delta)
	_check_fallen()
	if stage < 0:
		return
	_update_potholes(delta)
	match stage:
		0:
			_update_vases(delta)
		1:
			_update_waves(delta)
		2:
			_update_beam(delta)
	if gold_result().saved == 0:
		Game.finish_getaway()


func _process(delta: float) -> void:
	for item: Node3D in scrolling:
		item.position.z += Balance.GETAWAY_ROAD_SPEED * delta
		if item.position.z > Balance.GETAWAY_SCENERY_NEAR:
			item.position.z -= Balance.GETAWAY_SCENERY_LENGTH
	for index: int in range(ghosts.size()):
		var ghost: Node3D = ghosts[index]
		ghost.visible = index == stage
		ghost.position.y = Balance.GETAWAY_GHOST_SPOTS[index].y + sin(elapsed * 2.0) * 0.2
	banner_left = maxf(0.0, banner_left - delta)
	banner.visible = banner_left > 0.0
	gold_label.text = "GOLD ABOARD %s" % Loot.rupees(gold_result().saved)
	clock_label.text = Style.clock(Game.seconds_left)


func _on_game_changed() -> void:
	overlay.visible = Game.phase == "live"


# --- The stages ---
func _update_stage() -> void:
	var next: int = -1
	if elapsed >= Balance.GETAWAY_GRACE:
		var length: float = (Balance.GETAWAY_SECONDS - Balance.GETAWAY_GRACE) / Balance.GETAWAY_STAGE_NAMES.size()
		next = mini(floori((elapsed - Balance.GETAWAY_GRACE) / length), Balance.GETAWAY_STAGE_NAMES.size() - 1)
	if next == stage:
		return
	stage = next
	_show_banner(Balance.GETAWAY_STAGE_NAMES[stage], Balance.GETAWAY_BANNER_SECONDS)
	Sfx.play("organ", 1.0, Balance.GETAWAY_STAGE_DB)
	vase_left = Balance.GETAWAY_STAGE_OPENING
	wave_left = Balance.GETAWAY_STAGE_OPENING
	beam_rest = Balance.GETAWAY_STAGE_OPENING
	pool.hide()


func _show_banner(words: String, seconds: float) -> void:
	banner.text = words
	banner_left = seconds


# --- The gold slides ---
func _slide_gold(delta: float) -> void:
	# Loose gold creeps toward the open tailgate and swings with the truck's sway; the side walls hold it in.
	var sway: float = sin(TAU * elapsed / Balance.GETAWAY_SWAY_PERIOD) * Balance.GETAWAY_SWAY_SPEED
	for item: RigidBody3D in _loose_gold():
		if item.global_position.y > Balance.GETAWAY_SLIDE_HEIGHT:
			continue # In the air: a throw or a shove flies on.
		var push: Vector3 = item.linear_velocity
		push.x = move_toward(push.x, sway, Balance.GETAWAY_SLIDE_ACCEL * delta)
		push.z = move_toward(push.z, Balance.GETAWAY_DRIFT_SPEED, Balance.GETAWAY_SLIDE_ACCEL * delta)
		item.linear_velocity = push


func _loose_gold() -> Array[RigidBody3D]:
	var loose: Array[RigidBody3D] = []
	for item: RigidBody3D in gold:
		if is_instance_valid(item) and not item.finished and not item.is_held():
			loose.append(item)
	return loose


func _check_fallen() -> void:
	for item: RigidBody3D in _loose_gold():
		var point: Vector3 = item.global_position
		if point.z > Balance.GETAWAY_BED_HALF.y + Balance.GETAWAY_FALL_MARGIN or absf(point.x) > Balance.GETAWAY_BED_HALF.x + Balance.GETAWAY_FALL_MARGIN or point.y < -Balance.GETAWAY_FALL_MARGIN:
			_lose(item)


func _lose(item: RigidBody3D) -> void:
	# Off the back: it bounces away down the road, in the players' faces.
	lost_value += item.value
	var puppet: Node3D = DisasterCam.make_puppet(item)
	add_child(puppet)
	puppet.global_transform = item.global_transform
	var bounce: Tween = puppet.create_tween().set_parallel()
	bounce.tween_property(puppet, "position:z", puppet.position.z + Balance.GETAWAY_LOST_TRAVEL, Balance.GETAWAY_LOST_SECONDS)
	bounce.tween_property(puppet, "position:y", Balance.GETAWAY_ROAD_Y, Balance.GETAWAY_LOST_SECONDS / 4.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	bounce.chain().tween_callback(puppet.queue_free)
	item.retire("%s\nBYE!" % Loot.rupees(item.value), Balance.DAMAGE_COLOUR)
	Sfx.play("thud", 0.8)


func _shove(item: RigidBody3D, push: Vector3) -> void:
	item.linear_velocity += push


# --- Potholes: every ghost's stage has them ---
func _update_potholes(delta: float) -> void:
	pothole_left -= delta
	if pothole_left > 0.0:
		return
	pothole_left = Balance.GETAWAY_POTHOLE_INTERVAL
	for item: RigidBody3D in _loose_gold():
		_shove(item, Vector3(random.randf_range(-1.0, 1.0), Balance.GETAWAY_POTHOLE_HOP, Balance.GETAWAY_POTHOLE_BACK))
	_shake(Balance.GETAWAY_POTHOLE_SHAKE)
	Sfx.varied("thud")


func _shake(amount: float) -> void:
	for camera: Camera3D in get_tree().get_nodes_in_group("party_camera"):
		camera.shake(amount)


func _buzz() -> void:
	for slot: int in Game.participants:
		Net.send_to_player(Net.player_for_slot(slot), {"type": "buzz", "ms": Balance.TUMBLE_BUZZ_MS})


# --- Seth-ji's vases ---
func _update_vases(delta: float) -> void:
	vase_left -= delta
	if vase_left <= 0.0:
		vase_left = Balance.GETAWAY_VASE_INTERVAL
		_throw_vase()


func _throw_vase() -> void:
	# A red circle shows where it lands: on a mover or the gold, so it always matters.
	var targets: Array[Node3D] = []
	for mover: CharacterBody3D in get_tree().get_nodes_in_group("movers"):
		if mover.in_play:
			targets.append(mover)
	targets.append_array(_loose_gold())
	if targets.is_empty():
		return
	var target: Vector3 = targets[random.randi_range(0, targets.size() - 1)].global_position
	var bounds: Rect2 = mover_bounds()
	var at := Vector3(clampf(target.x, bounds.position.x, bounds.end.x), 0.0, clampf(target.z, bounds.position.y, bounds.end.y))
	var circle := MeshInstance3D.new()
	circle.mesh = _disc(Balance.GETAWAY_VASE_RADIUS)
	circle.material_override = _glow(Color(Balance.DAMAGE_COLOUR, Balance.GETAWAY_CIRCLE_ALPHA))
	circle.position = at + Vector3.UP * 0.03
	add_child(circle)
	var vase := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.16
	shape.bottom_radius = 0.26
	shape.height = 0.7
	vase.mesh = shape
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Balance.GETAWAY_VASE_COLOUR
	vase.material_override = paint
	vase.position = at + Vector3.UP * Balance.GETAWAY_VASE_HEIGHT
	add_child(vase)
	var fall: Tween = vase.create_tween()
	fall.tween_interval(Balance.GETAWAY_VASE_WARNING - Balance.GETAWAY_VASE_FALL)
	fall.tween_property(vase, "position:y", 0.3, Balance.GETAWAY_VASE_FALL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(func() -> void:
		_vase_lands(at)
		circle.queue_free()
		vase.queue_free())


func _vase_lands(at: Vector3) -> void:
	if Game.phase != "live":
		return
	Fx.burst(at + Vector3.UP * 0.3, Fx.Kind.SHARDS, self)
	Sfx.varied("smash_glass", Balance.GETAWAY_VASE_DB)
	for mover: CharacterBody3D in get_tree().get_nodes_in_group("movers"):
		if mover.in_play and _flat_gap(mover.global_position, at) <= Balance.GETAWAY_VASE_RADIUS and not mover.is_tumbling():
			mover.tumble()
	for item: RigidBody3D in _loose_gold():
		var gap: float = _flat_gap(item.global_position, at)
		if gap <= Balance.GETAWAY_VASE_RADIUS:
			var away := Vector3(item.global_position.x - at.x, 0.0, item.global_position.z - at.z).normalized()
			_shove(item, away * Balance.GETAWAY_VASE_SHOVE + Vector3.UP * Balance.GETAWAY_POTHOLE_HOP)
	_shake(Balance.GETAWAY_POTHOLE_SHAKE)


# --- The Captain's waves ---
func _update_waves(delta: float) -> void:
	if wave_warning_left > 0.0:
		wave_warning_left -= delta
		if wave_warning_left <= 0.0:
			_wave_hits()
		return
	wave_left -= delta
	if wave_left <= 0.0:
		wave_left = Balance.GETAWAY_WAVE_INTERVAL
		wave_warning_left = Balance.GETAWAY_WAVE_WARNING
		_show_banner("WAVE! BRACE!", Balance.GETAWAY_WAVE_WARNING)
		_buzz()
		Sfx.play("whoosh", 0.55)
		crest.position = Vector3(Balance.GETAWAY_WAVE_START, 1.0, 0.0)
		crest.show()
		var run: Tween = crest.create_tween()
		run.tween_property(crest, "position:x", -Balance.GETAWAY_WAVE_START, Balance.GETAWAY_WAVE_WARNING * 2.0)
		run.tween_callback(crest.hide)


func _wave_hits() -> void:
	# Bracing movers hold on; the rest go down. The gold is washed along the bed toward the tailgate.
	Sfx.play("wave_crash")
	_shake(Balance.GETAWAY_WAVE_SHAKE)
	for mover: CharacterBody3D in get_tree().get_nodes_in_group("movers"):
		if mover.in_play and not mover.is_bracing():
			mover.wash(Vector3.LEFT, Balance.GETAWAY_WAVE_WASH)
	for item: RigidBody3D in _loose_gold():
		_shove(item, Vector3(-Balance.GETAWAY_WAVE_SHOVE, Balance.GETAWAY_POTHOLE_HOP, Balance.GETAWAY_WAVE_BACK))


# --- Bahadur's searchlight ---
func _update_beam(delta: float) -> void:
	if beam_left <= 0.0:
		beam_rest -= delta
		if beam_rest <= 0.0:
			beam_left = Balance.GETAWAY_BEAM_SECONDS
			beam_time = random.randf_range(0.0, TAU)
			beam_caught.clear()
			pool.show()
			_show_banner("JAAGTE RAHO! FREEZE!", Balance.GETAWAY_BANNER_SECONDS)
			Sfx.play("whistle", 1.0, Balance.JAAGTE_WHISTLE_DB)
		return
	beam_left -= delta
	beam_time += delta
	var bounds: Rect2 = mover_bounds()
	var centre := Vector3(sin(beam_time * 1.3) * bounds.size.x / 2.0, 0.04, sin(beam_time * 0.8) * bounds.size.y / 2.0)
	pool.position = centre
	for mover: Node in beam_caught.keys():
		beam_caught[mover] = maxf(0.0, beam_caught[mover] - delta)
	for mover: CharacterBody3D in get_tree().get_nodes_in_group("movers"):
		if mover.in_play and _flat_gap(mover.global_position, centre) <= Balance.GETAWAY_BEAM_RADIUS and mover.is_moving() \
				and not mover.is_bracing() and not mover.is_tumbling() and beam_caught.get(mover, 0.0) <= 0.0:
			beam_caught[mover] = Balance.JAAGTE_CATCH_GAP
			mover.tumble()
			mover.shout("HALT!")
			Sfx.play("whistle", 1.3, Balance.JAAGTE_WHISTLE_DB)
	if beam_left <= 0.0:
		beam_rest = Balance.GETAWAY_BEAM_REST
		pool.hide()


func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- The gold ---
func _spawn_gold() -> void:
	for index: int in range(Balance.GETAWAY_LOOT.size()):
		var item: RigidBody3D = LOOT_SCENE.instantiate()
		item.set_script(GOLD_SCRIPT) # Before catalog_item: swapping the script resets its properties.
		item.catalog_item = load(Balance.GETAWAY_LOOT[index])
		var spot: Vector2 = Balance.GETAWAY_GOLD_SPOTS[index]
		item.position = Vector3(spot.x, item.catalog_item.footprint.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE, spot.y)
		add_child(item)
		item.can_sleep = false
		gold.append(item)
		total_value += item.value


# --- Building the truck and the road ---
func _build_world() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Balance.GETAWAY_SKY_TOP
	sky.sky_horizon_color = Balance.GETAWAY_SKY_HORIZON
	sky.ground_horizon_color = Balance.GETAWAY_SKY_HORIZON
	sky.ground_bottom_color = Balance.GETAWAY_SKY_TOP
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Balance.GETAWAY_AMBIENT
	environment.ambient_light_energy = 1.0
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Balance.GETAWAY_SKY_HORIZON
	environment.fog_density = Balance.GETAWAY_FOG
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Balance.GETAWAY_SUN_ROTATION
	sun.light_color = Balance.GETAWAY_SUN_COLOUR
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	# The road, the pavement and the sea stay put; only what is on them passes.
	_box(Vector3(Balance.GETAWAY_ROAD_WIDTH, 0.1, 300.0), Vector3(0.0, Balance.GETAWAY_ROAD_Y - 0.05, -110.0), Balance.GETAWAY_ROAD_COLOUR)
	_box(Vector3(12.0, 0.3, 300.0), Vector3(-Balance.GETAWAY_ROAD_WIDTH / 2.0 - 6.0, Balance.GETAWAY_ROAD_Y, -110.0), Balance.GETAWAY_PAVEMENT_COLOUR)
	_box(Vector3(400.0, 0.1, 300.0), Vector3(Balance.GETAWAY_ROAD_WIDTH / 2.0 + 202.0, Balance.GETAWAY_ROAD_Y - 1.0, -110.0), Balance.GETAWAY_SEA_COLOUR)
	_box(Vector3(1.0, 1.2, 300.0), Vector3(Balance.GETAWAY_ROAD_WIDTH / 2.0 + 0.5, Balance.GETAWAY_ROAD_Y + 0.1, -110.0), Balance.GETAWAY_PAVEMENT_COLOUR)


func _build_truck() -> void:
	var half: Vector2 = Balance.GETAWAY_BED_HALF
	var bed := StaticBody3D.new()
	bed.name = "Bed"
	bed.collision_layer = Balance.WORLD_LAYER
	bed.collision_mask = 0
	add_child(bed)
	_solid(bed, Vector3(half.x * 2.0, 0.4, half.y * 2.0), Vector3(0.0, -0.2, 0.0), Balance.GETAWAY_BED_COLOUR)
	var wall: float = Balance.GETAWAY_WALL_HEIGHT
	_solid(bed, Vector3(0.3, wall, half.y * 2.0), Vector3(-half.x - 0.15, wall / 2.0, 0.0), Balance.GETAWAY_WALL_COLOUR)
	_solid(bed, Vector3(0.3, wall, half.y * 2.0), Vector3(half.x + 0.15, wall / 2.0, 0.0), Balance.GETAWAY_WALL_COLOUR)
	_solid(bed, Vector3(half.x * 2.0 + 0.6, wall, 0.3), Vector3(0.0, wall / 2.0, -half.y - 0.15), Balance.GETAWAY_WALL_COLOUR)
	# The cab, the chassis and the wheels are only seen.
	_box(Vector3(half.x * 2.0, 2.6, 2.6), Vector3(0.0, 0.4, -half.y - 1.7), Balance.GETAWAY_CAB_COLOUR)
	_box(Vector3(half.x * 1.7, 0.9, 0.1), Vector3(0.0, 1.1, -half.y - 3.03), Balance.GETAWAY_GLASS_COLOUR)
	_box(Vector3(half.x * 1.8, 0.5, half.y * 2.0), Vector3(0.0, -0.65, 0.0), Balance.GETAWAY_ROAD_COLOUR)
	for x: float in [-half.x, half.x]:
		for z: float in [half.y - 1.5, -half.y - 1.5]:
			var wheel := MeshInstance3D.new()
			var tyre := CylinderMesh.new()
			tyre.top_radius = 0.55
			tyre.bottom_radius = 0.55
			tyre.height = 0.45
			wheel.mesh = tyre
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(x, Balance.GETAWAY_ROAD_Y + 0.55, z)
			wheel.material_override = _paint(Balance.COMIC_INK)
			add_child(wheel)
	var slogan := Label3D.new()
	slogan.text = "HORN OK PLEASE"
	slogan.font = load(Balance.COMIC_FONT_PATH)
	slogan.font_size = Balance.PRICE_FONT_SIZE
	slogan.modulate = Balance.GETAWAY_SLOGAN_COLOUR
	slogan.outline_modulate = Balance.COMIC_INK
	slogan.position = Vector3(0.0, -0.65, half.y + 0.03)
	slogan.pixel_size = 0.012
	add_child(slogan)


func _build_scenery() -> void:
	var length: float = Balance.GETAWAY_SCENERY_LENGTH
	var walls := _window_texture()
	for index: int in range(Balance.GETAWAY_BUILDINGS):
		var height: float = random.randf_range(6.0, 20.0)
		var size := Vector3(9.0, height, random.randf_range(7.0, 11.0))
		var building := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		building.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Balance.GETAWAY_BUILDING_COLOURS[index % Balance.GETAWAY_BUILDING_COLOURS.size()]
		material.albedo_texture = walls
		material.uv1_scale = Vector3(9.0, ceilf(height / 3.0) * 2.0, 1.0) # BoxMesh fits all six faces on one texture.
		building.material_override = material
		building.position = Vector3(-Balance.GETAWAY_ROAD_WIDTH / 2.0 - 7.0, Balance.GETAWAY_ROAD_Y + height / 2.0, Balance.GETAWAY_SCENERY_NEAR - length * index / Balance.GETAWAY_BUILDINGS)
		add_child(building)
		scrolling.append(building)
	var dashes: int = int(length / Balance.GETAWAY_DASH_GAP)
	for index: int in range(dashes):
		for x: float in [-Balance.GETAWAY_DASH_X, Balance.GETAWAY_DASH_X]:
			scrolling.append(_box(Vector3(0.2, 0.02, Balance.GETAWAY_DASH_GAP / 2.0), Vector3(x, Balance.GETAWAY_ROAD_Y + 0.02, Balance.GETAWAY_SCENERY_NEAR - index * Balance.GETAWAY_DASH_GAP), Color.WHITE))
	var lamps: int = int(length / Balance.GETAWAY_LAMP_GAP)
	for index: int in range(lamps):
		scrolling.append(_box(Vector3(0.2, 6.0, 0.2), Vector3(Balance.GETAWAY_ROAD_WIDTH / 2.0 + 0.5, Balance.GETAWAY_ROAD_Y + 3.0, Balance.GETAWAY_SCENERY_NEAR - index * Balance.GETAWAY_LAMP_GAP), Balance.COMIC_INK))


func _build_ghosts() -> void:
	var bodies: Array[Script] = [GhostModel, GhostCaptainModel, GhostWatchmanModel]
	for index: int in range(bodies.size()):
		var ghost: Node3D = bodies[index].new()
		if ghost is GhostModel:
			ghost.add_child(load(Balance.GHOST_MODEL_PATH).instantiate())
		ghost.position = Balance.GETAWAY_GHOST_SPOTS[index]
		ghost.scale = Vector3.ONE * Balance.GETAWAY_GHOST_SCALE
		ghost.visible = false
		add_child(ghost)
		ghosts.append(ghost)


func _build_effects() -> void:
	var wave := BoxMesh.new()
	wave.size = Vector3(1.6, 2.6, Balance.GETAWAY_BED_HALF.y * 2.0 + 1.0)
	crest.mesh = wave
	crest.material_override = _glow(Color(Balance.GETAWAY_WAVE_COLOUR, 0.8))
	crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crest.hide()
	add_child(crest)
	var foam := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(1.9, 0.5, wave.size.z)
	foam.mesh = top
	foam.position.y = wave.size.y / 2.0
	foam.material_override = _glow(Color(Color.WHITE, 0.9))
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crest.add_child(foam)
	pool.mesh = _disc(Balance.GETAWAY_BEAM_RADIUS)
	pool.material_override = _glow(Color(Balance.JAAGTE_BEAM_COLOUR, Balance.GETAWAY_BEAM_ALPHA))
	pool.hide()
	add_child(pool)


func _build_overlay() -> void:
	add_child(overlay)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	layout.offset_top = Balance.HUD_MARGIN
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(layout)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Balance.HOST_ROW_GAP * 6)
	layout.add_child(row)
	gold_label = Style.lettering("", Balance.COMIC_HEADING_SIZE, Balance.UI_MONEY)
	clock_label = Style.lettering("", Balance.COMIC_HEADING_SIZE, Balance.UI_TEXT)
	for line: Label in [gold_label, clock_label]:
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(line)
	banner = Style.lettering("", Balance.COMIC_TITLE_SIZE, Balance.UI_DANGER)
	banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(banner)


func _start_engine() -> void:
	var stream: AudioStreamOggVorbis = load(ENGINE_SOUND)
	stream.loop = true
	var engine := AudioStreamPlayer.new()
	engine.stream = stream
	engine.bus = &"SFX"
	engine.volume_db = Balance.GETAWAY_ENGINE_DB
	add_child(engine)
	engine.play()


# --- Building blocks ---
func _box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = at
	box.material_override = _paint(colour)
	add_child(box)
	return box


func _solid(body: StaticBody3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh: MeshInstance3D = _box(size, at, colour)
	mesh.reparent(body, false)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	body.add_child(collider)


func _paint(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material


func _glow(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	return material


func _disc(radius: float) -> CylinderMesh:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 32
	return disc


func _window_texture() -> ImageTexture:
	# One floor of a building: wall with two lit windows; the material repeats it.
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	for rect: Rect2i in [Rect2i(4, 8, 9, 14), Rect2i(19, 8, 9, 14)]:
		image.fill_rect(rect, Balance.GETAWAY_WINDOW_COLOUR)
	return ImageTexture.create_from_image(image)
