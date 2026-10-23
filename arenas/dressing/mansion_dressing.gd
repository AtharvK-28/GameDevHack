# The Old Mansion's hand-placed dressing: decor, lamps and the grounds around the plot. It is its own scene,
# instanced into Mansion.tscn, so rebuilding the layout never wipes it. Lamp and flame strengths come from
# Balance (by group), so only positions live in the scene; only the moon casts shadows. Decor colours are muted
# toward grey so nothing looks like loot. The grounds outside the plot (a wide dark ground, the iron perimeter
# fence, bare trees and grass tufts) are generated once the arena has built its layout.
extends Node3D

# --- Grounds models ---
const FENCE_MODEL := preload("res://assets/models/decor/graveyard/iron-fence.glb")
const GRASS_MODELS: Array[PackedScene] = [
	preload("res://assets/models/decor/nature/grass.glb"), preload("res://assets/models/decor/nature/grass_large.glb"),
]
const GROUND_SURFACE := preload("res://assets/materials/surfaces/dead_grass.tres")
const BARK_COLOUR := Color("2e2622")
const GRASS_SCALE := Vector2(1.2, 2.0) # Random size range for a grass tuft.
const TREE_SCALE := Vector2(0.8, 1.6) # Random size range for a bare tree.
const GROUND_DROP: float = 0.01 # Metres the wide ground sits below the plot's ground, out of sight under it.

# --- Bare tree shape: a trunk and branches as [height on trunk, turn (degrees), lean from upright (degrees), length] ---
const TRUNK_HEIGHT: float = 3.2
const TRUNK_RADII := Vector2(0.08, 0.22) # Top and bottom, metres.
const BRANCH_RADII := Vector2(0.02, 0.07)
const BRANCHES: Array = [[1.7, 0.0, 55.0, 1.3], [2.1, 130.0, 50.0, 1.1], [2.5, 250.0, 60.0, 0.9], [2.8, 60.0, 35.0, 0.8]]

# --- Setup ---
func _ready() -> void:
	_set_lamps("ceiling_lamps", Balance.LAMP_COLOUR, Balance.LAMP_ENERGY, Balance.LAMP_RANGE)
	_set_lamps("fires", Balance.FIRE_COLOUR, Balance.FIRE_ENERGY, Balance.FIRE_RANGE)
	_set_lamps("lanterns", Balance.LANTERN_COLOUR, Balance.LANTERN_ENERGY, Balance.LANTERN_RANGE)
	for flame: MeshInstance3D in find_children("*", "MeshInstance3D"):
		if flame.is_in_group("flames"):
			flame.material_override.emission = Balance.FIRE_COLOUR
			flame.material_override.emission_energy_multiplier = Balance.FLAME_GLOW_ENERGY
	for body: StaticBody3D in find_children("*", "StaticBody3D"):
		body.collision_layer = Balance.WORLD_LAYER
		body.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	ArenaBuilder.mute_colours(self)
	_build_grounds.call_deferred() # The arena builds its layout after its children are ready.


# --- Grounds ---
func _build_grounds() -> void:
	var arena: Node3D = get_parent()
	var limits: Rect2 = arena.mover_bounds()
	var random := RandomNumberGenerator.new()
	random.seed = Balance.GROUNDS_SEED

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * Balance.GROUNDS_SIZE
	ground.mesh = plane
	ground.material_override = GROUND_SURFACE
	ground.position = Vector3(limits.get_center().x, -GROUND_DROP, limits.get_center().y)
	add_child(ground)

	_add_fence(limits)
	_add_trees(limits, random)
	_add_grass(limits, arena.layout, random)


func _add_fence(limits: Rect2) -> void:
	# Iron fence sections all the way round the movers' outer limits; movers never reach it, so no collider.
	var length: float = Balance.GROUNDS_FENCE_SCALE
	var corners: Array[Vector3] = [
		Vector3(limits.position.x, 0.0, limits.position.y), Vector3(limits.end.x, 0.0, limits.position.y),
		Vector3(limits.end.x, 0.0, limits.end.y), Vector3(limits.position.x, 0.0, limits.end.y),
	]
	var transforms: Array[Transform3D] = []
	for side: int in range(4):
		var start: Vector3 = corners[side]
		var end: Vector3 = corners[(side + 1) % 4]
		var count: int = ceili(start.distance_to(end) / length)
		var direction: Vector3 = (end - start).normalized()
		var basis := Basis(Vector3.UP, atan2(-direction.z, direction.x)).scaled(Vector3.ONE * Balance.GROUNDS_FENCE_SCALE)
		for index: int in range(count):
			transforms.append(Transform3D(basis, start.lerp(end, (index + 0.5) / count)))
	_add_multimesh(_model_mesh(FENCE_MODEL), transforms)


func _add_trees(limits: Rect2, random: RandomNumberGenerator) -> void:
	# Bare trees scattered in a band outside the fence; the fog turns the far ones into silhouettes.
	var outer: Rect2 = limits.grow(Balance.GROUNDS_TREE_BAND)
	var transforms: Array[Transform3D] = []
	while transforms.size() < Balance.GROUNDS_TREE_COUNT:
		var point := Vector2(random.randf_range(outer.position.x, outer.end.x), random.randf_range(outer.position.y, outer.end.y))
		if limits.grow(1.0).has_point(point):
			continue
		var size: float = random.randf_range(TREE_SCALE.x, TREE_SCALE.y)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size)
		transforms.append(Transform3D(basis, Vector3(point.x, 0.0, point.y)))
	_add_multimesh(_dead_tree_mesh(), transforms)


func _add_grass(limits: Rect2, layout: Dictionary, random: RandomNumberGenerator) -> void:
	# Grass tufts inside the fence, kept off the rooms, paths, truck and delivery zone.
	var clear_rects: Array[Rect2] = []
	for room: Dictionary in layout.rooms:
		clear_rects.append(ArenaBuilder.rect_of(room.rect).grow(Balance.GROUNDS_GRASS_CLEARANCE))
	for path: Dictionary in layout.get("paths", []):
		clear_rects.append(ArenaBuilder.rect_of(path.rect).grow(Balance.GROUNDS_GRASS_CLEARANCE))
	var tailgate := Vector2(layout.truck.tailgate[0], layout.truck.tailgate[1])
	var truck_clearance: float = Balance.TRUCK_LENGTH + Balance.GROUNDS_GRASS_CLEARANCE
	var transforms: Array[Array] = [[], []] # One list per grass model.
	var placed: int = 0
	while placed < Balance.GROUNDS_GRASS_COUNT:
		var point := Vector2(random.randf_range(limits.position.x, limits.end.x), random.randf_range(limits.position.y, limits.end.y))
		var blocked: bool = point.distance_to(tailgate) < truck_clearance
		for rect: Rect2 in clear_rects:
			blocked = blocked or rect.has_point(point)
		if blocked:
			continue
		var size: float = random.randf_range(GRASS_SCALE.x, GRASS_SCALE.y)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size)
		transforms[placed % 2].append(Transform3D(basis, Vector3(point.x, 0.0, point.y)))
		placed += 1
	for index: int in range(GRASS_MODELS.size()):
		var typed: Array[Transform3D] = []
		typed.assign(transforms[index])
		_add_multimesh(_model_mesh(GRASS_MODELS[index]), typed)


# --- Helpers ---
func _set_lamps(group: String, colour: Color, energy: float, light_range: float) -> void:
	for lamp: OmniLight3D in find_children("*", "OmniLight3D"):
		if lamp.is_in_group(group):
			lamp.light_color = colour
			lamp.light_energy = energy
			lamp.omni_range = light_range
			lamp.shadow_enabled = false


func _model_mesh(scene: PackedScene) -> Mesh:
	# The first mesh in an imported model, with its colours muted like the rest of the decor.
	var model: Node = scene.instantiate()
	var source: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = source.mesh.duplicate()
	for surface: int in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		if material != null:
			mesh.surface_set_material(surface, ArenaBuilder.muted_material(material))
	model.free()
	return mesh


func _dead_tree_mesh() -> Mesh:
	# One low-poly mesh: a tapered trunk with a few bare, leaning branches.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = TRUNK_RADII.x
	trunk.bottom_radius = TRUNK_RADII.y
	trunk.height = TRUNK_HEIGHT
	trunk.radial_segments = 6
	trunk.rings = 1
	tool.append_from(trunk, 0, Transform3D(Basis(), Vector3.UP * TRUNK_HEIGHT / 2.0))
	for branch: Array in BRANCHES:
		var limb := CylinderMesh.new()
		limb.top_radius = BRANCH_RADII.x
		limb.bottom_radius = BRANCH_RADII.y
		limb.height = branch[3]
		limb.radial_segments = 5
		limb.rings = 1
		var basis := Basis(Vector3.UP, deg_to_rad(branch[1])) * Basis(Vector3.BACK, deg_to_rad(branch[2]))
		tool.append_from(limb, 0, Transform3D(basis, Vector3.UP * branch[0] + basis * Vector3.UP * branch[3] / 2.0))
	var mesh: ArrayMesh = tool.commit()
	var bark := StandardMaterial3D.new()
	bark.albedo_color = BARK_COLOUR
	bark.roughness = 1.0
	mesh.surface_set_material(0, bark)
	return mesh


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Far and thin: not worth the shadow pass.
	add_child(instance)
