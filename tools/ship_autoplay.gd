# Plays one scripted Ghost Ship round for a recording: three phones join (Tanish, then Atharv and Aditya), the
# match starts on the Ship, and bots play it out. Nothing in the game is faked: simulated phones connect to the real
# WebSocket port and send the same messages a phone does.
# The movers carry the treasure chest together down the forecastle steps and over the gangplank, then fetch the
# rest. They brace for gusts and waves, except Aditya, who is caught by the first wave on the plank. The ghost
# blows a gust, bowls rum barrels at the movers with ROLL and curses carried loot.
# Run (with a window, for recording):  godot --path . --script res://tools/ship_autoplay.gd
# Quick test without pauses:  godot --headless --path . --script res://tools/ship_autoplay.gd -- --test
# Another round's loot and timing: add  -- --seed=<number>  (default ROUND_SEED, a round checked to play well).
extends SceneTree

# --- Settings ---
const SETTINGS := preload("res://autoload/Balance.gd") # Autoloads are looked up at run time; this compiles first.
const DEMO := preload("res://tools/demo_autoplay.gd") # Reuses its simulated phone.
const PLAYER_NAMES: Array[String] = ["Tanish", "Atharv", "Aditya"] # The first to join is round 1's ghost.
const WASHED_PLAYER: String = "Aditya" # Misses the first wave's warning on the plank.
const SHIP_SCENE: String = "res://arenas/Ship.tscn"
const MATCH_SCENE: String = "res://Main.tscn"
const STEP_PAUSE: float = 2.5
const JOIN_GAP: float = 3.0
const RESULT_HOLD: float = 10.0
const INPUT_INTERVAL: int = 2 # Physics frames between joystick messages (30 a second at 60 Hz).
const ROUND_SEED: int = 3 # Seeds the match's random picks, so the recorded round is one that was checked.

# --- Bot tuning ---
const ARRIVE_DISTANCE: float = 0.45
const CARRY_STICK: float = 0.5
const CHEST_STICK: float = 0.55
const SNAG_DISTANCE: float = 0.45
const STAND_DISTANCE: float = 1.1
const GRAB_REACH: float = 1.6
const STUCK_SECONDS: float = 1.0
const STUCK_PROGRESS: float = 0.15
const SIDESTEP_SECONDS: float = 0.45
const MAX_STUCK: int = 4
const GIVE_UP_SECONDS: float = 12.0
const PLANK_LANE_OFFSET: float = 0.55 # Metres either side of the plank's centre line.
const DELIVERY_POINT := Vector3(12.0, 0.0, 17.4) # On the tug; held loot ahead lands in the amber area.

# --- The chest: two movers, one per handle, down the front forecastle steps and over the plank ---
const CHEST_ALIGN_GAIN: float = 1.4
const CHEST_TURN_ANGLE: float = 25.0
const CHEST_TURN_SPEED: float = 0.15
const CHEST_ARRIVE: float = 0.6
const CHEST_PATH: Array[Vector2] = [Vector2(19.6, 8.9), Vector2(12.0, 8.9), Vector2(12.0, 11.3), Vector2(12.0, 18.0)]
const CHEST_STANDS: Array[Vector3] = [Vector3(21.7, 0.7, 8.8), Vector3(25.4, 0.7, 8.2)] # West and east ends.

# --- Ghost tuning ---
const GUST_TIMES: Array[float] = [14.0, 58.0, 104.0] # Seconds into the live round.
const ROLL_TIMES: Array[float] = [32.0, 78.0, 120.0]
const CURSE_TIMES: Array[float] = [45.0, 92.0]
const ROLL_REACH: float = 9.0 # Metres: only bowl at a mover this close to the barrel.
const ROLL_HUNT_SECONDS: float = 7.0
const GHOST_HOVER_OFFSET := Vector3(1.8, 0.0, -1.8)

# --- Route map of the Ghost Ship (decision 107): name -> point on the floor. The front forecastle steps lead
# only to the chest's west end; the rest of the forecastle is reached up the back steps. ---
const NODES: Dictionary = {
	"q_back": Vector3(3.5, 1.2, 2.6), "q_mid": Vector3(4.6, 1.2, 6.0), "q_front": Vector3(3.5, 1.2, 9.4),
	"sb_top": Vector3(5.6, 1.2, 2.55), "sb_foot": Vector3(10.4, 0.0, 2.55),
	"sf_top": Vector3(5.6, 1.2, 9.45), "sf_foot": Vector3(10.4, 0.0, 9.45),
	"m_back_w": Vector3(11.2, 0.0, 3.4), "m_back_e": Vector3(17.6, 0.0, 2.8), "m_centre": Vector3(13.2, 0.0, 5.0),
	"m_east": Vector3(17.8, 0.0, 4.2), "m_port": Vector3(12.0, 0.0, 9.2), "m_front_e": Vector3(14.5, 0.0, 9.6),
	"fb_foot": Vector3(18.0, 0.0, 2.8), "fb_top": Vector3(21.2, 0.7, 2.8),
	"ff_foot": Vector3(18.0, 0.0, 9.1), "ff_top": Vector3(21.2, 0.7, 9.1),
	"f_back": Vector3(24.4, 0.7, 3.0), "f_mid": Vector3(24.6, 0.7, 6.2), "f_bow": Vector3(25.6, 0.7, 7.6),
	"p_port": Vector3(12.0, 0.0, 11.3), "p_mid": Vector3(12.0, 0.0, 14.0), "tug": Vector3(12.0, 0.0, 17.0),
}
const EDGES: Array[Array] = [
	["q_back", "q_mid"], ["q_mid", "q_front"], ["q_back", "sb_top"], ["sb_top", "sb_foot"], ["q_front", "sf_top"],
	["sf_top", "sf_foot"], ["sb_foot", "m_back_w"], ["m_back_w", "m_centre"], ["m_back_w", "m_back_e"],
	["m_centre", "m_east"], ["m_centre", "m_port"], ["m_east", "m_back_e"], ["sf_foot", "m_port"],
	["m_port", "m_front_e"], ["m_front_e", "ff_foot"], ["m_back_e", "fb_foot"], ["ff_foot", "ff_top"],
	["fb_foot", "fb_top"], ["fb_top", "f_back"], ["f_back", "f_mid"], ["f_mid", "f_bow"],
	["m_port", "p_port"], ["p_port", "p_mid"], ["p_mid", "tug"],
]

# --- A mover bot's state ---
class Bot:
	var phone: DEMO.Phone
	var mover: CharacterBody3D
	var mode: String = "idle" # idle, fetch, carry, chest
	var item: Node3D
	var route: Array[Vector3] = []
	var check_at: float = 0.0
	var check_position := Vector3.ZERO
	var stuck_count: int = 0
	var sidestep_left: float = 0.0
	var sidestep := Vector2.ZERO
	var give_up: Dictionary = {}
	var chest_end: int = -1

# --- Run state ---
var game: Node
var net: Node
var test_mode: bool = false
var phones: Array[DEMO.Phone] = []
var bots: Array[Bot] = []
var ghost_phone: DEMO.Phone
var astar := AStar3D.new()
var node_ids: Dictionary = {}
var frame: int = 0
var live_time: float = 0.0
var running_bots: bool = false
var chest: RigidBody3D
var chest_waypoint: int = 0
var chest_done: bool = false
var waves_seen: int = 0
var was_warning: bool = false
var log_left: float = 0.0
var ghost_state: String = "rest" # rest, hunt, bowl, leaving
var ghost_left: float = 0.0
var ghost_prop: Node3D # The barrel's possessable component.
var ghost_victim: CharacterBody3D
var gust_index: int = 0
var roll_index: int = 0
var curse_index: int = 0

# --- Setup ---
func _initialize() -> void:
	test_mode = "--test" in OS.get_cmdline_user_args()
	for node: String in NODES:
		node_ids[node] = node_ids.size()
		astar.add_point(node_ids[node], NODES[node])
	for edge: Array in EDGES:
		astar.connect_points(node_ids[edge[0]], node_ids[edge[1]])
	physics_frame.connect(_tick)
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	if not test_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("Ship autoplay: loading the Ghost Ship")
	game.selected_arena = SHIP_SCENE
	change_scene_to_file(MATCH_SCENE)
	while not is_instance_valid(game.host) or game.phase != "lobby":
		await process_frame
	await _seconds(STEP_PAUSE if not test_mode else 0.5)
	for player_name: String in PLAYER_NAMES:
		await _join(player_name)
		await _seconds(JOIN_GAP if not test_mode else 0.3)
	await _seconds(STEP_PAUSE if not test_mode else 0.5)
	print("Ship autoplay: starting the match")
	var round_seed: int = ROUND_SEED
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			round_seed = int(argument.trim_prefix("--seed="))
	seed(round_seed) # The match draws its loot seed from the global generator.
	_press_key(KEY_ENTER)
	while game.phase != "live":
		await process_frame
	_start_bots()
	while game.phase == "live":
		await process_frame
	running_bots = false
	for phone: DEMO.Phone in phones:
		phone.stick = Vector2.ZERO
		for button: String in phone.buttons:
			phone.buttons[button] = false
	print("Ship autoplay: round over. Movers won: %s. Banked ₹%d of ₹%d" % [game.result.get("moversWon"), game.result.get("banked", 0), game.result.get("starting", 0)])
	await _seconds(RESULT_HOLD if not test_mode else 2.0)
	quit()


func _join(player_name: String) -> void:
	var phone := DEMO.Phone.new()
	phone.name = player_name
	phone.socket.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	phones.append(phone)
	while phone.socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		await process_frame
	phone.send({"type": "hello", "name": player_name, "key": net.session_key})
	while phone.slot < 0:
		await process_frame
	await _seconds(0.8 if not test_mode else 0.2)
	phone.send({"type": "ready"})
	print("Ship autoplay: %s joined as player %d" % [player_name, phone.slot + 1])


func _start_bots() -> void:
	for phone: DEMO.Phone in phones:
		if phone.slot == game.ghost_slot:
			ghost_phone = phone
			continue
		var bot := Bot.new()
		bot.phone = phone
		bot.mover = game.host.movers[phone.slot]
		bots.append(bot)
	for item: Node in get_nodes_in_group("loot"):
		if item.weight_class == SETTINGS.TWO_PERSON:
			chest = item
	if chest != null and bots.size() >= 2:
		for index: int in range(2):
			bots[index].mode = "chest"
			# Each bot takes the handle at its own stand's end of the chest.
			var near: float = CHEST_STANDS[index].distance_to(chest.handle_position(0))
			bots[index].chest_end = 0 if near < CHEST_STANDS[index].distance_to(chest.handle_position(1)) else 1
			bots[index].route = _route_to(bots[index].mover.global_position, CHEST_STANDS[index])
	live_time = 0.0
	running_bots = true
	print("Ship autoplay: the round is live. Ghost: %s" % (ghost_phone.name if ghost_phone != null else "none"))


# --- Every physics frame ---
func _tick() -> void:
	frame += 1
	for phone: DEMO.Phone in phones:
		phone.poll()
	if running_bots and game.phase == "live":
		var delta: float = 1.0 / Engine.physics_ticks_per_second
		live_time += delta
		_count_waves()
		_steer_chest()
		for bot: Bot in bots:
			_update_bot(bot, delta)
		_update_ghost(delta)
		_log_progress(delta)
	_send_inputs()


func _send_inputs() -> void:
	for phone: DEMO.Phone in phones:
		if phone.slot < 0:
			continue
		for button: String in phone.tap_frames.keys():
			phone.tap_frames[button] -= 1
			if phone.tap_frames[button] <= 0:
				phone.tap_frames.erase(button)
				phone.buttons[button] = false
		if frame % INPUT_INTERVAL == 0:
			phone.send({"type": "in", "x": phone.stick.x, "y": phone.stick.y})
		for button: String in phone.buttons:
			if phone.sent_buttons.get(button, false) != phone.buttons[button]:
				phone.sent_buttons[button] = phone.buttons[button]
				phone.send({"type": "btn", "b": button, "down": phone.buttons[button]})


# --- Mover bots ---
func _update_bot(bot: Bot, delta: float) -> void:
	var phone: DEMO.Phone = bot.phone
	# Brace through a gust; on the plank, brace for a wave (Aditya misses the first one's warning).
	var arena: Node3D = game.host.arena
	var wave_coming: bool = arena.wave_warning_left >= 0.0 and arena.on_gangplank(bot.mover.global_position)
	var caught: bool = wave_coming and phone.name == WASHED_PLAYER and waves_seen <= 1 and bot.mode != "chest"
	# The two chest carriers brace together; one pushing while the other holds stretches the chest out of a grip.
	var partner_braces: bool = bot.mode == "chest" and _chest_wave_coming()
	if (_gust_active() or wave_coming or partner_braces) and not caught:
		phone.stick = Vector2.ZERO
		phone.buttons["brace"] = true
		return
	phone.buttons["brace"] = false
	match bot.mode:
		"chest":
			_bot_chest(bot, delta)
		"idle":
			phone.stick = Vector2.ZERO
			phone.buttons["grab"] = false
			_choose_item(bot)
		"fetch":
			_bot_fetch(bot, delta)
		"carry":
			_bot_carry(bot, delta)
	if bot.mode != "chest" and is_instance_valid(bot.mover.held_item) and bot.mover.held_item == chest:
		phone.buttons["grab"] = false # Nobody drags the chest alone.


func _chest_wave_coming() -> bool:
	if game.host.arena.wave_warning_left < 0.0:
		return false
	for other: Bot in bots:
		if other.mode == "chest" and game.host.arena.on_gangplank(other.mover.global_position):
			return true
	return false


func _count_waves() -> void:
	var warning: bool = game.host.arena.wave_warning_left >= 0.0
	if warning and not was_warning:
		waves_seen += 1
		print("Ship autoplay: wave %d is coming" % waves_seen)
	was_warning = warning


func _choose_item(bot: Bot) -> void:
	var best: Node3D
	var best_score: float = 0.0
	for item: Node in get_nodes_in_group("loot"):
		if item == chest or item.finished or item.is_held() or item.haunted or _in_tug(item):
			continue
		if bot.give_up.get(item, -1.0) > live_time or _claimed(item, bot):
			continue
		var trip: float = bot.mover.global_position.distance_to(item.global_position) + item.global_position.distance_to(DELIVERY_POINT)
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
	print("Ship autoplay: %s goes for the %s (₹%d)" % [bot.phone.name, best.item_name, best.value])


func _bot_fetch(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	var item: Node3D = bot.item
	if not is_instance_valid(item) or item.finished or (item.is_held() and not item.is_held_by(mover)):
		bot.mode = "idle"
		return
	if is_instance_valid(mover.held_item):
		if mover.held_item != chest:
			bot.item = mover.held_item
			_start_carry(bot)
		return
	if item.haunted:
		_give_up(bot, 4.0)
		return
	var to_item: Vector3 = item.global_position - mover.global_position
	var flat := Vector2(to_item.x, to_item.z)
	if not bot.route.is_empty() and flat.length() > STAND_DISTANCE:
		_follow_route(bot, delta)
		return
	bot.route.clear()
	var facing_ok: bool = Vector2(mover.facing.x, mover.facing.z).dot(flat.normalized()) > 0.85
	if to_item.length() <= GRAB_REACH and facing_ok:
		bot.phone.stick = Vector2.ZERO
		bot.phone.buttons["grab"] = true
		return
	bot.phone.buttons["grab"] = false
	bot.phone.stick = flat.normalized() * (0.35 if flat.length() < STAND_DISTANCE else 1.0)
	if _is_stuck(bot, delta) and bot.stuck_count > MAX_STUCK:
		_give_up(bot, GIVE_UP_SECONDS)


func _start_carry(bot: Bot) -> void:
	bot.mode = "carry"
	bot.stuck_count = 0
	bot.route = _route_to(bot.mover.global_position, DELIVERY_POINT)
	print("Ship autoplay: %s carries the %s to the tug" % [bot.phone.name, bot.item.item_name])


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
	if game.host.arena.truck.contains_point(bot.item.global_position):
		bot.phone.stick = Vector2.ZERO
		bot.phone.buttons["grab"] = false
		bot.mode = "idle"
		return
	if bot.route.is_empty():
		bot.route = [DELIVERY_POINT]
	if bot.item.global_position.distance_to(bot.item.carry_target()) > SNAG_DISTANCE and bot.sidestep_left <= 0.0:
		bot.phone.stick = Vector2.ZERO
		_is_stuck(bot, delta)
		return
	_follow_route(bot, delta)
	bot.phone.stick = bot.phone.stick.limit_length(CARRY_STICK)


func _give_up(bot: Bot, seconds: float) -> void:
	if is_instance_valid(bot.item):
		bot.give_up[bot.item] = live_time + seconds
	bot.phone.buttons["grab"] = false
	bot.mode = "idle"


# --- The chest ---
func _bot_chest(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	if not is_instance_valid(chest) or chest.finished:
		bot.phone.buttons["grab"] = false
		bot.mode = "idle"
		return
	if chest_done:
		bot.phone.buttons["grab"] = false
		bot.phone.stick = Vector2.ZERO
		if chest.holder_count() == 0:
			bot.mode = "idle"
		return
	if chest.is_held_by(mover):
		bot.phone.buttons["grab"] = true
		if chest.holder_count() < 2:
			bot.phone.stick = Vector2.ZERO # Wait for the partner before moving off.
		return
	if not bot.route.is_empty():
		bot.phone.buttons["grab"] = false
		_follow_route(bot, delta)
		return
	if chest.holder_count() > 0:
		bot.chest_end = 1 - chest.handle_holders.find(_chest_partner(bot).mover) if chest.is_held_by(_chest_partner(bot).mover) else bot.chest_end
	var handle: Vector3 = chest.handle_position(bot.chest_end)
	var to_handle := Vector2(handle.x - mover.global_position.x, handle.z - mover.global_position.z)
	var facing_ok: bool = Vector2(mover.facing.x, mover.facing.z).dot(to_handle.normalized()) > 0.85
	if to_handle.length() < GRAB_REACH and facing_ok:
		bot.phone.stick = Vector2.ZERO
		bot.phone.buttons["grab"] = true
	else:
		bot.phone.buttons["grab"] = false
		bot.phone.stick = to_handle.normalized() * (0.35 if to_handle.length() < 1.3 else 1.0)


func _chest_partner(bot: Bot) -> Bot:
	for other: Bot in bots:
		if other != bot and other.mode == "chest":
			return other
	return bot


func _steer_chest() -> void:
	# Both holders push along the path and pull their own handle onto the path line, so the chest turns to follow
	# it; at the turn onto the plank it slows to swing round first.
	if not is_instance_valid(chest) or chest.finished or chest.holder_count() < 2:
		return
	var centre := Vector2(chest.global_position.x, chest.global_position.z)
	if game.host.arena.truck.contains_point(chest.global_position):
		chest_done = true
		print("Ship autoplay: the chest is on the tug")
		return
	if chest_waypoint < CHEST_PATH.size() - 1 and centre.distance_to(CHEST_PATH[chest_waypoint]) < CHEST_ARRIVE:
		chest_waypoint += 1
	var direction: Vector2 = (CHEST_PATH[chest_waypoint] - centre).normalized()
	var handles: Array[Vector2] = []
	for index: int in range(2):
		var point: Vector3 = chest.handle_position(index)
		handles.append(Vector2(point.x, point.z))
	var axis: Vector2 = (handles[1] - handles[0]).normalized()
	var half_length: float = handles[0].distance_to(handles[1]) / 2.0
	var front: int = 1 if axis.dot(direction) >= 0.0 else 0
	var turn: float = rad_to_deg(acos(clampf(absf(axis.dot(direction)), 0.0, 1.0)))
	var speed: float = CHEST_TURN_SPEED if turn > CHEST_TURN_ANGLE else 1.0
	for bot: Bot in bots:
		if bot.mode != "chest" or not chest.is_held_by(bot.mover):
			continue
		var index: int = chest.handle_holders.find(bot.mover)
		var place: Vector2 = centre + direction * half_length * (1.0 if index == front else -1.0)
		var stick: Vector2 = direction * speed + (place - handles[index]) * CHEST_ALIGN_GAIN
		bot.phone.stick = stick.limit_length(CHEST_STICK)


# --- Walking ---
func _follow_route(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	var on_plank: bool = game.host.arena.on_gangplank(mover.global_position)
	if on_plank:
		bot.sidestep_left = 0.0 # A sidestep off a 2.2 m plank is a swim.
	if bot.sidestep_left > 0.0:
		bot.sidestep_left -= delta
		bot.phone.stick = bot.sidestep
		return
	while not bot.route.is_empty():
		var point: Vector3 = bot.route[0]
		var offset := Vector2(point.x - mover.global_position.x, point.z - mover.global_position.z)
		if offset.length() > ARRIVE_DISTANCE:
			bot.phone.stick = offset.normalized()
			if on_plank:
				# Two lanes, like a narrow bridge: toward the tug on one side, back to the ship on the other, so
				# movers crossing the plank pass instead of meeting nose to nose, and nobody drifts off an edge.
				var plank: Array = game.host.arena.layout.gangplank # x, z, width, length; ArenaBuilder can't load before the autoloads.
				var lane_x: float = plank[0] + plank[2] / 2.0 + PLANK_LANE_OFFSET * (1.0 if offset.y > 0.0 else -1.0)
				bot.phone.stick.x = clampf(bot.phone.stick.x + (lane_x - mover.global_position.x) * 1.5, -1.0, 1.0)
			else:
				_is_stuck(bot, delta)
			return
		bot.route.pop_front()
		bot.check_at = 0.0
	bot.phone.stick = Vector2.ZERO


func _is_stuck(bot: Bot, delta: float) -> bool:
	bot.check_at += delta
	if bot.check_at < STUCK_SECONDS:
		return false
	var moved: float = bot.mover.global_position.distance_to(bot.check_position)
	bot.check_at = 0.0
	bot.check_position = bot.mover.global_position
	if moved > STUCK_PROGRESS:
		return false
	bot.stuck_count += 1
	var side: float = 1.0 if bot.stuck_count % 2 == 0 else -1.0
	bot.sidestep = Vector2(-bot.phone.stick.y, bot.phone.stick.x) * side
	if bot.sidestep.is_zero_approx():
		bot.sidestep = Vector2.RIGHT * side
	bot.sidestep_left = SIDESTEP_SECONDS
	return true


func _route_to(from: Vector3, to: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point: Vector3 in astar.get_point_path(node_ids[_nearest_node(from)], node_ids[_nearest_node(to)]):
		points.append(point)
	points.append(to)
	return points


func _nearest_node(point: Vector3) -> String:
	# The closest node on the same deck with a clear straight walk to it, else the closest on that deck.
	var level: float = _deck(point)
	var best: String = ""
	var best_clear: String = ""
	var best_distance: float = INF
	var best_clear_distance: float = INF
	for node: String in NODES:
		var at: Vector3 = NODES[node]
		if not is_equal_approx(_deck(at), level):
			continue
		var distance: float = Vector2(at.x - point.x, at.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = node
		if distance < best_clear_distance and _clear_line(point, at):
			best_clear_distance = distance
			best_clear = node
	return best_clear if not best_clear.is_empty() else best


func _deck(point: Vector3) -> float:
	# Which deck a point is on, snapped so the foot and top of a step land on their own decks.
	var height: float = game.host.arena.floor_height_at(point)
	for level: float in [SETTINGS.LANTERN_POST_SPOTS[2].y, 0.7, 0.0]:
		if height >= level - 0.3:
			return level
	return 0.0


func _stand_point(item: Node3D) -> Vector3:
	var at: Vector3 = NODES[_nearest_node(item.global_position)]
	var toward := Vector3(item.global_position.x - at.x, 0.0, item.global_position.z - at.z)
	if toward.length() <= STAND_DISTANCE:
		return at
	var stand: Vector3 = item.global_position - toward.normalized() * STAND_DISTANCE
	return Vector3(stand.x, at.y, stand.z)


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var floor_y: float = _deck(to)
	var space: PhysicsDirectSpaceState3D = game.host.get_world_3d().direct_space_state
	for height: float in [0.35, 1.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(from.x, floor_y + height, from.z), Vector3(to.x, floor_y + height, to.z), SETTINGS.WORLD_LAYER)
		if not space.intersect_ray(query).is_empty():
			return false
	return true


# --- The ghost bot ---
func _update_ghost(delta: float) -> void:
	# Gusts at set times, rum barrels bowled at whoever is close, and curses on carried loot.
	var ghost: Node3D = game.host.ghost
	if ghost_phone == null or not is_instance_valid(ghost):
		return
	ghost_left -= delta
	var free: bool = not is_instance_valid(ghost.possessing)
	if free and ghost_state == "rest" and _ghost_timed(ghost):
		return
	match ghost_state:
		"rest":
			_ghost_fly(ghost, _busiest_mover().global_position + GHOST_HOVER_OFFSET)
		"hunt":
			if not is_instance_valid(ghost_prop) or ghost_left <= 0.0 or not ghost_prop.can_be_possessed():
				_ghost_rest()
				return
			_ghost_fly(ghost, ghost_prop.global_position)
			if ghost.target == ghost_prop and ghost.can_toggle_possession():
				ghost_phone.tap("possess")
				ghost_state = "bowl"
				ghost_left = 0.8
		"bowl":
			if free:
				if ghost_left < 0.2: # The tap is handled a few frames later; only give up if it never took.
					_ghost_rest()
				return
			# Aim at the victim, then ROLL.
			var at: Vector3 = ghost.possessing.global_position
			var aim := Vector2(ghost_victim.global_position.x - at.x, ghost_victim.global_position.z - at.z).normalized()
			ghost_phone.stick = aim * 0.2 # A nudge sets the direction without sliding it far.
			if ghost_left <= 0.0 and ghost.can_act():
				ghost_phone.stick = aim
				ghost_phone.tap("action")
				print("Ship autoplay: the ghost bowls a rum barrel at %s" % _name_of(ghost_victim))
				ghost_state = "leaving"
				ghost_left = 1.2
		"leaving":
			ghost_phone.stick = Vector2.ZERO
			if ghost_left <= 0.0:
				if not free:
					ghost_phone.tap("possess")
				_ghost_rest()


func _ghost_timed(ghost: Node3D) -> bool:
	if gust_index < GUST_TIMES.size() and live_time >= GUST_TIMES[gust_index]:
		_ghost_fly(ghost, _busiest_mover().global_position + GHOST_HOVER_OFFSET)
		if ghost.can_haunt(0):
			ghost_phone.stick = Vector2(0, 1) # Blow toward the plank side, where the wind does the most harm.
			ghost_phone.tap("haunt1")
			gust_index += 1
			print("Ship autoplay: the ghost calls a gust")
		return true
	if roll_index < ROLL_TIMES.size() and live_time >= ROLL_TIMES[roll_index]:
		roll_index += 1
		var pick: Array = _barrel_shot()
		if pick.is_empty():
			return false
		ghost_prop = pick[0]
		ghost_victim = pick[1]
		ghost_state = "hunt"
		ghost_left = ROLL_HUNT_SECONDS
		print("Ship autoplay: the ghost goes for a rum barrel")
		return true
	if curse_index < CURSE_TIMES.size() and live_time >= CURSE_TIMES[curse_index]:
		var carrier: CharacterBody3D = _carrier()
		if carrier == null:
			return false
		_ghost_fly(ghost, carrier.held_item.global_position)
		if ghost.can_curse() and ghost.curse_target == carrier.held_item:
			ghost_phone.tap("haunt3")
			curse_index += 1
			print("Ship autoplay: the ghost curses the %s" % carrier.held_item.item_name)
		return true
	return false


func _barrel_shot() -> Array:
	# A loose rum barrel within reach of a mover: [its possessable, the mover].
	var best: Array = []
	var best_distance: float = ROLL_REACH
	for node: Node in get_nodes_in_group("possessables"):
		var prop: Node = node.prop
		if not node.can_be_possessed() or not ("catalog_item" in prop and prop.catalog_item != null and prop.catalog_item.rolls):
			continue
		for bot: Bot in bots:
			var distance: float = node.global_position.distance_to(bot.mover.global_position)
			if distance < best_distance:
				best_distance = distance
				best = [node, bot.mover]
	return best


func _ghost_rest() -> void:
	ghost_state = "rest"
	ghost_left = 0.0
	ghost_prop = null
	ghost_phone.stick = Vector2.ZERO


func _ghost_fly(ghost: Node3D, target: Vector3) -> void:
	var offset := Vector2(target.x - ghost.global_position.x, target.z - ghost.global_position.z)
	ghost_phone.stick = offset.normalized() * clampf(offset.length() / 1.5, 0.0, 1.0) if offset.length() > 0.2 else Vector2.ZERO


# --- Round queries ---
func _gust_active() -> bool:
	var ghost: Node3D = game.host.ghost
	return is_instance_valid(ghost) and not ghost.hauntings.is_empty() and ghost.hauntings[0].is_active()


func _busiest_mover() -> CharacterBody3D:
	var carrier: CharacterBody3D = _carrier()
	return carrier if carrier != null else bots[0].mover


func _carrier() -> CharacterBody3D:
	for bot: Bot in bots:
		var held: Variant = bot.mover.held_item
		if is_instance_valid(held) and held != chest and "curse_left" in held and held.curse_left <= 0.0:
			return bot.mover
	return null


func _claimed(item: Node3D, asking: Bot) -> bool:
	for bot: Bot in bots:
		if bot != asking and bot.mode in ["fetch", "carry"] and bot.item == item:
			return true
	return false


func _in_tug(item: Node3D) -> bool:
	return game.host.arena.truck.contains_point(item.global_position)


func _name_of(mover: CharacterBody3D) -> String:
	for bot: Bot in bots:
		if bot.mover == mover:
			return bot.phone.name
	return "a mover"


func _log_progress(delta: float) -> void:
	log_left -= delta
	if log_left > 0.0:
		return
	log_left = 3.0
	var line: String = "Ship autoplay %.0fs: banked ₹%d of ₹%d |" % [live_time, game.banked_value, game.starting_value]
	if is_instance_valid(chest) and not chest.finished:
		line += " chest holders %d wp %d ₹%d |" % [chest.holder_count(), chest_waypoint, chest.value]
	for bot: Bot in bots:
		line += " %s %s at (%.1f, %.1f, %.1f) route %d |" % [bot.phone.name, bot.mode, bot.mover.global_position.x, bot.mover.global_position.y, bot.mover.global_position.z, bot.route.size()]
	line += " ghost %s" % ghost_state
	print(line)


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
