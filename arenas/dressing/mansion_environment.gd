# The world around the Old Mansion, all outside the play area and without colliders: a 300 m ground fading into
# the fog, the iron perimeter fence with stone pillars and a big front gate, the drive out to Haunted Hill Road
# (curbs, pavement, flickering street lamps, mailbox, hydrant, sign), a dark forest behind and beside the house
# (detailed near, cheap cones far), patchy grassland with props, a chimney stack with smoke and a weathervane,
# low mist, falling leaves and fireflies. Repeated things are MultiMeshes and nothing here casts shadows.
# Environment glow is pale yellow, blue or purple only: green glow belongs to the ghost.
extends Node3D

# --- Models ---
const DECOR: String = "res://assets/models/decor/"
const SWAY_SHADER := preload("res://assets/shaders/wind_sway.gdshader")
const GROUND_SURFACE := preload("res://assets/materials/surfaces/dead_grass.tres")
const GRAVEL_SURFACE := preload("res://assets/materials/surfaces/gravel.tres")
const PAVEMENT_SURFACE := preload("res://assets/materials/surfaces/stone_tiles.tres")
const STONE_SURFACE := preload("res://assets/materials/surfaces/stone_facade.tres")
const NEAR_TREES: Array[String] = ["nature/tree_pineTallA_detailed", "nature/tree_pineDefaultA", "nature/tree_thin_dark", "graveyard/pine-crooked"]
const NEAR_TREE_SCALES: Array[Vector2] = [Vector2(4.0, 6.0), Vector2(4.0, 6.0), Vector2(3.5, 5.0), Vector2(2.5, 3.5)]

# --- Shapes and colours (look only) ---
const GROUND_DROP: float = 0.01 # Metres below the plot's ground, out of sight under it.
const FAR_TREE_COLOUR := Color("1f2a2a")
const DIRT_COLOUR := Color("443f33") # Close to the dead grass, so the patches read as texture, not blots.
const BARK_COLOUR := Color("2e2622")
const ROAD_COLOUR := Color("2c2a33")
const CRACK_COLOUR := Color("141218")
const BULB_COLOUR := Color("fff1c9")
const PUDDLE_COLOUR := Color("1c2236")
const SMOKE_COLOUR := Color(0.55, 0.52, 0.6, 0.35)
const LEAF_COLOUR := Color("8a5a2b")
const CLEARANCE: float = 1.0 # Metres kept clear around rooms, paths, the drive and the truck.
const DEAD_TREE_HEIGHT: float = 3.2
const DEAD_TREE_BRANCHES: Array = [[1.7, 0.0, 55.0, 1.3], [2.1, 130.0, 50.0, 1.1], [2.5, 250.0, 60.0, 0.9], [2.8, 60.0, 35.0, 0.8]]
const FLICKER_STEP: float = 0.1 # Seconds between flicker rolls.
const SHUTTER_CREAK_DEGREES: float = 4.0
const VANE_SPEED: float = 0.6 # Radians per second, wandering.

# --- State ---
var arena: Node3D
var limits: Rect2
var random := RandomNumberGenerator.new()
var flicker_left: float = 0.0
var storm_left: float = 0.0 # Seconds of hard flickering after House Shake or a ghost win.
var vane: Node3D
var time: float = 0.0
var muted_colours: Dictionary = {}

# --- Setup ---
func _ready() -> void:
	_build.call_deferred() # The arena builds its layout after its children are ready.


func _exit_tree() -> void:
	Sfx.stop_ambient()


func _build() -> void:
	arena = get_parent()
	limits = arena.mover_bounds()
	random.seed = Balance.WORLD_SEED
	_add_ground()
	_add_perimeter()
	_add_front()
	_add_forest()
	_add_grassland()
	_add_props()
	_add_chimney()
	_add_atmosphere()
	for lamp: Light3D in get_tree().get_nodes_in_group("flicker_lamps"):
		lamp.set_meta("energy", lamp.light_energy)
	Sfx.start_ambient()


# --- Life: flicker, shutters, weathervane ---
func _process(delta: float) -> void:
	time += delta
	storm_left = maxf(0.0, storm_left - delta)
	flicker_left -= delta
	if flicker_left <= 0.0:
		flicker_left = FLICKER_STEP
		var chance: float = 0.5 if storm_left > 0.0 else Balance.LAMP_FLICKER_CHANCE
		for lamp: Light3D in get_tree().get_nodes_in_group("flicker_lamps"):
			lamp.light_energy = lamp.get_meta("energy", lamp.light_energy) * (Balance.LAMP_FLICKER_DIP if random.randf() < chance else 1.0)
		for glass: MeshInstance3D in get_tree().get_nodes_in_group("window_glass"):
			var dip: bool = random.randf() < chance * 0.5
			glass.material_override.emission_energy_multiplier = Balance.WINDOW_GLOW_ENERGY * (Balance.LAMP_FLICKER_DIP if dip else 1.0)
		for bulb: MeshInstance3D in get_tree().get_nodes_in_group("flicker_bulbs"):
			bulb.visible = random.randf() >= chance
	for hinge: Node3D in get_tree().get_nodes_in_group("shutters"):
		hinge.rotation.y = deg_to_rad(SHUTTER_CREAK_DEGREES) * hinge.get_meta("swing", 1.0) * (0.5 + 0.5 * sin(time * 0.7 + hinge.position.x))
	if vane != null:
		vane.rotation.y += sin(time * 0.3) * VANE_SPEED * delta


func storm(seconds: float) -> void:
	# Lamps and windows flicker hard for a while (House Shake, a ghost win).
	storm_left = maxf(storm_left, seconds)


func dust_from_walls() -> void:
	# A burst of dust falling from the wall tops (House Shake).
	var dust: GPUParticles3D = get_node_or_null("WallDust")
	if dust != null:
		dust.restart()


# --- Ground ---
func _add_ground() -> void:
	var tile_size: float = Balance.WORLD_GROUND_SIZE / Balance.WORLD_GROUND_TILES
	var centre: Vector2 = limits.get_center()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * tile_size
	for row: int in range(Balance.WORLD_GROUND_TILES):
		for column: int in range(Balance.WORLD_GROUND_TILES):
			var tile := MeshInstance3D.new()
			tile.mesh = plane
			tile.material_override = GROUND_SURFACE
			var offset: float = (Balance.WORLD_GROUND_TILES - 1) / 2.0
			tile.position = Vector3(centre.x + (column - offset) * tile_size, -GROUND_DROP, centre.y + (row - offset) * tile_size)
			add_child(tile)


# --- Perimeter fence and front gate ---
func _add_perimeter() -> void:
	var gate_x: float = _drive_rect().get_center().x
	var fence: Array[Transform3D] = []
	var pillars: Array[Transform3D] = []
	var corners: Array[Vector3] = [
		Vector3(limits.position.x, 0.0, limits.position.y), Vector3(limits.end.x, 0.0, limits.position.y),
		Vector3(limits.end.x, 0.0, limits.end.y), Vector3(limits.position.x, 0.0, limits.end.y),
	]
	var section: float = Balance.GROUNDS_FENCE_SCALE
	for side: int in range(4):
		var start: Vector3 = corners[side]
		var end: Vector3 = corners[(side + 1) % 4]
		var direction: Vector3 = (end - start).normalized()
		var basis := Basis(Vector3.UP, atan2(-direction.z, direction.x)).scaled(Vector3.ONE * section)
		var count: int = ceili(start.distance_to(end) / section)
		for index: int in range(count):
			var point: Vector3 = start.lerp(end, (index + 0.5) / count)
			if side == 2 and absf(point.x - gate_x) < Balance.GATE_WIDTH / 2.0:
				continue # The gate's opening.
			fence.append(Transform3D(basis, point))
		var posts: int = ceili(start.distance_to(end) / Balance.FENCE_PILLAR_SPACING)
		for index: int in range(posts):
			var point: Vector3 = start.lerp(end, float(index) / posts)
			if side == 2 and absf(point.x - gate_x) < Balance.GATE_WIDTH / 2.0 + 1.0:
				continue
			pillars.append(Transform3D(Basis().scaled(Vector3.ONE * Balance.FENCE_PILLAR_SCALE), point))
	_multimesh(_mesh("graveyard/iron-fence", false), fence)
	_multimesh(_mesh("graveyard/border-pillar", false), pillars)

	# The big gate: tall stone posts and two iron leaves standing open toward the road.
	for edge: float in [-1.0, 1.0]:
		var hinge := Vector3(gate_x + edge * Balance.GATE_WIDTH / 2.0, 0.0, limits.end.y)
		_place("graveyard/border-pillar", hinge, 0.0, Balance.FENCE_PILLAR_SCALE * 1.4)
		var leaf: Node3D = _place("graveyard/iron-fence", hinge + Vector3(0.0, 0.0, Balance.GATE_WIDTH / 4.0), PI / 2.0, Balance.GATE_WIDTH / 2.0)
		leaf.position.x += edge * 0.1


# --- Front: drive, road, lamps and street furniture ---
func _drive_rect() -> Rect2:
	# Gravel from the front gate posts on the path out to the road, under the parked truck.
	var front_gate: Dictionary = arena.layout.gates.filter(func(gate: Dictionary) -> bool: return gate.id == "gate-front")[0]
	var start_z: float = front_gate.from[1]
	return Rect2(arena.layout.paths[0].rect[0], start_z, arena.layout.paths[0].rect[2], limits.end.y + Balance.ROAD_GAP - start_z)


func _add_front() -> void:
	var drive: Rect2 = _drive_rect()
	_box(Vector3(drive.get_center().x, 0.008, drive.get_center().y), Vector3(drive.size.x, 0.016, drive.size.y), GRAVEL_SURFACE)

	var near_edge: float = limits.end.y + Balance.ROAD_GAP # Where the near pavement starts.
	var road_z: float = near_edge + Balance.PAVEMENT_WIDTH + Balance.ROAD_TILE / 2.0
	var centre_x: float = limits.get_center().x
	var tiles: Array[Transform3D] = []
	var count: int = ceili(Balance.ROAD_LENGTH / Balance.ROAD_TILE)
	for index: int in range(count):
		var x: float = centre_x - Balance.ROAD_LENGTH / 2.0 + (index + 0.5) * Balance.ROAD_TILE
		tiles.append(Transform3D(Basis().scaled(Vector3.ONE * Balance.ROAD_TILE), Vector3(x, 0.0, road_z)))
	_multimesh(_mesh("roads/road-straight", false), tiles)
	for pavement_z: float in [near_edge + Balance.PAVEMENT_WIDTH / 2.0, road_z + Balance.ROAD_TILE / 2.0 + Balance.PAVEMENT_WIDTH / 2.0]:
		_box(Vector3(centre_x, Balance.CURB_HEIGHT / 2.0, pavement_z), Vector3(Balance.ROAD_LENGTH, Balance.CURB_HEIGHT, Balance.PAVEMENT_WIDTH), PAVEMENT_SURFACE)
	# Cracks in the asphalt.
	for crack: int in range(24):
		var length: float = random.randf_range(0.8, 2.5)
		var spot := Vector3(centre_x + random.randf_range(-60.0, 60.0), 0.03, road_z + random.randf_range(-2.4, 2.4))
		var piece: MeshInstance3D = _box(spot, Vector3(length, 0.01, 0.06), _flat(CRACK_COLOUR))
		piece.rotation.y = random.randf() * PI

	# Street lamps along the near pavement; only the ones nearest the gate shine real light.
	var lamps: int = int(Balance.ROAD_LENGTH / Balance.STREET_LAMP_SPACING)
	var gate_x: float = drive.get_center().x
	var lamp_spots: Array[float] = []
	for index: int in range(lamps):
		lamp_spots.append(gate_x + (index - lamps / 2) * Balance.STREET_LAMP_SPACING + Balance.STREET_LAMP_SPACING / 2.0)
	lamp_spots.sort_custom(func(a: float, b: float) -> bool: return absf(a - gate_x) < absf(b - gate_x))
	for index: int in range(lamp_spots.size()):
		var base := Vector3(lamp_spots[index], Balance.CURB_HEIGHT, near_edge + 0.3)
		_place("roads/light-curved", base, -PI / 2.0, Balance.STREET_LAMP_SCALE)
		var bulb: MeshInstance3D = _sphere(base + Vector3(0.0, 0.64 * Balance.STREET_LAMP_SCALE, 0.9), 0.18, _glow(BULB_COLOUR))
		bulb.add_to_group("flicker_bulbs")
		if index < Balance.STREET_LAMP_LIT:
			var light := OmniLight3D.new()
			light.position = bulb.position + Vector3.DOWN * 0.3
			light.light_color = Balance.LANTERN_COLOUR
			light.light_energy = Balance.LANTERN_ENERGY
			light.omni_range = Balance.LANTERN_RANGE * 1.5
			light.add_to_group("flicker_lamps")
			add_child(light)

	# Mailbox, hydrant and the street sign by the gate.
	_mailbox(Vector3(gate_x - Balance.GATE_WIDTH / 2.0 - 1.4, 0.0, limits.end.y + 1.2))
	_hydrant(Vector3(gate_x + Balance.GATE_WIDTH / 2.0 + 2.5, Balance.CURB_HEIGHT, near_edge + 1.0))
	var sign_spot := Vector3(gate_x - Balance.GATE_WIDTH / 2.0 - 3.5, Balance.CURB_HEIGHT, near_edge + 0.6)
	_place("roads/road-sign-street", sign_spot, 0.0, 4.0)
	var words := Label3D.new()
	words.text = "Haunted Hill Rd"
	words.font_size = 40
	words.pixel_size = 0.008
	words.modulate = Color("e8f2ff")
	words.outline_modulate = Color("1d3b6e")
	words.outline_size = 10
	words.position = sign_spot + Vector3(0.0, 2.3, 0.2)
	add_child(words)


func _mailbox(spot: Vector3) -> void:
	_box(spot + Vector3(0.0, 0.55, 0.0), Vector3(0.08, 1.1, 0.08), _flat(BARK_COLOUR))
	_box(spot + Vector3(0.0, 1.2, 0.0), Vector3(0.28, 0.26, 0.5), _flat(Color("3b3550")))
	_box(spot + Vector3(0.16, 1.32, -0.1), Vector3(0.02, 0.18, 0.06), _flat(Color("b03a3a"))) # The flag.


func _hydrant(spot: Vector3) -> void:
	var red := _flat(Color("9c2f3a"))
	_cylinder(spot + Vector3(0.0, 0.3, 0.0), 0.16, 0.6, red)
	_sphere(spot + Vector3(0.0, 0.62, 0.0), 0.17, red)
	_cylinder(spot + Vector3(0.0, 0.42, 0.0), 0.07, 0.42, red).rotation.z = PI / 2.0


# --- Forest ---
func _add_forest() -> void:
	# Detailed trees in a band behind and beside the house (not in front, where the road is); cheap cones beyond.
	var near: Rect2 = limits.grow(Balance.FOREST_NEAR_DEPTH)
	var keep_out: Rect2 = limits.grow(3.0)
	var road_line: float = limits.end.y - 2.0
	var transforms: Array = []
	for model: int in range(NEAR_TREES.size() + 1):
		transforms.append([] as Array[Transform3D])
	var placed: int = 0
	while placed < Balance.FOREST_NEAR_TREES:
		var point := Vector2(random.randf_range(near.position.x, near.end.x), random.randf_range(near.position.y, road_line))
		if keep_out.has_point(point):
			continue
		var kind: int = NEAR_TREES.size() if random.randf() < Balance.FOREST_DEAD_SHARE else random.randi_range(0, NEAR_TREES.size() - 1)
		var size: float = random.randf_range(1.0, 1.6) if kind == NEAR_TREES.size() else random.randf_range(NEAR_TREE_SCALES[kind].x, NEAR_TREE_SCALES[kind].y)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size)
		transforms[kind].append(Transform3D(basis, Vector3(point.x, 0.0, point.y)))
		placed += 1
	for kind: int in range(NEAR_TREES.size()):
		_multimesh(_mesh(NEAR_TREES[kind], true, Color(0, 0, 0, 0), Balance.FOREST_SHADE), transforms[kind])
	_multimesh(_dead_tree_mesh(), transforms[NEAR_TREES.size()])

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.8
	cone.height = 9.0
	cone.radial_segments = 6
	cone.rings = 1
	cone.material = _flat(FAR_TREE_COLOUR)
	var far: Rect2 = limits.grow(Balance.FOREST_NEAR_DEPTH + Balance.FOREST_FAR_DEPTH)
	var far_trees: Array[Transform3D] = []
	while far_trees.size() < Balance.FOREST_FAR_TREES:
		var point := Vector2(random.randf_range(far.position.x, far.end.x), random.randf_range(far.position.y, far.end.y))
		if near.has_point(point) and point.y < road_line or limits.grow(6.0).has_point(point):
			continue
		if point.y > limits.end.y and point.y < limits.end.y + Balance.ROAD_GAP + Balance.PAVEMENT_WIDTH * 2.0 + Balance.ROAD_TILE + 4.0:
			continue # Keep the road and its verges open.
		var size: float = random.randf_range(0.8, 1.6)
		far_trees.append(Transform3D(Basis().scaled(Vector3(size, size * random.randf_range(0.9, 1.4), size)), Vector3(point.x, cone.height * size / 2.0, point.y)))
	_multimesh(cone, far_trees)


# --- Grassland ---
func _add_grassland() -> void:
	var clear: Array[Rect2] = _clear_rects()
	_scatter("nature/grass", Balance.GRASS_TUFTS / 2, Vector2(1.2, 2.2), clear, true, Balance.GRASS_TUFT_COLOUR)
	_scatter("nature/grass_large", Balance.GRASS_TUFTS / 2, Vector2(1.2, 2.2), clear, true, Balance.GRASS_TUFT_COLOUR)
	_scatter("nature/grass_large", Balance.WEEDS, Vector2(2.0, 3.0), clear, true, Balance.WEED_COLOUR, 2.2)
	_scatter("nature/plant_bush", Balance.DEAD_BUSHES, Vector2(2.0, 3.2), clear, true, Balance.DEAD_BUSH_COLOUR)
	# Darker dirt patches make the grass look patchy.
	var patch := CylinderMesh.new()
	patch.top_radius = 1.0
	patch.bottom_radius = 1.0
	patch.height = 0.01
	patch.radial_segments = 10
	patch.material = _flat(DIRT_COLOUR)
	var patches: Array[Transform3D] = []
	for index: int in range(Balance.DIRT_PATCHES):
		var point: Vector2 = _free_point(clear)
		var size: float = random.randf_range(0.6, 1.6)
		patches.append(Transform3D(Basis().scaled(Vector3(size, 1.0, size * random.randf_range(0.6, 1.0))), Vector3(point.x, 0.004, point.y)))
	_multimesh(patch, patches)


func _clear_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for room: Dictionary in arena.layout.rooms:
		rects.append(ArenaBuilder.rect_of(room.rect).grow(CLEARANCE))
	for path: Dictionary in arena.layout.paths:
		rects.append(ArenaBuilder.rect_of(path.rect).grow(CLEARANCE))
	rects.append(_drive_rect().grow(CLEARANCE))
	if is_instance_valid(arena.generator):
		var centre := Vector2(arena.generator.position.x, arena.generator.position.z)
		var size := Vector2(Balance.GENERATOR_ZONE_SIZE.x, Balance.GENERATOR_ZONE_SIZE.z + Balance.GENERATOR_BODY_SIZE.z)
		var origin := centre - Vector2(size.x / 2.0, Balance.GENERATOR_ZONE_SIZE.z / 2.0 + Balance.GENERATOR_BODY_SIZE.z)
		rects.append(Rect2(origin, size).grow(CLEARANCE))
	# The truck and its delivery half-circle, whichever way the truck faces: the zone reaches DELIVERY_RADIUS out
	# from the tailgate, the body TRUCK_LENGTH back from it.
	var tailgate := Vector2(arena.layout.truck.tailgate[0], arena.layout.truck.tailgate[1])
	var faces := Vector2(arena.layout.truck.faces[0], arena.layout.truck.faces[1]).normalized()
	var side := Vector2(-faces.y, faces.x) * Balance.DELIVERY_RADIUS
	var truck_area := Rect2(tailgate, Vector2.ZERO)
	for end: Vector2 in [tailgate + faces * Balance.DELIVERY_RADIUS, tailgate - faces * Balance.TRUCK_LENGTH]:
		truck_area = truck_area.expand(end + side).expand(end - side)
	rects.append(truck_area.grow(CLEARANCE))
	return rects


func _free_point(clear: Array[Rect2]) -> Vector2:
	# A random point inside the fence that is not on the house, garden, paths, drive or truck.
	while true:
		var point := Vector2(random.randf_range(limits.position.x, limits.end.x), random.randf_range(limits.position.y, limits.end.y))
		var blocked: bool = false
		for rect: Rect2 in clear:
			blocked = blocked or rect.has_point(point)
		if not blocked:
			return point
	return Vector2.ZERO


func _scatter(model: String, count: int, sizes: Vector2, clear: Array[Rect2], sway: bool, tint: Color = Color(0, 0, 0, 0), stretch: float = 1.0) -> void:
	var transforms: Array[Transform3D] = []
	for index: int in range(count):
		var point: Vector2 = _free_point(clear)
		var size: float = random.randf_range(sizes.x, sizes.y)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3(size, size * stretch, size))
		transforms.append(Transform3D(basis, Vector3(point.x, 0.0, point.y)))
	_multimesh(_mesh(model, sway, tint), transforms)


# --- Props in the grassland ---
func _add_props() -> void:
	# A tiny family graveyard west of the house.
	var plot := Vector3(limits.position.x + 4.5, 0.0, 22.0)
	var stones: Array[String] = ["graveyard/gravestone-round", "graveyard/gravestone-cross", "graveyard/gravestone-bevel", "graveyard/gravestone-broken", "graveyard/gravestone-round"]
	for index: int in range(stones.size()):
		_place(stones[index], plot + Vector3((index % 3 - 1) * 1.3, 0.0, floori(index / 3.0) * 1.6 - 0.8), random.randf_range(-0.2, 0.2), 1.5)
	for side: int in range(4):
		var direction := Vector3.RIGHT.rotated(Vector3.UP, side * PI / 2.0)
		for step: int in range(3):
			if side == 0 and step == 1:
				continue # The little graveyard's gate gap.
			var spot: Vector3 = plot + direction.rotated(Vector3.UP, PI / 2.0) * 2.6 + direction * (step - 1)
			_place("graveyard/iron-fence", spot, side * PI / 2.0, 1.0)
	_place("graveyard/pine-crooked", plot + Vector3(-2.0, 0.0, -3.4), 0.6, 3.0)

	# A crooked scarecrow among pumpkins, east of the garden.
	var field := Vector3(limits.end.x - 4.5, 0.0, 19.0)
	_scarecrow(field)
	for index: int in range(7):
		var kind: String = ["graveyard/pumpkin", "graveyard/pumpkin-tall", "graveyard/pumpkin-carved"][index % 3]
		_place(kind, field + Vector3(random.randf_range(-2.5, 2.5), 0.0, random.randf_range(-3.0, 3.0)), random.randf() * TAU, random.randf_range(1.4, 2.2))

	# A broken cart, west of the drive.
	var cart: Node3D = _place("town/cart", Vector3(limits.position.x + 5.0, -0.15, limits.end.y - 4.0), 0.4, 2.0)
	cart.rotation.z = deg_to_rad(14.0)
	var wheel: Node3D = _place("town/wheel", Vector3(limits.position.x + 6.8, 0.1, limits.end.y - 2.6), 0.0, 2.0)
	wheel.rotation.z = PI / 2.0

	# Faintly glowing mushrooms (pale blue), stumps, logs and rocks.
	for spot: Vector2 in [Vector2(limits.end.x - 3.0, 4.0), Vector2(limits.position.x + 3.0, 8.0), Vector2(limits.end.x - 2.0, limits.end.y - 3.0), Vector2(limits.position.x + 2.0, -4.0)]:
		var cluster: Node3D = _place("nature/mushroom_tanGroup", Vector3(spot.x, 0.0, spot.y), random.randf() * TAU, 2.4)
		for mesh: MeshInstance3D in cluster.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = _glow(Balance.MUSHROOM_GLOW, 0.6)
	for index: int in range(10):
		var kind: String = ["nature/stump_old", "nature/log", "nature/rock_tallA"][index % 3]
		var point: Vector2 = _free_point(_clear_rects())
		_place(kind, Vector3(point.x, 0.0, point.y), random.randf() * TAU, random.randf_range(1.5, 2.5))

	# A puddle for the frogs.
	var puddle: MeshInstance3D = _cylinder(Vector3(limits.end.x - 4.0, 0.006, 9.0), 1.6, 0.01, _puddle())
	puddle.scale = Vector3(1.4, 1.0, 1.0)


func _scarecrow(spot: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = spot
	holder.rotation.z = deg_to_rad(9.0) # Crooked.
	add_child(holder)
	var wood := _flat(BARK_COLOUR)
	var pole := _box(Vector3(0.0, 1.1, 0.0), Vector3(0.12, 2.2, 0.12), wood)
	var arms := _box(Vector3(0.0, 1.55, 0.0), Vector3(1.6, 0.1, 0.1), wood)
	var coat := _box(Vector3(0.0, 1.3, 0.0), Vector3(0.6, 0.7, 0.3), _flat(Color("4a3f5c")))
	for part: Node3D in [pole, arms, coat]:
		part.reparent(holder, false)
	var head: Node3D = _place("graveyard/pumpkin-carved", Vector3.ZERO, 0.3, 1.7)
	head.reparent(holder, false)
	head.position = Vector3(0.0, 1.75, 0.0)


# --- Chimney stack and weathervane ---
func _add_chimney() -> void:
	# Free-standing just outside the back wall (the house has no roof), with smoke and a weathervane on top.
	var size: Vector3 = Balance.CHIMNEY_SIZE
	var base := Vector3(15.0, 0.0, -size.z / 2.0 - Balance.ARENA_WALL_THICKNESS / 2.0)
	_box(base + Vector3.UP * size.y / 2.0, size, STONE_SURFACE)
	_box(base + Vector3.UP * (size.y + 0.15), Vector3(size.x + 0.3, 0.3, size.z + 0.3), STONE_SURFACE)
	var smoke := GPUParticles3D.new()
	smoke.position = base + Vector3.UP * (size.y + 0.4)
	smoke.amount = 18
	smoke.lifetime = 6.0
	smoke.draw_pass_1 = _quad(1.2, SMOKE_COLOUR, true)
	smoke.process_material = _particles(Vector3(0.6, 1.0, 0.2), 0.6, Vector3(0.3, 0.4, 0.0), 3.0)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	vane = Node3D.new()
	vane.position = base + Vector3.UP * (size.y + 1.2)
	add_child(vane)
	var iron := _flat(Color("1c1a22"))
	_box(Vector3(0.0, -0.45, 0.0), Vector3(0.05, 0.9, 0.05), iron).reparent(vane, false)
	_box(Vector3.ZERO, Vector3(1.0, 0.06, 0.06), iron).reparent(vane, false)
	_box(Vector3(-0.45, 0.0, 0.0), Vector3(0.05, 0.3, 0.3), iron).reparent(vane, false) # The tail fin.


# --- Mist, leaves, fireflies, wall dust ---
func _add_atmosphere() -> void:
	# Soft pale-purple mist blobs drifting low between the trunks behind the house.
	for index: int in range(14):
		var mist := MeshInstance3D.new()
		mist.mesh = _quad(random.randf_range(8.0, 14.0), Balance.MIST_COLOUR, true)
		mist.position = Vector3(random.randf_range(limits.position.x - 10.0, limits.end.x + 10.0), random.randf_range(0.6, 1.4), limits.position.y - random.randf_range(4.0, 16.0))
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mist)
		var drift: Tween = mist.create_tween().set_loops()
		drift.tween_property(mist, "position:x", mist.position.x + random.randf_range(3.0, 6.0), random.randf_range(10.0, 18.0)).set_trans(Tween.TRANS_SINE)
		drift.tween_property(mist, "position:x", mist.position.x, random.randf_range(10.0, 18.0)).set_trans(Tween.TRANS_SINE)

	var leaves := GPUParticles3D.new()
	leaves.position = Vector3(limits.get_center().x, 7.0, limits.position.y - 4.0)
	leaves.amount = 40
	leaves.lifetime = 9.0
	leaves.visibility_aabb = AABB(Vector3(-30, -10, -10), Vector3(60, 14, 30))
	leaves.draw_pass_1 = _quad(0.18, LEAF_COLOUR, false)
	leaves.process_material = _particles(Vector3(25.0, 1.0, 5.0), 0.4, Vector3(0.6, -0.5, 0.4))
	add_child(leaves)

	for spot: Vector3 in [Vector3(limits.end.x - 4.0, 0.8, 12.0), Vector3(limits.position.x + 4.0, 0.8, 14.0), Vector3(limits.get_center().x, 0.8, limits.end.y - 4.0)]:
		var flies := GPUParticles3D.new()
		flies.position = spot
		flies.amount = 16
		flies.lifetime = 6.0
		flies.draw_pass_1 = _quad(0.08, Balance.FIREFLY_COLOUR, true, true)
		flies.process_material = _particles(Vector3(4.0, 0.8, 4.0), 0.25, Vector3(0.0, 0.05, 0.0))
		add_child(flies)

	var dust := GPUParticles3D.new()
	dust.name = "WallDust"
	dust.position = Vector3(10.0, 4.0, 7.5)
	dust.amount = 80
	dust.lifetime = 2.0
	dust.one_shot = true
	dust.emitting = false
	dust.explosiveness = 0.9
	dust.visibility_aabb = AABB(Vector3(-15, -5, -10), Vector3(30, 10, 20))
	dust.draw_pass_1 = _quad(0.12, Color(0.7, 0.66, 0.6, 0.8), false)
	dust.process_material = _particles(Vector3(10.0, 0.2, 7.5), 0.3, Vector3(0.0, -3.0, 0.0))
	add_child(dust)


# --- Mesh and material helpers ---
func _mesh(model: String, sway: bool, tint: Color = Color(0, 0, 0, 0), shade: float = 1.0) -> Mesh:
	# The model's first mesh with muted colours; with sway, a tint or a shade, its surfaces use the wind shader.
	var scene: Node = load(DECOR + model + ".glb").instantiate()
	var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = source.mesh.duplicate()
	for surface: int in range(mesh.get_surface_count()):
		var original := mesh.surface_get_material(surface) as StandardMaterial3D
		if original == null:
			continue
		var muted: StandardMaterial3D = ArenaBuilder.muted_material(original)
		if not sway and tint.a == 0.0 and shade == 1.0:
			mesh.surface_set_material(surface, muted)
			continue
		var material := ShaderMaterial.new()
		material.shader = SWAY_SHADER
		var colour: Color = tint if tint.a > 0.0 else muted.albedo_color
		material.set_shader_parameter("albedo", Color(colour.r * shade, colour.g * shade, colour.b * shade, colour.a))
		material.set_shader_parameter("use_texture", muted.albedo_texture != null and tint.a == 0.0)
		if muted.albedo_texture != null:
			material.set_shader_parameter("albedo_texture", muted.albedo_texture)
		material.set_shader_parameter("sway_strength", Balance.SWAY_STRENGTH if sway else 0.0)
		material.set_shader_parameter("sway_speed", Balance.SWAY_SPEED)
		mesh.surface_set_material(surface, material)
	scene.free()
	return mesh


func _dead_tree_mesh() -> Mesh:
	# A twisted bare tree: a tapered trunk with a few leaning branches, swaying gently.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.22
	trunk.height = DEAD_TREE_HEIGHT
	trunk.radial_segments = 6
	trunk.rings = 1
	tool.append_from(trunk, 0, Transform3D(Basis(Vector3.FORWARD, 0.08), Vector3.UP * DEAD_TREE_HEIGHT / 2.0))
	for branch: Array in DEAD_TREE_BRANCHES:
		var limb := CylinderMesh.new()
		limb.top_radius = 0.02
		limb.bottom_radius = 0.07
		limb.height = branch[3]
		limb.radial_segments = 5
		limb.rings = 1
		var basis := Basis(Vector3.UP, deg_to_rad(branch[1])) * Basis(Vector3.BACK, deg_to_rad(branch[2]))
		tool.append_from(limb, 0, Transform3D(basis, Vector3.UP * branch[0] + basis * Vector3.UP * branch[3] / 2.0))
	var mesh: ArrayMesh = tool.commit()
	var bark := ShaderMaterial.new()
	bark.shader = SWAY_SHADER
	bark.set_shader_parameter("albedo", BARK_COLOUR)
	bark.set_shader_parameter("sway_strength", Balance.SWAY_STRENGTH * 0.5)
	bark.set_shader_parameter("sway_speed", Balance.SWAY_SPEED)
	mesh.surface_set_material(0, bark)
	return mesh


func _multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _place(model: String, spot: Vector3, yaw: float, size: float) -> Node3D:
	var node: Node3D = load(DECOR + model + ".glb").instantiate()
	node.position = spot
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	ArenaBuilder.mute_colours(node)
	for mesh: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _box(centre: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _shape(box, centre, material)


func _sphere(centre: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	return _shape(ball, centre, material)


func _cylinder(centre: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = height
	tube.radial_segments = 10
	return _shape(tube, centre, material)


func _shape(mesh: Mesh, centre: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = centre
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _flat(colour: Color) -> StandardMaterial3D:
	if not muted_colours.has(colour):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.95
		muted_colours[colour] = material
	return muted_colours[colour]


func _glow(colour: Color, strength: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = Balance.GLOW_ENERGY * strength
	return material


func _puddle() -> StandardMaterial3D:
	var water := StandardMaterial3D.new()
	water.albedo_color = PUDDLE_COLOUR
	water.metallic = 0.6
	water.roughness = 0.08
	return water


func _quad(size: float, colour: Color, soft: bool, glowing: bool = false) -> QuadMesh:
	# A camera-facing square; "soft" fades its edges with a radial gradient.
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	if soft:
		var gradient := GradientTexture2D.new()
		gradient.fill = GradientTexture2D.FILL_RADIAL
		gradient.fill_from = Vector2(0.5, 0.5)
		gradient.fill_to = Vector2(1.0, 0.5)
		gradient.gradient = Gradient.new()
		gradient.gradient.set_color(0, Color.WHITE)
		gradient.gradient.set_color(1, Color(1, 1, 1, 0))
		material.albedo_texture = gradient
	if glowing:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = Balance.GLOW_ENERGY
	quad.material = material
	return quad


func _particles(box: Vector3, speed: float, gravity: Vector3, grow: float = 1.0) -> ParticleProcessMaterial:
	# Simple drifting particles from a box: spread speed and gravity; "grow" above 1 enlarges them over their life.
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = speed * 0.5
	process.initial_velocity_max = speed
	process.gravity = gravity
	if grow != 1.0:
		var growth := Curve.new()
		growth.add_point(Vector2(0.0, 1.0 / grow))
		growth.add_point(Vector2(1.0, 1.0))
		var curve := CurveTexture.new()
		curve.curve = growth
		process.scale_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	return process
