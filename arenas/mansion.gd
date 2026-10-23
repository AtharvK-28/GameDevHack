# The Old Mansion, built from arenas/layouts/mansion_layout.json (the floor plan in mansion-layout.svg).
# The builder makes the house; this script places the loot, piano and flashlights on the layout's spawn spots.
# Furniture comes later with the art import.
extends Node3D

# --- Scene resources ---
const LAYOUT_PATH: String = "res://arenas/layouts/mansion_layout.json"
const LOOT_SCENES: Array[PackedScene] = [
	preload("res://props/loot/Vase.tscn"), preload("res://props/loot/TV.tscn"), preload("res://props/loot/Clock.tscn"),
]
const PIANO := preload("res://props/loot/Piano.tscn")
const PIANO_KIND: int = 3
const FLASHLIGHT := preload("res://props/Flashlight.tscn")

# --- Arena identity ---
const ARENA_NAME: String = "Old Mansion"
const SIGNATURE_HAUNTING := preload("res://hauntings/HouseShake.gd")

# --- Round settings, set by Main before the arena enters the tree ---
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0

var layout: Dictionary
var truck: Area3D

# --- Setup ---
func _ready() -> void:
	layout = ArenaBuilder.load_layout(LAYOUT_PATH)
	truck = ArenaBuilder.build(self, layout)
	_spawn_loot()
	_spawn(PIANO, ArenaBuilder.point_of(layout.spawns.piano, Balance.LOOT_SIZES[PIANO_KIND].y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE))
	var flashlights: int = 2 if demo_mode and player_count == 4 else 1
	for index: int in range(flashlights):
		var spot: Dictionary = layout.spawns.flashlights[index]
		_spawn(FLASHLIGHT, ArenaBuilder.point_of(spot, Balance.FLASHLIGHT_SIZE.y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE))


# --- Arena interface (shared with the greybox) ---
func mover_spawn(slot: int) -> Vector3:
	var spot: Array = layout.spawns.movers[slot]
	return Vector3(spot[0], Balance.CAPSULE_HEIGHT / 2.0, spot[1])


func ghost_spawn() -> Vector3:
	return ArenaBuilder.point_of(layout.spawns.ghost, Balance.WISP_HEIGHT)


func camera_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.camera_bounds)


func ghost_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.ghost_bounds)


func mover_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.mover_bounds)


# --- Spawning ---
func _spawn_loot() -> void:
	# A round gets 6/9/12 items (counting the piano) on shuffled spots; outside a match, every spot gets one.
	var random := RandomNumberGenerator.new()
	random.seed = spawn_seed
	var spots: Array = layout.spawns.loot.duplicate()
	for index: int in range(spots.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var saved: Variant = spots[index]
		spots[index] = spots[other]
		spots[other] = saved
	var count: int = Balance.LOOT_COUNTS[player_count - 2] - 1 if demo_mode else spots.size()
	for index: int in range(mini(count, spots.size())):
		var kind: int = random.randi_range(0, LOOT_SCENES.size() - 1)
		_spawn(LOOT_SCENES[kind], ArenaBuilder.point_of(spots[index], Balance.LOOT_SIZES[kind].y / 2.0 + Balance.LOOT_SPAWN_CLEARANCE))


func _spawn(scene: PackedScene, location: Vector3) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = location
	add_child(prop)
