# Medals and bonus goals (decision 123). Each round the movers earn 0 to 3 stars for their haul (the target, then
# MEDAL_STEPS percent above it) and get one bonus goal picked from those the arena allows; the ghost gets a
# counter-goal: shatter the dearest item. Game feeds this the round's events and asks for the outcome as it scores.
extends RefCounted

# --- State ---
var goat_id: int = 0 # The Museum's goat, for "Rescue the goat".
var goal: Dictionary = {} # {"id", "text", "state": "open" | "met" | "failed"}
var ghost_goal: Dictionary = {}
var pair_item_id: int = 0 # The two-person item, for the careful-delivery goal.
var dearest_id: int = 0 # The ghost's target.
var arena: Node3D

# --- A new round ---
func start(round_arena: Node3D, loot: Array[Node], round_seed: int) -> void:
	# Picked from the round's seed, so a restarted round keeps its goals.
	arena = round_arena
	pair_item_id = 0
	dearest_id = 0
	var pair_name: String = ""
	var dearest: Node = null
	for item: Node in loot:
		if item.weight_class == Balance.TWO_PERSON:
			pair_item_id = item.get_instance_id()
			pair_name = item.item_name
		if dearest == null or item.value > dearest.value:
			dearest = item
	var choices: Array[Dictionary] = [{"id": "no_shatter", "text": "Nothing shatters"}]
	if pair_item_id != 0:
		choices.append({"id": "careful", "text": "Deliver the %s with %d%% of its value" % [pair_name, Balance.GOAL_CAREFUL_SHARE]})
	if arena.has_signal("overboard"):
		choices.append({"id": "dry", "text": "Nobody goes overboard"})
	if arena.has_signal("caught_in_beam"):
		choices.append({"id": "unseen", "text": "Nobody gets caught in the beam"})
	for item: Node in loot:
		if item is MuseumGoat:
			goat_id = item.get_instance_id()
			choices.append({"id": "goat", "text": "Rescue the goat"})
	if is_instance_valid(arena.get("generator")):
		choices.append({"id": "task", "text": Balance.GOAL_TASK_TEXTS.get(arena.generator.TASK_NAME, "Finish the task")})
	var picker := RandomNumberGenerator.new()
	picker.seed = round_seed + Balance.GOAL_SEED_OFFSET
	goal = choices[picker.randi_range(0, choices.size() - 1)].duplicate()
	goal.state = "open"
	ghost_goal = {}
	if dearest != null:
		dearest_id = dearest.get_instance_id()
		ghost_goal = {"id": "shatter", "text": "Shatter the %s" % dearest.item_name, "state": "open"}


# --- Round events, from Game ---
func on_shattered(item: Node) -> void:
	if goal.get("id") == "no_shatter":
		_settle(goal, false)
	if goal.get("id") == "careful" and item.get_instance_id() == pair_item_id:
		_settle(goal, false)
	if item.get_instance_id() == dearest_id:
		_settle(ghost_goal, true)


func on_overboard() -> void:
	if goal.get("id") == "dry":
		_settle(goal, false)


func on_caught() -> void:
	if goal.get("id") == "unseen":
		_settle(goal, false)


func on_delivered(item_id: int, value: int, initial_value: int) -> void:
	if goal.get("id") == "goat" and item_id == goat_id:
		_settle(goal, true)
	if goal.get("id") == "careful" and item_id == pair_item_id:
		_settle(goal, value * 100 >= initial_value * Balance.GOAL_CAREFUL_SHARE)
	if item_id == dearest_id:
		_settle(ghost_goal, false) # Banked whole or not, it can no longer shatter.


func update() -> void:
	# Goals that are met the moment something happens, rather than at the round's end.
	if goal.get("id") == "task" and goal.state == "open" and is_instance_valid(arena) and is_instance_valid(arena.generator) and arena.generator.powered:
		_settle(goal, true)


# --- Scoring ---
func finish() -> void:
	# The round is over: goals nobody broke are met, and goals nobody reached are missed.
	update()
	if goal.get("state") == "open":
		_settle(goal, goal.id in ["no_shatter", "dry", "unseen"]) # Goals nobody broke are met.
	if ghost_goal.get("state") == "open":
		_settle(ghost_goal, false)


static func stars_for(banked: int, starting: int, target_percent: int) -> int:
	# 1 at the target, 2 and 3 at MEDAL_STEPS above it (never above 100%).
	var stars: int = 0
	for step: int in Balance.MEDAL_STEPS:
		if banked * 100 >= starting * mini(100, target_percent + step):
			stars += 1
	return stars


func summary() -> Dictionary:
	return {"goal": goal.duplicate(), "ghostGoal": ghost_goal.duplicate()}


func _settle(which: Dictionary, met: bool) -> void:
	if which.get("state") == "open":
		which.state = "met" if met else "failed"
