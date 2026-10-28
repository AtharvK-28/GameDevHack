# Developer mode's playing stand-ins (decision 121): bots that play every stand-in phone except the one the keyboard
# drives, so one developer can try a full round. They only press what a phone could, through the stand-in's real
# socket. Mover bots walk the arena's route map (core/bot_routes.gd), fetch the best loot for the walk, carry the
# two-person item in pairs and brace for hauntings and waves; the ghost bot hauntings, curses carried loot and steals
# items movers are walking to. Arenas without a route map get no bots. Adapted from the recording bots in tools/.
extends Node

const ROUTES := preload("res://core/bot_routes.gd")

# --- A mover bot's state ---
class Bot:
	var phone: RefCounted # A stand-in phone (core/stand_in_phone.gd).
	var mover: CharacterBody3D
	var mode: String = "idle" # idle, fetch, carry, pair
	var item: Node3D
	var route: Array[Vector3] = []
	var check_at: float = 0.0
	var check_position := Vector3.ZERO
	var stuck_count: int = 0
	var sidestep_left: float = 0.0
	var sidestep := Vector2.ZERO
	var give_up: Dictionary = {} # Item -> round time it may be tried again.
	var pair_end: int = -1 # The two-person item's handle this bot takes.
	var alone_time: float = 0.0 # Seconds holding the two-person item without the partner.
	var grab_time: float = 0.0 # Seconds GRAB has been held without taking hold.

# --- State ---
var host: Node3D # Main.
var active: bool = true
var stand_ins: Array = [] # Developer mode's stand-in phones; shared with core/dev_tools.gd.
var route_map: Dictionary = {} # This arena's entry in ROUTES; empty where bots can't walk.
var astar := AStar3D.new()
var node_ids: Dictionary = {}
var levels: Array[float] = [] # The route map's floor heights, highest first.
var arena_id: int = 0 # The arena the bots were set up for; a new round builds a new one.
var bots: Array[Bot] = []
var ghost_phone: RefCounted
var live_time: float = 0.0
var pair_item: RigidBody3D
var pair_waypoint: int = 0
var pair_done: bool = false
var pair_progress_at: float = 0.0 # Round time the pair item last reached a path point.
var ghost_state: String = "rest" # rest, hunt, steal, shove, leaving
var ghost_left: float = 0.0
var ghost_prop: Node # The possessable part of the prop being stolen or shoved.
var ghost_victim: CharacterBody3D # The mover a shoved prop is aimed at; null for a steal.
var haunt_at: float = 0.0
var curse_at: float = 0.0

# --- Every physics frame ---
func _physics_process(delta: float) -> void:
	if not active or Game.phase != "live" or not is_instance_valid(host) or not is_instance_valid(host.arena):
		return
	if host.arena.get_instance_id() != arena_id:
		_start_round()
	if route_map.is_empty():
		return
	live_time += delta
	_check_pair_patience()
	_steer_pair()
	for bot: Bot in bots:
		if bot.phone.slot == InputRouter.selected_slot:
			if bot.mode != "pair":
				bot.mode = "idle" # The keyboard has this one; it chooses afresh when handed back.
			continue
		_update_bot(bot, delta)
	if ghost_phone != null and ghost_phone.slot != InputRouter.selected_slot:
		_update_ghost(delta)


func _start_round() -> void:
	arena_id = host.arena.get_instance_id()
	route_map = ROUTES.ROUTES.get(host.arena.scene_file_path, {})
	bots.clear()
	ghost_phone = null
	live_time = 0.0
	pair_item = null
	pair_waypoint = 0
	pair_done = false
	pair_progress_at = Balance.BOT_PAIR_FIRST_PATIENCE - Balance.BOT_PAIR_PATIENCE # Longer to walk over and lift it.
	_ghost_rest()
	haunt_at = Balance.BOT_GHOST_FIRST_HAUNT
	curse_at = Balance.BOT_GHOST_FIRST_HAUNT + Balance.BOT_GHOST_CURSE_GAP / 2.0
	if route_map.is_empty():
		return
	_build_route_map()
	for phone: RefCounted in stand_ins:
		if phone.slot not in Game.participants:
			continue
		if phone.slot == Game.ghost_slot:
			ghost_phone = phone
			continue
		var bot := Bot.new()
		bot.phone = phone
		bot.mover = host.movers[phone.slot]
		bots.append(bot)
	for item: Node in get_tree().get_nodes_in_group("loot"):
		if item.weight_class == Balance.TWO_PERSON:
			pair_item = item
	if pair_item == null or bots.size() < 2:
		return
	var stands: Array = route_map.pair_stands
	for index: int in range(2):
		var bot: Bot = bots[index]
		bot.mode = "pair"
		var stand: Vector3 = stands[index]
		bot.pair_end = 0 if stand.distance_to(pair_item.handle_position(0)) < stand.distance_to(pair_item.handle_position(1)) else 1
		bot.route = _route_to(bot.mover.global_position, stand)


func release_all() -> void:
	for phone: RefCounted in stand_ins:
		phone.release()


# --- Mover bots ---
func _update_bot(bot: Bot, delta: float) -> void:
	var phone: RefCounted = bot.phone
	if _hazard_for(bot):
		phone.stick = Vector2.ZERO
		phone.buttons["brace"] = true
		return
	phone.buttons["brace"] = false
	match bot.mode:
		"pair":
			_bot_pair(bot, delta)
		"idle":
			phone.stick = Vector2.ZERO
			phone.buttons["grab"] = false
			_choose_item(bot)
		"fetch":
			_bot_fetch(bot, delta)
		"carry":
			_bot_carry(bot, delta)
	if host.arena.has_method("should_wait") and host.arena.should_wait(bot.mover.global_position, phone.stick):
		phone.stick = Vector2.ZERO # A hazard ahead, like a lit laser: wait for the gap.
	if bot.mode != "pair" and is_instance_valid(bot.mover.held_item) and bot.mover.held_item == pair_item:
		phone.buttons["grab"] = false # Nobody drags the two-person item alone.


func _hazard_for(bot: Bot) -> bool:
	# Brace through the arena's haunting; on the Ship, brace on the plank for a wave (both holders of the pair item
	# together, as one pushing while the other holds stretches it out of their grip).
	var ghost: Node3D = host.ghost
	if is_instance_valid(ghost) and not ghost.hauntings.is_empty() and ghost.hauntings[0].is_active():
		return true
	var arena: Node3D = host.arena
	if not arena.has_method("on_gangplank") or arena.wave_warning_left < 0.0:
		return false
	for other: Bot in bots:
		if (other == bot or (bot.mode == "pair" and other.mode == "pair")) and arena.on_gangplank(other.mover.global_position):
			return true
	return false


func _choose_item(bot: Bot) -> void:
	# The most valuable loose item for the walk, skipping the pair item and items other bots are after.
	var best: Node3D
	var best_score: float = 0.0
	for item: Node in get_tree().get_nodes_in_group("loot"):
		if item == pair_item or item.finished or item.is_held() or item.haunted or _delivered(item):
			continue
		if bot.give_up.get(item, -1.0) > live_time or _claimed(item, bot):
			continue
		var trip: float = bot.mover.global_position.distance_to(item.global_position) + item.global_position.distance_to(route_map.delivery)
		var score: float = item.value / (trip + 8.0)
		if score > best_score:
			best_score = score
			best = item
	if best == null:
		return
	bot.item = best
	bot.mode = "fetch"
	bot.stuck_count = 0
	bot.route = _route_to(bot.mover.global_position, _stand_point(best))


func _bot_fetch(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	var item: Node3D = bot.item
	if not is_instance_valid(item) or item.finished or (item.is_held() and not item.is_held_by(mover)):
		bot.mode = "idle"
		return
	if is_instance_valid(mover.held_item):
		if mover.held_item != pair_item:
			bot.item = mover.held_item
			_start_carry(bot)
		return
	if item.haunted:
		_give_up(bot, Balance.BOT_GHOST_STEAL_SECONDS)
		return
	var to_item: Vector3 = item.global_position - mover.global_position
	var flat := Vector2(to_item.x, to_item.z)
	if not bot.route.is_empty() and flat.length() > Balance.BOT_STAND_DISTANCE:
		_follow_route(bot, delta)
		return
	bot.route.clear()
	var facing_ok: bool = Vector2(mover.facing.x, mover.facing.z).dot(flat.normalized()) > 0.85
	if to_item.length() <= Balance.BOT_GRAB_REACH and facing_ok:
		bot.phone.stick = Vector2.ZERO
		_press_grab(bot, delta)
		return
	bot.phone.buttons["grab"] = false
	bot.phone.stick = flat.normalized() * (0.35 if flat.length() < Balance.BOT_STAND_DISTANCE else 1.0)
	if _is_stuck(bot, delta) and bot.stuck_count > Balance.BOT_MAX_STUCK:
		_give_up(bot, Balance.BOT_GIVE_UP_SECONDS)


func _start_carry(bot: Bot) -> void:
	bot.mode = "carry"
	bot.stuck_count = 0
	bot.route = _route_to(bot.mover.global_position, route_map.delivery)


func _bot_carry(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	if not is_instance_valid(bot.item) or bot.item.finished:
		bot.phone.buttons["grab"] = false
		bot.mode = "idle"
		return
	if mover.held_item != bot.item:
		bot.mode = "fetch" # Knocked flat or washed off: go back for it.
		bot.route.clear()
		bot.phone.buttons["grab"] = false
		return
	bot.phone.buttons["grab"] = true
	if _delivered(bot.item):
		bot.phone.stick = Vector2.ZERO
		bot.phone.buttons["grab"] = false
		bot.mode = "idle"
		return
	if bot.route.is_empty():
		bot.route = [route_map.delivery]
	if bot.item.global_position.distance_to(bot.item.carry_target()) > Balance.BOT_SNAG_DISTANCE and bot.sidestep_left <= 0.0:
		bot.phone.stick = Vector2.ZERO # Let a snagged item settle before pulling on.
		_is_stuck(bot, delta)
		return
	_follow_route(bot, delta)
	bot.phone.stick = bot.phone.stick.limit_length(Balance.BOT_CARRY_STICK)
	if bot.stuck_count > Balance.BOT_MAX_STUCK * 2:
		_give_up(bot, Balance.BOT_GIVE_UP_SECONDS) # Wedged: put it down and fetch something else.


func _press_grab(bot: Bot, delta: float) -> void:
	# GRAB takes hold only on a fresh press: if holding it down hasn't worked, let go for a moment and press again.
	# The release lasts a beat, so it reaches the host even when a sped-up round runs several steps per send.
	bot.grab_time += delta
	bot.phone.buttons["grab"] = bot.grab_time < Balance.BOT_REGRAB_SECONDS
	if bot.grab_time >= Balance.BOT_REGRAB_SECONDS + Balance.BOT_REGRAB_GAP:
		bot.grab_time = 0.0


func _give_up(bot: Bot, seconds: float) -> void:
	if is_instance_valid(bot.item):
		bot.give_up[bot.item] = live_time + seconds
	bot.phone.buttons["grab"] = false
	bot.mode = "idle"


# --- The two-person item ---
func _bot_pair(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	if not is_instance_valid(pair_item) or pair_item.finished:
		bot.phone.buttons["grab"] = false
		bot.mode = "idle"
		return
	if pair_done:
		bot.phone.buttons["grab"] = false
		bot.phone.stick = Vector2.ZERO
		if pair_item.holder_count() == 0:
			bot.mode = "idle"
		return
	var partner: CharacterBody3D = _pair_partner(bot)
	if pair_item.is_held_by(mover):
		if pair_item.holder_count() < 2:
			# Holding it alone drags it along the floor, which costs value: let go after a moment, and at once
			# while the partner is away from the handles.
			bot.alone_time += delta
			bot.phone.stick = Vector2.ZERO
			bot.phone.buttons["grab"] = bot.alone_time < Balance.BOT_ALONE_SECONDS and _at_pair_handle(partner)
		else:
			bot.alone_time = 0.0 # _steer_pair moves the pair.
			bot.phone.buttons["grab"] = true
		return
	bot.alone_time = 0.0
	if not bot.route.is_empty():
		bot.phone.buttons["grab"] = false
		_follow_route(bot, delta)
		return
	if partner != null and pair_item.is_held_by(partner):
		bot.pair_end = 1 - pair_item.handle_holders.find(partner) # Take whichever handle is still free.
	var handle: Vector3 = pair_item.handle_position(bot.pair_end)
	var to_handle := Vector2(handle.x - mover.global_position.x, handle.z - mover.global_position.z)
	var facing_ok: bool = Vector2(mover.facing.x, mover.facing.z).dot(to_handle.normalized()) > 0.85
	var partner_ready: bool = partner == null or pair_item.is_held_by(partner) or _at_pair_handle(partner)
	if to_handle.length() < Balance.BOT_GRAB_REACH and facing_ok and partner_ready:
		bot.phone.stick = Vector2.ZERO
		_press_grab(bot, delta)
	else:
		bot.phone.buttons["grab"] = false
		bot.phone.stick = _toward_handle(mover, handle, partner_ready)


func _toward_handle(mover: CharacterBody3D, handle: Vector3, partner_ready: bool) -> Vector2:
	# Come in from outside the handle, rounding the item's flank when starting on its far side, so the bot never
	# shoves the item while its partner holds the other end.
	var centre := Vector2(pair_item.global_position.x, pair_item.global_position.z)
	var at := Vector2(mover.global_position.x, mover.global_position.z)
	var grip := Vector2(handle.x, handle.z)
	var outward: Vector2 = (grip - centre).normalized()
	var behind: bool = (at - grip).dot(outward) < 0.0 # On the item's side of the handle.
	if not behind and at.distance_to(grip) < Balance.BOT_GRAB_REACH:
		return (grip - at).normalized() * 0.35 if partner_ready else Vector2.ZERO # Lined up: face it and step in.
	var line_up: Vector2 = grip + outward * Balance.BOT_HANDLE_SIDE
	if behind:
		var flank := Vector2(-outward.y, outward.x)
		if (at - centre).dot(flank) < 0.0:
			flank = -flank
		line_up += flank * Balance.BOT_HANDLE_SIDE * 2.0
	return (line_up - at).normalized()


func _at_pair_handle(mover: CharacterBody3D) -> bool:
	# Close enough to one of the two-person item's handles to take it within a moment.
	if mover == null:
		return false
	for index: int in range(2):
		var handle: Vector3 = pair_item.handle_position(index)
		if Vector2(handle.x - mover.global_position.x, handle.z - mover.global_position.z).length() < Balance.BOT_GRAB_REACH * 1.25:
			return true
	return false


func _pair_partner(bot: Bot) -> CharacterBody3D:
	for other: Bot in bots:
		if other != bot and other.mode == "pair":
			return other.mover
	return null


func _check_pair_patience() -> void:
	# A pair that makes no progress for a while (blocked, or knocked about) gives up on the item and fetches other
	# loot instead, so a developer's round never stalls.
	if pair_done or not is_instance_valid(pair_item) or live_time - pair_progress_at < Balance.BOT_PAIR_PATIENCE:
		return
	pair_done = true
	for bot: Bot in bots:
		if bot.mode == "pair":
			bot.mode = "idle"
			bot.route.clear()
			bot.phone.buttons["grab"] = false


func _steer_pair() -> void:
	# Both holders push along the path and pull their own handle onto the path line, so the item turns to follow
	# it; at a sharp bend it slows down to turn first.
	if not is_instance_valid(pair_item) or pair_item.finished or pair_item.holder_count() < 2:
		return
	if _delivered(pair_item):
		pair_done = true
		return
	var path: Array = route_map.pair_path
	var centre := Vector2(pair_item.global_position.x, pair_item.global_position.z)
	if pair_waypoint < path.size() - 1 and centre.distance_to(path[pair_waypoint]) < Balance.BOT_PAIR_ARRIVE:
		pair_waypoint += 1
		pair_progress_at = live_time
	var direction: Vector2 = (path[pair_waypoint] - centre).normalized()
	var handles: Array[Vector2] = []
	for index: int in range(2):
		var point: Vector3 = pair_item.handle_position(index)
		handles.append(Vector2(point.x, point.z))
	var axis: Vector2 = (handles[1] - handles[0]).normalized()
	var half_length: float = handles[0].distance_to(handles[1]) / 2.0
	var front: int = 1 if axis.dot(direction) >= 0.0 else 0
	var turn: float = rad_to_deg(acos(clampf(absf(axis.dot(direction)), 0.0, 1.0)))
	var speed: float = Balance.BOT_PAIR_TURN_SPEED if turn > Balance.BOT_PAIR_TURN_ANGLE else 1.0
	for bot: Bot in bots:
		if bot.mode != "pair" or not pair_item.is_held_by(bot.mover) or bot.phone.slot == InputRouter.selected_slot:
			continue
		var index: int = pair_item.handle_holders.find(bot.mover)
		var place: Vector2 = centre + direction * half_length * (1.0 if index == front else -1.0)
		var stick: Vector2 = direction * speed + (place - handles[index]) * Balance.BOT_PAIR_ALIGN_GAIN
		bot.phone.stick = stick.limit_length(Balance.BOT_PAIR_STICK)
	# Both holders wait together when either has a hazard ahead, so the item is never pulled apart.
	if host.arena.has_method("should_wait"):
		var wait: bool = false
		for bot: Bot in bots:
			if bot.mode == "pair" and pair_item.is_held_by(bot.mover) and host.arena.should_wait(bot.mover.global_position, direction):
				wait = true
		if wait:
			for bot: Bot in bots:
				if bot.mode == "pair" and pair_item.is_held_by(bot.mover) and bot.phone.slot != InputRouter.selected_slot:
					bot.phone.stick = Vector2.ZERO


# --- Walking ---
func _follow_route(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	var on_plank: bool = route_map.get("plank_lanes", false) and host.arena.on_gangplank(mover.global_position)
	if on_plank:
		bot.sidestep_left = 0.0 # A sidestep off a narrow plank is a swim.
	if bot.sidestep_left > 0.0:
		bot.sidestep_left -= delta
		bot.phone.stick = bot.sidestep
		return
	while not bot.route.is_empty():
		var point: Vector3 = bot.route[0]
		var offset := Vector2(point.x - mover.global_position.x, point.z - mover.global_position.z)
		if offset.length() > Balance.BOT_ARRIVE_DISTANCE:
			bot.phone.stick = offset.normalized()
			if on_plank:
				# Two lanes, like a narrow bridge: toward the truck on one side, back on the other.
				var plank: Array = host.arena.layout.gangplank # x, z, width, length.
				var lane_x: float = plank[0] + plank[2] / 2.0 + Balance.BOT_PLANK_LANE * (1.0 if offset.y > 0.0 else -1.0)
				bot.phone.stick.x = clampf(bot.phone.stick.x + (lane_x - mover.global_position.x) * 1.5, -1.0, 1.0)
			else:
				_is_stuck(bot, delta)
			return
		bot.route.pop_front()
		bot.check_at = 0.0
	bot.phone.stick = Vector2.ZERO


func _is_stuck(bot: Bot, delta: float) -> bool:
	# Every second without progress, sidestep one way and then the other.
	bot.check_at += delta
	if bot.check_at < Balance.BOT_STUCK_SECONDS:
		return false
	var moved: float = bot.mover.global_position.distance_to(bot.check_position)
	bot.check_at = 0.0
	bot.check_position = bot.mover.global_position
	if moved > Balance.BOT_STUCK_PROGRESS:
		return false
	bot.stuck_count += 1
	var side: float = 1.0 if bot.stuck_count % 2 == 0 else -1.0
	bot.sidestep = Vector2(-bot.phone.stick.y, bot.phone.stick.x) * side
	if bot.sidestep.is_zero_approx():
		bot.sidestep = Vector2.RIGHT * side
	bot.sidestep_left = Balance.BOT_SIDESTEP_SECONDS
	return true


func _build_route_map() -> void:
	astar.clear()
	node_ids.clear()
	levels.clear()
	for node: String in route_map.nodes:
		var point: Vector3 = route_map.nodes[node]
		node_ids[node] = node_ids.size()
		astar.add_point(node_ids[node], point)
		if not levels.has(point.y):
			levels.append(point.y)
	levels.sort()
	levels.reverse()
	for edge: Array in route_map.edges:
		astar.connect_points(node_ids[edge[0]], node_ids[edge[1]])


func _route_to(from: Vector3, to: Vector3) -> Array[Vector3]:
	# Nearest route point to each end, the shortest path between them, then the destination itself.
	var points: Array[Vector3] = []
	for point: Vector3 in astar.get_point_path(node_ids[_nearest_node(from)], node_ids[_nearest_node(to)]):
		points.append(point)
	points.append(to)
	return points


func _nearest_node(point: Vector3) -> String:
	# The closest route point on the same floor with a clear straight walk to it, else the closest on that floor.
	var level: float = _level(point)
	var best: String = ""
	var best_clear: String = ""
	var best_distance: float = INF
	var best_clear_distance: float = INF
	for node: String in route_map.nodes:
		var at: Vector3 = route_map.nodes[node]
		if not is_equal_approx(at.y, level):
			continue
		var distance: float = Vector2(at.x - point.x, at.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = node
		if distance < best_clear_distance and _clear_line(point, at):
			best_clear_distance = distance
			best_clear = node
	return best_clear if not best_clear.is_empty() else best


func _level(point: Vector3) -> float:
	# Which floor a point is on, snapped so the foot and top of a step land on their own floors. On the Ship it is
	# read in the ship's own frame, so its heave and roll never lift a lower deck onto a higher one.
	var arena: Node3D = host.arena
	var height: float = arena._layout_height(arena.to_ship(point)) if arena.has_method("to_ship") else arena.floor_height_at(point)
	for level: float in levels:
		if height >= level - 0.3:
			return level
	return levels.back()


func _stand_point(item: Node3D) -> Vector3:
	# Where to stop in front of an item: on the line from the nearest route point, a little short of it.
	var at: Vector3 = route_map.nodes[_nearest_node(item.global_position)]
	var toward := Vector3(item.global_position.x - at.x, 0.0, item.global_position.z - at.z)
	if toward.length() <= Balance.BOT_STAND_DISTANCE:
		return at
	var stand: Vector3 = item.global_position - toward.normalized() * Balance.BOT_STAND_DISTANCE
	return Vector3(stand.x, at.y, stand.z)


func _clear_line(from: Vector3, to: Vector3) -> bool:
	# Clear at knee and chest height on the world layer.
	var floor_y: float = _level(to)
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	for height: float in [0.35, 1.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(from.x, floor_y + height, from.z), Vector3(to.x, floor_y + height, to.z), Balance.WORLD_LAYER)
		if not space.intersect_ray(query).is_empty():
			return false
	return true


# --- The ghost bot ---
func _update_ghost(delta: float) -> void:
	var ghost: Node3D = host.ghost
	if not is_instance_valid(ghost):
		return
	ghost_left -= delta
	var free: bool = not is_instance_valid(ghost.possessing)
	if free and ghost_state in ["rest", "hunt"] and _ghost_haunt(ghost):
		return
	match ghost_state:
		"rest":
			var followed: CharacterBody3D = _busiest_mover()
			if followed != null:
				_ghost_fly(ghost, followed.global_position + Balance.BOT_GHOST_HOVER)
			var winning: bool = Game.lost_value * 100 >= Game.starting_value * Balance.BOT_GHOST_BACK_OFF_LOSS
			if ghost_left <= 0.0 and not winning and ghost.energy >= ghost.hauntings[0].cost + Balance.BOT_GHOST_ENERGY_RESERVE:
				# Steal what a mover is walking to; failing that, shove a prop at the busiest mover.
				ghost_victim = null
				ghost_prop = _steal_target()
				if ghost_prop == null and followed != null:
					ghost_prop = _shove_target(followed)
					ghost_victim = followed
				ghost_state = "hunt" if ghost_prop != null else "rest"
				ghost_left = Balance.BOT_GHOST_HUNT_SECONDS if ghost_prop != null else Balance.BOT_GHOST_REST
		"hunt":
			if not is_instance_valid(ghost_prop) or ghost_left <= 0.0 or not ghost_prop.can_be_possessed():
				_ghost_rest()
				return
			_ghost_fly(ghost, ghost_prop.global_position)
			if ghost.target == ghost_prop and ghost.can_toggle_possession():
				ghost_phone.tap("possess")
				ghost_state = "steal" if ghost_victim == null else "shove"
				ghost_left = Balance.BOT_GHOST_STEAL_SECONDS if ghost_victim == null else Balance.BOT_SHOVE_SECONDS
		"shove":
			if free:
				if ghost_left < Balance.BOT_SHOVE_SECONDS - 0.5: # The tap lands a few frames later.
					_ghost_rest()
				return
			# Nudge it toward the victim to aim, then use the prop's action (SHOVE, ROLL and the like).
			var from: Vector3 = ghost.possessing.global_position
			var aim := Vector2(ghost_victim.global_position.x - from.x, ghost_victim.global_position.z - from.z).normalized()
			ghost_phone.stick = aim * 0.3
			if ghost_left <= 0.0 and ghost.can_act():
				ghost_phone.stick = aim
				ghost_phone.tap("action")
				ghost_state = "leaving"
				ghost_left = 1.0
			elif ghost_left <= -Balance.BOT_SHOVE_SECONDS: # The action never came ready.
				ghost_state = "leaving"
				ghost_left = 0.3
		"steal":
			if free:
				if ghost_left < Balance.BOT_GHOST_STEAL_SECONDS - 0.5: # The tap lands a few frames later.
					_ghost_rest()
				return
			# Drag it away from the nearest mover and from the truck.
			var at: Vector3 = ghost.possessing.global_position
			var away := Vector2.ZERO
			var nearest: CharacterBody3D = _nearest_mover(at)
			if nearest != null:
				away = Vector2(at.x - nearest.global_position.x, at.z - nearest.global_position.z).normalized()
			var delivery: Vector3 = route_map.delivery
			away += Vector2(at.x - delivery.x, at.z - delivery.z).normalized() * 0.6
			ghost_phone.stick = away.normalized()
			if ghost_left <= 0.0 or ghost.energy < ghost.hauntings[0].cost:
				ghost_state = "leaving"
				ghost_left = 0.3
		"leaving":
			ghost_phone.stick = Vector2.ZERO
			if ghost_left <= 0.0:
				if not free:
					ghost_phone.tap("possess")
				_ghost_rest()


func _ghost_haunt(ghost: Node3D) -> bool:
	# The arena's haunting while movers are busy, and curses on carried loot; true while one is being lined up.
	var followed: CharacterBody3D = _busiest_mover()
	if live_time >= haunt_at and ghost.can_haunt(0) and followed != null:
		_ghost_fly(ghost, followed.global_position + Balance.BOT_GHOST_HOVER)
		ghost_phone.tap("haunt1")
		haunt_at = live_time + Balance.BOT_GHOST_HAUNT_GAP
		return true
	if live_time >= curse_at and ghost.energy >= Balance.CURSE_COST and ghost.curse_cooldown_left <= 0.0:
		var carrier: CharacterBody3D = _carrier()
		if carrier == null:
			return false
		_ghost_fly(ghost, carrier.held_item.global_position)
		if ghost.can_curse() and ghost.curse_target == carrier.held_item:
			ghost_phone.tap("haunt3")
			curse_at = live_time + Balance.BOT_GHOST_CURSE_GAP
		return true
	return false


func _steal_target() -> Node:
	# The possessable part of an item a mover bot is walking to, while that mover is still a few metres away.
	for bot: Bot in bots:
		if bot.mode != "fetch" or not is_instance_valid(bot.item) or bot.item.is_held() or bot.item == pair_item:
			continue
		if bot.mover.global_position.distance_to(bot.item.global_position) < Balance.BOT_GHOST_STEAL_DISTANCE:
			continue
		for node: Node in get_tree().get_nodes_in_group("possessables"):
			if node.prop == bot.item and node.can_be_possessed():
				return node
	return null


func _shove_target(victim: CharacterBody3D) -> Node:
	# The free prop nearest the mover, within reach; never the two-person item or anything being carried.
	var best: Node = null
	var best_distance: float = Balance.BOT_SHOVE_REACH
	for node: Node in get_tree().get_nodes_in_group("possessables"):
		if node.prop == pair_item or not node.can_be_possessed() or (node.prop is Carryable and node.prop.is_held()):
			continue
		var distance: float = node.global_position.distance_to(victim.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func _ghost_rest() -> void:
	ghost_state = "rest"
	ghost_left = Balance.BOT_GHOST_REST
	ghost_prop = null
	if ghost_phone != null:
		ghost_phone.stick = Vector2.ZERO


func _ghost_fly(ghost: Node3D, target: Vector3) -> void:
	var offset := Vector2(target.x - ghost.global_position.x, target.z - ghost.global_position.z)
	ghost_phone.stick = offset.normalized() * clampf(offset.length() / 1.5, 0.0, 1.0) if offset.length() > 0.2 else Vector2.ZERO


# --- Round queries ---
func _movers_in_play() -> Array[CharacterBody3D]:
	var movers: Array[CharacterBody3D] = []
	for mover: CharacterBody3D in host.movers:
		if mover.in_play and not host.is_ghost_slot(mover.slot):
			movers.append(mover)
	return movers


func _busiest_mover() -> CharacterBody3D:
	var carrier: CharacterBody3D = _carrier()
	if carrier != null:
		return carrier
	var movers: Array[CharacterBody3D] = _movers_in_play()
	return movers[0] if not movers.is_empty() else null


func _carrier() -> CharacterBody3D:
	# A mover carrying loot that isn't cursed yet, the keyboard's mover included.
	for mover: CharacterBody3D in _movers_in_play():
		var held: Variant = mover.held_item
		if is_instance_valid(held) and held != pair_item and "curse_left" in held and held.curse_left <= 0.0:
			return mover
	return null


func _nearest_mover(point: Vector3) -> CharacterBody3D:
	var best: CharacterBody3D = null
	for mover: CharacterBody3D in _movers_in_play():
		if best == null or mover.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = mover
	return best


func _claimed(item: Node3D, asking: Bot) -> bool:
	for bot: Bot in bots:
		if bot != asking and bot.mode in ["fetch", "carry"] and bot.item == item:
			return true
	return false


func _delivered(item: Node3D) -> bool:
	return host.arena.truck.contains_point(item.global_position)
