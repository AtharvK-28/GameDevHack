# Checks how a mission round ends (decision 161), in a real match on the Mansion: the crew needs the power back on and
# the delivery target banked, and the ghost wins on the clock or on a target out of reach. Each ending gets a restarted
# round, so restarts are proven to clear the mission too.
extends "res://core/match_check.gd"

const MISSION_ARENA: String = "res://arenas/MansionMission.tscn"
const DELIVERY_POINT := Vector3(7.75, 0.3, 22.6) # On the driveway at the tailgate.

var arena: Node3D


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting mission_win_check.gd")
		quit(1)
		return
	game.selected_arena = MISSION_ARENA
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	var dev: CanvasLayer = playground.dev_tools
	await _wait(SETTLE_SECONDS)
	dev.forced = true
	dev.bot_crew.active = false # The checks drive every ending; bots would only blur them.
	seed(3)
	for count: int in range(2):
		await _key(KEY_F10)
	await _wait(0.5)
	await _key(KEY_ENTER)
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	arena = playground.arena

	await _check_power_and_target_win()
	await _next_attempt()
	await _check_target_without_power_loses()
	await _next_attempt()
	await _check_power_without_target_loses()
	await _next_attempt()
	await _check_target_out_of_reach()
	print("MISSION WIN CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


# --- The endings ---
func _check_power_and_target_win() -> void:
	_check(_has_piano(), "The piano is in the round")
	_power_on()
	_check(game.mission_done, "The wires are the mission's last step")
	_check(arena.mission.hud_text() == SETTINGS.MISSION_DONE_HUD and arena.mission.phone_text() == SETTINGS.MISSION_DONE_PHONE, "The crew is told the gallery is open and to load the truck")
	await _bank_to_target()
	_check(game.phase == "live", "Reaching the target does not end the round, as on the other maps")
	game.seconds_left = 0.05
	await _wait(0.3)
	_check(game.phase == "result" and game.result.get("moversWon", false), "Power on and target met at the bell: the movers win")


func _check_target_without_power_loses() -> void:
	await _bank_to_target()
	game.seconds_left = 0.05
	await _wait(0.3)
	_check(game.phase == "result" and not game.result.get("moversWon", true), "Target met but the power never fixed: the ghost wins")
	_check(String(game.result.get("reason", "")).contains("power"), "The reason says the power never came back on")


func _check_power_without_target_loses() -> void:
	_power_on()
	game.seconds_left = 0.05
	await _wait(0.3)
	_check(game.phase == "result" and not game.result.get("moversWon", true), "Power on but the target missed: the ghost wins")


func _check_target_out_of_reach() -> void:
	_power_on()
	for item: Node in _loose_loot():
		if game.phase == "live":
			item._lose_value(item.value)
			await _wait(0.05)
	await _wait(0.2)
	_check(game.phase == "result" and not game.result.get("moversWon", true), "Wrecking enough to put the target out of reach wins for the ghost at once")


# --- Helpers ---
func _power_on() -> void:
	for id: String in ["key", "cupboard", "wires"]:
		arena.mission.complete(id)


func _bank_to_target() -> void:
	for item: Node in _loose_loot():
		if game.banked_value * 100 >= game.starting_value * game.delivery_percent():
			return
		item.global_position = DELIVERY_POINT
		arena.truck.try_bank(item)
		await _wait(0.1)
	_check(game.banked_value * 100 >= game.starting_value * game.delivery_percent(), "The target is banked (%d of %d)" % [game.banked_value, game.starting_value])


func _loose_loot() -> Array[Node]:
	var items: Array[Node] = []
	for item: Node in get_nodes_in_group("loot"):
		if not item.finished:
			items.append(item)
	return items


func _has_piano() -> bool:
	return _loose_loot().any(func(item: Node) -> bool: return item.weight_class == SETTINGS.TWO_PERSON)


func _next_attempt() -> void:
	await _key(KEY_R)
	await _wait(0.2)
	await _wait_for_phase("live")
	arena = playground.arena
	_check(not game.mission_done and game.phase == "live", "A restart clears the mission")
