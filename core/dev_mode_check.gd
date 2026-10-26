# Checks developer mode (decision 120) on the Ghost Ship with no phones: F10 stand-ins join and ready up, the
# keyboard drives a stand-in mover and the ghost while the others stand still, F3 shows the overlay, and every Ctrl
# shortcut fires its event. Off, none of the keys do anything.
extends "res://core/match_check.gd"

const DRIVE_SECONDS: float = 0.6
const MOVED_METRES: float = 0.3
const STILL_METRES: float = 0.15
const BOT_SECONDS: float = 2.5
const BOT_METRES: float = 1.0

var dev: CanvasLayer

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	game.selected_arena = game.SHIP_ARENA
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	dev = playground.dev_tools
	await _wait(SETTLE_SECONDS)

	if not dev.enabled(): # Skipped when this machine saved developer mode on.
		await _key(KEY_F10)
		await _wait(0.3)
		_check(net.players.is_empty() and not dev.root.visible, "Developer mode is off by default: F10 adds nobody and nothing shows")
	dev.forced = true
	for count: int in range(3):
		await _key(KEY_F10)
	await _wait(0.5)
	var stand_ins: Array = net.players.filter(func(player: Dictionary) -> bool: return player.get("stand_in", false))
	_check(stand_ins.size() == 3 and game.ready_slots().size() == 3 and game.can_start(), "F10 three times: three stand-in phones join and ready up (%d)" % stand_ins.size())
	_check(dev.lobby_hint.visible and dev.lobby_hint.text.contains("localhost:%d" % SETTINGS.WEB_PORT), "The lobby shows the laptop's phone-page link")
	await _key(KEY_F3)
	_check(dev.overlay.visible, "F3 shows the debug overlay")

	await _key(KEY_ENTER)
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait_for_phase("live")
	_check(game.phase == "live" and game.participants.size() == 3, "Enter starts a match with the stand-ins alone")
	var ship: Node3D = playground.arena
	ship.motion_scale = 0.0 # Level and calm, so only the keyboard moves anyone.
	ship.wave_left = INF
	await _wait(0.3)
	_check(dev.overlay_text.text.contains("FPS") and dev.overlay_text.text.contains("Ghost P%d" % (game.ghost_slot + 1)) and dev.overlay_text.text.contains("Ship ·"), "The overlay reports the frame rate, the ghost and the ship")

	# With the bots off, the keyboard drives one stand-in mover and the other stands still.
	await _ctrl_key(KEY_B)
	_check(not dev.bot_crew.active, "Ctrl+B turns the bots off")
	await _wait(0.5) # Let the movers the bots were walking come to rest.
	var movers: Array = game.participants.filter(func(slot: int) -> bool: return slot != game.ghost_slot)
	var driven: CharacterBody3D = playground.movers[movers[0]]
	var idle: CharacterBody3D = playground.movers[movers[1]]
	await _key(KEY_1 + movers[0])
	_check(router.selected_slot == movers[0], "A number key picks the stand-in to drive")
	var driven_from: Vector3 = driven.global_position
	var idle_from: Vector3 = idle.global_position
	await _hold(KEY_D)
	_check(_flat_gap(driven.global_position, driven_from) > MOVED_METRES, "The keyboard drives the chosen stand-in (%.2f m)" % _flat_gap(driven.global_position, driven_from))
	_check(_flat_gap(idle.global_position, idle_from) < STILL_METRES, "The stand-in nobody drives stands still")
	var ghost: Node3D = playground.ghost
	await _key(KEY_1 + game.ghost_slot)
	var ghost_from: Vector3 = ghost.global_position
	await _hold(KEY_D)
	_check(_flat_gap(ghost.global_position, ghost_from) > MOVED_METRES, "The keyboard drives the ghost too")

	# Bots on: they play every stand-in except the keyboard's.
	await _key(KEY_1 + movers[0])
	await _ctrl_key(KEY_B)
	idle_from = idle.global_position
	ghost_from = ghost.global_position
	# Movement can't show it (a bot may bump the keyboard's mover); its input must stay the idle keyboard's.
	var keyboard_input: Array[bool] = [true]
	var deadline: int = Time.get_ticks_msec() + int(BOT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var input: Object = router.for_slot(movers[0])
		keyboard_input[0] = keyboard_input[0] and input.direction.is_zero_approx() and not input.buttons.values().has(true)
		await _frame()
	_check(dev.bot_crew.active and _flat_gap(idle.global_position, idle_from) > BOT_METRES, "Bots play the other stand-in mover (%.2f m)" % _flat_gap(idle.global_position, idle_from))
	_check(_flat_gap(ghost.global_position, ghost_from) > BOT_METRES, "A bot plays the ghost stand-in")
	_check(keyboard_input[0], "No bot input reaches the keyboard's stand-in")
	await _ctrl_key(KEY_B) # Off again, so the shortcuts below meet a quiet round.

	# Shortcuts. Ctrl+number never switches the driven slot.
	var selected: int = router.selected_slot
	await _ctrl_key(KEY_2)
	_check(ship.wave_warning_left >= 0.0, "Ctrl+2 sends a wave")
	await _ctrl_key(KEY_4)
	_check(is_instance_valid(ship.get_node("ShipEnvironment").fog_bank), "Ctrl+4 rolls a fog bank")
	await _ctrl_key(KEY_5)
	_check(playground.audience_vote.open, "Ctrl+5 opens an audience vote")
	var haunting: Haunting = ghost.hauntings[0]
	haunting.cooldown_left = 5.0
	await _ctrl_key(KEY_1)
	_check(haunting.is_active() and haunting.cooldown_left <= 5.0, "Ctrl+1 starts the haunting without spending the ghost's cooldown")
	_check(router.selected_slot == selected, "Ctrl+number leaves the driven slot alone")
	var dearest: Node3D = dev._dearest_item()
	var dearest_value: int = dearest.value
	await _ctrl_key(KEY_3)
	_check(dearest.value < dearest_value and playground.camera.punch_left > 0.0, "Ctrl+3 smashes the dearest item with the punch-in")
	await create_timer(SETTINGS.SMASH_SLOWMO_SECONDS + 0.2, true, false, true).timeout
	var clock: float = game.seconds_left
	await _ctrl_key(KEY_T)
	_check(game.seconds_left > clock + SETTINGS.DEV_EXTRA_SECONDS - 1.0, "Ctrl+T adds 30 seconds")
	await _key(KEY_F6)
	_check(is_equal_approx(game.normal_speed, 2.0) and is_equal_approx(Engine.time_scale, 2.0), "F6 speeds the round up")
	await _key(KEY_F5)
	await _key(KEY_F5)
	_check(is_equal_approx(Engine.time_scale, 0.5), "F5 slows it down")
	await _key(KEY_F6)
	await _ctrl_key(KEY_G)
	ghost.energy = 5.0
	ghost.hauntings[0].cooldown_left = 20.0
	await _wait(0.1)
	_check(is_equal_approx(ghost.energy, SETTINGS.ENERGY_MAX) and is_zero_approx(ghost.hauntings[0].cooldown_left), "Ctrl+G keeps the ghost's energy full and its cooldowns clear")
	await _ctrl_key(KEY_G)
	ghost.energy = 5.0
	await _wait(0.1)
	_check(ghost.energy < 10.0, "Ctrl+G again ends the cheat")
	await _ctrl_key(KEY_W)
	_check(game.phase == "result" and game.result.moversWon, "Ctrl+W ends the round as a movers' win")
	await _key(KEY_ENTER)
	await _wait_for_phase("live")
	_check(is_equal_approx(Engine.time_scale, 1.0), "The next round plays at the chosen speed")
	await _ctrl_key(KEY_N)
	_check(game.phase == "result" and game.round_index + 2 == game.round_count, "Ctrl+N makes the next round the last")
	await _key(KEY_ENTER)
	await _wait_for_phase("live")
	await _ctrl_key(KEY_L)
	_check(game.phase == "result" and not game.result.moversWon, "Ctrl+L ends the round as a loss")
	await _key(KEY_ENTER)
	await _wait(0.2)
	_check(game.phase == "final", "After the last round come the final standings")

	# Back in the lobby the stand-ins ready up again; a fourth fits, a fifth does not.
	game.return_to_lobby()
	await _wait(0.4)
	_check(game.ready_slots().size() == 3, "Stand-ins ready up again in the next lobby")
	await _key(KEY_F10)
	await _key(KEY_F10)
	await _wait(0.5)
	_check(net.players.size() == 4 and net.audience_count() == 0, "A fourth stand-in fits; a fifth is refused")
	net.rotate_session()
	await _wait(0.3)
	_check(dev.stand_ins.is_empty() and net.players.is_empty(), "New join code clears the stand-ins")

	print("DEV MODE CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _hold(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(DRIVE_SECONDS if pressed else 0.1)


func _ctrl_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.ctrl_pressed = true
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frame()
	await _frame()


func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
