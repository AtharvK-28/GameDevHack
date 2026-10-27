# One of developer mode's stand-in phones: a real WebSocket client on the host's own port, so a match runs exactly
# as with phones. core/bot_crew.gd sets its stick (a world direction) and buttons; send_input() sends them on real
# time at a phone's rate, so a sped-up round never trips the host's rate limit.
extends RefCounted

var name: String = ""
var socket := WebSocketPeer.new()
var slot: int = -1
var greeted: bool = false
var stick := Vector2.ZERO
var buttons: Dictionary = {}
var sent_buttons: Dictionary = {}
var tap_until: Dictionary = {} # Button -> ticks (ms) when a tap is released.
var next_input: int = 0 # Ticks (ms) when the next stick message is due.

func send(message: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))


func tap(button: String) -> void:
	buttons[button] = true
	tap_until[button] = Time.get_ticks_msec() + Balance.BOT_TAP_MS


func release() -> void:
	stick = Vector2.ZERO
	for button: String in buttons:
		buttons[button] = false
	tap_until.clear()


func send_input() -> void:
	if slot < 0:
		return
	var now: int = Time.get_ticks_msec()
	for button: String in tap_until.keys():
		if now >= tap_until[button]:
			tap_until.erase(button)
			buttons[button] = false
	if now >= next_input:
		# A phone's rate in game time, so a sped-up round still steers smoothly, within the host's rate limit.
		var rate: float = minf(Balance.INPUT_RATE * maxf(Engine.time_scale, 1.0), Balance.BOT_MAX_INPUT_RATE)
		next_input = now + int(1000.0 / rate)
		var screen: Vector2 = InputRouter.world_to_stick(stick) # Bots steer in the world; a phone speaks screen.
		send({"type": "in", "x": screen.x, "y": screen.y})
	for button: String in buttons:
		if sent_buttons.get(button, false) != buttons[button]:
			sent_buttons[button] = buttons[button]
			send({"type": "btn", "b": button, "down": buttons[button]})
