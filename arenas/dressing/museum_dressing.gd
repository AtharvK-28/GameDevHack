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
	["PHARAOH\n(on loan)", Vector3(1.2, 2.3, 5.6), 90.0],
]

var layout: Dictionary
var skull_plaque: Label3D # Says whether the skull is on its neck, or "removed for cleaning".
var plaque_check: float = 0.0
var steel: StandardMaterial3D

func _ready() -> void:
	layout = ArenaBuilder.load_layout(get_parent().LAYOUT_PATH)
	_build_pedestals()
	for exhibit: Array in EXHIBITS:
		_exhibit(exhibit[0], exhibit[1], exhibit[2], exhibit[3], exhibit[4])
	_build_pharaoh()
	_build_paintings()
	_build_skeleton()
	for sign: Array in SIGNS:
		_sign(sign[0], sign[1], sign[2])


# --- Pedestals and plinths ---
func _build_pedestals() -> void:
	for spot: Dictionary in layout.spawns.loot:
		var top: float = spot.get("floor", 0.0)
		var at := Vector3(spot.at[0], 0.0, spot.at[1])
		if spot.role == "skull":
			_armature_post(Vector3(at.x, 0.0, at.z), top) # The skull rests on a steel bracket at the end of the neck.
			MuseumKit.solid(self, "SkullRest", Vector3(at.x, top / 2.0, at.z), Vector3(0.5, top, 0.5))
		elif top > 0.0:
			MuseumKit.place(self, POLY % "pedestal_a", at, top)
			MuseumKit.solid(self, "Pedestal-" + spot.id, Vector3(at.x, top / 2.0, at.z), Vector3(Balance.MUSEUM_PEDESTAL_WIDTH, top, Balance.MUSEUM_PEDESTAL_WIDTH))


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


# --- The T-Rex skeleton ---
func _build_skeleton() -> void:
	# A headless T-Rex skeleton along the back of the rotunda, built from bone-coloured shapes on a steel armature.
	# Its neck ends a metre short of the skull's bracket, so a carrier can stand at the skull's back handle; after the
	# skull is gone it stands headless beside its plaque.
	var neck: Vector3 = Balance.SKULL_NECK
	var start: float = neck.x + 1.1 + Balance.SKELETON_GAP # Where the vertebrae begin, behind the skull.
	var z: float = neck.z
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Balance.SKELETON_BONE
	bone.roughness = 0.7
	var root := Node3D.new()
	root.name = "TRexSkeleton"
	add_child(root)
	# Neck rising from the bracket to the shoulders, the back to the hips, and the tail sweeping down.
	var spine: Array[Vector3] = [Vector3(start, 1.25, z), Vector3(start + 0.5, 1.55, z), Vector3(start + 1.0, 1.85, z), Vector3(start + 1.6, 2.05, z),
		Vector3(start + 2.3, 2.15, z), Vector3(start + 3.0, 2.2, z), Vector3(start + 3.6, 2.05, z), Vector3(start + 4.1, 1.75, z),
		Vector3(start + 4.6, 1.4, z), Vector3(start + 5.0, 1.0, z)]
	for index: int in range(spine.size() - 1):
		var radius: float = lerpf(0.12, 0.05, float(index) / spine.size())
		_bone(root, spine[index], spine[index + 1], radius, bone)
		var block := MeshInstance3D.new()
		var vertebra := BoxMesh.new()
		vertebra.size = Vector3(0.12, radius * 3.2, radius * 1.6)
		block.mesh = vertebra
		block.material_override = bone
		block.position = spine[index] + Vector3.UP * radius
		root.add_child(block)
	# Ribs hang from the back in pairs, curving out and down.
	for step: int in range(6):
		var x: float = start + 1.5 + step * 0.32
		var top := Vector3(x, 2.05, z)
		var depth: float = 0.75 - absf(step - 2.5) * 0.12
		for side: float in [-1.0, 1.0]:
			var mid := Vector3(x + 0.05, 2.05 - depth * 0.5, z + side * 0.42)
			var low := Vector3(x + 0.12, 2.05 - depth, z + side * 0.18)
			_bone(root, top, mid, 0.03, bone)
			_bone(root, mid, low, 0.025, bone)
	# Hips, legs and feet, and the famous tiny arms.
	var hip := Vector3(start + 3.0, 2.0, z)
	for side: float in [-1.0, 1.0]:
		var thigh: Vector3 = hip + Vector3(0.0, 0.0, side * 0.32)
		var knee := Vector3(start + 3.35, 1.1, z + side * 0.36)
		var ankle := Vector3(start + 2.95, 0.3, z + side * 0.36)
		_bone(root, thigh, knee, 0.09, bone)
		_bone(root, knee, ankle, 0.07, bone)
		_bone(root, ankle, ankle + Vector3(-0.45, -0.25, 0.0), 0.05, bone)
		var shoulder := Vector3(start + 1.4, 1.75, z + side * 0.3)
		var elbow: Vector3 = shoulder + Vector3(-0.2, -0.25, side * 0.08)
		_bone(root, shoulder, elbow, 0.03, bone)
		_bone(root, elbow, elbow + Vector3(-0.15, 0.08, 0.0), 0.025, bone)
	var pelvis := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.4, 0.55)
	pelvis.mesh = box
	pelvis.material_override = bone
	pelvis.position = hip
	root.add_child(pelvis)
	ComicLook.apply(root, true)
	# The steel armature and a low dark marble base, and one box that keeps movers out of the bones.
	_armature_post(Vector3(start + 0.3, 0.0, z), 1.35)
	_armature_post(Vector3(start + 3.0, 0.0, z), 1.85)
	_armature_post(Vector3(start + 4.6, 0.0, z), 1.35)
	_bone(self, Vector3(neck.x + 0.6, neck.y + 0.05, z), spine[0], 0.03, _steel())
	var base := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(5.6, 0.06, 1.7)
	base.mesh = slab
	base.material_override = load("res://assets/materials/surfaces/marble_dark.tres")
	base.position = Vector3(start + 2.6, 0.03, z)
	add_child(base)
	MuseumKit.solid(self, "Skeleton", Vector3(start + 2.6, 1.2, z), Vector3(5.6, 2.4, 1.3))
	skull_plaque = Label3D.new()
	skull_plaque.font = load(Balance.COMIC_FONT_PATH)
	skull_plaque.font_size = Balance.MUSEUM_SIGN_FONT_SIZE
	skull_plaque.pixel_size = Balance.MUSEUM_SIGN_PIXEL_SIZE
	skull_plaque.modulate = Balance.MUSEUM_SIGN_COLOUR
	skull_plaque.outline_modulate = Balance.COMIC_INK
	skull_plaque.outline_size = Balance.MUSEUM_SIGN_OUTLINE
	skull_plaque.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	skull_plaque.position = Vector3(start + 2.4, 2.9, z)
	skull_plaque.text = Balance.SKELETON_PLAQUE
	add_child(skull_plaque)


func _process(delta: float) -> void:
	plaque_check -= delta
	if skull_plaque == null or plaque_check > 0.0:
		return
	plaque_check = 0.5
	var on_neck: bool = false
	for item: Node in get_tree().get_nodes_in_group("loot"):
		if item is TRexSkull and Vector2(item.global_position.x - Balance.SKULL_NECK.x, item.global_position.z - Balance.SKULL_NECK.z).length() < 1.0:
			on_neck = true
	skull_plaque.text = Balance.SKELETON_PLAQUE if on_neck else Balance.SKELETON_PLAQUE_HEADLESS


func _armature_post(foot: Vector3, height: float) -> void:
	var post := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.035
	shape.bottom_radius = 0.035
	shape.height = height
	post.mesh = shape
	post.material_override = _steel()
	post.position = foot + Vector3.UP * height / 2.0
	add_child(post)
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.25
	disc.height = 0.04
	plate.mesh = disc
	plate.material_override = _steel()
	plate.position = foot + Vector3.UP * 0.02
	add_child(plate)


func _bone(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var piece := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius * 1.15
	shape.height = from.distance_to(to)
	shape.radial_segments = 6
	shape.rings = 1
	piece.mesh = shape
	piece.material_override = material
	parent.add_child(piece)
	var direction: Vector3 = to - from
	var up: Vector3 = Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.FORWARD
	piece.global_transform = Transform3D(Basis.looking_at(direction, up) * Basis(Vector3.RIGHT, PI / 2.0), (from + to) / 2.0)


func _steel() -> StandardMaterial3D:
	if steel == null:
		steel = StandardMaterial3D.new()
		steel.albedo_color = Balance.SKELETON_STEEL
		steel.metallic = 0.4
		steel.roughness = 0.5
	return steel


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
