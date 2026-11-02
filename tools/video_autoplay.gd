# Plays one full round for a recording: Another is the ghost, and Atharv, Aditya and Tanish are the movers. Nothing in
# the game is faked: four developer stand-ins join the real socket and core/bot_crew.gd plays them. The Getaway has no
# route map and no ghost, so this script plays it itself, with all four players as movers.
# Run (with a window, for recording):
#   godot --path . --script res://tools/video_autoplay.gd -- --map=Ship [--seed=3]
# --map is Ship, Mansion, Museum or Getaway. To look for a good seed without a window, add --test and --speed=3:
#   godot --headless --path . --script res://tools/video_autoplay.gd -- --map=Ship --seed=3 --test --speed=3
# To check the picture first, add --test and --shots=<folder> without --headless: it saves frames to that folder.
extends "res://core/match_check.gd"

# --- Settings ---
const MAPS: Dictionary = {
	"Ship": "res://arenas/Ship.tscn", "Mansion": "res://arenas/Mansion.tscn", "Museum": "res://arenas/Museum.tscn",
	"Getaway": "res://arenas/Museum.tscn", # The Getaway opens from a Museum match.
}
const PLAYER_NAMES: Array[String] = ["Another", "Atharv", "Aditya", "Tanish"] # The first to join takes slot 0.
const GHOST_SLOT: int = 0
const NOBODYS_SLOT: int = 4 # The keyboard drives no one, so the bots play all four.
const COUNTDOWN_SECONDS: int = 5 # Time to start the recorder before anything moves.
const JOIN_GAP: float = 0.8 # Seconds between phones joining the lobby.
const LOBBY_HOLD: float = 3.0 # Seconds on the full lobby before the match starts.
const RESULT_HOLD: float = 10.0 # Seconds on the result page before quitting.
const REPLAY_TIMEOUT: float = 40.0 # Seconds to let the Disaster Cam finish.
const ROUND_TIMEOUT: float = 400.0 # Real seconds, with room for a slow machine.
const SHOT_SECONDS: Array[float] = [10.0, 40.0, 100.0] # Seconds into live play for --shots; the Getaway's are closer.
const GETAWAY_SHOT_SECONDS: Array[float] = [6.0, 25.0, 45.0]

# --- The Getaway's crew ---
const STAND_DISTANCE: float = 1.0 # Metres from a piece of gold where a mover presses GRAB.
const SAFE_Z: float = -3.0 # Gold is carried back to here, well away from the tailgate.
const WALK_STICK: float = 1.0
const CARRY_STICK: float = 0.8
const SETTLE_SPEED: float = 0.4 # Metres per second: slow enough that letting go sets the gold down, not throws it.
const BEAM_MARGIN: float = 1.2 # Metres outside the searchlight where a mover already freezes.

# --- Run state ---
var map_name: String = "Ship"
var round_seed: int = 3
var speed: float = 1.0
var testing: bool = false
var shots_folder: String = ""
var dev: CanvasLayer
var targets: Dictionary = {} # The Getaway: slot -> the gold that mover is going for.


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running game before starting the video run.")
		quit(1)
		return
	_read_arguments()
	if not MAPS.has(map_name):
		push_error("--map must be one of %s" % str(MAPS.keys()))
		quit(1)
		return
	if not testing:
		root.mode = Window.MODE_FULLSCREEN
	game.selected_arena = MAPS[map_name]
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	dev = playground.dev_tools
	dev.forced = true
	dev.visible = false # Bots and stand-ins keep running; only the developer text is hidden.
	await _wait(SETTLE_SECONDS)
	if not testing:
		for left: int in range(COUNTDOWN_SECONDS, 0, -1):
			print("Starting in %d..." % left)
			await _wait(1.0)
	await _join_players()
	await _start_match()
	if map_name == "Getaway":
		await _play_getaway()
	else:
		await _play_round()
	quit(0)


func _read_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			map_name = argument.trim_prefix("--map=")
		elif argument.begins_with("--seed="):
			round_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--speed="):
			speed = float(argument.trim_prefix("--speed="))
		elif argument.begins_with("--shots="):
			shots_folder = argument.trim_prefix("--shots=")
		elif argument == "--test":
			testing = true


func _shot(label: String) -> void:
	if shots_folder.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [shots_folder, map_name, label])


func _ignore_escape() -> void:
	# Esc pauses a round and skips the Getaway, so one stray key would ruin a take. Alt+F4 still closes the window.
	playground.find_child("HUD", true, false).set_process_unhandled_input(false)


func _play_with_shots(moments: Array[float], total: float) -> void:
	# Live play, stepping the crew when this script is the one playing, with a frame saved at each moment.
	var deadline: int = Time.get_ticks_msec() + int(ROUND_TIMEOUT * 1000.0)
	var taken: int = 0
	while game.phase in ["live", "paused"] and Time.get_ticks_msec() < deadline:
		if map_name == "Getaway":
			_drive_getaway_crew()
		if taken < moments.size() and total - game.seconds_left >= moments[taken]:
			await _shot("live_%03d" % int(moments[taken]))
			taken += 1
		await _frame()


# --- Lobby ---
func _join_players() -> void:
	for player_name: String in PLAYER_NAMES:
		dev.add_stand_in()
		dev.stand_ins.back().name = player_name # Before its hello goes out, on the next poll.
		await _wait(0.1 if testing else JOIN_GAP)
	await _wait(0.6 if testing else LOBBY_HOLD)
	await _shot("lobby")
	router.selected_slot = NOBODYS_SLOT


func _start_match() -> void:
	seed(round_seed)
	game.start_match()
	game.ghost_order.assign([GHOST_SLOT]) # Another is the ghost every round; the real game shuffles.
	await _wait(0.2)


# --- A normal round ---
func _play_round() -> void:
	if game.phase == "intro":
		await _key(KEY_ESCAPE)
		await _skip_briefing()
	await _wait_for_phase("reveal")
	_ignore_escape()
	game.seconds_left = SETTINGS.ROUND_SECONDS # Full length, whatever the Demo mode option says.
	await _wait(1.0)
	await _shot("reveal")
	await _wait_for_phase("live")
	_set_speed(speed)
	await _play_with_shots(SHOT_SECONDS, SETTINGS.ROUND_SECONDS)
	_set_speed(1.0)
	var replayed: int = game.replay.size()
	if not testing or not shots_folder.is_empty():
		await _wait_until(func() -> bool: return game.replay.is_empty(), REPLAY_TIMEOUT)
		await _wait(RESULT_HOLD if not testing else 2.0)
		await _shot("result")
	var share: float = 100.0 * game.banked_value / maxi(game.starting_value, 1)
	var lost: float = 100.0 * game.lost_value / maxi(game.starting_value, 1)
	print("VIDEO ROUND: map=%s seed=%d won=%s played=%.0fs items=%d banked=%.0f%% lost=%.0f%% target=%d%% stars=%d replays=%d phase=%s" % [
		map_name, round_seed, game.result.get("moversWon", false), SETTINGS.ROUND_SECONDS - game.seconds_left, playground.arena.truck.banked_items,
		share, lost, game.delivery_percent(), game.result.get("stars", 0), replayed, game.phase])


func _set_speed(scale: float) -> void:
	game.normal_speed = scale
	Engine.time_scale = scale


# --- The Getaway ---
func _play_getaway() -> void:
	game._begin_getaway()
	_ignore_escape()
	game.seconds_left = SETTINGS.GETAWAY_SECONDS
	await _wait(0.2)
	_set_speed(speed)
	await _play_with_shots(GETAWAY_SHOT_SECONDS, SETTINGS.GETAWAY_SECONDS)
	_set_speed(1.0)
	var played: float = SETTINGS.GETAWAY_SECONDS - game.seconds_left
	var chest_z: float = playground.arena.gold[0].global_position.z if is_instance_valid(playground.arena.gold[0]) else 99.0
	for phone: RefCounted in dev.stand_ins:
		phone.release()
	if not testing or not shots_folder.is_empty():
		await _wait(RESULT_HOLD if not testing else 2.0)
		await _shot("saved")
	var saved: Dictionary = game.getaway_result
	print("VIDEO ROUND: map=Getaway seed=%d played=%.0fs saved=%d of %d stars=%d chest_z=%.1f phase=%s" % [round_seed, played, saved.get("saved", 0), saved.get("total", 0), saved.get("stars", 0), chest_z, game.phase])


func _drive_getaway_crew() -> void:
	var arena: Node3D = playground.arena
	for phone: RefCounted in dev.stand_ins:
		var mover: CharacterBody3D = playground.movers[phone.slot]
		var beam_near: bool = arena.pool.visible and Vector2(mover.global_position.x - arena.pool.position.x, mover.global_position.z - arena.pool.position.z).length() < SETTINGS.GETAWAY_BEAM_RADIUS + BEAM_MARGIN
		if arena.wave_warning_left > 0.0 or beam_near:
			phone.stick = Vector2.ZERO
			phone.buttons["brace"] = true
			continue
		phone.buttons["brace"] = false
		if is_instance_valid(mover.held_item):
			_carry_gold_back(phone, mover)
		else:
			_go_for_gold(phone, mover)


func _carry_gold_back(phone: RefCounted, mover: CharacterBody3D) -> void:
	var to_safety: float = SAFE_Z - mover.held_item.global_position.z
	if to_safety < 0.0:
		phone.stick = Vector2(0.0, -CARRY_STICK)
		return
	phone.stick = Vector2.ZERO # Letting go with the stick pushed would throw it (decision 151).
	if Vector2(mover.velocity.x, mover.velocity.z).length() < SETTLE_SPEED:
		phone.buttons["grab"] = false
		targets.erase(phone.slot)


func _go_for_gold(phone: RefCounted, mover: CharacterBody3D) -> void:
	var item: RigidBody3D = _gold_for(phone.slot)
	if item == null:
		phone.stick = Vector2.ZERO
		phone.buttons["grab"] = false
		return
	var gap := Vector2(item.global_position.x - mover.global_position.x, item.global_position.z - mover.global_position.z)
	var reached: bool = gap.length() <= STAND_DISTANCE
	phone.stick = gap.normalized() * (WALK_STICK if not reached else WALK_STICK * 0.3)
	phone.buttons["grab"] = reached


func _gold_for(slot: int) -> RigidBody3D:
	# The loose gold nearest the tailgate that nobody else is going for; it may stay put once it is safe.
	if is_instance_valid(targets.get(slot, null)):
		var current: RigidBody3D = targets[slot]
		if not current.finished and not current.is_held() and current.global_position.z > SAFE_Z:
			return current
	targets.erase(slot) # Banked, off the tailgate or gone: choose again.
	var best: RigidBody3D = null
	for item: RigidBody3D in playground.arena.gold:
		if not is_instance_valid(item) or item.finished or item.is_held() or item.weight_class == SETTINGS.TWO_PERSON:
			continue
		if item in targets.values() or item.global_position.z <= SAFE_Z + 0.5:
			continue
		if best == null or item.global_position.z > best.global_position.z:
			best = item
	targets[slot] = best
	return best
