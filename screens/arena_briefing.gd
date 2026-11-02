# The arena briefing: before the first round of a map that has one, the camera pulls back over the whole arena and
# arrows point out the things that will catch a new crew out, one after another. It runs on the real map rather
# than a drawn diagram, so what players are shown is where they will be standing a moment later.
# Only the Museum has marks today (Balance.BRIEFING_MARKS); any other arena skips straight to the round.
# Host keys: Enter or Esc ends it early.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- State ---
var marks: Array = []
var elapsed: float = 0.0
var camera: Camera3D
var was_following: bool = false
var old_focus := Vector3.ZERO
var old_distance: float = 0.0
var font: Font

# --- Setup ---
func _ready() -> void:
	add_to_group("arena_briefing")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load(Balance.COMIC_FONT_PATH)
	hide()


func play_for_arena() -> bool:
	# Called by the cutscene when the story ends. False means this arena has no briefing, so the round starts now.
	var arena: Node3D = get_tree().get_first_node_in_group("arenas") as Node3D
	camera = get_tree().get_first_node_in_group("party_camera") as Camera3D
	if arena == null or camera == null:
		return false
	marks = Balance.BRIEFING_MARKS.get(arena.scene_file_path, [])
	if marks.is_empty():
		return false
	_take_camera(arena)
	elapsed = 0.0
	show()
	return true


func _take_camera(arena: Node3D) -> void:
	# Hold the camera still, high and back, so every mark stays in frame while the arrows come up.
	was_following = camera.follow_movers
	old_focus = camera.focus
	old_distance = camera.distance
	camera.follow_movers = false
	var middle := Vector3.ZERO
	for mark: Dictionary in marks:
		middle += arena.global_position + mark.at
	camera.focus = middle / marks.size()
	camera.distance = Balance.BRIEFING_DISTANCE
	camera.snap()


# --- Running ---
func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	queue_redraw()
	if elapsed >= _run_seconds():
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(camera):
		camera.follow_movers = was_following
		camera.focus = old_focus
		camera.distance = old_distance
	if Game.phase == "intro": # Something else may already have moved the match on; never start a round twice.
		Game.finish_intro()


func _run_seconds() -> float:
	return marks.size() * Balance.BRIEFING_STAGGER + Balance.BRIEFING_FADE + Balance.BRIEFING_HOLD


# --- Drawing ---
func _draw() -> void:
	if not is_instance_valid(camera):
		return
	var arena: Node3D = get_tree().get_first_node_in_group("arenas") as Node3D
	if arena == null:
		return
	_draw_title()
	for index: int in marks.size():
		var fade: float = clampf((elapsed - index * Balance.BRIEFING_STAGGER) / Balance.BRIEFING_FADE, 0.0, 1.0)
		if fade <= 0.0:
			continue
		_draw_mark(marks[index], arena, fade)


func _draw_title() -> void:
	var fade: float = clampf(elapsed / Balance.BRIEFING_FADE, 0.0, 1.0)
	var text: String = "KNOW THE BUILDING"
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.BRIEFING_TITLE_SIZE).x
	var at := Vector2((size.x - width) / 2.0, Balance.BRIEFING_TITLE_SIZE * 1.6)
	draw_string(font, at + Vector2(3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.BRIEFING_TITLE_SIZE, Color(Balance.COMIC_INK, fade))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.BRIEFING_TITLE_SIZE, Color(Balance.BRIEFING_INK, fade))


func _draw_mark(mark: Dictionary, arena: Node3D, fade: float) -> void:
	# The point on the map, then the card pushed off it so the label never covers what it is pointing at.
	var world: Vector3 = arena.global_position + mark.at
	if not camera.is_position_in_frustum(world):
		return
	var point: Vector2 = camera.unproject_position(world)
	var card_at: Vector2 = point + mark.push * fade
	var title: String = String(mark.title)
	var note: String = String(mark.note)
	var title_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.BRIEFING_LABEL_SIZE)
	var note_size: Vector2 = font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.BRIEFING_NOTE_SIZE)
	var inner := Vector2(maxf(title_size.x, note_size.x), title_size.y + note_size.y * 1.3)
	var card := Rect2(card_at - inner / 2.0 - Vector2.ONE * Balance.BRIEFING_PAD, inner + Vector2.ONE * Balance.BRIEFING_PAD * 2.0)

	_draw_arrow(card, point, fade)
	draw_rect(card, Color(Balance.BRIEFING_CARD, Balance.BRIEFING_CARD.a * fade))
	draw_rect(card, Color(Balance.BRIEFING_INK, fade), false, 2.0)
	var text_at: Vector2 = card.position + Vector2.ONE * Balance.BRIEFING_PAD + Vector2(0.0, title_size.y * 0.8)
	draw_string(font, text_at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.BRIEFING_LABEL_SIZE, Color(Balance.BRIEFING_INK, fade))
	draw_string(font, text_at + Vector2(0.0, note_size.y * 1.1), note, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.BRIEFING_NOTE_SIZE, Color(Balance.UI_MUTED, fade))


func _draw_arrow(card: Rect2, point: Vector2, fade: float) -> void:
	# From the edge of the card to the spot itself, so the line never starts under its own words.
	var from: Vector2 = _edge_of(card, point)
	var ink := Color(Balance.BRIEFING_INK, fade)
	draw_line(from, point, ink, Balance.BRIEFING_ARROW_WIDTH)
	var way: Vector2 = (point - from).normalized()
	var across := Vector2(-way.y, way.x) * Balance.BRIEFING_ARROW_HEAD * 0.45
	draw_colored_polygon(PackedVector2Array([point, point - way * Balance.BRIEFING_ARROW_HEAD + across,
		point - way * Balance.BRIEFING_ARROW_HEAD - across]), ink)
	draw_circle(point, Balance.BRIEFING_ARROW_WIDTH * 1.6, ink)


func _edge_of(card: Rect2, toward: Vector2) -> Vector2:
	# Where the line from the card's middle toward the point leaves the card.
	var middle: Vector2 = card.get_center()
	var way: Vector2 = toward - middle
	if way.is_zero_approx():
		return middle
	var half: Vector2 = card.size / 2.0
	var steps: float = minf(half.x / maxf(absf(way.x), 0.001), half.y / maxf(absf(way.y), 0.001))
	return middle + way * steps
