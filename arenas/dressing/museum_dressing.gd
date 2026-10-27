# The Museum's exhibits: pedestals under the small loot spots, the skull's plinth, dinosaurs in the Jurassic Hall,
# the Space Gallery's astronaut and genuine alien, a pharaoh in Egypt, paintings, columns and the lobby sign.
# Models are CC0 (assets/CREDITS.md), placed at real sizes by MuseumKit; exhibits that block movers get a box.
# Runs before the arena spawns loot (children are ready first), so loot lands on the pedestals.
extends Node3D

const POLY: String = "res://assets/models/museum/polypizza/%s.glb"
const SPACE: String = "res://assets/models/space/kenney/%s.glb"

# Exhibits: model, where it stands (x, z), height in metres, yaw in degrees, and whether it blocks movers.
const EXHIBITS: Array[Array] = [
	[POLY % "triceratops", Vector2(23.8, 2.4), 1.7, 90.0, true],
	[POLY % "parasaurolophus", Vector2(27.6, 2.6), 2.6, -60.0, true],
	[SPACE % "astronautA", Vector2(22.4, 12.2), 1.8, 30.0, true],
	[SPACE % "alien", Vector2(26.0, 11.8), 1.6, -10.0, true],
	[SPACE % "rover", Vector2(29.0, 11.6), 0.9, -90.0, true],
	[SPACE % "satelliteDish_detailed", Vector2(29.0, 9.0), 1.5, -120.0, true],
	[POLY % "column_a", Vector2(10.7, 8.7), 2.9, 0.0, true],
	[POLY % "column_a", Vector2(19.3, 8.7), 2.9, 0.0, true],
	[POLY % "column_a", Vector2(10.7, 14.3), 2.9, 0.0, true],
	[POLY % "column_a", Vector2(19.3, 14.3), 2.9, 0.0, true],
	[POLY % "bench_a", Vector2(18.5, 19.3), 0.5, 0.0, true],
	[POLY % "bench_a", Vector2(22.0, 19.3), 0.5, 0.0, true],
	[POLY % "armor_golden", Vector2(0.7, 9.8), 1.0, 90.0, false],
]

# Signs: text, where (x, height, z), yaw in degrees.
const SIGNS: Array[Array] = [
	["MUSEUM OF\nMOSTLY REAL THINGS", Vector3(20.5, 2.4, 19.85), 180.0],
	["ALIEN\n(100% genuine)", Vector3(26.0, 2.0, 11.0), 0.0],
	["T-REX SKULL\nPlease do not touch", Vector3(15.0, 1.6, 2.4), 0.0],
	["PHARAOH\n(on loan)", Vector3(1.2, 2.3, 5.6), 90.0],
]

var layout: Dictionary

func _ready() -> void:
	layout = ArenaBuilder.load_layout(get_parent().LAYOUT_PATH)
	_build_pedestals()
	for exhibit: Array in EXHIBITS:
		_exhibit(exhibit[0], exhibit[1], exhibit[2], exhibit[3], exhibit[4])
	_build_pharaoh()
	_build_paintings()
	for sign: Array in SIGNS:
		_sign(sign[0], sign[1], sign[2])


# --- Pedestals and plinths ---
func _build_pedestals() -> void:
	for spot: Dictionary in layout.spawns.loot:
		var top: float = spot.get("floor", 0.0)
		var at := Vector3(spot.at[0], 0.0, spot.at[1])
		if spot.role == "skull":
			_block("SkullPlinth", Vector3(at.x, top / 2.0, at.z), Vector3(Balance.MUSEUM_SKULL_PLINTH.x, top, Balance.MUSEUM_SKULL_PLINTH.y))
		elif top > 0.0:
			MuseumKit.place(self, POLY % "pedestal_a", at, top)
			MuseumKit.solid(self, "Pedestal-" + spot.id, Vector3(at.x, top / 2.0, at.z), Vector3(Balance.MUSEUM_PEDESTAL_WIDTH, top, Balance.MUSEUM_PEDESTAL_WIDTH))


func _block(node_name: String, centre: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = load("res://assets/materials/surfaces/stone_facade.tres")
	mesh.position = centre
	add_child(mesh)
	MuseumKit.solid(self, node_name, centre, size)


# --- Exhibits ---
func _exhibit(path: String, at: Vector2, height: float, yaw: float, blocks: bool) -> void:
	var holder: Node3D = MuseumKit.place(self, path, Vector3(at.x, 0.0, at.y), height, yaw)
	if not blocks:
		return
	var model: Node3D = holder.get_child(0)
	var box: AABB = MuseumKit.bounds(model)
	var size: Vector3 = box.size * model.scale.x * Balance.MUSEUM_EXHIBIT_COLLIDER
	MuseumKit.solid(holder, "Solid", Vector3(0.0, size.y / 2.0, 0.0), size)


func _build_pharaoh() -> void:
	# An upright gold sarcophagus against the Egypt wall, built from boxes in the Kenney style.
	var root := Node3D.new()
	root.name = "Pharaoh"
	root.position = Vector3(0.55, 0.0, 5.6)
	root.rotation.y = PI / 2.0
	add_child(root)
	var parts: Array = [
		[Vector3(0.75, 1.9, 0.45), Vector3(0, 0.95, 0), Balance.MUSEUM_GOLD],
		[Vector3(0.5, 0.55, 0.06), Vector3(0, 1.5, 0.24), Balance.MUSEUM_SKIN],
		[Vector3(0.62, 0.14, 0.07), Vector3(0, 1.12, 0.24), Balance.MUSEUM_LAPIS],
		[Vector3(0.62, 0.1, 0.07), Vector3(0, 0.75, 0.24), Balance.MUSEUM_LAPIS],
		[Vector3(0.62, 0.1, 0.07), Vector3(0, 0.45, 0.24), Balance.MUSEUM_LAPIS],
	]
	for part: Array in parts:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		material.roughness = 0.6
		mesh.material_override = material
		mesh.position = part[1]
		root.add_child(mesh)
	ComicLook.apply(root, true)
	MuseumKit.solid(self, "PharaohSolid", Vector3(0.55, 0.95, 5.6), Vector3(0.45, 1.9, 0.75))


func _build_paintings() -> void:
	# Two of the Mansion's built oil paintings hung on the Art Gallery's grand-hall wall.
	var scene: PackedScene = load("res://props/catalog/built/Painting.tscn")
	for z: float in [9.1, 14.0]:
		var painting: Node3D = scene.instantiate()
		painting.position = Vector3(9.88, Balance.MUSEUM_PAINTING_HEIGHT, z)
		painting.rotation.y = -PI / 2.0
		painting.scale = Vector3.ONE * Balance.MUSEUM_PAINTING_SCALE
		add_child(painting)
		ComicLook.apply(painting, true)


func _sign(text: String, at: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load(Balance.COMIC_FONT_PATH)
	label.font_size = Balance.MUSEUM_SIGN_FONT_SIZE
	label.pixel_size = Balance.MUSEUM_SIGN_PIXEL_SIZE
	label.modulate = Balance.MUSEUM_SIGN_COLOUR
	label.outline_modulate = Balance.COMIC_INK
	label.outline_size = Balance.MUSEUM_SIGN_OUTLINE
	label.position = at
	label.rotation.y = deg_to_rad(yaw)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y # Always readable from the party camera.
	add_child(label)
