# Ghost Ship: decks that ride the swell, seeded salvage, five hauntable props, gangplank waves and tug rescues.
# Everything that floats (hull, decks, plank, tug, zones and dressing) hangs off ShipRig, which rolls, pitches and
# heaves; layout queries convert to the rig's own frame, so they hold wherever the ship has moved.
extends Node3D

# --- Identity and resources ---
const ARENA_NAME: String = "Ghost Ship"
const SIGNATURE_HAUNTING := preload("res://hauntings/GustOfWind.gd")
const GHOST_AVATAR := preload("res://actors/ghost_captain_model.gd") # The wreck's drowned captain haunts it.
const LAYOUT_PATH: String = "res://arenas/layouts/ship_layout.json"
const MUSIC_TRACK: String = "round_ship" # A sea shanty in rounds (Sfx).
const LOOT_SCENE := preload("res://props/Loot.tscn")
const OIL_CAN_SCENE := preload("res://props/tasks/oil_can.tscn")
const LANTERN_SCENE := preload("res://props/tasks/lantern_posts.tscn")
const FURNITURE := {"slider": "Crate", "hopper": "Armour", "door": "Door", "dropper": "Chandelier", "rug": "Rug"}

signal overboard(slot: int) # A mover fell in the sea; the round's awards count it.

# --- Round settings and state ---
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0
var layout: Dictionary
var truck: Area3D
var generator: Node3D # The Light the Lanterns task in a match; the shared HUD and phones read it.
var rescues: Dictionary = {}
var wind_direction := Vector3.ZERO
var wind_active: bool = false
var rig: Node3D # Everything that floats.
var motion_scale: float = 1.0 # Checks set 0 to hold the ship level.
var sway_time: float = 0.0
var sway_rising: bool = true # Which way the roll is heading, to creak at each end of it.
var sway_override: float = NAN # Checks pin the roll here; NAN leaves it rolling.
var lurch: float = 0.0 # Extra degrees of roll from a breaking wave.
var lurch_push: float = 0.0 # Where the lurch is heading; it eases toward this so the deck never jolts loot.
var hanging: Dictionary = {} # Frozen hanging props -> their place in ship space; they follow the ship until they drop.
var riders: Dictionary = {} # Deck colliders -> their place in ship space; moved every physics frame.
var waves := RandomNumberGenerator.new()
var wave_left: float = 0.0 # Seconds until the next wave's warning.
var wave_warning_left: float = -1.0 # Counting down while a wave is about to hit; negative when calm.
var wave_direction := Vector3.RIGHT # The way the next wave pushes across the plank.
var crest: MeshInstance3D # The breaking wave.
var crest_material: StandardMaterial3D
var spray: CPUParticles3D
var foam_sheet: MeshInstance3D # Foam left draining off the plank.
var wave_label: Label3D

# --- Setup ---
func _ready() -> void:
	layout = ArenaBuilder.load_layout(LAYOUT_PATH)
	truck = ArenaBuilder.build(self, layout)
	_spawn_loot()
	_spawn_furniture()
	if demo_mode:
		_spawn_lantern_task()
	_build_rig()
	_build_wave()
	waves.seed = spawn_seed + Balance.SHIP_WAVE_SEED_OFFSET
	wave_left = waves.randf_range(Balance.SHIP_WAVE_INTERVAL.x, Balance.SHIP_WAVE_INTERVAL.y)


# --- Arena interface ---
func mover_spawn(slot: int) -> Vector3:
	var point: Array = layout.spawns.movers[slot]
	return from_ship(Vector3(point[0], Balance.CAPSULE_HEIGHT / 2.0, point[1]))


func ghost_spawn() -> Vector3:
	return from_ship(ArenaBuilder.point_of(layout.spawns.ghost, Balance.WISP_HEIGHT))


func to_ship(point: Vector3) -> Vector3:
	# A world point in the layout's own frame, wherever the ship has rolled to.
	return rig.transform.affine_inverse() * point if is_instance_valid(rig) else point


func from_ship(point: Vector3) -> Vector3:
	return rig.transform * point if is_instance_valid(rig) else point


func camera_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.camera_bounds)


func ghost_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.ghost_bounds)


func mover_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.mover_bounds)


func floor_height_at(point: Vector3) -> float:
	# The layout's deck height under this point, carried along with the ship's motion.
	var local: Vector3 = to_ship(point)
	return from_ship(Vector3(local.x, _layout_height(local), local.z)).y


func _layout_height(point: Vector3) -> float:
	var location := Vector2(point.x, point.z)
	for ramp: Dictionary in layout.ramps:
		var rect: Rect2 = ArenaBuilder.rect_of(ramp.rect)
		if rect.has_point(location):
			var along: float = (point.x - rect.position.x) / rect.size.x
			return ramp.floor + ramp.rise * (along if ramp.direction > 0 else 1.0 - along)
	for floor_data: Dictionary in layout.floors:
		if floor_data.has("polygon"):
			if Geometry2D.is_point_in_polygon(location, ArenaBuilder.polygon_of(floor_data.polygon)):
				return floor_data.floor
		elif ArenaBuilder.rect_of(floor_data.rect).has_point(location):
			return floor_data.floor
	return 0.0 # The free wisp flies safely over the ocean.


func room_at(world_point: Vector3) -> String:
	var point: Vector3 = to_ship(world_point)
	var location := Vector2(point.x, point.z)
	# Specific areas precede the main deck; height distinguishes being above the hold from standing in it.
	for room: Dictionary in layout.rooms:
		if ArenaBuilder.rect_of(room.rect).has_point(location) and point.y >= room.floor and point.y < room.floor + room.zone_height:
			return String(room.id).trim_prefix("room-").capitalize()
	return "Gangplank" if ArenaBuilder.rect_of(layout.gangplank).has_point(location) else "Sea"


# --- Round hazards ---
func _physics_process(delta: float) -> void:
	_update_rescues(delta)
	_update_sway(delta)
	_update_waves(delta)
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		if mover.global_position.y <= Balance.SHIP_WATER_Y:
			_begin_rescue(mover)
	for item: Node3D in get_tree().get_nodes_in_group("loot"):
		if item.get_parent() == self and not item.finished and item.global_position.y <= Balance.SHIP_WATER_Y:
			item._lose_value(item.value)
	for furniture: Node3D in get_tree().get_nodes_in_group("furniture"):
		if furniture.get_parent() == self and furniture is RigidBody3D and furniture.global_position.y <= Balance.SHIP_WATER_Y:
			var possession: Node = furniture.get_node_or_null("Possessable")
			if possession != null and possession.is_possessed():
				possession.ghost.leave()
			furniture.queue_free()


# --- Gangplank waves ---
func _update_waves(delta: float) -> void:
	if wave_warning_left >= 0.0:
		wave_warning_left -= delta
		if wave_warning_left < 0.0:
			_wave_hit()
		return
	# Waves are a match hazard: only in live play, so the reveal and the test harness stay calm.
	if not demo_mode or Game.phase != "live":
		return
	wave_left -= delta
	if wave_left <= 0.0:
		start_wave(Vector3.RIGHT if waves.randf() < 0.5 else Vector3.LEFT)


func start_wave(direction: Vector3) -> void:
	wave_direction = direction
	wave_warning_left = Balance.SHIP_WAVE_WARNING
	wave_left = waves.randf_range(Balance.SHIP_WAVE_INTERVAL.x, Balance.SHIP_WAVE_INTERVAL.y)
	# A swell builds out at sea on the side it comes from and runs at the plank, rising into a curling crest.
	var plank: Rect2 = ArenaBuilder.rect_of(layout.gangplank)
	var near_edge: float = plank.position.x if direction.x > 0.0 else plank.end.x
	crest.scale = Vector3(direction.x, 0.25, 1.0) # Mirrored so its face always looks at the plank.
	crest.position = Vector3(near_edge - direction.x * Balance.SHIP_WAVE_START, Balance.SHIP_WATER_Y - 0.4, plank.get_center().y)
	crest_material.albedo_color.a = 0.92
	crest.show()
	wave_label.show()
	var rise := create_tween()
	rise.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	rise.set_parallel(true)
	rise.tween_property(crest, "position:x", near_edge - direction.x * 0.9, Balance.SHIP_WAVE_WARNING).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	rise.tween_property(crest, "position:y", Balance.SHIP_WATER_Y, Balance.SHIP_WAVE_WARNING)
	rise.tween_property(crest, "scale:y", Balance.SHIP_WAVE_CREST_SCALE, Balance.SHIP_WAVE_WARNING).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	Sfx.play("whoosh", 0.55)
	print("Wave coming over the gangplank")


func on_gangplank(world_point: Vector3) -> bool:
	var point: Vector3 = to_ship(world_point)
	return ArenaBuilder.rect_of(layout.gangplank).has_point(Vector2(point.x, point.z)) and point.y > -0.5 and point.y < 1.5


func _wave_hit() -> void:
	var plank: Rect2 = ArenaBuilder.rect_of(layout.gangplank)
	var far_edge: float = plank.end.x if wave_direction.x > 0.0 else plank.position.x
	for mover: CharacterBody3D in get_tree().get_nodes_in_group("movers"):
		if mover.in_play and not mover.is_bracing() and on_gangplank(mover.global_position):
			# The push is along the ship's own plank, so it carries a mover off whichever way the ship has rolled.
			var across: Vector3 = rig.basis * wave_direction
			mover.wash(Vector3(across.x, 0.0, across.z).normalized(), absf(far_edge - to_ship(mover.global_position).x) + Balance.SHIP_WAVE_CLEARANCE)
	# The crest breaks over the plank and collapses; spray bursts up, foam drains off and the ship lurches.
	var sweep := create_tween()
	sweep.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	sweep.set_parallel(true)
	sweep.tween_property(crest, "position:x", far_edge + wave_direction.x * 0.8, Balance.SHIP_WAVE_SWEEP_TIME)
	sweep.tween_property(crest, "scale:y", 0.2, Balance.SHIP_WAVE_SWEEP_TIME * 1.6).set_ease(Tween.EASE_IN)
	sweep.tween_property(crest_material, "albedo_color:a", 0.0, Balance.SHIP_WAVE_SWEEP_TIME * 1.6)
	sweep.chain().tween_callback(crest.hide)
	spray.position = Vector3(plank.get_center().x - wave_direction.x * 0.6, 0.2, plank.get_center().y)
	spray.direction = Vector3(wave_direction.x, 1.6, 0.0)
	spray.restart()
	foam_sheet.position = Vector3(plank.get_center().x, 0.04, plank.get_center().y)
	var foam_material: StandardMaterial3D = foam_sheet.material_override
	foam_material.albedo_color.a = 0.75
	foam_sheet.show()
	var drain := create_tween()
	drain.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	drain.set_parallel(true)
	drain.tween_property(foam_material, "albedo_color:a", 0.0, Balance.SHIP_WAVE_FOAM_TIME).set_ease(Tween.EASE_IN)
	drain.tween_property(foam_sheet, "position:x", foam_sheet.position.x + wave_direction.x * 0.8, Balance.SHIP_WAVE_FOAM_TIME)
	drain.chain().tween_callback(foam_sheet.hide)
	wave_label.hide()
	lurch_push += Balance.SHIP_WAVE_LURCH * wave_direction.x
	Sfx.play("wave_crash")


func _build_wave() -> void:
	var plank: Rect2 = ArenaBuilder.rect_of(layout.gangplank)
	crest = MeshInstance3D.new()
	crest.name = "WaveCrest"
	crest.mesh = _crest_mesh(plank.size.y + 0.6) # Just past the plank's ends, clear of the ship and the tug.
	crest_material = StandardMaterial3D.new()
	crest_material.vertex_color_use_as_albedo = true
	crest_material.vertex_color_is_srgb = true # The colours below are picked in sRGB, like the rest of Balance.
	crest_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crest_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	crest_material.emission_enabled = true
	crest_material.emission = Balance.SHIP_WAVE_BODY_COLOUR
	crest_material.emission_energy_multiplier = 0.2
	crest_material.roughness = 0.6
	crest.material_override = crest_material
	crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crest.hide()
	rig.add_child(crest)
	spray = _build_spray(plank.size.y)
	rig.add_child(spray)
	foam_sheet = MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(plank.size.x + 0.6, plank.size.y)
	foam_sheet.mesh = sheet
	var foam_material := StandardMaterial3D.new()
	foam_material.albedo_color = Color(Balance.SHIP_WAVE_COLOUR, 0.0)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_sheet.material_override = foam_material
	foam_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam_sheet.hide()
	rig.add_child(foam_sheet)
	wave_label = Label3D.new()
	wave_label.text = "WAVE! BRACE!"
	wave_label.font = load(Balance.COMIC_FONT_PATH)
	wave_label.font_size = Balance.PRICE_FONT_SIZE
	wave_label.pixel_size = Balance.FLOOR_LABEL_PIXEL_SIZE * 1.6
	wave_label.outline_size = Balance.LABEL_OUTLINE
	wave_label.outline_modulate = Balance.COMIC_INK
	wave_label.modulate = Color(Balance.SHIP_WAVE_COLOUR, 1.0)
	wave_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wave_label.position = Vector3(plank.get_center().x, 2.2, plank.get_center().y)
	wave_label.hide()
	rig.add_child(wave_label)


func _crest_mesh(length: float) -> ArrayMesh:
	# A breaking wave's cross-section (x across, toward +x; y up from the sea), swept along the plank: a long back
	# slope, a steep face and a lip curling over it. Sea-green below, white foam where it breaks.
	var profile: Array[Vector2] = [
		Vector2(-2.6, 0.0), Vector2(-1.7, 0.25), Vector2(-0.9, 0.65), Vector2(-0.3, 1.05), Vector2(0.15, 1.25),
		Vector2(0.55, 1.2), Vector2(0.8, 1.0), Vector2(0.7, 0.82), Vector2(0.45, 0.88), Vector2(0.3, 0.6),
		Vector2(0.35, 0.25), Vector2(0.45, 0.0),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = length / 2.0
	for index: int in range(profile.size() - 1):
		var a: Vector2 = profile[index]
		var b: Vector2 = profile[index + 1]
		var corners: Array[Vector3] = [Vector3(a.x, a.y, -half), Vector3(b.x, b.y, -half), Vector3(b.x, b.y, half), Vector3(a.x, a.y, half)]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			var point: Vector3 = corners[corner]
			var foam_amount: float = smoothstep(0.95, 1.22, point.y) # White only along the breaking lip.
			tool.set_color(Balance.SHIP_WAVE_BODY_COLOUR.lerp(Color.WHITE, foam_amount))
			tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()


func _build_spray(length: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "WaveSpray"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = Balance.SHIP_WAVE_SPRAY
	particles.lifetime = 1.1
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.3, 0.1, length / 2.0)
	particles.spread = 35.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.5
	particles.gravity = Vector3(0, -Balance.GRAVITY, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.3
	var drop := SphereMesh.new()
	drop.radius = 0.09
	drop.height = 0.18
	drop.radial_segments = 6
	drop.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(Balance.SHIP_WAVE_COLOUR, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = material
	particles.mesh = drop
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


# --- Ship motion ---
func sway() -> float:
	# The roll, -1 to 1: positive rolls the front (+z) side down.
	if not is_nan(sway_override):
		return sway_override
	return sin(TAU * sway_time / Balance.SHIP_SWAY_PERIOD) * motion_scale


func _update_sway(delta: float) -> void:
	sway_time += delta
	lurch_push *= exp(-Balance.SHIP_LURCH_DECAY * delta)
	lurch = lerpf(lurch, lurch_push, 1.0 - exp(-Balance.SHIP_LURCH_EASE * delta))
	var roll: float = sway()
	var rising: bool = cos(TAU * sway_time / Balance.SHIP_SWAY_PERIOD) > 0.0
	if rising != sway_rising and is_nan(sway_override) and motion_scale > 0.0:
		Sfx.varied("creak", Balance.SHIP_SWAY_CREAK_DB) # The hull groans as the roll turns.
	sway_rising = rising
	_move_rig(roll)
	# Loose loot and task items on the galleon's decks creep toward the low side.
	for body: Node in get_children():
		if not body is Carryable or body.finished or body.is_held() or body.freeze:
			continue
		var possession: Node = body.get_node_or_null("Possessable")
		if possession != null and possession.is_possessed():
			continue
		if not _on_ship_deck(body.global_position):
			continue
		var target: float = Balance.SHIP_SWAY_DRIFT_SPEEDS[body.weight_class] * roll
		var change: float = clampf(target - body.linear_velocity.z, -Balance.SHIP_SWAY_GRIP * delta, Balance.SHIP_SWAY_GRIP * delta)
		if absf(target) > 0.01 and signf(change) == signf(target):
			body.apply_central_impulse(Vector3(0, 0, change * body.mass))


func _move_rig(roll: float) -> void:
	# Roll, pitch and heave on cycles of 9, 7 and 5 s never line up, so the ship rides an uneven swell.
	if not is_instance_valid(rig):
		return
	var pitch: float = sin(TAU * sway_time / Balance.SHIP_PITCH_PERIOD + 1.3) * motion_scale
	var heave: float = sin(TAU * sway_time / Balance.SHIP_HEAVE_PERIOD + 0.7) * motion_scale
	var roll_angle: float = -deg_to_rad(Balance.SHIP_SWAY_ANGLE * roll + lurch * motion_scale) # Positive roll dips +z.
	var basis := Basis.from_euler(Vector3(roll_angle, 0.0, deg_to_rad(Balance.SHIP_PITCH_ANGLE) * pitch))
	var pivot: Vector3 = Balance.SHIP_MOTION_PIVOT
	rig.transform = Transform3D(basis, pivot - basis * pivot + Vector3.UP * Balance.SHIP_HEAVE * heave)
	# Moving each collider's own transform is what lets the physics engine give it a velocity, so movers and loot
	# standing on it are carried along instead of sliding off.
	for body: AnimatableBody3D in riders:
		body.transform = rig.transform * riders[body]
	for prop: Variant in hanging.keys(): # Untyped: a freed prop can't be held in a typed variable.
		if not is_instance_valid(prop) or not prop.freeze:
			hanging.erase(prop) # Dropped or gone: it falls freely from here.
		else:
			prop.global_transform = rig.transform * hanging[prop]


func _build_rig() -> void:
	# Everything that floats moves to ShipRig; the sea, loose loot and free-standing props stay in the world.
	# Static colliders become AnimatableBody3D synced to physics and are moved one by one (a moving parent alone
	# would not move them), so movers and loot ride the moving decks.
	rig = Node3D.new()
	rig.name = "ShipRig"
	add_child(rig)
	for child: Node in get_children():
		if child == rig or child.name == "ShipEnvironment" or child is Carryable:
			continue
		if child is RigidBody3D:
			if child.freeze:
				hanging[child] = child.transform # The hanging lantern rides along until it drops.
			continue
		child.reparent(rig)
	for body: Node in rig.find_children("*", "StaticBody3D", true, false):
		if not body is AnimatableBody3D: # The haunted door is one already, and swings itself.
			_make_riding(body)


func _make_riding(body: StaticBody3D) -> void:
	var riding := AnimatableBody3D.new()
	riding.name = body.name
	riding.sync_to_physics = true
	riding.collision_layer = body.collision_layer
	riding.collision_mask = body.collision_mask
	riding.physics_material_override = body.physics_material_override
	var place: Transform3D = rig.transform.affine_inverse() * body.global_transform
	for part: Node in body.get_children():
		part.reparent(riding, false)
	body.get_parent().remove_child(body)
	body.queue_free()
	riding.transform = rig.transform * place
	add_child(riding) # Beside the rig, not under it: see _move_rig.
	riders[riding] = place


func _on_ship_deck(world_point: Vector3) -> bool:
	# Loot creeps only on the galleon's own decks, not on the tug or the plank.
	var point: Vector3 = to_ship(world_point)
	for room: Dictionary in layout.rooms:
		if room.id != "room-salvage-tug" and ArenaBuilder.rect_of(room.rect).has_point(Vector2(point.x, point.z)):
			return true
	return false


func _begin_rescue(mover: CharacterBody3D) -> void:
	if rescues.has(mover.slot):
		return
	# Release only this mover's grip, bypassing the voluntary delivery path.
	if is_instance_valid(mover.held_item):
		mover.held_item.release_for_rescue(mover)
		mover.held_item = null
	mover.set_in_play(false)
	rescues[mover.slot] = {"mover": mover, "left": Balance.SHIP_RESCUE_SECONDS}
	overboard.emit(mover.slot)
	print("Player %d overboard: rescue in %.0f seconds" % [mover.slot + 1, Balance.SHIP_RESCUE_SECONDS])


func _update_rescues(delta: float) -> void:
	for slot: int in rescues.keys():
		var rescue: Dictionary = rescues[slot]
		rescue.left -= delta
		if rescue.left > 0.0:
			continue
		var spawn: Vector3 = _clear_rescue_spawn(slot)
		if spawn == Vector3.INF:
			continue # A blocked tug slot waits for room rather than spawning inside a player or item.
		var mover: CharacterBody3D = rescue.mover
		mover.reset_for_round(spawn, true)
		mover.grab_released = false # A held phone button must be released before another grab.
		rescues.erase(slot)


func _clear_rescue_spawn(slot: int) -> Vector3:
	for offset: int in range(Balance.MAX_PLAYERS):
		var spawn: Vector3 = mover_spawn((slot + offset) % Balance.MAX_PLAYERS)
		var shape := SphereShape3D.new()
		shape.radius = Balance.CAPSULE_RADIUS
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = spawn
		query.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return spawn
	return Vector3.INF


# --- Seeded props ---
func _spawn_loot() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed
	var count: int = Balance.LOOT_COUNTS[player_count - 2] if demo_mode else -1
	var heavy_limit: int = Balance.HEAVY_LOOT_LIMITS[player_count - 2] if demo_mode else -1
	for placement: Dictionary in Catalog.pick_loot(&"ship", layout.spawns.loot, count, heavy_limit, random):
		var item: CatalogItem = placement.item
		var loot: RigidBody3D = LOOT_SCENE.instantiate()
		loot.catalog_item = item
		loot.position = ArenaBuilder.point_of(placement.spot, item.footprint.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
		add_child(loot)


func _spawn_furniture() -> void:
	for spot: Dictionary in layout.furniture:
		var prop: Node3D = load("res://props/furniture/%s.tscn" % FURNITURE[spot.kind]).instantiate()
		var height: float = 0.0
		match spot.kind:
			"slider", "hopper":
				prop.catalog_item = load("res://props/catalog/ship/%s.tres" % ("crate" if spot.kind == "slider" else "anchor"))
				height = prop.catalog_item.footprint.y / 2.0
			"door":
				prop.model_scene = load("res://props/catalog/built/ship_door.tscn")
				prop.panel_height = Balance.SHIP_DOOR_HEIGHT
				prop.item_name = "Hatch door"
			"dropper":
				prop.model_scene = load("res://props/catalog/built/ship_lantern.tscn")
				prop.item_name = "Hanging lantern"
				height = Balance.SHIP_DROPPER_HEIGHT
			"rug":
				prop.model_scene = load("res://props/catalog/built/ship_tarp.tscn")
				prop.item_name = "Deck tarp"
		prop.position = ArenaBuilder.point_of(spot, height)
		add_child(prop)


# --- Light the Lanterns ---
func oil_can_spots() -> Array[Vector3]:
	# A separate seeded stream, so the task never changes which loot spawns.
	var spots: Array[Vector3] = Balance.OIL_CAN_SPOTS.duplicate()
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed + Balance.LANTERN_SEED_OFFSET
	for index: int in range(spots.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var spot: Vector3 = spots[index]
		spots[index] = spots[other]
		spots[other] = spot
	return spots.slice(0, Balance.LANTERN_COUNT)


func _spawn_lantern_task() -> void:
	generator = LANTERN_SCENE.instantiate()
	add_child(generator)
	generator.powered_on.connect(_light_lanterns)
	for spot: Vector3 in oil_can_spots():
		var can: RigidBody3D = OIL_CAN_SCENE.instantiate()
		can.generator = generator
		can.arena = self
		can.position = spot + Vector3.UP * (Balance.OIL_CAN_SIZE.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE)
		add_child(can)


func _light_lanterns() -> void:
	# Brighten the existing ambient, moon and deck lamps; no new lights (the Ship's omni budget is spent).
	var environment: Environment = $ShipEnvironment/WorldEnvironment.environment
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.set_parallel(true)
	tween.tween_property(environment, "ambient_light_energy", Balance.SHIP_AMBIENT_ENERGY * Balance.GENERATOR_AMBIENT_RATIO, Balance.GENERATOR_LIGHT_FADE)
	tween.tween_property($ShipEnvironment, "moon_ratio", Balance.GENERATOR_MOON_RATIO, Balance.GENERATOR_LIGHT_FADE)
	for lamp: OmniLight3D in rig.get_node("ShipDressing").find_children("*", "OmniLight3D", true, false): # Rides on the rig.
		tween.tween_property(lamp, "light_energy", Balance.SHIP_LAMP_ENERGY * Balance.LANTERN_LAMP_RATIO, Balance.GENERATOR_LIGHT_FADE)
	for ghost: Node in get_tree().get_nodes_in_group("ghosts"):
		if ghost.arena == self:
			ghost.apply_generator_power()
	print("Lanterns lit: deck brightened and ghost weakened for the round")
