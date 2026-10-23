# Builds an arena from a layout data file (arenas/layouts/<arena>_layout.json, metres, Y up):
# ground, room floors (raised rooms become solid blocks), two-sided walls with trim (camera-facing walls fade
# while they hide a player), see-through railings with solid colliders, stairs (visible steps over one invisible
# ramp), fences, paths, the truck and one Area3D zone per room. It knows nothing about any one arena, so every
# arena can reuse it. Surfaces are named in the layout and loaded from assets/materials/surfaces/<name>.tres
# (triplanar, so the generated boxes need no UVs).
class_name ArenaBuilder
extends RefCounted

const TRUCK_SCENE := preload("res://props/TruckZone.tscn")
const TRUCK_MODEL_SCENE := preload("res://props/Truck.tscn")
const SURFACE_PATH: String = "res://assets/materials/surfaces/%s.tres"

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


static func _build_fence(arena: Node3D, fence: Dictionary, surface: String) -> void:
	_solid_box(arena, "Fence", _segment_box(fence.from, fence.to, 0.0, Balance.ARENA_FENCE_HEIGHT, Balance.ARENA_FENCE_THICKNESS), _surface(surface))


static func _build_railing(arena: Node3D, railing: Dictionary) -> void:
	# Posts and a top rail you can see through, over one solid collider so nothing gets past or falls off.
	var start := Vector3(railing.from[0], railing.base_from, railing.from[1])
	var end := Vector3(railing.to[0], railing.base_to, railing.to[1])
	var body := StaticBody3D.new()
	body.name = railing.id
	_set_world_layers(body)
	arena.add_child(body)
	var rise := Vector3.UP * Balance.ARENA_RAILING_HEIGHT
	_add_slab_shape(body, start + rise / 2.0, end + rise / 2.0, Balance.ARENA_RAILING_HEIGHT, Balance.ARENA_RAILING_THICKNESS)

	var material := _material(Balance.ARENA_RAILING_COLOUR, 1.0)
	var posts: int = maxi(1, ceili(start.distance_to(end) / Balance.ARENA_RAILING_POST_SPACING))
	for index: int in range(posts + 1):
		var base: Vector3 = start.lerp(end, float(index) / posts)
		var post := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = Balance.ARENA_RAILING_POST_RADIUS
		cylinder.bottom_radius = Balance.ARENA_RAILING_POST_RADIUS
		cylinder.height = Balance.ARENA_RAILING_HEIGHT
		cylinder.material = material
		post.mesh = cylinder
		post.position = base + rise / 2.0
		body.add_child(post)
	var rail := MeshInstance3D.new()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(Balance.ARENA_RAILING_POST_RADIUS * 3.0, Balance.ARENA_RAILING_POST_RADIUS * 3.0, start.distance_to(end))
	rail_mesh.material = material
	rail.mesh = rail_mesh
	body.add_child(rail)
	rail.global_transform = _along(start + rise, end + rise)


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


static func _material(colour: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func _set_world_layers(body: StaticBody3D) -> void:
	body.collision_layer = Balance.WORLD_LAYER
	body.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
