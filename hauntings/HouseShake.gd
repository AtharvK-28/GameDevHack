# House Shake, the Old Mansion's haunting: a 1 s rumble with falling dust and a small camera shake, then 2.5 s in
# which any mover who moves tumbles. Standing still or holding BRACE is the counter. The banner stands in for the
# rumble sound until Phase 7.
class_name HouseShake
extends Haunting

# --- Effects ---
var dust := CPUParticles3D.new()
var banner := Label.new()

# --- Setup ---
func _init() -> void:
	label = "SHAKE"
	cost = Balance.SHAKE_COST
	cooldown = Balance.SHAKE_COOLDOWN
	warning_time = Balance.SHAKE_WARNING
	run_time = Balance.SHAKE_DURATION


func _ready() -> void:
	_build_dust()
	_build_banner()


# --- Haunting hooks ---
func warn() -> void:
	dust.emitting = true
	_show_banner("RUMBLE… STAND STILL OR BRACE!")


func warning(_delta: float) -> void:
	get_tree().call_group("party_camera", "shake", Balance.SHAKE_WARNING_TRAUMA)


func run() -> void:
	_show_banner("HOUSE SHAKE!")


func running(_delta: float) -> void:
	get_tree().call_group("party_camera", "shake", Balance.SHAKE_TRAUMA)
	for mover: Node in get_tree().get_nodes_in_group("movers"):
		if mover.is_moving() and not mover.is_bracing():
			mover.tumble()


func end() -> void:
	dust.emitting = false
	banner.hide()


# --- Visual helpers ---
func _show_banner(text: String) -> void:
	banner.text = text
	banner.show()


func _build_dust() -> void:
	var speck := BoxMesh.new()
	speck.size = Vector3.ONE * Balance.DUST_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Balance.DUST_COLOUR
	speck.material = material
	dust.mesh = speck
	dust.amount = Balance.DUST_AMOUNT
	dust.lifetime = Balance.DUST_LIFETIME
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(Balance.ROOM_WIDTH / 2.0, 0.0, Balance.ROOM_DEPTH / 2.0)
	dust.direction = Vector3.DOWN
	dust.gravity = Vector3.DOWN * Balance.DUST_GRAVITY
	dust.emitting = false
	add_child(dust)
	# This node is not 3D, so the dust's own position is its place in the world.
	dust.position = Vector3(0.0, Balance.DUST_HEIGHT, Balance.ROOM_CENTRE_Z)


func _build_banner() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(banner)
	banner.add_theme_font_size_override("font_size", Balance.BANNER_FONT_SIZE)
	banner.add_theme_color_override("font_color", Balance.DAMAGE_COLOUR)
	banner.add_theme_constant_override("outline_size", Balance.BANNER_OUTLINE_SIZE)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, Balance.BANNER_TOP)
	banner.hide()
