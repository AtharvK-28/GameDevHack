# Motion shared by every screen: buttons squash when pressed, panels pop in with an overshoot, and a wipe slides
# across the screen between screens. Buttons are found as they enter the tree, so screens don't opt in.
extends CanvasLayer

# --- Wipe state ---
var wipe := Control.new() # A comic page: night with a slanted ink edge and a folded corner; see _draw_page().
var covered_scene: Node # The scene that was showing when the wipe covered the screen.

# --- Setup ---
func _ready() -> void:
	# Project-wide themes load before the editor imports assets on a fresh checkout.
	# Apply it to the root window at runtime, once the imported textures exist.
	get_tree().root.theme = load("res://assets/ui/ghosted_theme.tres")
	layer = 100 # Above every screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	wipe.draw.connect(_draw_page)
	wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	wipe.visible = false
	add_child(wipe)
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	# After a scene change under the wipe, slide it away to show the new scene.
	if wipe.visible and covered_scene != null and get_tree().current_scene != covered_scene:
		covered_scene = null
		uncover()


# --- Buttons ---
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.button_down.is_connected(_squash.bind(node)):
		node.button_down.connect(_squash.bind(node))


func _squash(button: Control) -> void:
	button.pivot_offset = button.size / 2.0
	button.scale = Balance.UI_SQUASH_SCALE
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, Balance.UI_SQUASH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Pop-ins ---
func pop_in(control: Control) -> void:
	# Grows from UI_POP_START to full size, overshooting a little, and fades in.
	control.modulate.a = 0.0
	_pop.call_deferred(control) # After layout, so it grows from its real centre.


func _pop(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * Balance.UI_POP_START
	var tween: Tween = control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, Balance.UI_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, Balance.UI_POP_TIME * 0.5)


# --- Wipe ---
func cover(then: Callable) -> void:
	# Turns the night page in from the left, then runs "then" (usually a scene change).
	var width: float = get_viewport().get_visible_rect().size.x
	wipe.size = get_viewport().get_visible_rect().size
	wipe.queue_redraw()
	wipe.position.x = -width - wipe.size.y * Balance.UI_PAGE_SLANT # Starts with its slanted edge off screen too.
	wipe.visible = true
	covered_scene = get_tree().current_scene
	var tween: Tween = create_tween()
	tween.tween_property(wipe, "position:x", 0.0, Balance.UI_WIPE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(then)


func uncover() -> void:
	# Slides the wipe off to the right.
	var width: float = get_viewport().get_visible_rect().size.x
	var tween: Tween = create_tween()
	tween.tween_property(wipe, "position:x", width, Balance.UI_WIPE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: wipe.visible = false)


func _draw_page() -> void:
	# The page's leading (right) edge slants and juts past the wipe's width, with a paper fold at its top corner.
	var page: Vector2 = wipe.size
	var slant: float = page.y * Balance.UI_PAGE_SLANT
	var edge_top := Vector2(page.x + slant, 0.0)
	var edge_bottom := Vector2(page.x, page.y)
	wipe.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, edge_top, edge_bottom, Vector2(0.0, page.y)]), Balance.UI_NIGHT)
	var fold: float = Balance.UI_PAGE_FOLD
	var along: Vector2 = (edge_bottom - edge_top).normalized() * fold
	var fold_points := PackedVector2Array([edge_top - Vector2(fold, 0.0), edge_top, edge_top + along])
	wipe.draw_colored_polygon(fold_points, Balance.COMIC_PAPER)
	wipe.draw_line(edge_top, edge_bottom, Balance.COMIC_INK, Balance.UI_PAGE_EDGE)
	fold_points.append(fold_points[0])
	wipe.draw_polyline(fold_points, Balance.COMIC_INK, Balance.UI_PAGE_EDGE * 0.6)


func flash() -> void:
	# A full wipe across, for changes within one scene (lobby → reveal → round → results).
	cover(uncover)
