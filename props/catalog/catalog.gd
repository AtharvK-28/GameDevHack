# The furniture catalog: every CatalogItem resource under props/catalog/, and the seeded loot pick for a round.
# A round gets exactly one two-person centrepiece, at most HEAVY_LOOT_LIMITS heavy items, and light and medium
# items for the rest; each lands on a free spawn spot whose role the item suits.
class_name Catalog
extends RefCounted

const ROOT: String = "res://props/catalog/"

# --- Loading ---
static func items(pool: StringName, category: CatalogItem.Category) -> Array[CatalogItem]:
	var found: Array[CatalogItem] = []
	for path: String in _resource_paths(ROOT):
		var item := load(path) as CatalogItem
		if item != null and item.category == category and pool in item.pools:
			found.append(item)
	found.sort_custom(func(a: CatalogItem, b: CatalogItem) -> bool: return String(a.id) < String(b.id))
	return found


static func _resource_paths(folder: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tres"):
			paths.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		paths.append_array(_resource_paths(folder.path_join(sub)))
	return paths


# --- The round's loot ---
static func pick_loot(pool: StringName, spots: Array, total: int, heavy_limit: int, random: RandomNumberGenerator) -> Array[Dictionary]:
	# Returns [{"item": CatalogItem, "spot": Dictionary}], placing at most "total" items (all of them when total < 0).
	var copies: Array[CatalogItem] = []
	for item: CatalogItem in items(pool, CatalogItem.Category.LOOT):
		for copy: int in range(item.count):
			copies.append(item)
	_shuffle(copies, random)
	# Keep the shuffled order stable while placing centrepieces first. sort_custom is not stable for ties.
	var ordered: Array[CatalogItem] = []
	for item: CatalogItem in copies:
		if item.weight_class == Balance.TWO_PERSON:
			ordered.append(item)
	for item: CatalogItem in copies:
		if item.weight_class != Balance.TWO_PERSON:
			ordered.append(item)
	copies = ordered

	var free: Array = spots.duplicate()
	_shuffle(free, random)
	var chosen: Array[Dictionary] = []
	var centrepieces: int = 0
	var heavies: int = 0
	for item: CatalogItem in copies:
		if total >= 0 and chosen.size() >= total:
			break
		if item.weight_class == Balance.TWO_PERSON:
			if centrepieces >= 1:
				continue
		elif item.weight_class == Balance.HEAVY and heavy_limit >= 0 and heavies >= heavy_limit:
			continue
		var spot: Dictionary = _free_spot(free, item)
		if spot.is_empty():
			continue
		free.erase(spot)
		chosen.append({"item": item, "spot": spot})
		centrepieces += int(item.weight_class == Balance.TWO_PERSON)
		heavies += int(item.weight_class == Balance.HEAVY)
	return chosen


static func _free_spot(free: Array, item: CatalogItem) -> Dictionary:
	for spot: Dictionary in free:
		if StringName(spot.role) in item.spot_roles:
			return spot
	return {}


static func _shuffle(list: Array, random: RandomNumberGenerator) -> void:
	# Fisher–Yates with the round's generator, so a restart reproduces the same layout.
	for index: int in range(list.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var saved: Variant = list[index]
		list[index] = list[other]
		list[other] = saved
