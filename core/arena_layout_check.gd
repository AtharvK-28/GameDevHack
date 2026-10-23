# Checks the Old Mansion built from arenas/layouts/mansion_layout.json: room zones, doorway widths, routes from
# every room to the truck, the stairs with every carry weight and the two-person piano, and that railings and
# walls hold movers and loot. Movers are steered by writing their input snapshots, so their real movement runs.
# This script compiles before the autoloads exist, so it reaches them through the scene tree.
extends SceneTree

# --- Test settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const LAYOUT_PATH: String = "res://arenas/layouts/mansion_layout.json"
const MOVER_HEIGHT: float = 0.8 # Mover centre above its floor.
const ARRIVE_DISTANCE: float = 0.4 # Metres from a waypoint that counts as reached.
const ROUTE_TIMEOUT: float = 25.0 # Seconds allowed for a route.
const PIANO_SHORT_SIDE: float = 1.4 # The piano's footprint is 2.2 × 1.4 m; turned, it needs 1.4 m.
const DOOR_RAY_HEIGHT: float = 0.5 # Above the floor, where rays cross a doorway (under the 0.9 m fence).
const DELIVERY_POINT := Vector3(5.5, 0, 24.5) # Inside the half-circle behind the tailgate at (7, 24.5).
const VASE_KIND: int = 0
const TV_KIND: int = 1
const CLOCK_KIND: int = 2
const PIANO_KIND: int = 3

# --- Test state ---
var playground: Node3D
var arena: Node3D
var router: Node
var layout: Dictionary
var loot_scene: PackedScene
var failures: int = 0

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	router = root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED # The check writes each mover's input itself.
	loot_scene = load("res://props/Loot.tscn")
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_check(layout is Dictionary and layout.has("rooms"), "The Mansion layout file reads")
	playground = load("res://Main.tscn").instantiate()
	playground.match_mode = false
	playground.arena_scene = load("res://arenas/Mansion.tscn")
	root.add_child(playground)
	arena = playground.arena
	await _frames(10)
	_check(arena.truck != null and arena.name == "Mansion", "Main builds the Mansion arena with a truck zone")

	_check_room_zones()
	_check_doorways()
	await _clear_carryables()
	await _check_routes()
	await _check_stairs()
	await _check_piano_stairs()
	await _check_containment()
	await _check_truck()
	print("ARENA LAYOUT CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Static layout ---
func _check_room_zones() -> void:
	for room: Dictionary in layout.rooms:
		var zone: Node = arena.get_node_or_null(NodePath(room.id))
		var ok: bool = zone is Area3D
		if ok:
			var size: Vector3 = zone.get_child(0).shape.size
			var bottom: float = zone.position.y - size.y / 2.0
			ok = is_equal_approx(size.x, room.rect[2]) and is_equal_approx(size.z, room.rect[3]) and is_equal_approx(bottom, room.floor)
		_check(ok, "Room zone %s is %s × %s m at floor %.1f m" % [room.id, room.rect[2], room.rect[3], room.floor])


func _check_doorways() -> void:
	var space: PhysicsDirectSpaceState3D = playground.get_world_3d().direct_space_state
	for door: Dictionary in layout.doors:
		var from := Vector3(door.from[0], float(door.floor) + DOOR_RAY_HEIGHT, door.from[1])
		var to := Vector3(door.to[0], float(door.floor) + DOOR_RAY_HEIGHT, door.to[1])
		var along: Vector3 = (to - from).normalized()
		var across := Vector3(along.z, 0.0, -along.x)
		var width: float = from.distance_to(to)
		# Rays cross the gap at many points: none may hit. Just past each end, the wall must be there.
		var clear: bool = true
		for step: int in range(11):
			var point: Vector3 = from.lerp(to, 0.05 + 0.9 * step / 10.0)
			if _hits(space, point - across, point + across):
				clear = false
		var edges: bool = _hits(space, from - along * 0.15 - across, from - along * 0.15 + across) and _hits(space, to + along * 0.15 - across, to + along * 0.15 + across)
		_check(clear and edges and width >= door.width - 0.01, "%s is open for its full %.1f m and walled either side" % [door.id, width])
		_check(width >= PIANO_SHORT_SIDE + 0.2, "The piano (1.4 m when turned) fits through %s" % door.id)


# --- Walking routes ---
func _check_routes() -> void:
	# Every room to the truck; the gallery route carries a vase down the stairs.
	var routes: Dictionary = {
		"main room": [Vector3(6, 0, 11), Vector3(7.75, 0, 14), Vector3(7.75, 0, 17), Vector3(7.75, 0, 21.5), DELIVERY_POINT],
		"kitchen": [Vector3(16, 0, 11), Vector3(13, 0, 11), Vector3(11, 0, 11), Vector3(7.75, 0, 14), Vector3(7.75, 0, 17), Vector3(7.75, 0, 21.5), DELIVERY_POINT],
		"garden": [Vector3(15, 0, 19), Vector3(11, 0, 16.5), Vector3(9, 0, 16.5), Vector3(8.5, 0, 20), Vector3(7.75, 0, 21.5), DELIVERY_POINT],
	}
	for room: String in routes:
		var points: Array = routes[room]
		await _start(0, points[0], 0.0)
		var reached: bool = await _walk(0, points.slice(1))
		_check(reached and arena.truck.contains_point(playground.movers[0].global_position), "A mover walks from the %s to the truck" % room)
	# From the gallery, carrying a vase down the stairs.
	await _start(0, Vector3(6, 0, 3), 1.2)
	var vase := await _pick_up(0, VASE_KIND)
	var gallery_route: Array = [Vector3(1.5, 0, 4.5), Vector3(1.5, 0, 11.5), Vector3(7.75, 0, 14), Vector3(7.75, 0, 17), Vector3(7.75, 0, 21.5), DELIVERY_POINT]
	var reached: bool = await _walk(0, gallery_route)
	_check(reached and playground.movers[0].held_item == vase, "A mover carries a vase from the gallery, down the stairs, to the truck")
	await _release_all()
	await _clear_carryables()


func _check_stairs() -> void:
	# Up and down the stairs while carrying each weight class.
	for kind: int in [VASE_KIND, TV_KIND, CLOCK_KIND]:
		await _start(0, Vector3(1.5, 0, 12.5), 0.0)
		var item := await _pick_up(0, kind)
		var up: bool = await _walk(0, [Vector3(1.5, 0, 3.5)])
		var mover: CharacterBody3D = playground.movers[0]
		var on_gallery: bool = mover.global_position.y > 1.2 + MOVER_HEIGHT - 0.15 and mover.held_item == item and item.global_position.y > 1.2
		_check(up and on_gallery, "A mover carries the %s up the stairs (mover at %.2f m)" % [item.item_name, mover.global_position.y])
		var down: bool = await _walk(0, [Vector3(1.5, 0, 12.5)])
		_check(down and mover.global_position.y < MOVER_HEIGHT + 0.15 and mover.held_item == item, "...and back down with it")
		await _release_all()
		await _clear_carryables()


func _check_piano_stairs() -> void:
	# Two movers carry the piano from the gallery down the stairs, then back up.
	await _clear_carryables()
	var piano: RigidBody3D = loot_scene.instantiate()
	piano.loot_kind = PIANO_KIND
	piano.position = Vector3(1.5, 1.2 + SETTINGS.LOOT_SIZES[PIANO_KIND].y / 2.0 + 0.03, 2.5)
	piano.rotation.y = PI / 2.0 # Long side down the stairs.
	playground.add_child(piano)
	var reach: float = SETTINGS.LOOT_SIZES[PIANO_KIND].x / 2.0 + SETTINGS.TEAM_STAND_DISTANCE
	_only([0, 1])
	_place(0, Vector3(1.5, 1.2 + MOVER_HEIGHT, 2.5 + reach), Vector3.FORWARD)
	_place(1, Vector3(1.5, 1.2 + MOVER_HEIGHT, 2.5 - reach), Vector3.BACK)
	await _seconds(0.5)
	for index: int in range(2):
		_input(index, Vector2.ZERO, {"grab": true}, {"grab": true})
	await _seconds(0.6)
	_check(piano.holder_count() == 2, "Two movers take the piano's handles on the gallery")
	var down: bool = await _push_piano(piano, Vector2(0.0, 1.0), func() -> bool: return piano.global_position.z > 12.0)
	_check(down and piano.holder_count() == 2 and piano.global_position.y < 1.2, "Two movers carry the piano down the stairs (now at %.2f m, %s)" % [piano.global_position.y, _value_text(piano)])
	var up: bool = await _push_piano(piano, Vector2(0.0, -1.0), func() -> bool: return piano.global_position.z < 3.5)
	_check(up and piano.holder_count() == 2 and piano.global_position.y > 1.2 + 0.4, "...and back up to the gallery (now at %.2f m, %s)" % [piano.global_position.y, _value_text(piano)])
	await _release_all()
	await _clear_carryables()
	_only([0])


func _check_containment() -> void:
	var mover: CharacterBody3D = playground.movers[0]
	# Walking into the gallery's railing: the mover stays up on the gallery.
	await _start(0, Vector3(10, 0, 4.5), 1.2)
	_input(0, Vector2(0.0, 1.0), {})
	await _seconds(1.5)
	_check(mover.global_position.z < 6.0 and mover.global_position.y > 1.6, "The gallery railing stops a mover (z %.2f, y %.2f)" % [mover.global_position.z, mover.global_position.y])
	# A vase shoved at the railing stays on the gallery.
	var vase: RigidBody3D = _spawn(VASE_KIND, Vector3(12, 1.2, 4.0))
	await _seconds(0.3)
	vase.sleeping = false
	vase.linear_velocity = Vector3(0, 1.5, 6.0)
	await _seconds(1.5)
	_check(not is_instance_valid(vase) or (vase.global_position.z < 6.0 and vase.global_position.y > 1.2), "A vase thrown at the railing stays on the gallery")
	await _clear_carryables()
	# The stairs' open side.
	await _start(0, Vector3(1.5, 0, 8), 0.6)
	_input(0, Vector2(1.0, 0.0), {})
	await _seconds(1.2)
	_check(mover.global_position.x < 3.0, "The stairs railing stops a mover stepping off the side (x %.2f)" % mover.global_position.x)
	# The gallery's front edge is too high to climb from below.
	await _start(0, Vector3(8, 0, 8), 0.0)
	_input(0, Vector2(0.0, -1.0), {})
	await _seconds(1.2)
	_check(mover.global_position.z > 6.0 and mover.global_position.y < 1.0, "Movers can't climb the gallery's edge from the main room")
	# See-through walls still block.
	await _start(0, Vector3(2, 0, 13), 0.0)
	_input(0, Vector2(-1.0, 0.0), {})
	await _seconds(1.2)
	_check(mover.global_position.x > 0.0, "A see-through wall still blocks (x %.2f)" % mover.global_position.x)
	_input(0, Vector2.ZERO, {})


func _check_truck() -> void:
	# Loot released anywhere in the half-circle banks; beside the truck or past the radius it doesn't.
	var truck: Area3D = arena.truck
	_check(truck.contains_point(Vector3(4.2, 0.5, 24.5)) and truck.contains_point(Vector3(6.8, 0.5, 26.9)), "The half-circle behind the tailgate counts as the truck")
	_check(not truck.contains_point(Vector3(3.8, 0.5, 24.5)) and not truck.contains_point(Vector3(8.0, 0.5, 22.0)), "Past the radius or beside the truck doesn't count")
	await _start(0, DELIVERY_POINT, 0.0)
	await _pick_up(0, VASE_KIND)
	var banked_before: int = truck.banked_items
	await _release_all()
	await _seconds(0.5)
	_check(truck.banked_items == banked_before + 1, "A vase released in the half-circle is delivered")
	await _clear_carryables()
	# The truck is solid: a mover walking into its side stops.
	var mover: CharacterBody3D = playground.movers[0]
	await _start(0, Vector3(9.0, 0, 22.3), 0.0)
	_input(0, Vector2(0.0, 1.0), {})
	await _seconds(1.5)
	_check(mover.global_position.z < 23.6, "The truck is solid (mover stopped at z %.2f)" % mover.global_position.z)
	_input(0, Vector2.ZERO, {})


# --- Movement helpers ---
func _start(index: int, at: Vector3, floor_height: float) -> void:
	await _release_all()
	_only([index])
	_place(index, Vector3(at.x, floor_height + MOVER_HEIGHT, at.z), Vector3.FORWARD)
	await _seconds(0.3)


func _walk(index: int, points: Array) -> bool:
	# Steer toward each waypoint in turn; keep GRAB as it is.
	var mover: CharacterBody3D = playground.movers[index]
	var buttons: Dictionary = router.snapshots[index].buttons.duplicate()
	var deadline: int = Time.get_ticks_msec() + int(ROUTE_TIMEOUT * 1000.0)
	for point: Vector3 in points:
		while Time.get_ticks_msec() < deadline:
			var offset := Vector2(point.x - mover.global_position.x, point.z - mover.global_position.z)
			if offset.length() < ARRIVE_DISTANCE:
				break
			_input(index, offset.normalized(), buttons)
			await physics_frame
	_input(index, Vector2.ZERO, buttons)
	await _seconds(0.2)
	return Time.get_ticks_msec() < deadline


func _push_piano(piano: RigidBody3D, stick: Vector2, done: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(ROUTE_TIMEOUT * 1000.0)
	while not done.call() and Time.get_ticks_msec() < deadline:
		for index: int in range(2):
			_input(index, stick, {"grab": true})
		await physics_frame
	for index: int in range(2):
		_input(index, Vector2.ZERO, {"grab": true})
	await _seconds(0.8)
	return done.call()


func _pick_up(index: int, kind: int) -> RigidBody3D:
	var mover: CharacterBody3D = playground.movers[index]
	var at: Vector3 = mover.global_position + mover.facing * SETTINGS.HOLD_DISTANCE
	var item := _spawn(kind, Vector3(at.x, mover.global_position.y - MOVER_HEIGHT, at.z))
	await _seconds(0.4)
	_input(index, Vector2.ZERO, {"grab": true}, {"grab": true})
	await _seconds(0.6)
	return item


func _spawn(kind: int, at_floor: Vector3) -> RigidBody3D:
	var item: RigidBody3D = loot_scene.instantiate()
	item.loot_kind = kind
	item.position = at_floor + Vector3.UP * (SETTINGS.LOOT_SIZES[kind].y / 2.0 + 0.03)
	playground.add_child(item)
	return item


func _only(indexes: Array) -> void:
	for mover: CharacterBody3D in playground.movers:
		mover.set_in_play(mover.slot in indexes)


func _place(index: int, at: Vector3, facing: Vector3) -> void:
	var mover: CharacterBody3D = playground.movers[index]
	mover.position = at
	mover.velocity = Vector3.ZERO
	mover.facing = facing
	mover._update_hold_point()


func _input(index: int, stick: Vector2, buttons: Dictionary, pressed: Dictionary = {}) -> void:
	var snapshot = router.snapshots[index]
	snapshot.direction = stick
	snapshot.buttons = buttons.duplicate()
	snapshot.pressed = pressed.duplicate()
	snapshot.released = {}
	if not pressed.is_empty():
		_clear_pressed.call_deferred(index)


func _clear_pressed(index: int) -> void:
	await physics_frame
	await physics_frame
	router.snapshots[index].pressed = {}


func _release_all() -> void:
	for index: int in range(4):
		_input(index, Vector2.ZERO, {})
	await _seconds(0.2)


func _clear_carryables() -> void:
	for item: Node in get_nodes_in_group("carryables"):
		item.queue_free()
	await _frames(3)


func _hits(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, SETTINGS.WORLD_LAYER)
	return not space.intersect_ray(query).is_empty()


func _value_text(item: RigidBody3D) -> String:
	return "₹%d left" % item.value if is_instance_valid(item) else "shattered"


func _seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await physics_frame


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
