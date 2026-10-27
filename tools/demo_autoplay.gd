# Plays one scripted round for a recording or an attract loop: the home menu, the guide, Play, the map select,
# four phones joining one by one, the intro, and a full Old Mansion round that the movers win.
# Nothing in the game is faked: simulated phones connect to the real WebSocket port and send the same messages a
# phone does. Bots steer the three movers along a hand-placed route map of the Mansion (two carry the piano while
# the third fetches the most valuable loot) and play a ghost with a readable plan: it steals the item a mover is
# walking to, shakes the house and curses carried loot. Most movers brace when a shake warns them; one is caught out.
# Run (with a window, for recording):  godot --path . --script res://tools/demo_autoplay.gd
# Quick test without pauses or the intro:  godot --headless --path . --script res://tools/demo_autoplay.gd -- --test
extends SceneTree

# --- Settings ---
const SETTINGS := preload("res://autoload/Balance.gd") # Autoloads are looked up at run time; this compiles first.
const PLAYER_NAMES: Array[String] = ["Ggs", "Aditya", "Atharv", "Tanish"] # The first to join is round 1's ghost.
const MAIN_MENU_SCENE: String = "res://menus/main_menu/main_menu.tscn"
const MATCH_SCENE: String = "res://Main.tscn"
const STEP_PAUSE: float = 2.5 # Seconds between menu steps, so the recording is easy to follow.
const GUIDE_SECONDS: float = 5.0
const JOIN_GAP: float = 3.0 # Seconds between phones joining.
const RESULT_HOLD: float = 10.0 # Seconds on the result screen before quitting.
const INPUT_INTERVAL: int = 2 # Physics frames between joystick messages (30 a second at 60 Hz).
const BUTTON_TAP_FRAMES: int = 4 # Physics frames a tapped ghost button stays down.

# --- Bot tuning ---
const ARRIVE_DISTANCE: float = 0.45 # Metres from a waypoint that counts as reached.
const CARRY_STICK: float = 0.5 # Stick tilt while carrying: slow enough that a snag stays under the damage speed.
const PIANO_STICK: float = 0.55 # Top stick for the piano holders.
const SNAG_DISTANCE: float = 0.45 # Metres a carried item may lag its carry point before the bot stops to let it settle.
const STAND_DISTANCE: float = 1.1 # Metres from an item where a mover stops to grab it.
const GRAB_REACH: float = 1.6 # Metres (3D) within which a mover tries GRAB.
const STUCK_SECONDS: float = 1.0 # Seconds of almost no progress before sidestepping.
const STUCK_PROGRESS: float = 0.15 # Metres that count as progress.
const SIDESTEP_SECONDS: float = 0.45
const MAX_STUCK: int = 4 # Sidesteps before a bot gives up on its current item for a while.
const GIVE_UP_SECONDS: float = 12.0
const DELIVERY_POINT := Vector3(7.75, 0.0, 22.6) # On the driveway at the tailgate; held loot ahead is in the zone.
const GALLERY_EDGE_Z: float = 6.0 # North of this is the gallery (floor 1.2).
const LEVEL_HEIGHT: float = 1.2

# --- Piano tuning ---
const PIANO_ALIGN_GAIN: float = 1.4 # Stick per metre a handle is off its place on the route line.
const PIANO_TURN_ANGLE: float = 25.0 # Degrees off the route at which the piano slows to turn.
const PIANO_TURN_SPEED: float = 0.15 # Share of full stick while turning.
const PIANO_ARRIVE: float = 0.7
const PIANO_PATH: Array[Vector2] = [
	Vector2(6.5, 3.6), Vector2(2.7, 3.8), Vector2(1.6, 7.0), Vector2(1.5, 11.8), Vector2(4.5, 12.8),
	Vector2(7.75, 13.4), Vector2(7.75, 16.8), Vector2(7.75, 19.8), Vector2(7.75, 21.6),
]
const PIANO_STANDS: Array[Vector3] = [Vector3(7.85, 1.2, 3.0), Vector3(12.15, 1.2, 3.0)] # West and east ends.
const PIANO_STAND_ROUTES: Array[String] = ["g_lib", "g_hall"]

# --- Ghost tuning ---
const SHAKE_TIMES: Array[float] = [12.0, 52.0, 92.0, 128.0] # Seconds into the live round.
const CURSE_TIMES: Array[float] = [28.0, 70.0, 110.0]
const GHOST_HOVER_OFFSET := Vector3(1.8, 0.0, -1.8) # Where the resting ghost floats relative to the mover it follows.
const STEAL_SECONDS: float = 4.0 # How long the ghost drags a stolen item away.
const STEAL_MIN_DISTANCE: float = 3.0 # Metres; the ghost only steals an item its mover hasn't nearly reached.
const HUNT_TIMEOUT: float = 6.0 # Seconds to reach an item before giving up on it.
const REST_SECONDS: float = 3.0 # Between steals, so energy refills.
const ENERGY_RESERVE: float = 10.0 # Energy kept on top of a House Shake's cost before stealing.
const GHOST_SAFE_SHARE: int = 82 # Percent of the starting value still in play below which the ghost backs off.

# --- Route map of the Old Mansion: name -> point on the floor (y is the floor height) ---
const NODES: Dictionary = {
	"g_stairs": Vector3(1.5, 1.2, 4.6), "g_west": Vector3(3.4, 1.2, 4.6), "g_lib": Vector3(6.6, 1.2, 4.6),
	"g_mid": Vector3(10.0, 1.2, 5.0), "g_hall": Vector3(12.4, 1.2, 4.4), "g_bed": Vector3(15.0, 1.2, 3.4),
	"g_tv": Vector3(18.0, 1.2, 3.0),
	"m_west": Vector3(1.5, 0.0, 11.6), "m_centre": Vector3(5.5, 0.0, 11.5), "m_north": Vector3(7.0, 0.0, 8.6),
	"m_east": Vector3(11.0, 0.0, 11.0), "m_door": Vector3(7.75, 0.0, 13.4),
	"k_door": Vector3(13.2, 0.0, 11.0), "k_centre": Vector3(15.5, 0.0, 9.2), "k_east": Vector3(18.0, 0.0, 12.0),
	"k_corner": Vector3(18.0, 0.0, 13.9),
	"o_porch": Vector3(7.75, 0.0, 16.6), "o_path": Vector3(7.75, 0.0, 19.5), "truck": Vector3(7.75, 0.0, 21.2),
	"o_gate": Vector3(9.0, 0.0, 16.5), "gd_in": Vector3(11.2, 0.0, 16.5), "gd_path": Vector3(12.8, 0.0, 18.0),
	"gd_east": Vector3(16.6, 0.0, 16.4),
}
const EDGES: Array[Array] = [
	["g_stairs", "g_west"], ["g_west", "g_lib"], ["g_lib", "g_mid"], ["g_mid", "g_hall"], ["g_hall", "g_bed"],
	["g_bed", "g_tv"], ["g_stairs", "m_west"], ["m_west", "m_centre"], ["m_centre", "m_north"],
	["m_centre", "m_door"], ["m_centre", "m_east"], ["m_north", "m_east"], ["m_east", "m_door"],
	["m_east", "k_door"], ["k_door", "k_centre"], ["k_door", "k_east"], ["k_centre", "k_east"],
	["k_east", "k_corner"], ["m_door", "o_porch"], ["o_porch", "o_path"], ["o_path", "truck"],
	["o_porch", "o_gate"], ["o_gate", "gd_in"], ["gd_in", "gd_path"], ["gd_in", "gd_east"], ["gd_path", "gd_east"],
]

# --- A simulated phone ---
class Phone:
	var name: String
	var socket := WebSocketPeer.new()
	var slot: int = -1
	var stick := Vector2.ZERO
	var buttons: Dictionary = {}
	var sent_buttons: Dictionary = {}
	var tap_frames: Dictionary = {} # Button -> physics frames left before it is released again.

	func send(message: Dictionary) -> void:
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			socket.send_text(JSON.stringify(message))

	func poll() -> void:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if message is Dictionary and message.get("type") == "welcome":
				slot = int(message.get("slot", -1))

	func tap(button: String) -> void:
		buttons[button] = true
		tap_frames[button] = BUTTON_TAP_FRAMES

# --- A mover bot's state ---
class Bot:
	var phone: Phone
	var mover: CharacterBody3D
	var mode: String = "idle" # idle, fetch, carry, piano
	var item: Node3D
	var route: Array[Vector3] = []
	var check_at: float = 0.0
	var check_position := Vector3.ZERO
	var stuck_count: int = 0
	var sidestep_left: float = 0.0
	var sidestep := Vector2.ZERO
	var give_up: Dictionary = {} # Item -> time it may be tried again.
	var piano_end: int = -1

# --- Run state ---
var game: Node
var net: Node
var test_mode: bool = false
var phones: Array[Phone] = []
var bots: Array[Bot] = []
var ghost_phone: Phone
var astar := AStar3D.new()
var node_ids: Dictionary = {}
var frame: int = 0
var live_time: float = 0.0
var running_bots: bool = false
var piano: RigidBody3D
var piano_waypoint: int = 0
var piano_done: bool = false
var log_left: float = 0.0
var ghost_state: String = "rest" # rest, hunt, ram, leaving
var ghost_left: float = 0.0
var ghost_prop: Node3D # The possessable component being hunted or driven.
var shake_index: int = 0
var curse_index: int = 0

# --- Setup ---
func _initialize() -> void:
	test_mode = "--test" in OS.get_cmdline_user_args()
	_build_route_map()
	physics_frame.connect(_tick)
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")

	if not test_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# The menus: home, the guide for a few seconds, Play, then the Old Mansion on the map select.
	change_scene_to_file(MAIN_MENU_SCENE)
	await _seconds(STEP_PAUSE + 1.0)
	print("Autoplay: opening the guide")
	_find_button(root, "GuideButton").pressed.emit()
	await _seconds(GUIDE_SECONDS if not test_mode else 0.5)
	_press_visible_back()
	await _seconds(STEP_PAUSE)
	print("Autoplay: Play")
	_find_button(root, "NewGameButton").pressed.emit()
	await _seconds(STEP_PAUSE)
	print("Autoplay: choosing the Old Mansion")
	# Highlight the house, then load the match directly: the threaded loading screen can deadlock when a script
	# drives the menus.
	_first_enabled_tile().grab_focus()
	await _seconds(1.0)
	change_scene_to_file(MATCH_SCENE)
	while not is_instance_valid(game.host) or game.phase != "lobby":
		await process_frame
	await _seconds(STEP_PAUSE)

	# Four phones join one by one and get ready; then the host starts the match.
	for player_name: String in PLAYER_NAMES:
		await _join(player_name)
		await _seconds(JOIN_GAP)
	await _seconds(STEP_PAUSE)
	print("Autoplay: starting the match")
	_press_key(KEY_ENTER)
	if test_mode:
		await _seconds(1.0)
		_press_key(KEY_ESCAPE) # Skip the intro.
	while game.phase != "live":
		await process_frame
	_start_bots()

	# Play until the round ends, then hold on the result.
	while game.phase == "live":
		await process_frame
	running_bots = false
	_release_all_inputs()
	print("Autoplay: round over. Movers won: %s. Banked ₹%d of ₹%d" % [game.result.get("moversWon"), game.result.get("banked", 0), game.result.get("starting", 0)])
	await _seconds(RESULT_HOLD if not test_mode else 2.0)
	quit()


func _join(player_name: String) -> void:
	var phone := Phone.new()
	phone.name = player_name
	phone.socket.connect_to_url("ws://127.0.0.1:%d" % SETTINGS.SOCKET_PORT)
	phones.append(phone)
	while phone.socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		await process_frame
	phone.send({"type": "hello", "name": player_name, "key": net.session_key})
	while phone.slot < 0:
		await process_frame
	await _seconds(0.8)
	phone.send({"type": "ready"})
	print("Autoplay: %s joined as player %d" % [player_name, phone.slot + 1])


func _start_bots() -> void:
	# The ghost is whoever the round picked; every other phone drives a mover bot.
	for phone: Phone in phones:
		if phone.slot == game.ghost_slot:
			ghost_phone = phone
			continue
		var bot := Bot.new()
		bot.phone = phone
		bot.mover = game.host.movers[phone.slot]
		bots.append(bot)
	for item: Node in get_nodes_in_group("loot"):
		if item.weight_class == SETTINGS.TWO_PERSON:
			piano = item
	# The first two movers fetch the piano; the third starts on the most valuable loot.
	for index: int in range(mini(2, bots.size())):
		if piano != null:
			bots[index].mode = "piano"
			bots[index].piano_end = index
			bots[index].route = _route_to(bots[index].mover.global_position, PIANO_STANDS[index], PIANO_STAND_ROUTES[index])
	live_time = 0.0
	running_bots = true
	print("Autoplay: the round is live. Ghost: %s" % ghost_phone.name)


# --- Every physics frame ---
func _tick() -> void:
	frame += 1
	for phone: Phone in phones:
		phone.poll()
	if running_bots and game.phase == "live":
		var delta: float = 1.0 / Engine.physics_ticks_per_second
		live_time += delta
		_steer_piano()
		for bot: Bot in bots:
			_update_bot(bot, delta)
		_update_ghost(delta)
		_log_progress(delta)
	_send_inputs()


func _send_inputs() -> void:
	# Joystick state at the phone's rate (also the heartbeat), and button changes as they happen.
	for phone: Phone in phones:
		if phone.slot < 0:
			continue
		for button: String in phone.tap_frames.keys():
			phone.tap_frames[button] -= 1
			if phone.tap_frames[button] <= 0:
				phone.tap_frames.erase(button)
				phone.buttons[button] = false
		if frame % INPUT_INTERVAL == 0:
			var screen: Vector2 = root.get_node("InputRouter").world_to_stick(phone.stick) # Sticks are screen-relative.
			phone.send({"type": "in", "x": screen.x, "y": screen.y})
		for button: String in phone.buttons:
			if phone.sent_buttons.get(button, false) != phone.buttons[button]:
				phone.sent_buttons[button] = phone.buttons[button]
				phone.send({"type": "btn", "b": button, "down": phone.buttons[button]})


func _release_all_inputs() -> void:
	for phone: Phone in phones:
		phone.stick = Vector2.ZERO
		for button: String in phone.buttons:
			phone.buttons[button] = false


# --- Mover bots ---
func _update_bot(bot: Bot, delta: float) -> void:
	var phone: Phone = bot.phone
	var mover: CharacterBody3D = bot.mover

	# Everyone freezes and braces while a House Shake warns or runs.
	var caught_out: bool = bot == bots[bots.size() - 1] and shake_index % 2 == 1 # The solo mover misses the 1st and 3rd warning.
	if _shake_active() and not caught_out:
		phone.stick = Vector2.ZERO
		phone.buttons["brace"] = true
		return
	phone.buttons["brace"] = false

	match bot.mode:
		"piano":
			_bot_piano(bot, delta)
		"idle":
			phone.stick = Vector2.ZERO
			phone.buttons["grab"] = false
			_choose_item(bot)
		"fetch":
			_bot_fetch(bot, delta)
		"carry":
			_bot_carry(bot, delta)
	if bot.mode != "piano" and is_instance_valid(mover.held_item) and mover.held_item == piano:
		phone.buttons["grab"] = false # A solo bot never drags the piano.


func _choose_item(bot: Bot) -> void:
	# The most valuable loose item for the walk, skipping the piano and items other bots are after.
	var best: Node3D
	var best_score: float = 0.0
	for item: Node in get_nodes_in_group("loot"):
		if item == piano or item.finished or item.is_held() or item.haunted or _in_truck(item):
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
	bot.route = _route_to(bot.mover.global_position, _stand_point(best), "")
	print("Autoplay: %s goes for the %s (₹%d)" % [bot.phone.name, best.item_name, best.value])


func _bot_fetch(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	var item: Node3D = bot.item
	if not is_instance_valid(item) or item.finished or (item.is_held() and not item.is_held_by(mover)):
		bot.mode = "idle"
		return
	if is_instance_valid(mover.held_item):
		if mover.held_item != piano:
			bot.item = mover.held_item # Whatever came to hand is worth carrying.
			_start_carry(bot)
		return
	if item.haunted:
		_give_up(bot, 4.0)
		return

	# Walk the route, then close in and grab when near enough and facing it.
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
	bot.route = _route_to(bot.mover.global_position, DELIVERY_POINT, "truck")
	print("Autoplay: %s carries the %s to the truck" % [bot.phone.name, bot.item.item_name])


func _bot_carry(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	if not is_instance_valid(bot.item) or bot.item.finished:
		bot.phone.buttons["grab"] = false
		bot.mode = "idle"
		return
	if mover.held_item != bot.item:
		bot.mode = "fetch" # Dropped it (a tumble or a shake): pick it straight back up.
		bot.route.clear()
		bot.phone.buttons["grab"] = false
		return
	bot.phone.buttons["grab"] = true
	if game.host.arena.truck.contains_point(bot.item.global_position):
		bot.phone.stick = Vector2.ZERO
		bot.phone.buttons["grab"] = false # Let go inside the zone: it banks.
		bot.mode = "idle"
		return
	if bot.route.is_empty():
		bot.route = [DELIVERY_POINT]
	if bot.item.global_position.distance_to(bot.item.carry_target()) > SNAG_DISTANCE and bot.sidestep_left <= 0.0:
		bot.phone.stick = Vector2.ZERO # Snagged on a frame or a step: stop and let the spring bring it back.
		_is_stuck(bot, delta)
		return
	_follow_route(bot, delta)
	bot.phone.stick = bot.phone.stick.limit_length(CARRY_STICK)


func _give_up(bot: Bot, seconds: float) -> void:
	if is_instance_valid(bot.item):
		bot.give_up[bot.item] = live_time + seconds
	bot.phone.buttons["grab"] = false
	bot.mode = "idle"


# --- The piano: two bots, one per handle ---
func _bot_piano(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	if not is_instance_valid(piano) or piano.finished:
		bot.phone.buttons["grab"] = false
		bot.mode = "idle"
		return
	if piano_done:
		bot.phone.buttons["grab"] = false
		bot.phone.stick = Vector2.ZERO
		if piano.holder_count() == 0:
			bot.mode = "idle"
		return
	if piano.is_held_by(mover):
		bot.phone.buttons["grab"] = true
		return # _steer_piano sets the stick.
	# Walk to this bot's end, face the handle and grab it.
	if not bot.route.is_empty():
		bot.phone.buttons["grab"] = false
		_follow_route(bot, delta)
		return
	var handle: Vector3 = piano.handle_position(bot.piano_end)
	var to_handle := Vector2(handle.x - mover.global_position.x, handle.z - mover.global_position.z)
	var facing_ok: bool = Vector2(mover.facing.x, mover.facing.z).dot(to_handle.normalized()) > 0.85
	if to_handle.length() < GRAB_REACH and facing_ok:
		bot.phone.stick = Vector2.ZERO
		bot.phone.buttons["grab"] = true
	else:
		bot.phone.buttons["grab"] = false
		bot.phone.stick = to_handle.normalized() * (0.35 if to_handle.length() < 1.3 else 1.0)


func _steer_piano() -> void:
	# Both holders push along the route; each also pulls its own handle onto the route line, which turns the
	# piano to follow the bends. At a sharp bend it slows down to turn first.
	if not is_instance_valid(piano) or piano.finished or piano.holder_count() < 2:
		return
	var centre := Vector2(piano.global_position.x, piano.global_position.z)
	if game.host.arena.truck.contains_point(piano.global_position) and centre.y > 19.0:
		piano_done = true
		print("Autoplay: the piano is in the truck at %s" % piano.global_position)
		return
	if piano_waypoint < PIANO_PATH.size() - 1 and centre.distance_to(PIANO_PATH[piano_waypoint]) < PIANO_ARRIVE:
		piano_waypoint += 1
	var direction: Vector2 = (PIANO_PATH[piano_waypoint] - centre).normalized()
	var handles: Array[Vector2] = []
	for index: int in range(2):
		var point: Vector3 = piano.handle_position(index)
		handles.append(Vector2(point.x, point.z))
	var axis: Vector2 = (handles[1] - handles[0]).normalized()
	var half_length: float = handles[0].distance_to(handles[1]) / 2.0
	var front: int = 1 if axis.dot(direction) >= 0.0 else 0
	var turn: float = rad_to_deg(acos(clampf(absf(axis.dot(direction)), 0.0, 1.0)))
	var speed: float = PIANO_TURN_SPEED if turn > PIANO_TURN_ANGLE else 1.0
	for bot: Bot in bots:
		if bot.mode != "piano" or not piano.is_held_by(bot.mover):
			continue
		var index: int = piano.handle_holders.find(bot.mover)
		var place: Vector2 = centre + direction * half_length * (1.0 if index == front else -1.0)
		var stick: Vector2 = direction * speed + (place - handles[index]) * PIANO_ALIGN_GAIN
		bot.phone.stick = stick.limit_length(PIANO_STICK)


# --- Walking ---
func _follow_route(bot: Bot, delta: float) -> void:
	var mover: CharacterBody3D = bot.mover
	if bot.sidestep_left > 0.0:
		bot.sidestep_left -= delta
		bot.phone.stick = bot.sidestep
		return
	while not bot.route.is_empty():
		var point: Vector3 = bot.route[0]
		var offset := Vector2(point.x - mover.global_position.x, point.z - mover.global_position.z)
		if offset.length() > ARRIVE_DISTANCE:
			bot.phone.stick = offset.normalized()
			_is_stuck(bot, delta)
			return
		bot.route.pop_front()
		bot.check_at = 0.0
	bot.phone.stick = Vector2.ZERO


func _is_stuck(bot: Bot, delta: float) -> bool:
	# Little progress for a second: sidestep left or right for a moment, alternating.
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


func _route_to(from: Vector3, to: Vector3, last_node: String) -> Array[Vector3]:
	# Nearest route node to each end, the shortest path between them, then the destination itself.
	var start: String = _nearest_node(from)
	var finish: String = last_node if not last_node.is_empty() else _nearest_node(to)
	var points: Array[Vector3] = []
	for point: Vector3 in astar.get_point_path(node_ids[start], node_ids[finish]):
		points.append(point)
	points.append(to)
	return points


func _nearest_node(point: Vector3) -> String:
	# The closest node on the same floor that a mover can walk to in a straight line, else the closest on it.
	var level: int = _level(point)
	var best: String = ""
	var best_clear: String = ""
	var best_distance: float = INF
	var best_clear_distance: float = INF
	for node: String in NODES:
		var at: Vector3 = NODES[node]
		if _level(at) != level:
			continue
		var distance: float = Vector2(at.x - point.x, at.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = node
		if distance < best_clear_distance and _clear_line(point, at):
			best_clear_distance = distance
			best_clear = node
	return best_clear if not best_clear.is_empty() else best


func _stand_point(item: Node3D) -> Vector3:
	# Where to stop in front of an item: on the line from the nearest walkable node, a little short of it.
	var at: Vector3 = NODES[_nearest_node(item.global_position)]
	var toward := Vector3(item.global_position.x - at.x, 0.0, item.global_position.z - at.z)
	if toward.length() <= STAND_DISTANCE:
		return at
	var stand: Vector3 = item.global_position - toward.normalized() * STAND_DISTANCE
	return Vector3(stand.x, at.y, stand.z)


func _clear_line(from: Vector3, to: Vector3) -> bool:
	# Clear at knee and chest height on the world layer.
	var floor_y: float = LEVEL_HEIGHT if _level(to) == 1 else 0.0
	var space: PhysicsDirectSpaceState3D = game.host.get_world_3d().direct_space_state
	for height: float in [0.35, 1.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(from.x, floor_y + height, from.z), Vector3(to.x, floor_y + height, to.z), SETTINGS.WORLD_LAYER)
		if not space.intersect_ray(query).is_empty():
			return false
	return true


func _level(point: Vector3) -> int:
	return 1 if point.z < GALLERY_EDGE_Z else 0


func _build_route_map() -> void:
	for node: String in NODES:
		var id: int = node_ids.size()
		node_ids[node] = id
		astar.add_point(id, NODES[node])
	for edge: Array in EDGES:
		astar.connect_points(node_ids[edge[0]], node_ids[edge[1]])


# --- The ghost bot ---
func _update_ghost(delta: float) -> void:
	# A ghost with a plan the audience can read: it steals the item a mover is walking to and drags it off, shakes
	# the house (saving energy for it), and curses carried loot. Sliding stays under the damage speed.
	var ghost: Node3D = game.host.ghost
	if ghost_phone == null or not is_instance_valid(ghost):
		return
	ghost_left -= delta
	var free: bool = not is_instance_valid(ghost.possessing)
	if free and ghost_state in ["rest", "hunt"] and _ghost_haunt(ghost):
		return
	match ghost_state:
		"rest":
			_ghost_fly(ghost, _busiest_mover().global_position + GHOST_HOVER_OFFSET)
			if ghost_left <= 0.0 and ghost.energy >= SETTINGS.SHAKE_COST + ENERGY_RESERVE:
				ghost_prop = _steal_target()
				ghost_state = "hunt" if ghost_prop != null else "rest"
				ghost_left = HUNT_TIMEOUT if ghost_prop != null else REST_SECONDS
		"hunt":
			if not is_instance_valid(ghost_prop) or ghost_left <= 0.0 or not ghost_prop.can_be_possessed():
				_ghost_rest()
				return
			_ghost_fly(ghost, ghost_prop.global_position)
			if ghost.target == ghost_prop and ghost.can_toggle_possession():
				ghost_phone.tap("possess")
				ghost_state = "steal"
				ghost_left = STEAL_SECONDS
				print("Autoplay: the ghost steals the %s" % ghost_prop.prop_name())
		"steal":
			if free:
				_ghost_rest()
				return
			# Drag it away from the nearest mover, toward the far side of the house from the truck.
			var at: Vector3 = ghost.possessing.global_position
			var away: Vector3 = at - _nearest_mover(at).global_position
			var flat := Vector2(away.x, away.z).normalized() + Vector2(0.0, -0.6)
			ghost_phone.stick = flat.normalized()
			if ghost_left <= 0.0 or ghost.energy < SETTINGS.SHAKE_COST:
				ghost_state = "leaving"
				ghost_left = 0.3
		"leaving":
			ghost_phone.stick = Vector2.ZERO
			if ghost_left <= 0.0:
				if not free:
					ghost_phone.tap("possess")
				_ghost_rest()


func _ghost_haunt(ghost: Node3D) -> bool:
	# The timed hauntings; returns true while one is being lined up.
	if shake_index < SHAKE_TIMES.size() and live_time >= SHAKE_TIMES[shake_index]:
		_ghost_fly(ghost, _busiest_mover().global_position + GHOST_HOVER_OFFSET)
		if ghost.can_haunt(0) and _any_mover_walking():
			ghost_phone.tap("haunt1")
			shake_index += 1
			print("Autoplay: the ghost shakes the house")
		return true
	if curse_index < CURSE_TIMES.size() and live_time >= CURSE_TIMES[curse_index]:
		var carrier: CharacterBody3D = _carrier()
		if carrier == null:
			return false
		_ghost_fly(ghost, carrier.held_item.global_position)
		if ghost.can_curse() and ghost.curse_target == carrier.held_item:
			ghost_phone.tap("haunt3")
			curse_index += 1
			print("Autoplay: the ghost curses the %s" % carrier.held_item.item_name)
		return true
	return false


func _steal_target() -> Node3D:
	# The possessable part of an item a mover is walking to, while that mover is still a few metres away.
	for bot: Bot in bots:
		if bot.mode != "fetch" or not is_instance_valid(bot.item) or bot.item.is_held() or bot.item == piano:
			continue
		if bot.mover.global_position.distance_to(bot.item.global_position) < STEAL_MIN_DISTANCE:
			continue
		for node: Node in get_nodes_in_group("possessables"):
			if node.prop == bot.item and node.can_be_possessed():
				return node
	return null


func _ghost_rest() -> void:
	ghost_state = "rest"
	ghost_left = REST_SECONDS
	ghost_prop = null
	ghost_phone.stick = Vector2.ZERO


func _ghost_fly(ghost: Node3D, target: Vector3) -> void:
	var offset := Vector2(target.x - ghost.global_position.x, target.z - ghost.global_position.z)
	ghost_phone.stick = offset.normalized() * clampf(offset.length() / 1.5, 0.0, 1.0) if offset.length() > 0.2 else Vector2.ZERO


func _nearest_mover(point: Vector3) -> CharacterBody3D:
	var best: CharacterBody3D = bots[0].mover
	for bot: Bot in bots:
		if bot.mover.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = bot.mover
	return best


func _log_progress(delta: float) -> void:
	log_left -= delta
	if log_left > 0.0:
		return
	log_left = 3.0
	var line: String = "Autoplay %.0fs: banked ₹%d of ₹%d, in play ₹%d |" % [live_time, game.banked_value, game.starting_value, _value_in_play()]
	if is_instance_valid(piano) and not piano.finished:
		line += " piano holders %d wp %d ₹%d |" % [piano.holder_count(), piano_waypoint, piano.value]
	for bot: Bot in bots:
		line += " %s %s |" % [bot.phone.name, bot.mode]
	line += " ghost %s" % ghost_state
	print(line)


# --- Round queries ---
func _shake_active() -> bool:
	var ghost: Node3D = game.host.ghost
	if not is_instance_valid(ghost) or ghost.hauntings.is_empty():
		return false
	return ghost.hauntings[0].is_active()


func _any_mover_walking() -> bool:
	for bot: Bot in bots:
		if Vector2(bot.mover.velocity.x, bot.mover.velocity.z).length() > 1.0:
			return true
	return false


func _busiest_mover() -> CharacterBody3D:
	# A mover carrying something, else the first one.
	var carrier: CharacterBody3D = _carrier()
	return carrier if carrier != null else bots[0].mover


func _carrier() -> CharacterBody3D:
	for bot: Bot in bots:
		var held: Variant = bot.mover.held_item
		if is_instance_valid(held) and held != piano and "curse_left" in held and held.curse_left <= 0.0:
			return bot.mover
	return null


func _claimed(item: Node3D, asking: Bot) -> bool:
	for bot: Bot in bots:
		if bot != asking and bot.mode in ["fetch", "carry"] and bot.item == item:
			return true
	return false


func _in_truck(item: Node3D) -> bool:
	return game.host.arena.truck.contains_point(item.global_position)


func _value_in_play() -> int:
	var total: int = 0
	for item: Node in get_nodes_in_group("loot"):
		if not item.finished:
			total += item.value
	return total


# --- Menu helpers ---
func _find_button(from: Node, button_name: String) -> Button:
	return from.find_child(button_name, true, false) as Button


func _press_visible_back() -> void:
	for node: Node in root.find_children("*", "Button", true, false):
		if node.text == "Back" and node.is_visible_in_tree():
			node.pressed.emit()
			return


func _first_enabled_tile() -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if node.theme_type_variation == &"TileButton" and not node.disabled and node.is_visible_in_tree():
			return node
	return null


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _seconds(seconds: float) -> void:
	# Game time, not the wall clock, so pauses keep their length when Movie Maker records slower than real time.
	await create_timer(seconds).timeout
