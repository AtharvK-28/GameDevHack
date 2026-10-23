# Checks the furniture catalog (props/catalog/): every entry loads and instantiates; every loot item has a value,
# weight class, fragility and collider; two-person items fit their route to the truck (doorways and stairs);
# decor and furniture in the Mansion's dressing never carry a price tag, and only furniture is possessable; the
# whole Mansion pool spawns onto spots that suit it and stays where it lands; and every match-sized pick has
# 6/9/12 items, exactly one centrepiece and no more heavy items than allowed.
# This script compiles before the autoloads exist, so it loads the catalog scripts at run time.
extends SceneTree

# --- Test settings ---
const SETTINGS := preload("res://autoload/Balance.gd")
const LAYOUT_PATH: String = "res://arenas/layouts/mansion_layout.json"
const CATEGORY_LOOT: int = 0
const CATEGORY_FURNITURE: int = 1
const CATEGORY_DECOR: int = 2
const ROUTE_MARGIN: float = 0.2 # Metres a two-person item needs either side of its narrow side in a doorway.
const STAIRS_WIDTH: float = 3.0 # The Mansion's stairs (layout "area-stairs").
const SETTLE_SECONDS: float = 2.5
const REST_DRIFT: float = 0.35 # Metres a spawned item may settle away from its spot.
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]

# --- Test state ---
var catalog: Script
var layout: Dictionary
var failures: int = 0

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	catalog = load("res://props/catalog/catalog.gd")
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_check_entries()
	_check_routes()
	_check_picks()
	await _check_dressing_and_spawn()
	print("CATALOG CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- Entries ---
func _check_entries() -> void:
	var roles: Array = []
	for spot: Dictionary in layout.spawns.loot:
		roles.append(StringName(spot.role))
	for category: int in [CATEGORY_LOOT, CATEGORY_FURNITURE, CATEGORY_DECOR]:
		var items: Array = catalog.items(&"mansion", category)
		_check(not items.is_empty(), "The Mansion pool has %s entries (%d)" % [["loot", "furniture", "decor"][category], items.size()])
		for item: Resource in items:
			var model: Node = item.model.instantiate() if item.model != null else null
			_check(model != null and item.footprint.x > 0.0 and item.footprint.y > 0.0 and item.footprint.z > 0.0, "%s loads, with a model and a footprint" % item.display_name)
			if model != null:
				model.free()
			if category == CATEGORY_LOOT:
				var fits_somewhere: bool = false
				for role: StringName in item.spot_roles:
					fits_somewhere = fits_somewhere or role in roles
				_check(item.value > 0 and item.fragility >= 1 and item.fragility <= 3 and item.count >= 1, "%s has a value (₹%d), fragility %d and count %d" % [item.display_name, item.value, item.fragility, item.count])
				_check(item.throwable == (item.weight_class == SETTINGS.LIGHT) and fits_somewhere, "%s: throwable only if light, and it has a spawn spot" % item.display_name)


func _check_routes() -> void:
	# The narrow side of every two-person item fits each doorway on the way to the truck and the stairs.
	var front_door: float = 0.0
	for door: Dictionary in layout.doors:
		if door.id == "door-front":
			front_door = door.width
	for item: Resource in catalog.items(&"mansion", CATEGORY_LOOT):
		if item.weight_class != SETTINGS.TWO_PERSON:
			continue
		var narrow: float = minf(item.footprint.x, item.footprint.z)
		var fits: bool = narrow + ROUTE_MARGIN * 2.0 <= front_door and narrow + ROUTE_MARGIN * 2.0 <= STAIRS_WIDTH and item.footprint.y < SETTINGS.ARENA_ARCH_SPRING
		_check(fits, "%s (%.1f m turned) fits the %.1f m front door, the %.1f m stairs and under the arch" % [item.display_name, narrow, front_door, STAIRS_WIDTH])


func _check_picks() -> void:
	for players: int in [2, 3, 4]:
		var ok: bool = true
		for seed_value: int in SEEDS:
			var random := RandomNumberGenerator.new()
			random.seed = seed_value
			var picks: Array = catalog.pick_loot(&"mansion", layout.spawns.loot, SETTINGS.LOOT_COUNTS[players - 2], SETTINGS.HEAVY_LOOT_LIMITS[players - 2], random)
			var centrepieces: int = 0
			var heavies: int = 0
			for pick: Dictionary in picks:
				centrepieces += int(pick.item.weight_class == SETTINGS.TWO_PERSON)
				heavies += int(pick.item.weight_class == SETTINGS.HEAVY)
				ok = ok and StringName(pick.spot.role) in pick.item.spot_roles
			ok = ok and picks.size() == SETTINGS.LOOT_COUNTS[players - 2] and centrepieces == 1 and heavies <= SETTINGS.HEAVY_LOOT_LIMITS[players - 2]
		_check(ok, "%d players: every seed picks %d items, one centrepiece, at most %d heavy, each on a suitable spot" % [players, SETTINGS.LOOT_COUNTS[players - 2], SETTINGS.HEAVY_LOOT_LIMITS[players - 2]])


# --- The dressed, spawned Mansion ---
func _check_dressing_and_spawn() -> void:
	var playground: Node3D = load("res://Main.tscn").instantiate()
	playground.match_mode = false
	playground.arena_scene = load("res://arenas/Mansion.tscn")
	root.add_child(playground)
	var arena: Node3D = playground.arena
	await _seconds(0.3)

	# Only furniture scenes are possessable, and nothing in the dressing carries a price tag.
	var dressing: Node = arena.get_node("MansionDressing")
	var stray: Array[String] = []
	for node: Node in dressing.find_children("*", "", true, false):
		if node.get_script() == load("res://props/Possessable.gd"):
			var owner_path: String = node.get_parent().scene_file_path
			if not owner_path.begins_with("res://props/catalog/furniture/"):
				stray.append(String(node.get_parent().name))
		if node.has_method("show_popup"):
			stray.append(String(node.name) + " (price tag)")
	_check(stray.is_empty(), "Decor has no price tags or Possessables; only the 5 furniture props are possessable %s" % str(stray))

	# The whole pool spawns on suitable spots and stays put.
	var pool_size: int = 0
	for item: Resource in catalog.items(&"mansion", CATEGORY_LOOT):
		pool_size += item.count
	var spawned: Array[Node] = []
	for node: Node in get_nodes_in_group("loot"):
		if node.get("catalog_item") != null:
			spawned.append(node)
	_check(spawned.size() == pool_size, "Outside a match the whole pool spawns (%d of %d)" % [spawned.size(), pool_size])
	var starts: Dictionary = {}
	for item: Node3D in spawned:
		starts[item] = item.global_position
	await _seconds(SETTLE_SECONDS)
	var moved: Array[String] = []
	for item: Node3D in spawned:
		if not is_instance_valid(item):
			moved.append("a shattered item")
			continue
		var drift: float = Vector2(item.global_position.x - starts[item].x, item.global_position.z - starts[item].z).length()
		var dropped: float = starts[item].y - item.global_position.y
		var colliders: int = item.find_children("*", "CollisionShape3D", false, false).size()
		if drift > REST_DRIFT or dropped > 0.5 or colliders == 0 or item.value < item.initial_value:
			moved.append("%s (moved %.2f m, dropped %.2f m, ₹%d)" % [item.item_name, drift, dropped, item.value])
	_check(moved.is_empty(), "Every spawned item rests where it was placed, undamaged, with a collider %s" % str(moved))


# --- Helpers ---
func _seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
