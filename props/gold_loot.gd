# The Getaway's gold (decision 147): solid treasure, so bumps cost nothing; it only counts as lost when it leaves the truck.
class_name GoldLoot
extends Loot

func apply_impact(_speed: float, _was_thrown: bool = false) -> void:
	pass


func _apply_scrape() -> void:
	scrape_distance = 0.0
