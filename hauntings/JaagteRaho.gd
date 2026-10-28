# JAAGTE RAHO!, the Museum's haunting (decision 128; replaces the spec's Lights Out): Bahadur blows his whistle and
# the galleries go dark (the warning), then for the run his torch beam follows the ghost, so the ghost player hunts
# with it. A mover moving inside the beam is caught: HALT!, they drop what they hold and tumble. The counter is to
# hold BRACE and freeze like a statue; a frozen mover gets a museum label instead. The street and the van stay lit.
class_name JaagteRaho
extends Haunting

# --- Effects ---
var banner := Label.new()
var beam := SpotLight3D.new()
var pool := MeshInstance3D.new() # The bright circle the beam throws on the floor.
var last_caught: Dictionary = {} # Mover -> seconds until the beam may catch them again.
var labelled: Dictionary = {} # Movers already given a statue label this run.
var darkness: float = 0.0 # 0 lit to 1 dark, eased.
var dark_target: float = 0.0

# --- Setup ---
func _init() -> void:
	label = "JAAGTE RAHO"
	cost = Balance.JAAGTE_COST
	cooldown = Balance.JAAGTE_COOLDOWN
	warning_time = Balance.JAAGTE_WARNING
	run_time = Balance.JAAGTE_DURATION


func _ready() -> void:
	_build_banner()
	beam.light_color = Balance.JAAGTE_BEAM_COLOUR
	beam.light_energy = Balance.JAAGTE_BEAM_ENERGY
	beam.spot_range = Balance.JAAGTE_BEAM_HEIGHT + 1.0
	beam.spot_angle = rad_to_deg(atan(Balance.JAAGTE_BEAM_RADIUS / Balance.JAAGTE_BEAM_HEIGHT))
	beam.shadow_enabled = false
	beam.visible = false
	add_child(beam)
	var disc := CylinderMesh.new()
	disc.top_radius = Balance.JAAGTE_BEAM_RADIUS
	disc.bottom_radius = Balance.JAAGTE_BEAM_RADIUS
	disc.height = 0.01
	disc.radial_segments = 32
	pool.mesh = disc
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(Balance.JAAGTE_BEAM_COLOUR, Balance.JAAGTE_POOL_ALPHA)
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool.material_override = glow
	pool.visible = false
	add_child(pool)


# --- Haunting hooks ---
func warn() -> void:
	_show_banner("JAAGTE RAHO! FREEZE OR BRACE!")
	Sfx.play("whistle", 1.0, Balance.JAAGTE_WHISTLE_DB)
	dark_target = 1.0
	last_caught.clear()
	labelled.clear()


func run() -> void:
	_show_banner("JAAGTE RAHO!")
	beam.visible = true
	pool.visible = true


func running(delta: float) -> void:
	var centre: Vector3 = _beam_centre()
	beam.global_position = centre + Vector3.UP * Balance.JAAGTE_BEAM_HEIGHT
	beam.global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	pool.global_position = Vector3(centre.x, 0.03, centre.z)
	for mover: Node in last_caught.keys():
		last_caught[mover] = maxf(0.0, last_caught[mover] - delta)
	for mover: Node in get_tree().get_nodes_in_group("movers"):
		if not mover.in_play or Vector2(mover.global_position.x - centre.x, mover.global_position.z - centre.z).length() > Balance.JAAGTE_BEAM_RADIUS:
			continue
		if mover.is_bracing():
			if not labelled.has(mover):
				labelled[mover] = true
				_popup(mover, Balance.JAAGTE_STATUE_LABEL, Balance.JAAGTE_STATUE_COLOUR)
		elif mover.is_moving() and not mover.is_tumbling() and last_caught.get(mover, 0.0) <= 0.0:
			last_caught[mover] = Balance.JAAGTE_CATCH_GAP
			mover.tumble()
			_popup(mover, "HALT!", Balance.DAMAGE_COLOUR)
			Sfx.play("whistle", 1.3, Balance.JAAGTE_WHISTLE_DB)
			var arena: Node = _arena()
			if arena != null and arena.has_signal("caught_in_beam"):
				arena.caught_in_beam.emit(mover.slot)


func end() -> void:
	banner.hide()
	beam.visible = false
	pool.visible = false
	dark_target = 0.0


func _process(delta: float) -> void:
	# The galleries fade dark through the warning and back when it ends; the arena dims its own lights.
	var next: float = move_toward(darkness, dark_target, delta / Balance.JAAGTE_FADE_TIME)
	if next == darkness:
		return
	darkness = next
	var arena: Node = _arena()
	if arena != null and arena.has_method("set_darkness"):
		arena.set_darkness(darkness)


# --- Helpers ---
func _beam_centre() -> Vector3:
	# The torch shines where Bahadur is: on the ghost, or on the prop he is hiding in.
	if not is_instance_valid(ghost):
		return Vector3.ZERO
	var possessing: Node3D = ghost.get("possessing")
	var at: Vector3 = possessing.global_position if is_instance_valid(possessing) else ghost.global_position
	return Vector3(at.x, 0.0, at.z)


func _arena() -> Node:
	return ghost.get("arena") if is_instance_valid(ghost) else null


func _popup(mover: Node3D, text: String, colour: Color) -> void:
	var popup := Label3D.new()
	popup.text = text
	popup.font = load(Balance.COMIC_FONT_PATH)
	popup.font_size = Balance.PRICE_FONT_SIZE
	popup.modulate = colour
	popup.outline_size = Balance.VALUE_POPUP_OUTLINE
	popup.outline_modulate = Balance.COMIC_INK
	popup.pixel_size = Balance.VALUE_POPUP_PIXEL_SIZE
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	mover.get_parent().add_child(popup)
	popup.global_position = mover.global_position + Vector3.UP * Balance.JAAGTE_POPUP_HEIGHT
	var tween := popup.create_tween()
	tween.tween_interval(Balance.JAAGTE_POPUP_SECONDS)
	tween.tween_property(popup, "modulate:a", 0.0, 0.4)
	tween.tween_callback(popup.queue_free)


func _show_banner(text: String) -> void:
	banner.text = text
	banner.show()


func _build_banner() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(banner)
	banner.add_theme_font_size_override("font_size", Balance.BANNER_FONT_SIZE)
	banner.add_theme_color_override("font_color", Balance.JAAGTE_BANNER_COLOUR)
	banner.add_theme_constant_override("outline_size", Balance.BANNER_OUTLINE_SIZE)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, Balance.BANNER_TOP)
	banner.hide()
