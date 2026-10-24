# Reuses real phone helpers to check Ship selection, roles, intro skipping, possession and seeded restart.
extends "res://core/match_check.gd"

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	game.selected_arena = "res://arenas/Ship.tscn"
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	await _connect_phone("Asha")
	await _connect_phone("Bilal")
	for index: int in range(2):
		_send(index, {"type": "ready"})
	await _wait(0.3)
	game.start_match()
	_check(game.phase == "reveal" and playground.arena.ARENA_NAME == "Ghost Ship", "Selecting Ship starts Ship and skips the Mansion intro")
	_check(get_nodes_in_group("loot").size() == 6 and game.starting_value > 0, "Ship match has seeded two-player loot and a real quota")
	var first: Array = _ship_placements()
	var seed_before: int = game.round_seed
	await _wait(3.3)
	_check(game.phase == "live" and not paused, "Ship reaches live play with both phones")
	var ghost: Node3D = playground.ghost
	_check(ghost.hauntings[0].label == "WIND" and ghost.hud().simple, "Ghost phone uses Wind and Curse controls")
	for prop: Node3D in get_nodes_in_group("furniture"):
		var component: Node3D = prop.get_node("Possessable")
		ghost.position = component.global_position
		ghost._update_target()
		_check(ghost.target != null and ghost.target.kind == component.kind, "Ship permits possession type %d in match mode" % component.kind)
	game._finish_round(false, "Ship restart check")
	game.restart_round()
	_check(game.round_seed == seed_before and _ship_placements() == first, "Ship restart reproduces the same catalog pick and spawn positions")
	_check(playground.arena.rescues.is_empty() and not playground.arena.wind_active, "Ship restart clears wind and pending rescues")
	for client: WebSocketPeer in clients:
		client.close()
	game.return_to_lobby()
	await _wait(0.1)
	print("SHIP MATCH CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _ship_placements() -> Array:
	var placements: Array = []
	for item: Node3D in get_nodes_in_group("loot"):
		placements.append([String(item.catalog_item.id), item.position])
	return placements
