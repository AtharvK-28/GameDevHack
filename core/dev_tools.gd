# Developer mode (decision 120), for testing alone on the laptop. Off by default; Options → Game turns it on.
# F10 in the lobby adds a ready stand-in phone: a real WebSocket client, so the match runs exactly as with phones.
# Bots play the stand-ins (decision 121, core/bot_crew.gd) except the one the keyboard drives (1–4 to switch).
# F9 opens the phone page in the laptop's browser, F3 shows the debug overlay, F5 and F6 change the round speed,
# and Ctrl keys fire the match's events on demand.
extends CanvasLayer

const Style := preload("res://screens/screen_style.gd")
const STAND_IN_PHONE := preload("res://core/stand_in_phone.gd")
const BOT_CREW := preload("res://core/bot_crew.gd")
const SHORTCUTS: Dictionary = {
	KEY_1: "haunting", KEY_2: "wave", KEY_3: "smash", KEY_4: "fog", KEY_5: "vote",
	KEY_W: "win", KEY_L: "loss", KEY_T: "time", KEY_N: "last", KEY_B: "bots", KEY_G: "cheat",
}
const KEYS_TEXT: String = "Ctrl+1 haunting · Ctrl+2 wave · Ctrl+3 smash · Ctrl+4 fog · Ctrl+5 vote · Ctrl+T +30 s\nCtrl+W/L win/lose · Ctrl+N next round is the last · Ctrl+B bots · Ctrl+G ghost cheat · F5/F6 speed"

# --- State ---
var host: Node3D # Main.
var forced: bool = false # Checks turn developer mode on without touching the saved options.
var stand_ins: Array = [] # Stand-in phones (core/stand_in_phone.gd); the bot crew plays them.
var bot_crew: Node
var ghost_cheat: bool = false # Ctrl+G: the ghost keeps full energy and no cooldowns.
var stand_in_count: int = 0 # Names each new stand-in.
var seen_phase: String = "" # Stand-ins ready up again each time the lobby comes back.
var refresh_left: float = 0.0
var root: Control
var overlay: PanelContainer
var overlay_text: Label
var lobby_hint: Label
var toast: Label
var toast_fade: Tween

# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5 # Over the match screens.
	_build()
	bot_crew = BOT_CREW.new()
	bot_crew.name = "BotCrew"
	bot_crew.host = host
	bot_crew.stand_ins = stand_ins
	add_child(bot_crew)


func _exit_tree() -> void:
	for phone: RefCounted in stand_ins:
		phone.socket.close()
	Game.normal_speed = 1.0 # A sped-up developer match never outlives the match world.


func enabled() -> bool:
	return forced or PlayerConfig.get_config("GameSettings", "DevMode", false)


# --- Keys ---
func _unhandled_input(event: InputEvent) -> void:
	var key: Key = Style.pressed_key(event)
	if key == KEY_NONE or not enabled():
		return
	if event.ctrl_pressed and SHORTCUTS.has(key):
		run_shortcut(SHORTCUTS[key])
	elif key == KEY_F10 and not event.ctrl_pressed:
		add_stand_in()
	elif key == KEY_F9:
		OS.shell_open(phone_page_url())
	elif key == KEY_F3:
		overlay.visible = not overlay.visible
		refresh_left = 0.0
	elif key in [KEY_F5, KEY_F6]:
		change_speed(-1 if key == KEY_F5 else 1)
	else:
		return
	get_viewport().set_input_as_handled()


# --- Stand-in phones ---
func add_stand_in() -> void:
	if Game.phase != "lobby" or Net.listen_error != OK:
		return
	var online: int = Net.players.filter(func(player: Dictionary) -> bool: return player.socket != null).size()
	if online + _joining_count() >= Balance.MAX_PLAYERS:
		note("All four slots are taken")
		return
	var phone: RefCounted = STAND_IN_PHONE.new()
	phone.name = Balance.DEV_STAND_IN_NAMES[stand_in_count % Balance.DEV_STAND_IN_NAMES.size()]
	phone.socket.connect_to_url("ws://127.0.0.1:%d" % Balance.SOCKET_PORT)
	stand_in_count += 1
	stand_ins.append(phone)
	note("%s joins" % phone.name)


func _poll_stand_ins() -> void:
	# Each stand-in says hello, marks its player as a stand-in when welcomed, readies up in every lobby and sends
	# what the bot crew presses.
	var lobby_again: bool = Game.phase == "lobby" and seen_phase != "lobby"
	seen_phase = Game.phase
	for phone: RefCounted in stand_ins.duplicate():
		var socket: WebSocketPeer = phone.socket
		socket.poll()
		var state: WebSocketPeer.State = socket.get_ready_state()
		if state == WebSocketPeer.STATE_CLOSED:
			stand_ins.erase(phone)
			continue
		if state != WebSocketPeer.STATE_OPEN:
			continue
		if not phone.greeted:
			phone.greeted = true
			phone.send({"type": "hello", "name": phone.name, "key": Net.session_key})
		while socket.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if message is Dictionary and message.get("type") == "welcome":
				if message.get("audience", false):
					socket.close() # No slot left: a stand-in never watches.
					continue
				phone.slot = int(message.slot)
				Net.player_for_slot(phone.slot).stand_in = true
				phone.send({"type": "ready"})
		if lobby_again and phone.slot >= 0:
			phone.send({"type": "ready"})
		phone.send_input()


func _joining_count() -> int:
	return stand_ins.filter(func(phone: RefCounted) -> bool: return phone.slot < 0).size()


func change_speed(step: int) -> void:
	var speeds: Array[float] = Balance.DEV_SPEEDS
	var index: int = clampi(speeds.find(Game.normal_speed) + step, 0, speeds.size() - 1)
	Game.normal_speed = speeds[index]
	if Game.phase == "live" and not Game.punching_in():
		Engine.time_scale = Game.normal_speed
	note("Speed ×%s" % str(Game.normal_speed))


func phone_page_url() -> String:
	# The laptop's own browser reaches the page server on localhost.
	return "http://localhost:%d/#k=%s" % [PageServer.port, Net.session_key]


# --- Shortcuts ---
func run_shortcut(action: String) -> void:
	match action: # These two work in any phase.
		"bots":
			bot_crew.active = not bot_crew.active
			if not bot_crew.active:
				bot_crew.release_all()
			note("Bots %s" % ("on" if bot_crew.active else "off: stand-ins stand still"))
			return
		"cheat":
			ghost_cheat = not ghost_cheat
			note("Ghost cheat %s" % ("on: full energy, no cooldowns" if ghost_cheat else "off"))
			return
	if Game.phase != "live" or not is_instance_valid(host):
		note("Shortcuts work during live play")
		return
	var arena: Node3D = host.arena
	match action:
		"haunting":
			note("Free haunting" if host.free_haunting() else "A haunting is already running")
		"wave":
			if arena.has_method("start_wave"):
				arena.start_wave(Vector3.RIGHT if randf() < 0.5 else Vector3.LEFT)
				note("Wave!")
			else:
				note("Waves are on the Ghost Ship")
		"smash":
			var item: Node3D = _dearest_item()
			if item == null:
				note("Nothing left to smash")
				return
			Game.smash_ready_at = 0
			item._lose_value(mini(item.value, Balance.SMASH_PUNCH_LOSS))
			Game.big_smash(item.global_position) # Plays only if the damage itself didn't already.
			note("Big smash: %s" % item.item_name)
		"fog":
			var sky: Node = arena.get_node_or_null("ShipEnvironment")
			if sky != null:
				sky.roll_fog_bank()
				note("Fog bank")
			else:
				note("Fog banks are on the Ghost Ship")
		"vote":
			if host.audience_vote.open:
				note("A vote is already open")
			else:
				host.audience_vote.open_vote()
				note("Audience vote open")
		"win", "loss":
			Game._finish_round(action == "win", "Ended in developer mode.")
		"last":
			Game.round_index = maxi(Game.round_index, Game.round_count - 2)
			Game._finish_round(true, "Skipped ahead in developer mode.")
			note("The next round is the last" if Game.round_index + 1 < Game.round_count else "This was the last round")
		"time":
			Game.seconds_left += Balance.DEV_EXTRA_SECONDS
			note("+%d s" % Balance.DEV_EXTRA_SECONDS)


func _dearest_item() -> Node3D:
	var dearest: Node3D = null
	for item: Node in get_tree().get_nodes_in_group("loot"):
		if not item.finished and item.value > 0 and (dearest == null or item.value > dearest.value):
			dearest = item
	return dearest


func note(text: String) -> void:
	# A short line at the bottom of the screen, so a shortcut always answers.
	print("Developer mode: ", text)
	toast.text = text
	toast.modulate.a = 1.0
	if toast_fade != null:
		toast_fade.kill()
	toast_fade = toast.create_tween()
	toast_fade.tween_interval(Balance.DEV_TOAST_SECONDS)
	toast_fade.tween_property(toast, "modulate:a", 0.0, 0.4)


# --- Every frame ---
func _process(delta: float) -> void:
	_poll_stand_ins()
	root.visible = enabled()
	if not root.visible:
		return
	lobby_hint.visible = Game.phase == "lobby"
	if lobby_hint.visible:
		lobby_hint.text = "DEVELOPER MODE · F10 add a stand-in · F9 open the phone page (%s) · F3 overlay" % phone_page_url().get_slice("/#", 0)
	if ghost_cheat and is_instance_valid(host) and is_instance_valid(host.ghost):
		_free_ghost(host.ghost)
	refresh_left -= delta / maxf(Engine.time_scale, 0.01) # Real time, whatever the round speed.
	if overlay.visible and refresh_left <= 0.0:
		refresh_left = 1.0 / Balance.DEV_OVERLAY_RATE
		overlay_text.text = "\n".join(overlay_lines())


func _free_ghost(ghost: Node3D) -> void:
	# Ctrl+G: full energy and every cooldown and lock cleared, so hauntings can be tried back to back.
	ghost.energy = Balance.ENERGY_MAX
	for haunting: Haunting in ghost.hauntings:
		haunting.cooldown_left = 0.0
	ghost.curse_cooldown_left = 0.0
	ghost.shared_lock_left = 0.0
	ghost.opening_left = 0.0
	ghost.lockout_left = 0.0


func overlay_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var heading: String = "DEVELOPER MODE · %d FPS · %s" % [Engine.get_frames_per_second(), Game.phase]
	if Game.phase != "lobby":
		heading += " · round %d/%d · %s left" % [Game.round_index + 1, Game.round_count, Style.clock(Game.seconds_left)]
	lines.append(heading)
	lines.append("Speed ×%s (now ×%.2f) · bots %s · ghost cheat %s" % [str(Game.normal_speed), Engine.time_scale, "on" if bot_crew.active else "off", "on" if ghost_cheat else "off"])
	var slot: int = InputRouter.selected_slot
	var player: Dictionary = Net.player_for_slot(slot)
	var role: String = player.get("role", "")
	lines.append("Keyboard drives P%d %s · %s · 1–4 to switch" % [slot + 1, player.get("name", "(empty slot)"), role.to_upper() if not role.is_empty() else "no role"])
	if not is_instance_valid(host):
		return lines
	var ghost: Node3D = host.ghost
	if is_instance_valid(ghost):
		var inside: String = ghost.possessing.prop.name if is_instance_valid(ghost.possessing) else "nothing"
		var haunting: Haunting = ghost.hauntings[0]
		var haunting_state: String = "ready"
		if haunting.is_active():
			haunting_state = "running"
		elif haunting.cooldown_left > 0.0:
			haunting_state = "in %.0f s" % haunting.cooldown_left
		lines.append("Ghost P%d · energy %d · inside %s · %s %s · curse %.0f s · lockout %.0f s" % [ghost.slot + 1, floori(ghost.energy), inside,
			haunting.label, haunting_state, ghost.curse_cooldown_left, ghost.lockout_left])
	var movers: PackedStringArray = []
	for mover: CharacterBody3D in host.movers:
		if mover.in_play and not host.is_ghost_slot(mover.slot):
			var held: String = mover.held_item.item_name if is_instance_valid(mover.held_item) and not mover.held_item.finished else "nothing"
			movers.append("P%d ghost-near %d, holding %s%s" % [mover.slot + 1, host.ghost_near_level(mover), held, " BOOST" if mover.boost_left > 0.0 else ""])
	if not movers.is_empty():
		lines.append("Movers · " + " · ".join(movers))
	var arena: Node3D = host.arena
	if arena.has_method("start_wave") and is_instance_valid(arena.rig):
		var wave: String = "HITTING" if arena.wave_warning_left >= 0.0 else "in %.0f s" % arena.wave_left
		var sky: Node = arena.get_node_or_null("ShipEnvironment")
		var fog: String = "-"
		if sky != null:
			fog = "rolling" if is_instance_valid(sky.fog_bank) else "in %.0f s" % sky.fog_left
		var tilt: Vector3 = arena.rig.rotation_degrees
		lines.append("Ship · wave %s · fog %s · roll %+.1f° pitch %+.1f° rise %+.2f m" % [wave, fog, tilt.x, tilt.z, arena.rig.position.y])
	if Game.starting_value > 0:
		lines.append("Loot · banked %s of %s target · lost %s of %s limit" % [Loot.rupees(Game.banked_value), Loot.rupees(Game.target_value()), Loot.rupees(Game.lost_value), Loot.rupees(Game.loss_limit())])
	var stats: PackedStringArray = []
	for stat_slot: int in Game.round_stats:
		stats.append("P%d %s" % [stat_slot + 1, JSON.stringify(Game.round_stats[stat_slot]).replace("\"", "")])
	if not stats.is_empty():
		lines.append("Award stats · " + " · ".join(stats))
	var vote: AudienceVote = host.audience_vote
	var votes: String = "open %.0f s %s" % [vote.left, vote.tally()] if vote.open else "next in %.0f s" % vote.next_left
	lines.append("Audience %d · vote %s" % [Net.audience_count(), votes])
	lines.append(KEYS_TEXT)
	return lines


# --- Layout ---
func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.use_theme(root)
	add_child(root)
	overlay = Style.ink_panel(0.0, Balance.UI_PANEL_MARGIN / 2)
	overlay.self_modulate.a = Balance.DEV_OVERLAY_ALPHA
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()
	overlay_text = _small_label(Balance.UI_TEXT)
	overlay.add_child(overlay_text)
	overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN # Bottom left: the one corner the match HUD leaves free.
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, int(Balance.UI_SCREEN_MARGIN))
	root.add_child(overlay)
	lobby_hint = _small_label(Balance.UI_GHOST)
	lobby_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lobby_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, int(Balance.UI_SCREEN_MARGIN))
	root.add_child(lobby_hint)
	toast = Style.lettering("", Balance.COMIC_LABEL_SIZE, Balance.UI_MONEY)
	toast.modulate.a = 0.0
	toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(Balance.UI_SCREEN_MARGIN * 4.0))
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(toast)


func _small_label(colour: Color) -> Label:
	var line := Label.new()
	line.add_theme_font_size_override("font_size", Balance.DEV_OVERLAY_SIZE)
	line.add_theme_color_override("font_color", colour)
	line.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	line.add_theme_color_override("font_outline_color", Balance.HOST_OUTLINE_COLOUR)
	return line
