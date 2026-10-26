# Ghost Ship: static decks, seeded salvage, five hauntable props and tug rescues.
extends Node3D

# --- Identity and resources ---
const ARENA_NAME: String = "Ghost Ship"
const SIGNATURE_HAUNTING := preload("res://hauntings/GustOfWind.gd")
const GHOST_AVATAR := preload("res://actors/ghost_captain_model.gd") # The wreck's drowned captain haunts it.
const LAYOUT_PATH: String = "res://arenas/layouts/ship_layout.json"
const LOOT_SCENE := preload("res://props/Loot.tscn")
const FURNITURE := {"slider": "Crate", "hopper": "Armour", "door": "Door", "dropper": "Chandelier", "rug": "Rug"}

# --- Round settings and state ---
var demo_mode: bool = false
var player_count: int = 2
var spawn_seed: int = 0
var layout: Dictionary
var truck: Area3D
var generator: Area3D # No Battery Run on this arena; shared HUD queries this optional task.
var rescues: Dictionary = {}
var wind_direction := Vector3.ZERO
var wind_active: bool = false

# --- Setup ---
func _ready() -> void:
	layout = ArenaBuilder.load_layout(LAYOUT_PATH)
	truck = ArenaBuilder.build(self, layout)
	_spawn_loot()
	_spawn_furniture()


# --- Arena interface ---
func mover_spawn(slot: int) -> Vector3:
	var point: Array = layout.spawns.movers[slot]
	return Vector3(point[0], Balance.CAPSULE_HEIGHT / 2.0, point[1])


func ghost_spawn() -> Vector3:
	return ArenaBuilder.point_of(layout.spawns.ghost, Balance.WISP_HEIGHT)


func camera_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.camera_bounds)


func ghost_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.ghost_bounds)


func mover_bounds() -> Rect2:
	return ArenaBuilder.rect_of(layout.mover_bounds)


func floor_height_at(point: Vector3) -> float:
	var location := Vector2(point.x, point.z)
	for ramp: Dictionary in layout.ramps:
		var rect: Rect2 = ArenaBuilder.rect_of(ramp.rect)
		if rect.has_point(location):
			var along: float = (point.x - rect.position.x) / rect.size.x
			return ramp.floor + ramp.rise * (along if ramp.direction > 0 else 1.0 - along)
	for floor_data: Dictionary in layout.floors:
		if ArenaBuilder.rect_of(floor_data.rect).has_point(location):
			return floor_data.floor
	return 0.0 # The free wisp flies safely over the ocean.


func room_at(point: Vector3) -> String:
	var location := Vector2(point.x, point.z)
	# Specific areas precede the main deck; height distinguishes being above the hold from standing in it.
	for room: Dictionary in layout.rooms:
		if ArenaBuilder.rect_of(room.rect).has_point(location) and point.y >= room.floor and point.y < room.floor + room.zone_height:
			return String(room.id).trim_prefix("room-").capitalize()
	return "Gangplank" if ArenaBuilder.rect_of(layout.gangplank).has_point(location) else "Sea"


# --- Round hazards ---
func _physics_process(delta: float) -> void:
	_update_rescues(delta)
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


func _begin_rescue(mover: CharacterBody3D) -> void:
	if rescues.has(mover.slot):
		return
	# Release only this mover's grip, bypassing the voluntary delivery path.
	if is_instance_valid(mover.held_item):
		mover.held_item.release_for_rescue(mover)
		mover.held_item = null
	mover.set_in_play(false)
	rescues[mover.slot] = {"mover": mover, "left": Balance.SHIP_RESCUE_SECONDS}
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
