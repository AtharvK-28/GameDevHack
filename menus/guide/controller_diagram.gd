# Drawn pictures for the How to play screen: the phone as a mover holds it, the phone as the ghost holds it, and
# how a phone gets into the game at all. They are drawn rather than loaded so they always match the real controller
# layout and need no art file, and so numbered callouts can line up with the guide's own numbered lines.
extends Control

# --- Which picture ---
enum Picture {JOIN, MOVER, GHOST}

# --- Layout (fractions of the drawn box, so the picture scales with the panel) ---
const BODY_INSET := Vector2(0.03, 0.12) # Space left round the phone for its callout badges.
const CORNER: float = 10.0
const BORDER: float = 2.0
const STRIP_HEIGHT: float = 0.17 # Of the phone body: the status strip along the top.
const STICK_CENTRE := Vector2(0.27, 0.62) # Of the phone body.
const STICK_RADIUS: float = 0.17
const BUTTON_LEFT: float = 0.54 # Of the phone body: where the button column starts.
const BUTTON_RIGHT: float = 0.96
const BADGE_RADIUS: float = 11.0

# --- Settings ---
var picture: int = Picture.MOVER
var accent := Color.WHITE

# --- Setup ---
func _init(which: int, colour: Color) -> void:
	picture = which
	accent = colour
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	match picture:
		Picture.JOIN:
			_draw_join()
		Picture.MOVER:
			# Badge 3 is the throw, which is a flick of the stick rather than a button of its own.
			_draw_phone("MOVER", [["GRAB", Balance.PLAYER_COLOURS[0], 2], ["BRACE", "#8ed081", 4]], 5, 3)
		Picture.GHOST:
			_draw_phone("GHOST", [["POSSESS", "#6dff8a", 2], ["ACTION", "#6dff8a", 3], ["SHAKE", "#6dff8a", 4], ["HEX", "#c9a7ff", 5]], 0, 0)


# --- The phone, as each role holds it ---
func _draw_phone(role: String, buttons: Array, shout_badge: int, flick_badge: int) -> void:
	var body := Rect2(size * BODY_INSET, size * (Vector2.ONE - BODY_INSET * 2.0))
	_rounded(body, Balance.UI_PANEL, CORNER)

	# The status strip: the player's colour chip and who they are this round.
	var strip := Rect2(body.position, Vector2(body.size.x, body.size.y * STRIP_HEIGHT))
	_rounded(strip, accent.darkened(0.45), CORNER * 0.5)
	_rounded(Rect2(strip.position + Vector2(8.0, strip.size.y * 0.25), Vector2(10.0, strip.size.y * 0.5)), accent, 3.0)
	_text(role, strip.position + Vector2(26.0, strip.size.y * 0.74), Balance.UI_TEXT, 13)

	# The stick: a ring with the thumb's knob resting off centre, as a pushed stick looks.
	var centre: Vector2 = body.position + body.size * STICK_CENTRE
	var radius: float = body.size.y * STICK_RADIUS * 2.0
	draw_circle(centre, radius, Color(Balance.UI_TEXT, 0.08))
	draw_arc(centre, radius, 0.0, TAU, 32, Balance.UI_MUTED, BORDER)
	var pushed: Vector2 = centre + Vector2(radius * 0.4, -radius * 0.3)
	draw_circle(pushed, radius * 0.42, accent)
	_badge(1, centre + Vector2(-radius - 4.0, -radius - 2.0))

	# The throw: an arrow carrying on the way the stick is pushed, because that is where the item goes.
	if flick_badge > 0:
		var way: Vector2 = (pushed - centre).normalized()
		var tip: Vector2 = centre + way * (radius + 26.0)
		draw_line(pushed + way * radius * 0.5, tip, accent, 2.5)
		var across := Vector2(-way.y, way.x) * 5.0
		draw_colored_polygon(PackedVector2Array([tip + way * 7.0, tip - across, tip + across]), accent)
		_badge(flick_badge, tip + way * 16.0)

	# The buttons, stacked down the right as the phone stacks them.
	var top: float = body.position.y + body.size.y * (STRIP_HEIGHT + 0.11)
	var bottom: float = body.position.y + body.size.y * (0.9 if shout_badge > 0 else 0.96)
	var gap: float = 5.0
	var height: float = (bottom - top - gap * (buttons.size() - 1)) / buttons.size()
	for index: int in buttons.size():
		var key: Array = buttons[index]
		var at := Rect2(body.position.x + body.size.x * BUTTON_LEFT, top + index * (height + gap),
			body.size.x * (BUTTON_RIGHT - BUTTON_LEFT), height)
		_rounded(at, Color(key[1]), CORNER * 0.6)
		_text(String(key[0]), at.position + Vector2(9.0, at.size.y * 0.66), Balance.COMIC_INK, 13)
		_badge(int(key[2]), at.position + Vector2(-BADGE_RADIUS - 2.0, at.size.y / 2.0))

	# The shout row along the bottom, which only movers have.
	if shout_badge > 0:
		var row: float = body.position.y + body.size.y * 0.93
		for index: int in 3:
			var pill := Rect2(body.position.x + 10.0 + index * (body.size.x * 0.17), row, body.size.x * 0.15, body.size.y * 0.1)
			_rounded(pill, Color(Balance.UI_TEXT, 0.14), 4.0)
		_badge(shout_badge, Vector2(body.position.x + body.size.x * 0.54, row + body.size.y * 0.05))


# --- Getting a phone into the game ---
func _draw_join() -> void:
	# The big screen with its code, an arrow, and the phone that scanned it.
	var screen := Rect2(size * Vector2(0.03, 0.16), size * Vector2(0.46, 0.58))
	_rounded(screen, Balance.UI_PANEL, CORNER)
	var code := Rect2(screen.position + screen.size * Vector2(0.52, 0.16), screen.size * Vector2(0.36, 0.56))
	_rounded(code, Balance.UI_TEXT, 3.0)
	for cell: Vector2 in [Vector2(0.1, 0.1), Vector2(0.62, 0.1), Vector2(0.1, 0.62), Vector2(0.42, 0.42)]:
		draw_rect(Rect2(code.position + code.size * cell, code.size * Vector2(0.28, 0.28)), Balance.COMIC_INK)
	_text("GAME CODE", screen.position + Vector2(8.0, screen.size.y * 0.3), accent, 11)
	_text("on the big", screen.position + Vector2(8.0, screen.size.y * 0.48), Balance.UI_MUTED, 10)
	_text("screen", screen.position + Vector2(8.0, screen.size.y * 0.64), Balance.UI_MUTED, 10)
	_badge(1, screen.position + Vector2(-BADGE_RADIUS, screen.size.y * 0.5))

	var arrow_y: float = screen.position.y + screen.size.y * 0.5
	var from := Vector2(screen.end.x + 8.0, arrow_y)
	var to := Vector2(size.x * 0.62, arrow_y)
	draw_line(from, to, accent, 3.0)
	draw_colored_polygon(PackedVector2Array([to + Vector2(8.0, 0.0), to + Vector2(-2.0, -6.0), to + Vector2(-2.0, 6.0)]), accent)

	var phone := Rect2(size * Vector2(0.68, 0.1), size * Vector2(0.26, 0.74))
	_rounded(phone, Balance.UI_PANEL, CORNER)
	_rounded(Rect2(phone.position + Vector2(7.0, 10.0), Vector2(phone.size.x - 14.0, 16.0)), accent, 4.0)
	for line: int in 3:
		_rounded(Rect2(phone.position + Vector2(7.0, 34.0 + line * 13.0), Vector2(phone.size.x - 14.0, 8.0)), Color(Balance.UI_TEXT, 0.16), 3.0)
	_rounded(Rect2(phone.position + Vector2(7.0, phone.size.y - 26.0), Vector2(phone.size.x - 14.0, 18.0)), Balance.UI_GHOST, 4.0)
	_text("READY", phone.position + Vector2(13.0, phone.size.y - 13.0), Balance.COMIC_INK, 11)
	_badge(2, phone.position + Vector2(-BADGE_RADIUS, phone.size.y * 0.3))
	_badge(3, phone.position + Vector2(-BADGE_RADIUS, phone.size.y - 17.0))


# --- Drawing helpers ---
func _rounded(at: Rect2, colour: Color, corner: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.border_color = Balance.COMIC_INK
	box.set_border_width_all(int(BORDER))
	box.set_corner_radius_all(int(corner))
	draw_style_box(box, at)


func _text(content: String, at: Vector2, colour: Color, points: int) -> void:
	draw_string(get_theme_default_font(), at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, points, colour)


func _badge(number: int, at: Vector2) -> void:
	# The numbered circles the guide's lines refer to, so a picture and its words stay tied together.
	draw_circle(at, BADGE_RADIUS, Balance.UI_MONEY)
	draw_arc(at, BADGE_RADIUS, 0.0, TAU, 20, Balance.COMIC_INK, BORDER)
	draw_string(get_theme_default_font(), at + Vector2(-4.0, 5.0), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Balance.COMIC_INK)
