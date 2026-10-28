# The Museum's getaway van (Kenney Car Kit), parked at the loading dock with its back to the building. Same contract
# as the farm truck: the tailgate on the origin and the cab along +X, so ArenaBuilder places it and the delivery zone
# the same way. One solid box, plus the crew's fake sign taped over the side.
extends StaticBody3D

const MODEL_PATH: String = "res://assets/models/vehicles/kenney/van.glb"

func _ready() -> void:
	collision_layer = Balance.WORLD_LAYER
	collision_mask = 0
	var model: Node3D = load(MODEL_PATH).instantiate()
	var box: AABB = MuseumKit.bounds(model)
	var fit: float = Balance.VAN_LENGTH / box.size.z
	model.scale = Vector3.ONE * fit
	# The model's front points +Z; turn it to +X and put its back bumper on the origin.
	model.rotation.y = PI / 2.0
	model.position = Vector3(-box.position.z, -box.position.y, box.get_center().x) * fit
	add_child(model)
	ComicLook.apply(model, true)

	var size := Vector3(Balance.VAN_LENGTH, box.size.y * fit, box.size.x * fit)
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = size
	shape.shape = solid
	shape.position = size / 2.0 * Vector3(1, 1, 0)
	add_child(shape)

	for side: float in [-1.0, 1.0]:
		_lettering(Balance.VAN_SIGN_TITLE, Balance.VAN_SIGN_COLOUR, size, Balance.VAN_SIGN_TITLE_WIDTH, Balance.VAN_SIGN_TITLE_HEIGHT, side)
		_lettering(Balance.VAN_SIGN_SUBTITLE, Balance.VAN_SIGN_SUBTITLE_COLOUR, size, Balance.VAN_SIGN_SUBTITLE_WIDTH, Balance.VAN_SIGN_SUBTITLE_HEIGHT, side)


# One line of the side sign, measured with its font and scaled so it spans the given share of the van's length.
func _lettering(text: String, colour: Color, size: Vector3, width_share: float, height_share: float, side: float) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.font = load(Balance.COMIC_FONT_PATH)
	sign.font_size = Balance.VAN_SIGN_FONT_SIZE
	var pixels: float = sign.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Balance.VAN_SIGN_FONT_SIZE).x
	sign.pixel_size = size.x * width_share / pixels
	sign.modulate = colour
	sign.outline_modulate = Balance.COMIC_INK
	sign.outline_size = Balance.VAN_SIGN_OUTLINE
	sign.position = Vector3(size.x * Balance.VAN_SIGN_PANEL_CENTRE, size.y * height_share, side * size.z / 2.0 * Balance.VAN_SIGN_INSET)
	sign.rotation.y = 0.0 if side > 0.0 else PI
	add_child(sign)
