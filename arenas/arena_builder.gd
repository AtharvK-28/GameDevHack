# Builds an arena from a layout data file (arenas/layouts/<arena>_layout.json, metres, Y up):
# ground, room floors (raised rooms become solid blocks), walls with see-through camera sides, see-through
# railings with solid colliders, stairs (visible steps over one invisible ramp), fences, paths, the truck and
# one Area3D zone per room. It knows nothing about any one arena, so every arena can reuse it.
class_name ArenaBuilder
extends RefCounted

const TRUCK_SCENE := preload("res://props/TruckZone.tscn")

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
		_build_wall(arena, wall, _room_colour(layout, wall.get("room", ""), "wall_colour"))
	for railing: Dictionary in layout.get("railings", []):
		_build_railing(arena, railing)
	for stairs: Dictionary in layout.get("stairs", []):
		_build_stairs(arena, stairs)
	for fence: Dictionary in layout.get("fences", []):
		_build_fence(arena, fence)
	for path: Dictionary in layout.get("paths", []):
		var rect: Rect2 = rect_of(path.rect)
		_visual_box(arena, path.id, _box_from_rect(rect, 0.0, Balance.ARENA_FLOOR_SLAB), Color(path.colour))
	return _build_truck(arena, layout.truck)


# --- Small conversions ---
static func rect_of(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


static func point_of(spot: Dictionary, height: float) -> Vector3:
	# A spawn spot at a height above its floor.
	return Vector3(spot.at[0], float(spot.get("floor", 0.0)) + height, spot.at[1])


static func _box_from_rect(rect: Rect2, bottom: float, height: float) -> AABB:
	return AABB(Vector3(rect.position.x, bottom, rect.position.y), Vector3(rect.size.x, height, rect.size.y))


static func _room_colour(layout: Dictionary, room_id: String, key: String) -> Color:
	for room: Dictionary in layout.rooms:
		if room.id == room_id and room.has(key):
			return Color(room[key])
	return Balance.ARENA_WALL_COLOUR


# --- Floors and rooms ---
static func _build_ground(arena: Node3D, ground: Dictionary) -> void:
	var rect: Rect2 = rect_of(ground.rect)
	_solid_box(arena, "Ground", _box_from_rect(rect, -Balance.FLOOR_THICKNESS, Balance.FLOOR_THICKNESS), Color(ground.colour), 1.0)


static func _build_room(arena: Node3D, room: Dictionary) -> void:
	var rect: Rect2 = rect_of(room.rect)
	var floor_height: float = room.floor
	if floor_height > 0.0:
		# A raised room is a solid block up to its floor: nothing can get underneath it.
		_solid_box(arena, room.id + "-floor", _box_from_rect(rect, 0.0, floor_height), Color(room.colour), 1.0)
	else:
		_visual_box(arena, room.id + "-floor", _box_from_rect(rect, 0.0, Balance.ARENA_FLOOR_SLAB), Color(room.colour))

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
static func _build_wall(arena: Node3D, wall: Dictionary, colour: Color) -> void:
	# A full-height wall from the ground up to ARENA_WALL_HEIGHT above its room's floor; camera sides see-through.
	var top: float = float(wall.get("floor", 0.0)) + Balance.ARENA_WALL_HEIGHT
	var alpha: float = Balance.ARENA_SEE_THROUGH_ALPHA if wall.get("see_through", false) else 1.0
	_solid_box(arena, wall.id, _segment_box(wall.from, wall.to, 0.0, top, Balance.ARENA_WALL_THICKNESS), colour, alpha)


static func _build_fence(arena: Node3D, fence: Dictionary) -> void:
	_solid_box(arena, "Fence", _segment_box(fence.from, fence.to, 0.0, Balance.ARENA_FENCE_HEIGHT, Balance.ARENA_FENCE_THICKNESS), Balance.ARENA_FENCE_COLOUR, 1.0)


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
		_visual_box(arena, "%s-step-%d" % [stairs.id, index + 1], step, Color(stairs.colour))

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
	var bed: Rect2 = rect_of(truck.bed)
	_visual_box(arena, "TruckBed", _box_from_rect(bed, 0.0, Balance.ARENA_FLOOR_SLAB * 2.0), Color(truck.colour))
	var cab: Rect2 = rect_of(truck.cab)
	_solid_box(arena, "TruckCab", _box_from_rect(cab, 0.0, truck.cab_height), Color(truck.cab_colour), 1.0)
	var zone_rect: Rect2 = rect_of(truck.zone)
	var zone: Area3D = TRUCK_SCENE.instantiate()
	zone.zone_size = Vector3(zone_rect.size.x, Balance.TRUCK_SIZE.y, zone_rect.size.y)
	zone.position = Vector3(zone_rect.get_center().x, 0.0, zone_rect.get_center().y)
	arena.add_child(zone)
	return zone


# --- Geometry helpers ---
static func _segment_box(from: Array, to: Array, bottom: float, top: float, thickness: float) -> AABB:
	# Walls and fences run along X or Z; thickness is centred on the plan's line.
	var a := Vector3(from[0], bottom, from[1])
	var b := Vector3(to[0], top, to[1])
	var low := Vector3(minf(a.x, b.x), bottom, minf(a.z, b.z))
	var high := Vector3(maxf(a.x, b.x), top, maxf(a.z, b.z))
	if is_equal_approx(low.x, high.x):
		low.x -= thickness / 2.0
		high.x += thickness / 2.0
	else:
		low.z -= thickness / 2.0
		high.z += thickness / 2.0
	return AABB(low, high - low)


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


static func _solid_box(arena: Node3D, node_name: String, box: AABB, colour: Color, alpha: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	_set_world_layers(body)
	body.position = box.get_center()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(_mesh(box.size, colour, alpha))
	arena.add_child(body)


static func _visual_box(arena: Node3D, node_name: String, box: AABB, colour: Color) -> void:
	var mesh: MeshInstance3D = _mesh(box.size, colour, 1.0)
	mesh.name = node_name
	mesh.position = box.get_center()
	arena.add_child(mesh)


static func _mesh(size: Vector3, colour: Color, alpha: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(colour, alpha)
	if alpha < 1.0:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # See-through walls never darken the room.
	return mesh


static func _material(colour: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func _set_world_layers(body: StaticBody3D) -> void:
	body.collision_layer = Balance.WORLD_LAYER
	body.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
