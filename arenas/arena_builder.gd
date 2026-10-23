# Builds an arena from a layout data file (arenas/layouts/<arena>_layout.json, metres, Y up):
# ground, room floors (raised rooms become solid blocks), two-sided walls with trim (camera-facing walls fade
# while they hide a player) with glowing windows, arches over doorways, iron gates standing open, see-through balustrades with solid
# colliders, stairs (visible steps over one invisible ramp), fences, paths, the truck and one Area3D zone per room. It knows nothing about any one arena, so every
# arena can reuse it. Surfaces are named in the layout and loaded from assets/materials/surfaces/<name>.tres
# (triplanar, so the generated boxes need no UVs).
class_name ArenaBuilder
extends RefCounted

const TRUCK_SCENE := preload("res://props/TruckZone.tscn")
const TRUCK_MODEL_SCENE := preload("res://props/Truck.tscn")
const SURFACE_PATH: String = "res://assets/materials/surfaces/%s.tres"

# Muted copies of model materials and textures, shared by every arena build.
static var muted_materials: Dictionary = {}
static var muted_textures: Dictionary = {}

# --- Loading ---
static func load_layout(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Arena layout %s could not be read" % path)
		return {}
	return data


static func build(arena: Node3D, layout: Dictionary) -> Area3D:
	# Builds everything into the arena node and returns its truck zone.
	_build_ground(arena, layout.ground)
	for room: Dictionary in layout.rooms:
		_build_room(arena, room)
	for wall: Dictionary in layout.walls:
		_build_wall(arena, wall, layout)
	for door: Dictionary in layout.doors:
		if door.has("arch"):
			_build_arch(arena, door)
	for gate: Dictionary in layout.get("gates", []):
		_build_gate(arena, gate)
	for railing: Dictionary in layout.get("railings", []):
		_build_railing(arena, railing)
	for stairs: Dictionary in layout.get("stairs", []):
		_build_stairs(arena, stairs)
	for fence: Dictionary in layout.get("fences", []):
		_build_fence(arena, fence, layout.fence_surface)
	for path: Dictionary in layout.get("paths", []):
		var rect: Rect2 = rect_of(path.rect)
		_visual_box(arena, path.id, _box_from_rect(rect, 0.0, Balance.ARENA_FLOOR_SLAB), _surface(path.surface))
	return _build_truck(arena, layout.truck)


# --- Decor colours ---
static func mute_colours(model: Node) -> void:
	# Pulls an imported model's colours toward grey (DECOR_DESATURATION) and darkens them (DECOR_SHADE), so decor
	# sits in the dusk mood and never looks like loot. Builder meshes (which use material_override) are left alone.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override != null or mesh.mesh == null:
			continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null:
				mesh.set_surface_override_material(surface, muted_material(material))


static func muted_material(material: StandardMaterial3D) -> StandardMaterial3D:
	if not muted_materials.has(material):
		var copy: StandardMaterial3D = material.duplicate()
		copy.albedo_color = _muted_colour(material.albedo_color)
		if material.albedo_texture != null:
			copy.albedo_texture = _muted_texture(material.albedo_texture)
		muted_materials[material] = copy
	return muted_materials[material]


static func _muted_texture(texture: Texture2D) -> Texture2D:
	if not muted_textures.has(texture):
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.clear_mipmaps()
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				image.set_pixel(x, y, _muted_colour(image.get_pixel(x, y)))
		image.generate_mipmaps()
		muted_textures[texture] = ImageTexture.create_from_image(image)
	return muted_textures[texture]


static func _muted_colour(colour: Color) -> Color:
	var grey: float = colour.get_luminance()
	var muted: Color = colour.lerp(Color(grey, grey, grey, colour.a), Balance.DECOR_DESATURATION)
	return Color(muted.r * Balance.DECOR_SHADE, muted.g * Balance.DECOR_SHADE, muted.b * Balance.DECOR_SHADE, colour.a)


# --- Small conversions ---
static func rect_of(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


static func point_of(spot: Dictionary, height: float) -> Vector3:
	# A spawn spot at a height above its floor.
	return Vector3(spot.at[0], float(spot.get("floor", 0.0)) + height, spot.at[1])


static func _box_from_rect(rect: Rect2, bottom: float, height: float) -> AABB:
	return AABB(Vector3(rect.position.x, bottom, rect.position.y), Vector3(rect.size.x, height, rect.size.y))


static func _surface(surface: String) -> StandardMaterial3D:
	return load(SURFACE_PATH % surface)


static func _indoor_room_at(layout: Dictionary, point: Vector3) -> Dictionary:
	# The indoor room whose floor plan contains this point, or {} when it is outside the house.
	for room: Dictionary in layout.rooms:
		if not room.get("outdoors", false) and rect_of(room.rect).has_point(Vector2(point.x, point.z)):
			return room
	return {}


# --- Floors and rooms ---
static func _build_ground(arena: Node3D, ground: Dictionary) -> void:
	var rect: Rect2 = rect_of(ground.rect)
	_solid_box(arena, "Ground", _box_from_rect(rect, -Balance.FLOOR_THICKNESS, Balance.FLOOR_THICKNESS), _surface(ground.surface))


static func _build_room(arena: Node3D, room: Dictionary) -> void:
	var rect: Rect2 = rect_of(room.rect)
	var floor_height: float = room.floor
	if floor_height > 0.0:
		# A raised room is a solid block up to its floor: nothing can get underneath it.
		_solid_box(arena, room.id + "-block", _box_from_rect(rect, 0.0, floor_height), _surface(room.base_surface))
	_visual_box(arena, room.id + "-floor", _box_from_rect(rect, floor_height, Balance.ARENA_FLOOR_SLAB), _surface(room.floor_surface))

	# The room zone: named by the room id, from the floor up to the top of the walls.
	var zone := Area3D.new()
	zone.name = room.id
	zone.add_to_group("room_zones")
	zone.collision_layer = 0
	zone.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	zone.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, Balance.ARENA_WALL_HEIGHT, rect.size.y)
	shape.shape = box
	zone.add_child(shape)
	zone.position = Vector3(rect.get_center().x, floor_height + Balance.ARENA_WALL_HEIGHT / 2.0, rect.get_center().y)
	arena.add_child(zone)


# --- Walls, railings and fences ---
static func _build_wall(arena: Node3D, wall: Dictionary, layout: Dictionary) -> void:
	# A full-height wall from the ground up to ARENA_WALL_HEIGHT above its room's floor. Each face shows the room
	# it faces, with skirting, wainscoting and a dado rail, or the house's outside stone. Camera-facing walls
	# ("see_through") are FadeWalls: solid until they hide a player, and they never cast shadows.
	var top: float = float(wall.get("floor", 0.0)) + Balance.ARENA_WALL_HEIGHT
	var fades: bool = wall.get("see_through", false)
	var body: StaticBody3D = FadeWall.new() if fades else StaticBody3D.new()
	body.name = wall.id
	_set_world_layers(body)
	arena.add_child(body)
	var box: AABB = _segment_box(wall.from, wall.to, 0.0, top, Balance.ARENA_WALL_THICKNESS)
	_add_box_shape(body, box)
	if fades:
		(body as FadeWall).box = box

	var half: float = Balance.ARENA_WALL_THICKNESS / 2.0
	var middle: Vector3 = box.get_center()
	for side: float in [-1.0, 1.0]:
		var room: Dictionary = _indoor_room_at(layout, middle + _wall_normal(wall) * side * (half + 0.05))
		var surface: String = layout.exterior_surface if room.is_empty() else room.wall_surface
		_add_mesh(body, _segment_box(wall.from, wall.to, 0.0, top, half, side * half / 2.0), _surface(surface), fades)
		if not room.is_empty():
			_add_trim(body, wall, side, float(room.floor), layout.trim, fades)
	for along: float in wall.get("windows", []):
		_add_window(body, wall, along, _surface(layout.trim.rail), fades)


static func _add_trim(body: StaticBody3D, wall: Dictionary, side: float, floor_height: float, trim: Dictionary, fades: bool) -> void:
	# Wainscoting up to ARENA_WAINSCOT_HEIGHT, a dado rail on top of it and a skirting board, proud of one face.
	var face: float = Balance.ARENA_WALL_THICKNESS / 2.0
	var wainscot_top: float = floor_height + Balance.ARENA_WAINSCOT_HEIGHT
	var parts: Array = [
		[floor_height, wainscot_top, Balance.ARENA_WAINSCOT_DEPTH, trim.wainscot],
		[wainscot_top - Balance.ARENA_RAIL_HEIGHT, wainscot_top, Balance.ARENA_RAIL_DEPTH, trim.rail],
		[floor_height, floor_height + Balance.ARENA_SKIRTING_HEIGHT, Balance.ARENA_RAIL_DEPTH, trim.rail],
	]
	for part: Array in parts:
		var depth: float = part[2]
		_add_mesh(body, _segment_box(wall.from, wall.to, part[0], part[1], depth, side * (face + depth / 2.0)), _surface(part[3]), fades)


static func _add_window(body: StaticBody3D, wall: Dictionary, along: float, frame_material: Material, fades: bool) -> void:
	# A glowing window "along" metres from the wall's start: a lit pane poking out of both faces, a frame and a
	# cross of glazing bars.
	var start := Vector3(wall.from[0], 0.0, wall.from[1])
	var direction: Vector3 = (Vector3(wall.to[0], 0.0, wall.to[1]) - start).normalized()
	var size: Vector2 = Balance.ARENA_WINDOW_SIZE
	var frame: float = Balance.ARENA_WINDOW_FRAME
	var depth: float = Balance.ARENA_WALL_THICKNESS
	var centre: Vector3 = start + direction * along + Vector3.UP * (float(wall.get("floor", 0.0)) + Balance.ARENA_WINDOW_SILL + size.y / 2.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Balance.ARENA_WINDOW_GLASS_COLOUR
	glass.emission_enabled = true
	glass.emission = Balance.WINDOW_GLOW_COLOUR
	glass.emission_energy_multiplier = Balance.WINDOW_GLOW_ENERGY
	_add_mesh(body, _box_around(centre, direction, size.x, size.y, depth + 0.02), glass, fades)
	for side: float in [-1.0, 1.0]:
		_add_mesh(body, _box_around(centre + direction * side * (size.x + frame) / 2.0, direction, frame, size.y + frame * 2.0, depth + 0.04), frame_material, fades)
		_add_mesh(body, _box_around(centre + Vector3.UP * side * (size.y + frame) / 2.0, direction, size.x, frame, depth + 0.04), frame_material, fades)
	_add_mesh(body, _box_around(centre, direction, frame / 2.0, size.y, depth + 0.04), frame_material, fades)
	_add_mesh(body, _box_around(centre, direction, size.x, frame / 2.0, depth + 0.04), frame_material, fades)


static func _build_fence(arena: Node3D, fence: Dictionary, surface: String) -> void:
	_solid_box(arena, "Fence", _segment_box(fence.from, fence.to, 0.0, Balance.ARENA_FENCE_HEIGHT, Balance.ARENA_FENCE_THICKNESS), _surface(surface))


static func _build_railing(arena: Node3D, railing: Dictionary) -> void:
	# A balustrade you can see through (tapered balusters, newel posts, a handrail and a base rail) over one solid
	# collider, so nothing gets past or falls off.
	var start := Vector3(railing.from[0], railing.base_from, railing.from[1])
	var end := Vector3(railing.to[0], railing.base_to, railing.to[1])
	var body := StaticBody3D.new()
	body.name = railing.id
	_set_world_layers(body)
	arena.add_child(body)
	var rise := Vector3.UP * Balance.ARENA_RAILING_HEIGHT
	_add_slab_shape(body, start + rise / 2.0, end + rise / 2.0, Balance.ARENA_RAILING_HEIGHT, Balance.ARENA_RAILING_THICKNESS)
	var material: StandardMaterial3D = _surface(railing.surface)

	# Balusters, one MultiMesh for the whole run.
	var baluster := CylinderMesh.new()
	baluster.top_radius = Balance.ARENA_BALUSTER_RADIUS * 0.6
	baluster.bottom_radius = Balance.ARENA_BALUSTER_RADIUS
	baluster.height = Balance.ARENA_RAILING_HEIGHT
	baluster.radial_segments = 6
	baluster.material = material
	var count: int = maxi(1, ceili(start.distance_to(end) / Balance.ARENA_BALUSTER_SPACING))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = baluster
	multimesh.instance_count = count + 1
	for index: int in range(count + 1):
		multimesh.set_instance_transform(index, Transform3D(Basis(), start.lerp(end, float(index) / count) + rise / 2.0))
	var balusters := MultiMeshInstance3D.new()
	balusters.multimesh = multimesh
	body.add_child(balusters)

	# Newel posts at the ends and every ARENA_NEWEL_SPACING metres.
	var newels: int = maxi(1, ceili(start.distance_to(end) / Balance.ARENA_NEWEL_SPACING))
	for index: int in range(newels + 1):
		var base: Vector3 = start.lerp(end, float(index) / newels)
		var size := Vector3(Balance.ARENA_NEWEL_SIZE, Balance.ARENA_RAILING_HEIGHT + Balance.ARENA_HANDRAIL_SIZE.y, Balance.ARENA_NEWEL_SIZE)
		_add_mesh(body, AABB(base - Vector3(size.x / 2.0, 0.0, size.z / 2.0), size), material, false)

	# Handrail on top and a base rail along the floor.
	for height: float in [Balance.ARENA_RAILING_HEIGHT, Balance.ARENA_HANDRAIL_SIZE.y / 2.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(Balance.ARENA_HANDRAIL_SIZE.x, Balance.ARENA_HANDRAIL_SIZE.y, start.distance_to(end))
		rail_mesh.material = material
		rail.mesh = rail_mesh
		body.add_child(rail)
		rail.global_transform = _along(start + Vector3.UP * height, end + Vector3.UP * height)


# --- Arches and gates ---
static func _build_arch(arena: Node3D, door: Dictionary) -> void:
	# Pillars just outside the opening and a curved head from ARENA_ARCH_SPRING up to the wall top, so the doorway
	# keeps its full width and at least ARENA_ARCH_SPRING of height. No collider: nothing reaches that high.
	# It fades with its wall (a FadeWall of its own).
	var floor_height: float = door.floor
	var top: float = floor_height + Balance.ARENA_WALL_HEIGHT
	var opening: AABB = _segment_box(door.from, door.to, floor_height, top, Balance.ARENA_ARCH_DEPTH)
	var along: Vector3 = (Vector3(door.to[0], 0.0, door.to[1]) - Vector3(door.from[0], 0.0, door.from[1])).normalized()
	var width: float = Vector2(door.to[0] - door.from[0], door.to[1] - door.from[1]).length()
	var arch := FadeWall.new()
	arch.name = door.id + "-arch"
	arena.add_child(arch)
	arch.box = opening.grow(Balance.ARENA_ARCH_PILLAR_WIDTH)
	var material: StandardMaterial3D = _surface(door.arch)

	# The two pillars, full height, beside the opening.
	for end: float in [-1.0, 1.0]:
		var centre: Vector3 = opening.get_center() + along * end * (width + Balance.ARENA_ARCH_PILLAR_WIDTH) / 2.0
		_add_mesh(arch, _box_around(centre, along, Balance.ARENA_ARCH_PILLAR_WIDTH, Balance.ARENA_WALL_HEIGHT, Balance.ARENA_ARCH_DEPTH), material, true)

	# The head: vertical slices whose undersides follow a half-ellipse from the spring line to the crown.
	var slice_width: float = width / Balance.ARENA_ARCH_SLICES
	for index: int in range(Balance.ARENA_ARCH_SLICES):
		var across: float = -width / 2.0 + slice_width * (index + 0.5)
		var curve: float = sqrt(maxf(0.0, 1.0 - pow(across / (width / 2.0), 2.0)))
		var underside: float = floor_height + Balance.ARENA_ARCH_SPRING + (Balance.ARENA_ARCH_CROWN - Balance.ARENA_ARCH_SPRING) * curve
		var centre: Vector3 = opening.get_center() + along * across
		centre.y = (underside + top) / 2.0
		_add_mesh(arch, _box_around(centre, along, slice_width, top - underside, Balance.ARENA_ARCH_DEPTH), material, true)


static func _build_gate(arena: Node3D, gate: Dictionary) -> void:
	# An iron gate standing open: one leaf hinged at each end of the opening, swung toward "swing", so nothing
	# stands in the opening. Leaves get thin colliders; stone posts (optional) get box colliders.
	var body := StaticBody3D.new()
	body.name = gate.id
	_set_world_layers(body)
	arena.add_child(body)
	var swing := Vector3(gate.swing[0], 0.0, gate.swing[1]).normalized()
	for hinge_values: Array in [gate.from, gate.to]:
		var hinge := Vector3(hinge_values[0], 0.0, hinge_values[1])
		var leaf: Node3D = load(Balance.ARENA_GATE_LEAF_MODEL).instantiate()
		var model := Node3D.new() # Hinge at its origin; the leaf runs along its +X.
		model.position = hinge
		model.rotation.y = atan2(-swing.z, swing.x)
		leaf.position = Balance.ARENA_GATE_LEAF_OFFSET
		mute_colours(leaf)
		model.add_child(leaf)
		body.add_child(model)
		var leaf_centre: Vector3 = hinge + swing * Balance.ARENA_GATE_LEAF_LENGTH / 2.0 + Vector3.UP * Balance.ARENA_GATE_LEAF_HEIGHT / 2.0
		_add_box_shape(body, _box_around(leaf_centre, swing, Balance.ARENA_GATE_LEAF_LENGTH, Balance.ARENA_GATE_LEAF_HEIGHT, Balance.ARENA_GATE_LEAF_THICKNESS))
		if gate.get("posts", false):
			var post: Node3D = load(Balance.ARENA_GATE_POST_MODEL).instantiate()
			post.position = hinge
			post.scale = Vector3.ONE * Balance.ARENA_GATE_POST_SCALE
			mute_colours(post)
			body.add_child(post)
			var size := Vector3(Balance.ARENA_GATE_POST_WIDTH, Balance.ARENA_GATE_POST_HEIGHT, Balance.ARENA_GATE_POST_WIDTH)
			_add_box_shape(body, AABB(hinge - Vector3(size.x / 2.0, 0.0, size.z / 2.0), size))


static func _box_around(centre: Vector3, along: Vector3, length: float, height: float, depth: float) -> AABB:
	# An axis-aligned box centred on centre: length along "along" (X or Z), depth across, height tall.
	var size := Vector3(length, height, depth) if absf(along.x) > absf(along.z) else Vector3(depth, height, length)
	return AABB(centre - size / 2.0, size)


# --- Stairs ---
static func _build_stairs(arena: Node3D, stairs: Dictionary) -> void:
	# Visible steps rise toward the room's back (−Z); one invisible ramp over them carries movers and loot.
	var rect: Rect2 = rect_of(stairs.rect)
	var rise: float = stairs.rise
	var steps: int = stairs.steps
	var step_depth: float = rect.size.y / steps
	for index: int in range(steps):
		var back: float = rect.end.y - step_depth * (index + 1)
		var step := AABB(Vector3(rect.position.x, 0.0, back), Vector3(rect.size.x, rise * (index + 1) / steps, step_depth))
		_visual_box(arena, "%s-step-%d" % [stairs.id, index + 1], step, _surface(stairs.surface))

	var bottom := Vector3(rect.get_center().x, 0.0, rect.end.y)
	var top := Vector3(rect.get_center().x, rise, rect.position.y)
	var ramp := StaticBody3D.new()
	ramp.name = stairs.id + "-ramp"
	_set_world_layers(ramp)
	arena.add_child(ramp)
	# The ramp's top surface runs from the bottom step's front edge to the gallery's edge.
	var normal: Vector3 = (top - bottom).cross(Vector3.RIGHT).normalized()
	if normal.y < 0.0:
		normal = -normal
	var middle: Vector3 = (top + bottom) / 2.0 - normal * Balance.ARENA_RAMP_THICKNESS / 2.0
	_add_slab_shape(ramp, middle + (bottom - top) / 2.0, middle + (top - bottom) / 2.0, Balance.ARENA_RAMP_THICKNESS, rect.size.x, normal)


# --- Truck ---
static func _build_truck(arena: Node3D, truck: Dictionary) -> Area3D:
	# The truck model sits with its tailgate on the given point, its open back facing "faces";
	# the delivery half-circle shares that point and direction.
	var tailgate := Vector3(truck.tailgate[0], 0.0, truck.tailgate[1])
	var yaw: float = atan2(truck.faces[1], -truck.faces[0]) # Turns local −X onto the faces direction.
	var body: Node3D = TRUCK_MODEL_SCENE.instantiate()
	body.position = tailgate
	body.rotation.y = yaw
	arena.add_child(body)
	var zone: Area3D = TRUCK_SCENE.instantiate()
	zone.radius = Balance.DELIVERY_RADIUS
	zone.position = tailgate
	zone.rotation.y = yaw
	arena.add_child(zone)
	return zone


# --- Geometry helpers ---
static func _segment_box(from: Array, to: Array, bottom: float, top: float, thickness: float, offset: float = 0.0) -> AABB:
	# Walls and fences run along X or Z; thickness is centred on the plan's line, moved sideways by offset.
	var a := Vector3(from[0], bottom, from[1])
	var b := Vector3(to[0], top, to[1])
	var low := Vector3(minf(a.x, b.x), bottom, minf(a.z, b.z))
	var high := Vector3(maxf(a.x, b.x), top, maxf(a.z, b.z))
	if is_equal_approx(low.x, high.x):
		low.x += offset - thickness / 2.0
		high.x += offset + thickness / 2.0
	else:
		low.z += offset - thickness / 2.0
		high.z += offset + thickness / 2.0
	return AABB(low, high - low)


static func _wall_normal(wall: Dictionary) -> Vector3:
	# The direction a wall's sides face: +X for walls running along Z, +Z for walls running along X.
	return Vector3.RIGHT if is_equal_approx(float(wall.from[0]), float(wall.to[0])) else Vector3.BACK


static func _along(start: Vector3, end: Vector3) -> Transform3D:
	# A transform at the midpoint whose local Z runs from start to end.
	var forward: Vector3 = (end - start).normalized()
	var side: Vector3 = Vector3.UP.cross(forward).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	var up: Vector3 = forward.cross(side).normalized()
	return Transform3D(Basis(side, up, forward), (start + end) / 2.0)


static func _add_slab_shape(body: StaticBody3D, start: Vector3, end: Vector3, height: float, width: float, up_hint: Vector3 = Vector3.UP) -> void:
	# A box from start to end (its centre line), height along up_hint, width across.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var forward: Vector3 = (end - start).normalized()
	var side: Vector3 = up_hint.cross(forward).normalized()
	var up: Vector3 = forward.cross(side).normalized()
	box.size = Vector3(width, height, start.distance_to(end))
	shape.shape = box
	body.add_child(shape)
	shape.global_transform = Transform3D(Basis(side, up, forward), (start + end) / 2.0)


static func _solid_box(arena: Node3D, node_name: String, box: AABB, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	_set_world_layers(body)
	arena.add_child(body)
	_add_box_shape(body, box)
	_add_mesh(body, box, material, false)


static func _visual_box(arena: Node3D, node_name: String, box: AABB, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.material_override = material
	mesh.position = box.get_center()
	arena.add_child(mesh)


static func _add_box_shape(body: StaticBody3D, box: AABB) -> void:
	# The body sits at the origin, so its parts use world positions.
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	shape.position = box.get_center()
	body.add_child(shape)


static func _add_mesh(body: StaticBody3D, box: AABB, material: Material, fades: bool) -> void:
	# A fading wall's parts each get their own copy of the material, and never cast shadows.
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.material_override = material.duplicate() if fades else material
	mesh.position = box.get_center()
	if fades:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)


static func _set_world_layers(body: StaticBody3D) -> void:
	body.collision_layer = Balance.WORLD_LAYER
	body.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
