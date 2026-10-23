# The Mansion's animals, all outside the play area and without colliders. Each is a few simple dark shapes,
# cartoonish at the camera's distance: crows that hop and fly off when a mover comes close (or the house shakes,
# or something smashes nearby), bats that loop past now and then, a black cat on a fence pillar whose head follows
# the ghost wisp, rats running along the back wall, frogs by the puddle, an owl that hoots, and pairs of
# pale-yellow eyes that blink in the forest. A distant howl plays now and then.
extends Node3D

# --- Looks ---
const FEATHER := Color("15131a")
const FUR := Color("1a1820")
const RAT_FUR := Color("3a3540")
const FROG_SKIN := Color("3d4a2f")
const OWL_FEATHER := Color("3b3128")
const BEAK := Color("8a6a2a")
const CROW_FLIGHT_HEIGHT: float = 14.0 # Metres a scared crow climbs before vanishing.
const CROW_FLIGHT_SECONDS: float = 2.2
const BAT_FLIGHT_SECONDS: float = 7.0
const BAT_HEIGHT: float = 9.0
const RAT_SPEED: float = 2.5 # Metres per second.

# --- State ---
var arena: Node3D
var random := RandomNumberGenerator.new()
var crows: Array[Node3D] = []
var cat_head: Node3D
var owl: Node3D
var bats: Array[Node3D] = []
var timers: Dictionary = {} # Name → seconds until it next happens.
var check_left: float = 0.0
var shared: Dictionary = {} # Meshes and materials reused by every creature.


# --- Setup ---
func _ready() -> void:
	_build.call_deferred() # After the arena has its layout.


func _build() -> void:
	arena = get_parent().get_parent()
	random.seed = Balance.WORLD_SEED + 1
	var limits: Rect2 = arena.mover_bounds()
	var pillar_top: float = 0.76 * Balance.FENCE_PILLAR_SCALE

	# Crows on fence pillars, the chimney top and stumps at the forest edge.
	var perches: Array[Vector3] = [
		Vector3(limits.position.x + 6.0, pillar_top, limits.position.y), Vector3(limits.end.x - 6.0, pillar_top, limits.position.y),
		Vector3(limits.end.x, pillar_top, limits.position.y + 12.0), Vector3(limits.position.x, pillar_top, limits.position.y + 18.0),
		Vector3(15.0, Balance.CHIMNEY_SIZE.y + 0.3, -0.9), Vector3(limits.position.x + 12.0, 0.0, limits.position.y - 4.0),
		Vector3(limits.end.x - 2.0, 0.0, limits.position.y - 5.0),
	]
	for perch: Vector3 in perches:
		var crow: Node3D = _crow()
		crow.position = perch
		crow.rotation.y = random.randf() * TAU
		crow.set_meta("perch", perch)
		crow.set_meta("hop_left", random.randf_range(1.0, 4.0))
		crows.append(crow)

	# The black cat on the front fence pillar nearest the left corner.
	var cat := Node3D.new()
	cat.position = Vector3(limits.position.x + Balance.FENCE_PILLAR_SPACING * 2.0, pillar_top, limits.end.y)
	add_child(cat)
	_part(cat, _sphere_mesh(), Vector3(0.0, 0.14, 0.0), Vector3(0.22, 0.24, 0.34), FUR)
	_part(cat, _box_mesh(), Vector3(0.0, 0.14, 0.22), Vector3(0.03, 0.03, 0.3), FUR).rotation.x = -0.9 # The tail.
	cat_head = Node3D.new()
	cat_head.position = Vector3(0.0, 0.3, -0.12)
	cat.add_child(cat_head)
	_part(cat_head, _sphere_mesh(), Vector3.ZERO, Vector3(0.16, 0.14, 0.15), FUR)
	for side: float in [-1.0, 1.0]:
		_part(cat_head, _box_mesh(), Vector3(side * 0.05, 0.08, 0.0), Vector3(0.04, 0.07, 0.03), FUR).rotation.z = side * 0.4
		_part(cat_head, _sphere_mesh(), Vector3(side * 0.035, 0.01, -0.07), Vector3.ONE * 0.025, Balance.EYE_COLOUR, true)

	# Rats along the back wall, outside.
	for index: int in range(2):
		var rat := Node3D.new()
		rat.position = Vector3(2.0 + index * 8.0, 0.0, -0.45)
		add_child(rat)
		_part(rat, _sphere_mesh(), Vector3(0.0, 0.06, 0.0), Vector3(0.22, 0.1, 0.1), RAT_FUR)
		_part(rat, _box_mesh(), Vector3(-0.2, 0.03, 0.0), Vector3(0.2, 0.015, 0.015), RAT_FUR)
		_run_rat(rat)

	# Frogs by the puddle.
	var pond := Vector3(limits.end.x - 4.0, 0.0, 9.0)
	for index: int in range(3):
		var frog := Node3D.new()
		frog.position = pond + Vector3.FORWARD.rotated(Vector3.UP, index * TAU / 3.0) * 2.1
		add_child(frog)
		_part(frog, _sphere_mesh(), Vector3(0.0, 0.06, 0.0), Vector3(0.16, 0.1, 0.18), FROG_SKIN)
		frog.set_meta("home", frog.position)
		frog.add_to_group("frogs")

	# The owl on a stump at the forest edge.
	owl = Node3D.new()
	owl.position = Vector3(limits.position.x + 3.0, 1.2, limits.position.y - 3.0)
	add_child(owl)
	_part(owl, _sphere_mesh(), Vector3(0.0, 0.25, 0.0), Vector3(0.3, 0.42, 0.28), OWL_FEATHER)
	_part(owl, _box_mesh(), Vector3(0.0, -0.4, 0.0), Vector3(0.2, 0.8, 0.2), Color("2e2622")) # Its post.
	for side: float in [-1.0, 1.0]:
		_part(owl, _sphere_mesh(), Vector3(side * 0.07, 0.34, 0.12), Vector3.ONE * 0.06, Balance.EYE_COLOUR, true)

	# Pale-yellow eyes deep in the forest behind the house.
	for spot: Vector3 in [Vector3(4.0, 1.0, limits.position.y - 14.0), Vector3(13.0, 1.4, limits.position.y - 19.0), Vector3(23.0, 0.8, limits.position.y - 12.0)]:
		var pair := Node3D.new()
		pair.position = spot
		pair.add_to_group("forest_eyes")
		add_child(pair)
		for side: float in [-1.0, 1.0]:
			_part(pair, _sphere_mesh(), Vector3(side * 0.12, 0.0, 0.0), Vector3(0.09, 0.06, 0.05), Balance.EYE_COLOUR, true)

	timers = {
		"bats": random.randf_range(Balance.BAT_INTERVAL.x, Balance.BAT_INTERVAL.y),
		"owl": random.randf_range(Balance.OWL_INTERVAL.x, Balance.OWL_INTERVAL.y),
		"howl": random.randf_range(Balance.HOWL_INTERVAL.x, Balance.HOWL_INTERVAL.y),
		"blink": random.randf_range(Balance.EYE_BLINK_INTERVAL.x, Balance.EYE_BLINK_INTERVAL.y),
		"frog": random.randf_range(2.0, 5.0),
	}


# --- Behaviour ---
func _process(delta: float) -> void:
	if timers.is_empty():
		return
	for event: String in timers:
		timers[event] -= delta
	if timers.bats <= 0.0:
		timers.bats = random.randf_range(Balance.BAT_INTERVAL.x, Balance.BAT_INTERVAL.y)
		_fly_bats()
	if timers.owl <= 0.0:
		timers.owl = random.randf_range(Balance.OWL_INTERVAL.x, Balance.OWL_INTERVAL.y)
		Sfx.play("owl", 1.0, Balance.CREATURE_VOLUME_DB)
		owl.create_tween().tween_property(owl, "rotation:y", owl.rotation.y + PI / 2.0 * (1.0 if random.randf() < 0.5 else -1.0), 0.4)
	if timers.howl <= 0.0:
		timers.howl = random.randf_range(Balance.HOWL_INTERVAL.x, Balance.HOWL_INTERVAL.y)
		Sfx.play("howl", random.randf_range(0.9, 1.1), Balance.CREATURE_VOLUME_DB - 6.0)
	if timers.blink <= 0.0:
		timers.blink = random.randf_range(Balance.EYE_BLINK_INTERVAL.x, Balance.EYE_BLINK_INTERVAL.y)
		var pair: Node3D = get_tree().get_nodes_in_group("forest_eyes").pick_random()
		var blink: Tween = pair.create_tween()
		blink.tween_property(pair, "scale:y", 0.05, 0.08)
		blink.tween_property(pair, "scale:y", 1.0, 0.1)
	if timers.frog <= 0.0:
		timers.frog = random.randf_range(2.0, 5.0)
		_hop(get_tree().get_nodes_in_group("frogs").pick_random(), 0.25, 0.3)

	# Crows: hop now and then; fly off when a mover comes close.
	check_left -= delta
	var check_movers: bool = check_left <= 0.0
	if check_movers:
		check_left = 0.2
	for crow: Node3D in crows:
		if not crow.visible:
			continue
		crow.set_meta("hop_left", crow.get_meta("hop_left") - delta)
		if crow.get_meta("hop_left") <= 0.0 and not crow.has_meta("flying"):
			crow.set_meta("hop_left", random.randf_range(2.0, 6.0))
			crow.rotation.y += random.randf_range(-1.2, 1.2)
			_hop(crow, 0.12, 0.25)
		if check_movers and _mover_near(crow.global_position, Balance.CROW_SCARE_DISTANCE):
			_fly_off(crow)

	# The cat watches the wisp.
	var ghosts: Array[Node] = get_tree().get_nodes_in_group("ghosts")
	if not ghosts.is_empty() and is_instance_valid(cat_head):
		var target: Vector3 = (ghosts[0] as Node3D).global_position
		var flat := Vector3(target.x - cat_head.global_position.x, 0.0, target.z - cat_head.global_position.z)
		if flat.length() > 0.1:
			var wanted: float = atan2(-flat.x, -flat.z) - cat_head.get_parent().rotation.y
			cat_head.rotation.y = lerp_angle(cat_head.rotation.y, wanted, minf(1.0, delta * 3.0))


func scatter(around: Vector3 = Vector3.INF, distance: float = INF) -> void:
	# Every crow (or those within "distance" of "around") takes off, cawing.
	var cawed: bool = false
	for crow: Node3D in crows:
		if crow.visible and not crow.has_meta("flying") and (around == Vector3.INF or crow.global_position.distance_to(around) <= distance):
			_fly_off(crow)
			if not cawed:
				Sfx.play("caw", random.randf_range(0.9, 1.15), Balance.CREATURE_VOLUME_DB)
				cawed = true


func _fly_off(crow: Node3D) -> void:
	crow.set_meta("flying", true)
	var away := Vector3(random.randf_range(-1.0, 1.0), 0.0, random.randf_range(-1.0, -0.2)).normalized() * 12.0
	var flight: Tween = crow.create_tween()
	flight.tween_property(crow, "position", crow.position + away + Vector3.UP * CROW_FLIGHT_HEIGHT, CROW_FLIGHT_SECONDS).set_ease(Tween.EASE_IN)
	flight.tween_callback(func() -> void: crow.visible = false)
	flight.tween_interval(Balance.CROW_RETURN_SECONDS)
	flight.tween_callback(func() -> void:
		crow.position = crow.get_meta("perch")
		crow.visible = true
		crow.remove_meta("flying")
	)


func _fly_bats() -> void:
	# Three bats sweep across behind the house, flapping.
	var limits: Rect2 = arena.mover_bounds()
	var from := Vector3(limits.position.x - 15.0, BAT_HEIGHT, limits.position.y - 2.0)
	var to := Vector3(limits.end.x + 15.0, BAT_HEIGHT + 3.0, limits.get_center().y)
	for index: int in range(3):
		var bat := Node3D.new()
		add_child(bat)
		bat.position = from + Vector3(index * 1.2, index * 0.6, index * 0.8)
		bat.look_at(to, Vector3.UP)
		for side: float in [-1.0, 1.0]:
			_part(bat, _box_mesh(), Vector3(side * 0.22, 0.0, 0.0), Vector3(0.4, 0.02, 0.2), FUR)
		_part(bat, _sphere_mesh(), Vector3.ZERO, Vector3(0.12, 0.1, 0.18), FUR)
		var flap: Tween = bat.create_tween().set_loops()
		flap.tween_property(bat, "scale:x", 0.3, 0.12)
		flap.tween_property(bat, "scale:x", 1.0, 0.12)
		var path: Tween = bat.create_tween()
		path.tween_property(bat, "position", to + Vector3(index * 1.2, 0.0, index), BAT_FLIGHT_SECONDS).set_trans(Tween.TRANS_SINE)
		path.tween_callback(bat.queue_free)


func _run_rat(rat: Node3D) -> void:
	# Scurries along the back wall between two spots, pausing at each end.
	var start: float = rat.position.x
	var end: float = start + random.randf_range(5.0, 8.0)
	var run: Tween = rat.create_tween().set_loops()
	run.tween_callback(func() -> void: rat.rotation.y = 0.0)
	run.tween_property(rat, "position:x", end, (end - start) / RAT_SPEED)
	run.tween_interval(random.randf_range(1.5, 4.0))
	run.tween_callback(func() -> void: rat.rotation.y = PI)
	run.tween_property(rat, "position:x", start, (end - start) / RAT_SPEED)
	run.tween_interval(random.randf_range(1.5, 4.0))


func _hop(animal: Node3D, height: float, seconds: float) -> void:
	var base: float = animal.position.y
	var hop: Tween = animal.create_tween()
	hop.tween_property(animal, "position:y", base + height, seconds / 2.0).set_ease(Tween.EASE_OUT)
	hop.tween_property(animal, "position:y", base, seconds / 2.0).set_ease(Tween.EASE_IN)


func _mover_near(point: Vector3, distance: float) -> bool:
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		if mover.visible and Vector2(mover.global_position.x - point.x, mover.global_position.z - point.z).length() < distance:
			return true
	return false


# --- Building helpers ---
func _crow() -> Node3D:
	var crow := Node3D.new()
	add_child(crow)
	_part(crow, _sphere_mesh(), Vector3(0.0, 0.16, 0.0), Vector3(0.18, 0.18, 0.3), FEATHER)
	_part(crow, _sphere_mesh(), Vector3(0.0, 0.3, -0.13), Vector3.ONE * 0.13, FEATHER)
	_part(crow, _box_mesh(), Vector3(0.0, 0.29, -0.23), Vector3(0.04, 0.04, 0.1), BEAK)
	_part(crow, _box_mesh(), Vector3(0.0, 0.14, 0.2), Vector3(0.12, 0.02, 0.16), FEATHER) # The tail.
	return crow


func _part(parent: Node3D, mesh: Mesh, offset: Vector3, size: Vector3, colour: Color, glowing: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = offset
	part.scale = size
	part.material_override = _material(colour, glowing)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func _material(colour: Color, glowing: bool) -> StandardMaterial3D:
	var key: String = "%s%s" % [colour.to_html(), glowing]
	if not shared.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.9
		if glowing:
			material.emission_enabled = true
			material.emission = colour
			material.emission_energy_multiplier = Balance.GLOW_ENERGY
		shared[key] = material
	return shared[key]


func _sphere_mesh() -> SphereMesh:
	if not shared.has("sphere"):
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = 8
		ball.rings = 4
		shared["sphere"] = ball
	return shared["sphere"]


func _box_mesh() -> BoxMesh:
	if not shared.has("box"):
		shared["box"] = BoxMesh.new()
	return shared["box"]
