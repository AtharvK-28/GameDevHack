# Reuses real phone helpers to check Ship selection, its story, roles, possession and seeded restart.
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
	_check(game.phase == "intro", "A Ship match opens with its own story")
	await _wait(0.5)
	var cutscene: Node = playground.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node.get_script() != null and node.get_script().resource_path == "res://screens/cutscene.gd")[0] # Not preload: it would compile before the autoloads.
	_check(cutscene._panels() == SETTINGS.SHIP_INTRO_PANELS and cutscene.lettering.get_child_count() > 0, "The Ship's panels play, with their captions lettered")
	await _key(KEY_ESCAPE)
	_check(game.phase == "reveal" and playground.arena.ARENA_NAME == "Ghost Ship", "Esc skips the story into the Ship's first round")
	_check(get_nodes_in_group("loot").size() == 6 and game.starting_value > 0, "Ship match has seeded two-player loot and a real quota")
	var first: Array = _ship_placements()
	var seed_before: int = game.round_seed
	await _wait(3.3)
	_check(game.phase == "live" and not paused, "Ship reaches live play with both phones")
	var ghost: Node3D = playground.ghost
	_check(ghost.hauntings[0].label == "WIND" and ghost.hud().simple, "Ghost phone uses Wind and Curse controls")
	# Shouts: a mover's phone pops words over their head; spam, junk and the ghost are ignored.
	var shouter: int = 1 - game.ghost_slot
	_send(shouter, {"type": "shout", "s": 0})
	_send(shouter, {"type": "shout", "s": 1}) # Inside the cooldown.
	_send(shouter, {"type": "shout", "s": 9})
	_send(shouter, {"type": "shout", "s": "LIFT"})
	_send(game.ghost_slot, {"type": "shout", "s": 2})
	await _wait(0.3)
	var words: Array = playground.movers[shouter].find_children("*", "Label3D", false, false).map(func(label: Label3D) -> String: return label.text)
	_check(words.count("LIFT!") == 1 and not words.has("WAIT!"), "A mover's shout pops over their head once, cooldown respected (%s)" % [words])
	var ghost_words: Array = playground.movers[game.ghost_slot].find_children("*", "Label3D", false, false).map(func(label: Label3D) -> String: return label.text)
	_check(not ghost_words.has("MY BAD!"), "The ghost's phone cannot shout")
	for prop: Node3D in get_nodes_in_group("furniture"):
		var component: Node3D = prop.get_node("Possessable")
		ghost.position = component.global_position
		ghost._update_target()
		_check(ghost.target != null and ghost.target.kind == component.kind, "Ship permits possession type %d in match mode" % component.kind)
	# Awards: a real fall overboard and a real tumble count; the ghost is credited with what was lost.
	var mover_slot: int = 1 - game.ghost_slot
	var mover: CharacterBody3D = playground.movers[mover_slot]
	mover.tumble()
	playground.arena._begin_rescue(mover)
	var any_loot: Node = get_nodes_in_group("loot")[0]
	any_loot._lose_value(any_loot.value) # Lost to the ghost, so it is not anyone's butterfingers.
	await _wait(0.1)
	game._finish_round(false, "Ship restart check")
	var awards: Array = game.result.get("awards", [])
	_check(game.award_for(mover_slot, awards).get("title", "") == "MAN OVERBOARD", "The mover who fell in gets MAN OVERBOARD (%s)" % [awards])
	_check(game.award_for(game.ghost_slot, awards).get("title", "") == "MENACE", "The ghost gets MENACE for the loot it wrecked")
	_check(game.round_stats.get(mover_slot, {}).get("tumbles", 0) == 1 and not game.round_stats.get(mover_slot, {}).has("smashed"), "Tumbles count; loot lost while nobody held it is not a mover's fault")
	var picked: Array = game.awards_for({0: {"smashed": 900, "tumbles": 3}, 1: {"banked": 4000, "tumbles": 5}, 2: {"tumbles": 1}})
	_check(picked.size() == 2 and game.award_for(0, picked).title == "BUTTERFINGERS" and game.award_for(1, picked).title == "FLOOR INSPECTOR" and game.award_for(2, picked).is_empty(),
		"Each award goes to the leader without one already, above its threshold (%s)" % [picked])
	game.restart_round()
	_check(game.match_stats.is_empty(), "A restarted round's stats never reach the match totals")
	_check(game.round_seed == seed_before and _ship_placements() == first, "Ship restart reproduces the same catalog pick and spawn positions")
	_check(playground.arena.rescues.is_empty() and not playground.arena.wind_active, "Ship restart clears wind and pending rescues")
	while game.phase != "live":
		await process_frame
	# Big smash, in the restarted round once it is live (it ends the round: over 30% is lost): a five-figure hit slows the match and eases the camera in, then normal speed returns by itself.
	game.smash_ready_at = 0 # The awards check above shattered a valuable item, which started the cooldown.
	var chest: Node = get_nodes_in_group("loot").filter(func(item: Node) -> bool: return item.initial_value >= SETTINGS.SFX_TROMBONE_VALUE)[0]
	chest._lose_value(SETTINGS.SMASH_PUNCH_LOSS)
	_check(Engine.time_scale < 1.0 and playground.camera.punch_left > 0.0, "A big smash slows the match and punches the camera in")
	chest._lose_value(SETTINGS.SMASH_PUNCH_LOSS)
	await create_timer(SETTINGS.SMASH_SLOWMO_SECONDS + 0.2, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "Normal speed returns after the punch-in")
	var cooled: float = playground.camera.punch_left
	chest._lose_value(SETTINGS.SMASH_PUNCH_LOSS)
	_check(is_equal_approx(Engine.time_scale, 1.0) and playground.camera.punch_left <= cooled, "Another big smash within the cooldown plays no second punch-in")

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
