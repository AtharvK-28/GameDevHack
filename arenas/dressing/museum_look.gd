# What makes the Museum read as a museum at night: a spotlight over every exhibit in otherwise dim galleries, velvet
# ropes on brass posts, plaques, a name plate beside each doorway, green EXIT signs, a runner carpet down the grand
# hall, a reception desk, a UFO hanging in the Space Gallery, gold in a glass case, the classical facade on the
# camera side (a FadeWall, so it turns see-through when it hides a player) and the loading dock's bay markings.
# Visual only, except the facade columns and the desk, which block like walls; walking routes stay clear.
extends Node3D

const POLY: String = "res://assets/models/museum/polypizza/%s.glb"

# Plaques: text, where it stands (x, z), yaw in degrees.
const PLAQUES: Array[Array] = [
	["TRICERATOPS\nLife-size. Mostly.", Vector2(23.8, 4.4), 0.0],
	["PARASAUROLOPHUS\nHonks when nobody looks.", Vector2(27.6, 4.6), 0.0],
	["ASTRONAUT\nReal suit. Fake moon.", Vector2(22.4, 13.4), 0.0],
	["UFO\nRecovered. Do not ask.", Vector2(24.6, 13.6), 0.0],
	["MONA LISA'S COUSIN\nSmiles less.", Vector2(8.9, 10.4), -60.0],
	["GOLD\nDefinitely real.", Vector2(17.2, 6.9), 0.0],
]
# Name plates beside doorways: text, centre (x, height, z), which way it faces (yaw in degrees).
const NAME_PLATES: Array[Array] = [
	["ROTUNDA", Vector3(12.5, 2.25, 8.13), 0.0],
	["EGYPT", Vector3(2.5, 2.25, 8.13), 0.0],
	["JURASSIC HALL", Vector3(28.0, 2.25, 8.13), 0.0],
	["GRAND HALL", Vector3(11.8, 2.25, 15.13), 0.0],
	["SPACE", Vector3(22.4, 2.25, 15.13), 0.0],
	["ART", Vector3(10.13, 2.25, 9.4), 90.0],
	["SPACE", Vector3(19.87, 2.25, 9.4), -90.0],
	["LASER HALL\nstaff only", Vector3(12.13, 2.25, 19.3), 90.0],
]
const EXIT_SIGNS: Array[Vector3] = [Vector3(2.1, 2.55, 19.75), Vector3(26.5, 2.55, 19.75)]
# Velvet ropes: centre (x, z) and half size (x, z) of the roped-off rectangle.
const ROPES: Array[Array] = [
	[Vector2(16.85, 2.3), Vector2(2.6, 0.95)],
	[Vector2(23.8, 2.4), Vector2(1.9, 1.3)],
	[Vector2(27.6, 2.6), Vector2(1.2, 1.4)],
	[Vector2(24.2, 12.0), Vector2(2.5, 1.0)],
	[Vector2(1.0, 5.6), Vector2(0.75, 0.9)],
]
const FACADE_COLUMNS: Array[float] = [5.4, 8.6, 11.8, 15.0, 18.2, 21.4] # x of each column along the front.

var layout: Dictionary
var gold := StandardMaterial3D.new()
var velvet := StandardMaterial3D.new()

func _ready() -> void:
	layout = ArenaBuilder.load_layout(get_parent().LAYOUT_PATH)
	gold.albedo_color = Balance.MUSEUM_GOLD
	gold.metallic = 0.6
	gold.roughness = 0.35
	velvet.albedo_color = Balance.MUSEUM_VELVET
	_spotlights()
	for rope: Array in ROPES:
		_rope_ring(rope[0], rope[1])
	for plaque: Array in PLAQUES:
		_plaque(plaque[0], plaque[1], plaque[2])
	for plate: Array in NAME_PLATES:
		_name_plate(plate[0], plate[1], plate[2])
	for at: Vector3 in EXIT_SIGNS:
		_exit_sign(at)
	_runner()
	_desk()
	_ufo()
	_gold_case()
	_facade()
	_dock()


# --- Light ---
func _spotlights() -> void:
	# A narrow warm light straight down on every exhibit; the galleries' own lights stay dim.
	var targets: Array[Vector2] = []
	for spot: Dictionary in layout.spawns.loot:
		targets.append(Vector2(spot.at[0], spot.at[1]))
	for exhibit: Array in get_parent().get_node("MuseumDressing").EXHIBITS:
		if not String(exhibit[0]).contains("column") and not String(exhibit[0]).contains("bench"):
			targets.append(exhibit[1])
	targets.append_array([Vector2(1.0, 5.6), Vector2(18.4, 6.4), Vector2(9.5, 9.1), Vector2(9.5, 14.0), Vector2(16.0, 2.3), Vector2(17.6, 2.3)])
	for target: Vector2 in targets:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(target.x, Balance.MUSEUM_SPOT_HEIGHT, target.y)
		lamp.rotation_degrees = Vector3(-90, 0, 0)
		lamp.light_color = Balance.MUSEUM_SPOT_COLOUR
		lamp.light_energy = Balance.MUSEUM_SPOT_ENERGY
		lamp.spot_range = Balance.MUSEUM_SPOT_HEIGHT + 1.0
		lamp.spot_angle = Balance.MUSEUM_SPOT_ANGLE
		lamp.shadow_enabled = false
		add_child(lamp)


# --- Ropes, plaques and signs ---
func _rope_ring(centre: Vector2, half: Vector2) -> void:
	var corners: Array[Vector2] = [centre + Vector2(-half.x, -half.y), centre + Vector2(half.x, -half.y), centre + Vector2(half.x, half.y), centre + Vector2(-half.x, half.y)]
	for index: int in corners.size():
		var a: Vector2 = corners[index]
		var b: Vector2 = corners[(index + 1) % corners.size()]
		var posts: int = maxi(1, ceili(a.distance_to(b) / Balance.MUSEUM_ROPE_SPAN))
		for step: int in range(posts):
			var from: Vector2 = a.lerp(b, float(step) / posts)
			var to: Vector2 = a.lerp(b, float(step + 1) / posts)
			_post(from)
			_rope(from, to)


func _post(at: Vector2) -> void:
	var post := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.03
	shape.bottom_radius = 0.05
	shape.height = Balance.MUSEUM_ROPE_HEIGHT
	post.mesh = shape
	post.material_override = gold
	post.position = Vector3(at.x, Balance.MUSEUM_ROPE_HEIGHT / 2.0, at.y)
	add_child(post)
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.055
	ball.height = 0.11
	knob.mesh = ball
	knob.material_override = gold
	knob.position = Vector3(at.x, Balance.MUSEUM_ROPE_HEIGHT, at.y)
	add_child(knob)


func _rope(from: Vector2, to: Vector2) -> void:
	# Two straight pieces dipping to the middle, which reads as a sagging velvet rope.
	var a := Vector3(from.x, Balance.MUSEUM_ROPE_HEIGHT - 0.04, from.y)
	var c := Vector3(to.x, Balance.MUSEUM_ROPE_HEIGHT - 0.04, to.y)
	var b: Vector3 = (a + c) / 2.0 + Vector3.DOWN * Balance.MUSEUM_ROPE_SAG
	for piece: Array in [[a, b], [b, c]]:
		var start: Vector3 = piece[0]
		var end: Vector3 = piece[1]
		var rope := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.022
		tube.bottom_radius = 0.022
		tube.height = start.distance_to(end)
		tube.radial_segments = 6
		rope.mesh = tube
		rope.material_override = velvet
		add_child(rope)
		rope.global_transform = Transform3D(Basis.looking_at(end - start, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0), (start + end) / 2.0)


func _plaque(text: String, at: Vector2, yaw: float) -> void:
	var stand := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.95, 0.06)
	stand.mesh = box
	stand.material_override = gold
	stand.position = Vector3(at.x, 0.475, at.y)
	add_child(stand)
	var board := MeshInstance3D.new()
	var face := BoxMesh.new()
	face.size = Vector3(0.62, 0.36, 0.03)
	board.mesh = face
	board.material_override = _flat(Balance.MUSEUM_PLAQUE_COLOUR)
	board.position = Vector3(at.x, 1.0, at.y)
	board.rotation = Vector3(deg_to_rad(-30), deg_to_rad(yaw), 0)
	add_child(board)
	var label := _text(text, Balance.MUSEUM_PLAQUE_FONT_SIZE, Balance.MUSEUM_PLAQUE_INK)
	label.outline_size = 0
	label.position = Vector3(0, 0, 0.02)
	board.add_child(label)


func _name_plate(text: String, at: Vector3, yaw: float) -> void:
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.7, 0.42 if not text.contains("\n") else 0.6, 0.03)
	plate.mesh = box
	plate.material_override = gold
	plate.position = at
	plate.rotation.y = deg_to_rad(yaw)
	add_child(plate)
	var label := _text(text, Balance.MUSEUM_PLATE_FONT_SIZE, Balance.MUSEUM_PLATE_INK)
	label.outline_size = 0
	label.position = Vector3(0, 0, 0.02)
	plate.add_child(label)


func _exit_sign(at: Vector3) -> void:
	var label := _text("EXIT", Balance.MUSEUM_PLATE_FONT_SIZE, Balance.MUSEUM_EXIT_GREEN)
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.modulate = Balance.MUSEUM_EXIT_GREEN * 2.2 # Over 1, so it glows.
	add_child(label)


func _text(text: String, size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load(Balance.COMIC_FONT_PATH)
	label.font_size = size
	label.pixel_size = Balance.MUSEUM_PLAQUE_PIXEL_SIZE
	label.modulate = colour
	label.outline_modulate = Balance.COMIC_INK
	return label


# --- Furnishings ---
func _runner() -> void:
	var carpet := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 0.02, 14.0)
	carpet.mesh = box
	carpet.material_override = velvet
	carpet.position = Vector3(15.0, 0.035, 8.0)
	add_child(carpet)


func _desk() -> void:
	# The lobby's reception desk, with a glass donation box on it.
	var wood: StandardMaterial3D = load("res://assets/materials/surfaces/trim_walnut.tres")
	var top: StandardMaterial3D = load("res://assets/materials/surfaces/marble_dark.tres")
	_box(Vector3(2.6, 1.0, 0.7), Vector3(15.6, 0.5, 19.15), wood)
	_box(Vector3(2.7, 0.06, 0.8), Vector3(15.6, 1.03, 19.15), top)
	var glass := _flat(Color(0.75, 0.9, 1.0, 0.35))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(0.3, 0.3, 0.3), Vector3(16.5, 1.21, 19.15), glass)
	MuseumKit.solid(self, "Desk", Vector3(15.6, 0.5, 19.15), Vector3(2.7, 1.0, 0.8))
	var sign := _text("DONATIONS\n(please)", Balance.MUSEUM_PLAQUE_FONT_SIZE, Balance.MUSEUM_SIGN_COLOUR)
	sign.position = Vector3(16.5, 1.55, 19.15)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign)


func _ufo() -> void:
	var holder: Node3D = MuseumKit.place(self, POLY % "ufo", Vector3(24.6, Balance.MUSEUM_UFO_HEIGHT, 11.6), 0.55)
	holder.rotation_degrees = Vector3(8, 25, -6) # Hung a little crooked.
	# The model's own paint is near black in the dark gallery: brushed silver, with a faint glow.
	for mesh: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		for index: int in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_surface_override_material(index) as BaseMaterial3D
			if material != null:
				material.albedo_color = Balance.MUSEUM_UFO_COLOUR
				material.albedo_texture = null
				material.emission_enabled = true
				material.emission = Balance.MUSEUM_UFO_GLOW
	for side: float in [-0.6, 0.6]:
		var wire := MeshInstance3D.new()
		var line := CylinderMesh.new()
		line.top_radius = 0.008
		line.bottom_radius = 0.008
		line.height = 3.0 - Balance.MUSEUM_UFO_HEIGHT
		wire.mesh = line
		wire.material_override = _flat(Color("20252c"))
		wire.position = Vector3(24.6 + side, (3.0 + Balance.MUSEUM_UFO_HEIGHT) / 2.0 + 0.3, 11.6)
		add_child(wire)


func _gold_case() -> void:
	# Gold ingots in a glass case on a dark marble plinth in the rotunda's corner.
	_box(Vector3(0.9, 0.8, 0.7), Vector3(18.4, 0.4, 6.4), load("res://assets/materials/surfaces/marble_dark.tres"))
	MuseumKit.place(self, POLY % "gold_ingots", Vector3(18.4, 0.8, 6.4), 0.35)
	var glass := _flat(Color(0.75, 0.9, 1.0, 0.25))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(0.86, 0.6, 0.66), Vector3(18.4, 1.1, 6.4), glass)
	MuseumKit.solid(self, "GoldCase", Vector3(18.4, 0.7, 6.4), Vector3(0.9, 1.4, 0.7))


# --- The facade, on the camera side ---
func _facade() -> void:
	# Marble columns along the front, a beam across them and a stepped pediment with the museum's name. A FadeWall,
	# so the camera's line test turns it see-through whenever it hides a player, like the walls behind it.
	var marble: StandardMaterial3D = load("res://assets/materials/surfaces/marble_floor.tres")
	var body := FadeWall.new()
	body.name = "Facade"
	body.collision_layer = Balance.WORLD_LAYER
	body.collision_mask = 0
	get_parent().add_child.call_deferred(body)
	var z: float = 20.0 + Balance.MUSEUM_FACADE_DEPTH
	var left: float = FACADE_COLUMNS[0] - 0.6
	var right: float = FACADE_COLUMNS[-1] + 0.6
	var height: float = Balance.MUSEUM_FACADE_HEIGHT
	for x: float in FACADE_COLUMNS:
		var column := AABB(Vector3(x - 0.25, 0.0, z - 0.25), Vector3(0.5, height, 0.5))
		ArenaBuilder._add_mesh(body, column, marble, true)
		ArenaBuilder._add_box_shape(body, column)
	var beam := AABB(Vector3(left, height, z - 0.35), Vector3(right - left, 0.45, 0.7))
	ArenaBuilder._add_mesh(body, beam, marble, true)
	var middle: float = (left + right) / 2.0
	for step: int in range(3):
		var width: float = (right - left) * (0.62 - step * 0.2)
		var layer := AABB(Vector3(middle - width / 2.0, height + 0.45 + step * 0.32, z - 0.3), Vector3(width, 0.32, 0.6))
		ArenaBuilder._add_mesh(body, layer, marble, true)
	body.box = AABB(Vector3(left, 0.0, z - 0.4), Vector3(right - left, height + 1.5, 0.8))
	var name_label := _text("MUSEUM OF MOSTLY REAL THINGS", Balance.MUSEUM_FACADE_FONT_SIZE, Balance.MUSEUM_PLATE_INK)
	name_label.outline_size = 0
	name_label.position = Vector3(middle, height + 0.22, z + 0.36)
	body.add_child(name_label)


# --- The loading dock ---
func _dock() -> void:
	var paint := _flat(Balance.MUSEUM_DOCK_PAINT)
	for line: Array in [[Vector3(0.6, 0.0, 21.0), Vector3(0.1, 0.02, 7.0)], [Vector3(4.6, 0.0, 21.0), Vector3(0.1, 0.02, 7.0)], [Vector3(2.6, 0.0, 20.9), Vector3(4.0, 0.02, 0.1)]]:
		_box(line[1], line[0] + Vector3(line[1].x / 2.0 if line[1].x < 1.0 else 0.0, 0.025, line[1].z / 2.0 if line[1].z > 1.0 else 0.0), paint)
	var crate := _flat(Color("8a6239"))
	for at: Vector3 in [Vector3(9.0, 0.35, 26.6), Vector3(9.8, 0.35, 26.6), Vector3(9.4, 1.05, 26.6), Vector3(29.0, 0.35, 23.5)]:
		_box(Vector3(0.7, 0.7, 0.7), at, crate)
		MuseumKit.solid(self, "Crate", at, Vector3(0.7, 0.7, 0.7))


# --- Helpers ---
func _box(size: Vector3, centre: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = centre
	add_child(mesh)
	return mesh


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	return material
