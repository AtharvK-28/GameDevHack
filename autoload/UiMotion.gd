# Motion shared by every screen: buttons squash when pressed, panels pop in with an overshoot, and a wipe slides
# across the screen between screens. Buttons are found as they enter the tree, so screens don't opt in.
extends CanvasLayer

# --- Wipe state ---
var wipe := ColorRect.new()
var covered_scene: Node # The scene that was showing when the wipe covered the screen.

# --- Setup ---
func _ready() -> void:
	# Project-wide themes load before the editor imports assets on a fresh checkout.
	# Apply it to the root window at runtime, once the imported textures exist.
	get_tree().root.theme = load("res://assets/ui/ghosted_theme.tres")
	layer = 100 # Above every screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	wipe.color = Balance.UI_NIGHT
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
	# Slides the night colour in from the left, then runs "then" (usually a scene change).
	var width: float = get_viewport().get_visible_rect().size.x
	wipe.size = get_viewport().get_visible_rect().size
	wipe.position.x = -width
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


func flash() -> void:
	# A full wipe across, for changes within one scene (lobby → reveal → round → results).
	cover(uncover)
