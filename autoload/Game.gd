# Owns the match lifecycle, frozen result snapshots and score ledger. Networking and host UI keep running while paused.
extends Node

signal changed
signal delivery_notice(value: int, item_name: String, slots: Array[int])

# --- Match state ---
const SHIP_ARENA: String = "res://arenas/Ship.tscn"
const MUSEUM_ARENA: String = "res://arenas/Museum.tscn"
var selected_arena: String = "res://arenas/Mansion.tscn"
var room_items: Dictionary = {}
var host: Node3D
var phase: String = "lobby"
var resume_phase: String = "live"
var participants: Array[int] = []
var round_index: int = 0
var round_count: int = 0
var round_seed: int = 0
var ghost_slot: int = -1
var seconds_left: float = 0.0
var reveal_left: float = 0.0
var starting_value: int = 0
var banked_value: int = 0
var lost_value: int = 0
var scores: Dictionary = {}
var bank_credit: Dictionary = {}
var round_points: Dictionary = {}
var round_stats: Dictionary = {} # Slot -> {stat: amount} this round, for the awards.
var match_stats: Dictionary = {} # The same, summed over the rounds played to the end.
var result: Dictionary = {}
var pause_reason: String = ""
var host_paused: bool = false
var broadcast_left: float = 0.0
const ROUND_GOALS := preload("res://core/round_goals.gd")
var goals: RefCounted = ROUND_GOALS.new() # This round's stars and bonus goals (decision 123).
var smash_ready_at: int = 0 # Ticks (ms) before another big-smash punch-in may play.
var slow_until: int = 0 # Ticks (ms) when the current punch-in's slow motion ends.
var normal_speed: float = 1.0 # Live play's game speed; developer mode changes it (decision 121).

# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.players_changed.connect(_players_changed)


func attach(world: Node3D) -> void:
	host = world
	return_to_lobby()


func ready_slots() -> Array[int]:
	var slots: Array[int] = []
	for player: Dictionary in Net.players:
		if player.socket != null and player.ready:
			slots.append(player.slot)
	slots.sort()
	return slots


func can_start() -> bool:
	return Net.listen_error == OK and phase == "lobby" and ready_slots().size() >= 2


func start_match() -> void:
	if not can_start():
		return
	participants = ready_slots()
	round_count = Balance.MATCH_ROUNDS[participants.size() - 2]
	round_index = 0
	scores.clear()
	match_stats.clear()
	for slot: int in participants:
		scores[slot] = 0.0
	Net.accept_new_players = false
	_set_phase("intro") # Each arena's story plays once per match.


func finish_intro() -> void:
	if phase != "intro":
		return
	_begin_round(false)
	Sfx.start_ambient()


func _begin_round(restarting: bool) -> void:
	_set_phase("setup")
	if not restarting:
		round_seed = randi()
	ghost_slot = participants[round_index % participants.size()]
	bank_credit.clear()
	round_points.clear()
	round_stats.clear()
	result.clear()
	banked_value = 0
	lost_value = 0
	starting_value = 0
	room_items.clear()
	seconds_left = Balance.DEMO_ROUND_SECONDS if PlayerConfig.get_config("GameSettings", "DemoMode", false) else Balance.ROUND_SECONDS
	reveal_left = Balance.REVEAL_SECONDS
	host.setup_match_round(round_seed, participants, ghost_slot)
	for item: Node in get_tree().get_nodes_in_group("loot"):
		starting_value += item.value
		var item_id: int = item.get_instance_id()
		room_items[item_id] = {"room": room_at(item.global_position), "state": "pending"}
		item.shattered.connect(func(_slot: int) -> void:
			room_items[item_id].state = "broken"
			if phase == "live":
				goals.on_shattered(item))
		# Damage counts against a mover only while they hold or have just thrown the item.
		item.damaged.connect(func(loss: int, remaining: int) -> void:
			if item.is_held() or item.thrown:
				add_stat(item.last_carrier_slot, "smashed", loss)
			if loss >= Balance.SMASH_PUNCH_LOSS or (remaining == 0 and item.initial_value >= Balance.SFX_TROMBONE_VALUE):
				big_smash(item.global_position))
	for mover: CharacterBody3D in host.movers:
		if not mover.tumbled.is_connected(_on_tumbled):
			mover.tumbled.connect(_on_tumbled)
	if host.arena.has_signal("overboard"):
		host.arena.overboard.connect(func(slot: int) -> void:
			add_stat(slot, "overboard", 1)
			if phase == "live":
				goals.on_overboard())
	goals.start(host.arena, get_tree().get_nodes_in_group("loot"), round_seed)
	host.arena.truck.delivered.connect(_on_delivered)
	host.arena.truck.delivery_notice.connect(_delivery_notice)
	for slot: int in participants:
		var player: Dictionary = Net.player_for_slot(slot)
		Net.send_to_player(player, {"type": "buzz", "ms": Balance.TUMBLE_BUZZ_MS})
	_set_phase("reveal")
	_players_changed()


# --- Round loop ---
func _process(delta: float) -> void:
	if not is_instance_valid(host):
		return
	if phase == "reveal":
		reveal_left = maxf(0.0, reveal_left - delta)
		if reveal_left <= 0.0:
			_set_phase("live")
	elif phase == "live":
		seconds_left = maxf(0.0, seconds_left - delta)
		goals.update()
		_evaluate_round()
	broadcast_left -= delta
	if broadcast_left <= 0.0:
		broadcast_left = 1.0 / Balance.HUD_RATE
		_broadcast()


func _evaluate_round() -> void:
	var remaining: int = 0
	var unresolved: int = 0
	for item: Node3D in get_tree().get_nodes_in_group("loot"):
		if item.finished:
			continue
		if item.global_position.y < Balance.LOST_ITEM_Y:
			item._lose_value(item.value)
			continue
		remaining += item.value
		unresolved += 1
	lost_value = maxi(0, starting_value - banked_value - remaining)
	if (banked_value + remaining) * 100 < starting_value * delivery_percent():
		_finish_round(false, "More than %d%% of the starting value was lost." % (100 - delivery_percent()))
	elif seconds_left <= 0.0 or unresolved == 0:
		var won: bool = banked_value * 100 >= starting_value * delivery_percent()
		_finish_round(won, "Time is up." if seconds_left <= 0.0 else "All items are accounted for.")


func _on_delivered(value: int, carrier_slots: Array[int]) -> void:
	if phase != "live":
		return
	banked_value += value
	if carrier_slots.is_empty():
		return
	for slot: int in carrier_slots:
		if slot in participants and slot != ghost_slot:
			bank_credit[slot] = bank_credit.get(slot, 0.0) + float(value) / carrier_slots.size()


func _finish_round(movers_won: bool, reason: String) -> void:
	if phase != "live":
		return
	goals.finish()
	var stars: int = ROUND_GOALS.stars_for(banked_value, starting_value, delivery_percent()) if movers_won else 0
	var goal_met: bool = goals.goal.get("state") == "met"
	var ghost_goal_met: bool = goals.ghost_goal.get("state") == "met"
	for slot: int in participants:
		var points: float
		if slot == ghost_slot:
			points = lost_value / Balance.RUPEES_PER_POINT + (0.0 if movers_won else Balance.GHOST_WIN_BONUS)
			points += Balance.GHOST_GOAL_POINTS if ghost_goal_met else 0.0
		else:
			points = bank_credit.get(slot, 0.0) / Balance.RUPEES_PER_POINT + (Balance.MOVER_WIN_BONUS if movers_won else 0.0)
			points += stars * Balance.STAR_POINTS + (Balance.GOAL_POINTS if goal_met else 0.0)
		round_points[slot] = points
		scores[slot] += points
		Net.player_for_slot(slot).points = scores[slot]
	for slot: int in bank_credit:
		add_stat(slot, "banked", roundi(bank_credit[slot]))
	add_stat(ghost_slot, "wrecked", lost_value)
	result = {"moversWon": movers_won, "reason": reason, "banked": banked_value, "starting": starting_value, "lost": lost_value, "awards": awards_for(round_stats),
		"stars": stars, "goal": goals.goal.duplicate(), "ghostGoal": goals.ghost_goal.duplicate()}
	_set_phase("result")
	for slot: int in participants:
		Net.send_to_player(Net.player_for_slot(slot), {"type": "result", "moversWon": movers_won, "points": round_points, "stars": stars,
			"goal": goals.goal.duplicate(), "ghostGoal": goals.ghost_goal.duplicate()})




# --- Big smash ---
func big_smash(point: Vector3) -> void:
	# Slow the match and ease the camera in on the disaster for a moment, at most every few seconds.
	if phase != "live" or Time.get_ticks_msec() < smash_ready_at:
		return
	smash_ready_at = Time.get_ticks_msec() + int(Balance.SMASH_COOLDOWN * 1000.0)
	slow_until = Time.get_ticks_msec() + int(Balance.SMASH_SLOWMO_SECONDS * 1000.0)
	Engine.time_scale = Balance.SMASH_SLOWMO_SCALE * normal_speed
	if is_instance_valid(host) and is_instance_valid(host.camera):
		host.camera.punch_in(point)
	# Real time, and through pauses, so nothing can leave the match stuck in slow motion.
	get_tree().create_timer(Balance.SMASH_SLOWMO_SECONDS, true, false, true).timeout.connect(func() -> void: Engine.time_scale = normal_speed if phase == "live" else 1.0)


func punching_in() -> bool:
	return Time.get_ticks_msec() < slow_until


# --- Awards ---
func add_stat(slot: int, stat: String, amount: int) -> void:
	if phase != "live" and stat not in ["banked", "wrecked"]:
		return # Stats only count during play; the round's totals are added as it finishes.
	if slot not in participants or amount <= 0:
		return
	var stats: Dictionary = round_stats.get_or_add(slot, {})
	stats[stat] = stats.get(stat, 0) + amount


func awards_for(stats: Dictionary) -> Array[Dictionary]:
	# Each award, in order, to the player with the most of its stat who has none yet: [{slot, title, detail}].
	var awards: Array[Dictionary] = []
	var awarded: Dictionary = {}
	for award: Dictionary in Balance.AWARDS:
		var best_slot: int = -1
		var best: int = award.least - 1
		for slot: int in stats:
			var amount: int = stats[slot].get(award.stat, 0)
			if not awarded.has(slot) and amount > best:
				best = amount
				best_slot = slot
		if best_slot < 0:
			continue
		awarded[best_slot] = true
		var shown: String = Loot.rupees(best) if award.get("money", false) else str(best)
		awards.append({"slot": best_slot, "title": award.title, "detail": award.detail % shown if award.get("money", false) else award.detail % best})
	return awards


func award_for(slot: int, awards: Array) -> Dictionary:
	for award: Dictionary in awards:
		if int(award.slot) == slot:
			return award
	return {}


func _fold_round_stats() -> void:
	for slot: int in round_stats:
		var total: Dictionary = match_stats.get_or_add(slot, {})
		for stat: String in round_stats[slot]:
			total[stat] = total.get(stat, 0) + round_stats[slot][stat]
	round_stats.clear()


func _on_tumbled(slot: int) -> void:
	if slot != ghost_slot:
		add_stat(slot, "tumbles", 1)


# --- Host actions ---
func pause_by_host() -> void:
	if phase not in ["live", "reveal"]:
		return
	host_paused = true
	resume_phase = phase
	pause_reason = "Host paused the game"
	_set_phase("paused")


func resume_by_host() -> void:
	host_paused = false
	_players_changed() # A disconnected phone still keeps the match paused.


func restart_round() -> void:
	if phase != "result":
		return
	for slot: int in participants:
		scores[slot] -= round_points.get(slot, 0.0)
		Net.player_for_slot(slot).points = scores[slot]
	_begin_round(true)


func next_round() -> void:
	if phase != "result":
		return
	_fold_round_stats() # Only rounds played on count: a restart replays the round instead.
	if round_index + 1 >= round_count:
		_set_phase("final")
		for player: Dictionary in Net.players:
			Net.send_to_player(player, {"type": "final", "standings": standings(), "awards": awards_for(match_stats)})
		return
	round_index += 1
	_begin_round(false)


func return_to_lobby() -> void:
	if is_instance_valid(host):
		host.reset_for_lobby()
	Net.accept_new_players = true
	participants.clear()
	scores.clear()
	result.clear()
	round_points.clear()
	pause_reason = ""
	host_paused = false
	ghost_slot = -1
	for player: Dictionary in Net.players:
		player.ready = false
		player.role = ""
		player.points = 0
	_set_phase("lobby")
	Net._broadcast_lobby()


# --- Connection and phase synchronisation ---
func _players_changed() -> void:
	if not is_instance_valid(host):
		return
	if phase in ["live", "reveal", "paused"]:
		var missing: PackedStringArray = []
		for slot: int in participants:
			var player: Dictionary = Net.player_for_slot(slot)
			if player.socket == null:
				missing.append(player.name)
		if not missing.is_empty():
			pause_reason = "Waiting for " + ", ".join(missing) + " to reconnect"
			if phase != "paused":
				resume_phase = phase
				_set_phase("paused")
		elif phase == "paused" and not host_paused:
			pause_reason = ""
			_set_phase(resume_phase)
		elif host_paused:
			pause_reason = "Host paused the game"
	_broadcast.call_deferred() # Join sends the role after emitting players_changed.
	changed.emit()


func _set_phase(next: String) -> void:
	# A punch-in never outlives live play; the screens between rounds always run at normal speed.
	Engine.time_scale = normal_speed if next == "live" else 1.0
	phase = next
	InputRouter.input_enabled = phase == "live"
	InputRouter._clear_keyboard()
	for player: Dictionary in Net.players:
		Net._reset_input(player)
	get_tree().paused = phase != "live"
	changed.emit()
	_broadcast()


func snapshot() -> Dictionary:
	var players: Array[Dictionary] = []
	for player: Dictionary in Net.players:
		players.append({"slot": player.slot, "name": player.name, "ready": player.ready, "online": player.socket != null})
	return {"type": "match", "phase": phase, "round": round_index + 1, "rounds": round_count,
		"t": ceili(seconds_left), "countdown": ceili(reveal_left), "target": target_value(),
		"starting": starting_value, "banked": banked_value, "lost": lost_value, "ghost": ghost_slot,
		"result": result, "standings": standings(), "pauseReason": pause_reason, "canStart": can_start(),
		"players": players, "goal": goals.goal, "ghostGoal": goals.ghost_goal}


# --- Queries for the host screens ---
func target_value() -> int:
	# The smallest whole-rupee delivery that reaches the crew's share of the starting value.
	return ceili(starting_value * delivery_percent() / 100.0)


func delivery_percent() -> int:
	# The movers' target share, by how many movers there are (decision 122).
	var movers: int = maxi(1, participants.size() - 1)
	return Balance.DELIVERY_PERCENTS[mini(movers, Balance.DELIVERY_PERCENTS.size()) - 1]


func loss_limit() -> int:
	# Losing more than this makes the target impossible, which ends the round for the ghost.
	return starting_value - target_value()


func ghost() -> Node3D:
	return host.ghost if is_instance_valid(host) and is_instance_valid(host.ghost) else null


func arena_name() -> String:
	return host.arena.ARENA_NAME if is_instance_valid(host) and is_instance_valid(host.arena) else ""


func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot: int in participants:
		var player: Dictionary = Net.player_for_slot(slot)
		rows.append({"slot": slot, "name": player.get("name", "Player %d" % (slot + 1)), "points": scores.get(slot, 0.0), "roundPoints": round_points.get(slot, 0.0)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.points > b.points)
	return rows


func _broadcast() -> void:
	if not is_instance_valid(host):
		return
	var message: Dictionary = snapshot()
	for player: Dictionary in Net.players:
		Net.send_to_player(player, message)
	changed.emit()


func _delivery_notice(value: int, item_name: String, slots: Array[int], item_id: int) -> void:
	var item: Object = instance_from_id(item_id)
	if phase == "live" and is_instance_valid(item):
		goals.on_delivered(item_id, value, item.initial_value)
	if room_items.has(item_id):
		room_items[item_id].state = "delivered"
	delivery_notice.emit(value, item_name, slots)


func room_at(point: Vector3) -> String:
	if not is_instance_valid(host) or host.arena.get("layout") == null:
		return "Main room"
	if host.arena.has_method("room_at"):
		return host.arena.room_at(point)
	for room: Dictionary in host.arena.layout.rooms:
		var area: Array = room.rect
		if Rect2(area[0], area[1], area[2], area[3]).has_point(Vector2(point.x, point.z)):
			return String(room.id).trim_prefix("room-").replace("first-floor", "Gallery").capitalize()
	return "Outside"


func live_points(slot: int) -> float:
	var total: float = scores.get(slot, 0.0)
	if phase in ["live", "paused", "reveal"]:
		total += (lost_value if slot == ghost_slot else bank_credit.get(slot, 0.0)) / Balance.RUPEES_PER_POINT
	return total
