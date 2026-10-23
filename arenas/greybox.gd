# The one-room CSG greybox with a back parlour, kept for the headless checks. Real matches use arenas/Mansion.tscn.
extends Node3D

# --- Scene resources ---
const VASE := preload("res://props/loot/Vase.tscn")
const TV := preload("res://props/loot/TV.tscn")
const CLOCK := preload("res://props/loot/Clock.tscn")
const PIANO := preload("res://props/loot/Piano.tscn")
const FLASHLIGHT := preload("res://props/Flashlight.tscn")
const TRUCK := preload("res://props/TruckZone.tscn")
const CRATE := preload("res://props/furniture/Crate.tscn")
const ARMOUR := preload("res://props/furniture/Armour.tscn")
const DOOR := preload("res://props/furniture/Door.tscn")
const CHANDELIER := preload("res://props/furniture/Chandelier.tscn")
const RUG := preload("res://props/furniture/Rug.tscn")

# --- Arena identity ---
const ARENA_NAME: String = "Old Mansion"
const SIGNATURE_HAUNTING := preload("res://hauntings/HouseShake.gd")

var truck: Area3D
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0

# --- Setup ---
func _ready() -> void:
	_build_room()
	if demo_mode:
		_spawn_seeded_loot()
	else:
		for point: Vector2 in Balance.VASE_POSITIONS:
			_spawn_loot(VASE, point, 0)
		for point: Vector2 in Balance.TV_POSITIONS:
			_spawn_loot(TV, point, 1)
		_spawn_loot(CLOCK, Balance.CLOCK_POSITION, 2)
	_spawn_loot(PIANO, Balance.PIANO_POSITION, 3)
	var flashlight := FLASHLIGHT.instantiate()
	flashlight.position = Vector3(Balance.FLASHLIGHT_POSITION.x, Balance.FLASHLIGHT_SIZE.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE, Balance.FLASHLIGHT_POSITION.y)
	add_child(flashlight)
	if demo_mode and player_count == 4:
		var second := FLASHLIGHT.instantiate()
		second.position = flashlight.position
		second.position.x = -second.position.x
		add_child(second)
	_spawn_furniture()
	truck = TRUCK.instantiate()
	truck.position = Balance.TRUCK_POSITION
	add_child(truck)


func ghost_spawn() -> Vector3:
	return Vector3(Balance.GHOST_SPAWN.x, Balance.WISP_HEIGHT, Balance.GHOST_SPAWN.y)


# --- Arena interface (shared with the data-built arenas) ---
func mover_spawn(slot: int) -> Vector3:
	return Vector3((slot - (Balance.MAX_PLAYERS - 1) / 2.0) * Balance.SPAWN_SPACING, Balance.CAPSULE_HEIGHT / 2.0, Balance.MOVER_SPAWN_Z)


func camera_bounds() -> Rect2:
	return Balance.CAMERA_BOUNDS


func ghost_bounds() -> Rect2:
	return Balance.GHOST_BOUNDS


func mover_bounds() -> Rect2:
	return Rect2(-Balance.FLOOR_SIZE / 2.0, -Balance.FLOOR_SIZE / 2.0, Balance.FLOOR_SIZE, Balance.FLOOR_SIZE)


func _spawn_furniture() -> void:
	# One possessable prop of each type, none of them worth anything.
	var crate_size: Vector3 = Balance.FURNITURE_SIZES[0]
	var armour_size: Vector3 = Balance.FURNITURE_SIZES[1]
	_spawn(CRATE, Vector3(Balance.CRATE_POSITION.x, crate_size.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE, Balance.CRATE_POSITION.y))
	if demo_mode:
		return # Extra furniture abilities remain in the regression harness, not the first demo.
	_spawn(ARMOUR, Vector3(Balance.ARMOUR_POSITION.x, armour_size.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE, Balance.ARMOUR_POSITION.y))
	# The door hangs on the parlour doorway's right-hand jamb.
	_spawn(DOOR, Vector3(Balance.PARLOUR_DOOR_WIDTH / 2.0, 0.0, Balance.PARLOUR_WALL_Z))
	var chandelier_centre: float = Balance.CHANDELIER_HEIGHT + Balance.CHANDELIER_SIZE.y / 2.0
	_spawn(CHANDELIER, Vector3(Balance.CHANDELIER_POSITION.x, chandelier_centre, Balance.CHANDELIER_POSITION.y))
	_spawn(RUG, Vector3(Balance.RUG_POSITION.x, 0.0, Balance.RUG_POSITION.y))


# --- Greybox helpers ---
func _spawn_seeded_loot() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed
	var points: Array[Vector2] = Balance.MATCH_SPAWN_POINTS.duplicate()
	for index: int in range(points.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var saved: Vector2 = points[index]
		points[index] = points[other]
		points[other] = saved
	var scenes: Array[PackedScene] = [VASE, TV, CLOCK]
	for index: int in range(Balance.LOOT_COUNTS[player_count - 2] - 1):
		var kind: int = random.randi_range(0, scenes.size() - 1)
		_spawn_loot(scenes[kind], points[index], kind)


func _build_room() -> void:
	_box("Ground", Vector3(Balance.FLOOR_SIZE, Balance.FLOOR_THICKNESS, Balance.FLOOR_SIZE), Vector3(0.0, -Balance.FLOOR_THICKNESS / 2.0, 0.0), Color("526761"))
	var rear: float = Balance.ROOM_CENTRE_Z - Balance.ROOM_DEPTH / 2.0
	var front: float = Balance.ROOM_CENTRE_Z + Balance.ROOM_DEPTH / 2.0
	_box("RearWall", Vector3(Balance.ROOM_WIDTH, Balance.WALL_HEIGHT, Balance.WALL_THICKNESS), Vector3(0.0, Balance.WALL_HEIGHT / 2.0, rear), Color("a0a69a"))
	for side: float in [-1.0, 1.0]:
		_box("SideWall", Vector3(Balance.WALL_THICKNESS, Balance.WALL_HEIGHT, Balance.ROOM_DEPTH), Vector3(side * Balance.ROOM_WIDTH / 2.0, Balance.WALL_HEIGHT / 2.0, Balance.ROOM_CENTRE_Z), Color("a0a69a"))
		var segment_width: float = (Balance.ROOM_WIDTH - Balance.DOOR_WIDTH) / 2.0
		var centre_x: float = side * (Balance.DOOR_WIDTH / 2.0 + segment_width / 2.0)
		_box("FrontWall", Vector3(segment_width, Balance.FRONT_WALL_HEIGHT, Balance.WALL_THICKNESS), Vector3(centre_x, Balance.FRONT_WALL_HEIGHT / 2.0, front), Color("d0bda2"))
	_box("DoorframePractice", Balance.OBSTACLE_SIZE, Balance.OBSTACLE_POSITION, Color("9a8b7c"))

	# The parlour partition: two wall segments either side of a doorway at the room's centre line.
	var parlour_segment: float = (Balance.ROOM_WIDTH - Balance.PARLOUR_DOOR_WIDTH) / 2.0
	for side: float in [-1.0, 1.0]:
		var segment_x: float = side * (Balance.PARLOUR_DOOR_WIDTH / 2.0 + parlour_segment / 2.0)
		_box("ParlourWall", Vector3(parlour_segment, Balance.PARLOUR_WALL_HEIGHT, Balance.WALL_THICKNESS), Vector3(segment_x, Balance.PARLOUR_WALL_HEIGHT / 2.0, Balance.PARLOUR_WALL_Z), Color("8f86a6"))


func _box(node_name: String, size: Vector3, location: Vector3, colour: Color) -> void:
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = size
	box.position = location
	box.use_collision = true
	box.collision_layer = Balance.WORLD_LAYER
	box.collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	box.material = material
	add_child(box)


func _spawn_loot(scene: PackedScene, point: Vector2, kind: int) -> void:
	_spawn(scene, Vector3(point.x, Balance.LOOT_SIZES[kind].y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE, point.y))


func _spawn(scene: PackedScene, location: Vector3) -> void:
	var prop := scene.instantiate()
	prop.position = location
	add_child(prop)
