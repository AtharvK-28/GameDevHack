# The Ship's global gust: a clear direction tell, then drift; brace or move across/against it.
class_name GustOfWind
extends Haunting

# --- Visual state ---
var direction := Vector3.BACK
var banner := Label.new()
var streaks: Node3D

# --- Setup ---
func _init() -> void:
	label = "WIND"
	cost = Balance.SHIP_GUST_COST
	cooldown = Balance.SHIP_GUST_COOLDOWN
	warning_time = Balance.SHIP_GUST_WARNING
	run_time = Balance.SHIP_GUST_DURATION


func _ready() -> void:
	Game.changed.connect(_round_changed)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(banner)
	banner.add_theme_font_override("font", load(Balance.COMIC_FONT_PATH))
	banner.add_theme_font_size_override("font_size", Balance.BANNER_FONT_SIZE)
	banner.add_theme_color_override("font_color", Balance.SHIP_LANTERN_COLOUR)
	banner.add_theme_color_override("font_outline_color", Balance.COMIC_INK)
	banner.add_theme_constant_override("outline_size", Balance.COMIC_OUTLINE_SIZE)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.position.y = Balance.BANNER_TOP
	banner.hide()


# --- Haunting hooks ---
func warn() -> void:
	var aim: Vector2 = ghost.aim
	# Cardinal directions are easy to read; a centred stick blows toward the dangerous crossing.
	direction = Vector3.BACK
	if not aim.is_zero_approx():
		if absf(aim.x) > absf(aim.y):
			direction = Vector3(signf(aim.x), 0.0, 0.0)
		else:
			direction = Vector3(0.0, 0.0, signf(aim.y))
	banner.text = "WIND %s — BRACE OR WALK ACROSS / AGAINST IT!" % ("→" if direction.x > 0 else "←" if direction.x < 0 else "↓" if direction.z > 0 else "↑")
	banner.show()
	ghost.arena.wind_direction = direction
	_build_streaks()
	Sfx.play("whoosh")


func run() -> void:
	ghost.arena.wind_active = true


func end() -> void:
	ghost.arena.wind_active = false
	banner.hide()
	if is_instance_valid(streaks):
		streaks.queue_free()


func _exit_tree() -> void:
	if is_instance_valid(ghost) and is_instance_valid(ghost.arena):
		ghost.arena.wind_active = false


# --- Direction tells ---
func _build_streaks() -> void:
	if is_instance_valid(streaks):
		streaks.queue_free()
	streaks = Node3D.new()
	add_child(streaks)
	for point: Vector3 in Balance.SHIP_WIND_MARKERS:
		var arrow := Label3D.new()
		arrow.text = "➜"
		arrow.font_size = Balance.PRICE_FONT_SIZE
		arrow.pixel_size = Balance.SHIP_WIND_MARKER_SIZE
		arrow.modulate = Balance.SHIP_LANTERN_COLOUR
		arrow.rotation = Vector3(-PI / 2.0, -atan2(direction.z, direction.x), 0.0)
		arrow.position = point
		streaks.add_child(arrow)


func _round_changed() -> void:
	if Game.phase in ["result", "final", "lobby"] and phase != Phase.IDLE:
		phase = Phase.IDLE
		end()
