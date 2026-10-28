# The Museum's surroundings: a city block at night instead of an empty ground plane. In front, a paved forecourt
# with a fountain, benches and an opening-hours sign, hedges, a pavement with street lamps, a kerb and a two-lane
# street with a zebra crossing and parked cars; flagpoles with exhibition banners at the front corners; lawns, trees
# and a paved path round the sides and back; a stone plinth band round the building and a cornice on its far walls;
# and a skyline of lit office blocks behind and beside it, with water tanks on the roofs. Only things a mover can
# reach collide (the fountain, benches, sign, hedges, trees and cars); the skyline sits outside the movers' bounds.
extends Node3D

const TOWN: String = "res://assets/models/decor/town/%s.glb"
const ROADS: String = "res://assets/models/decor/roads/%s.glb"
const NATURE: String = "res://assets/models/decor/nature/%s.glb"
const CARS: String = "res://assets/models/vehicles/kenney/%s.glb"
const POLY: String = "res://assets/models/museum/polypizza/%s.glb"

const STREET_X := Vector2(-40.0, 70.0) # Where the street and pavements run, west to east.
const PAVEMENT_Z := Vector2(28.0, 30.5) # Front pavement, between the forecourt and the kerb.
const STREET_Z := Vector2(30.5, 37.5)
const FAR_PAVEMENT_Z := Vector2(37.5, 40.0)
const LAMPS: Array[float] = [-6.0, 3.0, 12.0, 21.0, 30.0, 39.0] # x of each street lamp on the front pavement.
const CARS_PARKED: Array[Array] = [["taxi", 7.5], ["sedan", 21.0], ["police", 35.0], ["suv", -8.0]]
const TREES: Array[Vector2] = [
	Vector2(-4.0, 3.0), Vector2(-4.5, 9.5), Vector2(-4.0, 16.0), Vector2(34.0, 3.5), Vector2(34.5, 10.0), Vector2(34.0, 16.5),
	Vector2(4.0, -4.0), Vector2(12.0, -4.5), Vector2(19.0, -4.0), Vector2(26.0, -4.5),
	Vector2(-2.0, 41.5), Vector2(10.0, 41.5), Vector2(22.0, 41.5), Vector2(34.0, 41.5),
]
const HEDGE_RUNS: Array[Array] = [[9.4, 12.6], [17.4, 29.8], [-6.0, -0.6], [30.6, 36.0]] # x spans along the forecourt's edge.
# Skyline blocks: centre (x, z), footprint (x, z), height.
const BLOCKS: Array[Array] = [
	[Vector2(-20, -16), Vector2(10, 8), 14.0], [Vector2(-8, -18), Vector2(9, 7), 9.0], [Vector2(4, -17), Vector2(11, 8), 17.0],
	[Vector2(16, -19), Vector2(8, 7), 11.0], [Vector2(27, -17), Vector2(10, 8), 15.0], [Vector2(39, -18), Vector2(9, 8), 10.0],
	[Vector2(51, -16), Vector2(10, 9), 18.0], [Vector2(-22, -2), Vector2(8, 10), 12.0], [Vector2(-22, 12), Vector2(8, 10), 8.0],
	[Vector2(-23, 25), Vector2(9, 9), 13.0], [Vector2(52, -2), Vector2(8, 10), 9.0], [Vector2(53, 12), Vector2(9, 10), 14.0],
	[Vector2(52, 25), Vector2(8, 9), 11.0], [Vector2(-12, 48), Vector2(12, 7), 5.0], [Vector2(6, 48), Vector2(14, 7), 4.0],
	[Vector2(25, 48), Vector2(12, 7), 5.5], [Vector2(43, 48), Vector2(12, 7), 4.5],
]

var paint := {}

func _ready() -> void:
	_ground()
	_street()
	_forecourt()
	_greenery()
	_lamps()
	_flags()
	_cars()
	_building_trim()
	_skyline()


# --- Ground: paths round the building, pavements, kerbs and the street ---
func _ground() -> void:
	var paving: Material = _surface("paving")
	_slab(Rect2(-2.5, -2.5, 35.0, 2.5), paving) # Path behind the building.
	_slab(Rect2(-2.5, 0.0, 2.5, 20.0), paving)
	_slab(Rect2(30.0, 0.0, 2.5, 20.0), paving)
	_slab(Rect2(-8.0, 20.0, 8.0, 8.0), paving) # Side plazas either side of the dock and forecourt.
	_slab(Rect2(30.0, 20.0, 8.0, 8.0), paving)
	_slab(Rect2(STREET_X.x, PAVEMENT_Z.x, STREET_X.y - STREET_X.x, PAVEMENT_Z.y - PAVEMENT_Z.x), paving)
	_slab(Rect2(STREET_X.x, FAR_PAVEMENT_Z.x, STREET_X.y - STREET_X.x, FAR_PAVEMENT_Z.y - FAR_PAVEMENT_Z.x), paving)


func _street() -> void:
	_slab(Rect2(STREET_X.x, STREET_Z.x, STREET_X.y - STREET_X.x, STREET_Z.y - STREET_Z.x), _surface("asphalt"), 0.01)
	var kerb: Material = _colour(Balance.MUSEUM_KERB)
	for z: float in [STREET_Z.x, STREET_Z.y]:
		_box(Vector3(STREET_X.y - STREET_X.x, Balance.MUSEUM_KERB_HEIGHT, 0.25), Vector3((STREET_X.x + STREET_X.y) / 2.0, Balance.MUSEUM_KERB_HEIGHT / 2.0, z), kerb)
	var white: Material = _colour(Balance.MUSEUM_ROAD_PAINT)
	var middle: float = (STREET_Z.x + STREET_Z.y) / 2.0
	var x: float = STREET_X.x
	while x < STREET_X.y:
		if x < 12.5 or x > 18.0:
			_box(Vector3(1.8, 0.02, 0.15), Vector3(x + 0.9, 0.03, middle), white) # Dashed centre line.
		x += 3.6
	for stripe: int in range(7):
		_box(Vector3(0.5, 0.02, STREET_Z.y - STREET_Z.x - 0.6), Vector3(13.0 + stripe * 0.85, 0.03, middle), white) # Zebra crossing.


# --- The forecourt ---
func _forecourt() -> void:
	var fountain: Node3D = MuseumKit.place(self, TOWN % "fountain-round-detail", Vector3(Balance.MUSEUM_FOUNTAIN.x, 0.0, Balance.MUSEUM_FOUNTAIN.y), Balance.MUSEUM_FOUNTAIN_HEIGHT)
	var water := MeshInstance3D.new()
	var surface := CylinderMesh.new()
	surface.top_radius = 1.2
	surface.bottom_radius = 1.2
	surface.height = 0.04
	water.mesh = surface
	var shine := _colour(Balance.MUSEUM_FOUNTAIN_WATER)
	shine.roughness = 0.1
	shine.emission_enabled = true
	shine.emission = Balance.MUSEUM_FOUNTAIN_WATER * 0.35
	water.material_override = shine
	water.position = Vector3(0.0, Balance.MUSEUM_FOUNTAIN_HEIGHT * 0.7, 0.0)
	fountain.add_child(water)
	MuseumKit.solid(self, "Fountain", Vector3(Balance.MUSEUM_FOUNTAIN.x, 0.4, Balance.MUSEUM_FOUNTAIN.y), Vector3(2.8, 0.8, 2.8))
	for side: float in [-1.0, 1.0]:
		var at := Vector3(Balance.MUSEUM_FOUNTAIN.x + side * 3.0, 0.0, Balance.MUSEUM_FOUNTAIN.y)
		MuseumKit.place(self, POLY % "bench_a", at, 0.5, 90.0)
		MuseumKit.solid(self, "Bench", at + Vector3.UP * 0.25, Vector3(0.6, 0.5, 1.6))
	# The opening-hours sign at the forecourt's edge, facing the street.
	var board := Vector3(25.5, 0.0, 26.9)
	_box(Vector3(2.6, 0.5, 0.5), board + Vector3(0, 0.25, 0), _surface("marble_dark"))
	_box(Vector3(2.4, 1.3, 0.12), board + Vector3(0, 1.15, 0), _surface("stone_cream"))
	MuseumKit.solid(self, "Signboard", board + Vector3(0, 0.9, 0), Vector3(2.6, 1.8, 0.5))
	var words := _text("MUSEUM OF MOSTLY REAL THINGS\nOpen 10 to 6. Closed at night. (Mostly.)", Balance.MUSEUM_PLATE_INK, 44)
	words.position = board + Vector3(0, 1.15, 0.07)
	add_child(words)


# --- Hedges and trees ---
func _greenery() -> void:
	for run: Array in HEDGE_RUNS:
		var x: float = run[0]
		while x < run[1] - 0.5:
			var at := Vector3(x + 0.75, 0.0, 27.7)
			ArenaBuilder.mute_colours(MuseumKit.place(self, TOWN % "hedge-large", at, Balance.MUSEUM_HEDGE_HEIGHT, 90.0))
			x += 1.5
		MuseumKit.solid(self, "Hedge", Vector3((run[0] + run[1]) / 2.0, 0.45, 27.7), Vector3(run[1] - run[0], 0.9, 0.7))
	var kinds: Array[String] = ["tree_pineDefaultA", "tree_thin_dark"]
	for index: int in TREES.size():
		var at: Vector2 = TREES[index]
		ArenaBuilder.mute_colours(MuseumKit.place(self, NATURE % kinds[index % 2], Vector3(at.x, 0.0, at.y), Balance.MUSEUM_TREE_HEIGHT + float(index % 3) * 0.6, index * 37.0))
		MuseumKit.solid(self, "Tree", Vector3(at.x, 1.0, at.y), Vector3(0.5, 2.0, 0.5))
	for at: Vector2 in [Vector2(-1.4, 27.0), Vector2(31.4, 27.0), Vector2(8.6, 27.0), Vector2(-6.5, 21.0), Vector2(36.5, 21.0)]:
		ArenaBuilder.mute_colours(MuseumKit.place(self, NATURE % "plant_bush", Vector3(at.x, 0.0, at.y), 0.7))


# --- Light ---
func _lamps() -> void:
	# Street lamps on the front pavement, their arms over the road, each with a warm pool of light.
	for x: float in LAMPS:
		MuseumKit.place(self, ROADS % "light-curved", Vector3(x, 0.0, Balance.MUSEUM_LAMP_Z), Balance.MUSEUM_LAMP_HEIGHT, 180.0)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, Balance.MUSEUM_LAMP_HEIGHT - 0.3, Balance.MUSEUM_LAMP_Z + 1.1)
		lamp.light_color = Balance.MUSEUM_OUTSIDE_LIGHT_COLOUR
		lamp.light_energy = Balance.MUSEUM_LAMP_ENERGY
		lamp.omni_range = Balance.MUSEUM_LAMP_RANGE
		lamp.shadow_enabled = false
		add_child(lamp)


func _flags() -> void:
	# Two flagpoles at the front corners, each with an exhibition banner.
	var pole_material := _colour(Color("c9ccd1"))
	pole_material.metallic = 0.5
	for flag: Array in [[Vector3(-3.5, 0.0, 21.5), "DINOSAURS!\nNOW SHOWING", Balance.MUSEUM_BANNER_RED], [Vector3(33.5, 0.0, 21.5), "SPACE!\nNEW GALLERY", Balance.MUSEUM_BANNER_BLUE]]:
		var at: Vector3 = flag[0]
		var pole := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.05
		shape.bottom_radius = 0.07
		shape.height = Balance.MUSEUM_FLAGPOLE_HEIGHT
		pole.mesh = shape
		pole.material_override = pole_material
		pole.position = at + Vector3.UP * Balance.MUSEUM_FLAGPOLE_HEIGHT / 2.0
		add_child(pole)
		var banner: MeshInstance3D = _box(Vector3(1.3, 2.4, 0.04), at + Vector3(0.72, Balance.MUSEUM_FLAGPOLE_HEIGHT - 1.5, 0.0), _colour(flag[2]))
		var words := _text(flag[1], Color("fff4dc"), 60)
		words.position = Vector3(0, 0, 0.03)
		banner.add_child(words)
		MuseumKit.solid(self, "Flagpole", at + Vector3.UP, Vector3(0.2, 2.0, 0.2))


func _cars() -> void:
	for car: Array in CARS_PARKED:
		var at := Vector3(car[1], 0.0, Balance.MUSEUM_PARKING_Z)
		MuseumKit.place(self, CARS % car[0], at, Balance.MUSEUM_CAR_HEIGHT, 90.0)
		MuseumKit.solid(self, "Car", at + Vector3.UP * 0.8, Vector3(4.2, 1.6, 2.0))


# --- The building's outside ---
func _building_trim() -> void:
	# A dark stone plinth band round the outside walls (low, so it never hides anyone), and a white cornice along the
	# two walls the camera never looks through.
	var plinth: Material = _surface("marble_dark")
	var cornice: Material = _surface("marble_floor")
	var band: float = Balance.MUSEUM_PLINTH_BAND
	var proud: float = 0.1 + 0.08
	_box(Vector3(30.36, band, 0.16), Vector3(15.0, band / 2.0, -proud), plinth)
	_box(Vector3(0.16, band, 20.36), Vector3(-proud, band / 2.0, 10.0), plinth)
	_box(Vector3(0.16, band, 20.36), Vector3(30.0 + proud, band / 2.0, 10.0), plinth)
	for span: Vector2 in [Vector2(-0.18, 0.8), Vector2(3.4, 25.0), Vector2(28.0, 30.18)]:
		_box(Vector3(span.y - span.x, band, 0.16), Vector3((span.x + span.y) / 2.0, band / 2.0, 20.0 + proud), plinth)
	var top: float = Balance.ARENA_WALL_HEIGHT
	_box(Vector3(30.5, 0.22, 0.34), Vector3(15.0, top - 0.05, -0.12), cornice)
	_box(Vector3(0.34, 0.22, 20.5), Vector3(30.12, top - 0.05, 10.0), cornice)


# --- The skyline ---
func _skyline() -> void:
	var windows := StandardMaterial3D.new()
	windows.albedo_texture = load("res://assets/textures/decor/city_windows.png")
	windows.emission_enabled = true
	windows.emission_texture = load("res://assets/textures/decor/city_windows_lit.png")
	windows.emission_energy_multiplier = Balance.MUSEUM_SKYLINE_GLOW
	windows.uv1_triplanar = true
	windows.uv1_world_triplanar = true
	windows.uv1_scale = Vector3.ONE / Balance.MUSEUM_SKYLINE_TILE
	windows.roughness = 0.9
	var roof := _colour(Color("1d2028"))
	var tank := _colour(Color("2f3b4a"))
	for index: int in BLOCKS.size():
		var block: Array = BLOCKS[index]
		var centre: Vector2 = block[0]
		var footprint: Vector2 = block[1]
		var height: float = block[2]
		var body: MeshInstance3D = _box(Vector3(footprint.x, height, footprint.y), Vector3(centre.x, height / 2.0, centre.y), windows)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(footprint.x + 0.3, 0.4, footprint.y + 0.3), Vector3(centre.x, height + 0.2, centre.y), roof)
		if index % 2 == 0:
			# Mumbai roofs: a water tank on legs.
			var cylinder := MeshInstance3D.new()
			var drum := CylinderMesh.new()
			drum.top_radius = 0.9
			drum.bottom_radius = 0.9
			drum.height = 1.6
			cylinder.mesh = drum
			cylinder.material_override = tank
			cylinder.position = Vector3(centre.x + footprint.x * 0.25, height + 1.6, centre.y - footprint.y * 0.2)
			add_child(cylinder)


# --- Helpers ---
func _slab(area: Rect2, material: Material, lift: float = 0.0) -> void:
	_box(Vector3(area.size.x, 0.02, area.size.y), Vector3(area.get_center().x, 0.012 + lift, area.get_center().y), material)


func _box(size: Vector3, centre: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = centre
	add_child(mesh)
	return mesh


func _surface(name: String) -> Material:
	return load("res://assets/materials/surfaces/%s.tres" % name)


func _colour(colour: Color) -> StandardMaterial3D:
	if not paint.has(colour):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.8
		paint[colour] = material
	return paint[colour]


func _text(text: String, colour: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = load(Balance.COMIC_FONT_PATH)
	label.font_size = size
	label.pixel_size = Balance.MUSEUM_PLAQUE_PIXEL_SIZE
	label.modulate = colour
	label.outline_size = 0
	return label
