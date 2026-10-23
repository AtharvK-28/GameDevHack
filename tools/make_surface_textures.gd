# Makes the stylised, low-detail surface textures (256 px, seamless) and their triplanar materials:
# assets/textures/surfaces/<name>.png and assets/materials/surfaces/<name>.tres. The arena builder picks a
# material by the surface name in a layout file. It also makes the few decor images the Mansion dressing uses
# (two portraits and a cobweb) in assets/textures/decor/. Run once after changing a pattern:
#   godot --headless --path . --script res://tools/make_surface_textures.gd
# then open the editor (or run --import) so Godot imports the new images.
extends SceneTree

# --- Output ---
const TEXTURE_DIR: String = "res://assets/textures/surfaces/"
const MATERIAL_DIR: String = "res://assets/materials/surfaces/"
const DECOR_DIR: String = "res://assets/textures/decor/"
const SIZE: int = 256 # Pixels per side; every texture tiles seamlessly.

# --- Settings: metres covered by one texture tile, and roughness (0 to 1) ---
const SURFACES: Dictionary = {
	"wallpaper_purple": {"tile": 0.75, "roughness": 0.85},
	"wood_planks": {"tile": 0.8, "roughness": 0.7},
	"stone_tiles": {"tile": 1.0, "roughness": 0.6},
	"gravel": {"tile": 1.0, "roughness": 1.0},
	"grass": {"tile": 1.5, "roughness": 1.0},
	"dead_grass": {"tile": 3.0, "roughness": 1.0},
	"trim_walnut": {"tile": 0.5, "roughness": 0.6},
	"wainscot_walnut": {"tile": 1.0, "roughness": 0.6},
	"plaster_sage": {"tile": 2.0, "roughness": 0.9},
	"stone_facade": {"tile": 2.0, "roughness": 0.9},
}

# --- Setup ---
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEXTURE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_DIR))
	var images: Dictionary = {
		"wallpaper_purple": _wallpaper(),
		"wood_planks": _planks(),
		"stone_tiles": _tiles(),
		"gravel": _gravel(),
		"grass": _grass(Color("4f6b3a"), Color("3f5a2e"), Color("62804a"), 7),
		"dead_grass": _grass(Color("3c4a35"), Color("343d2c"), Color("4c4a3a"), 11),
		"trim_walnut": _wood(Color("4a3022"), 3),
		"wainscot_walnut": _beadboard(),
		"plaster_sage": _plaster(),
		"stone_facade": _ashlar(),
	}
	for surface: String in images:
		var image: Image = images[surface]
		image.save_png(ProjectSettings.globalize_path(TEXTURE_DIR + surface + ".png"))
		_write_import_settings(surface)
		_write_material(surface, SURFACES[surface])
		print("made ", surface)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DECOR_DIR))
	var decor: Dictionary = {
		"portrait_lady": _portrait(Color("3d1f2b"), Color("6b3a4a"), false),
		"portrait_lord": _portrait(Color("1f2d26"), Color("3f5a4a"), true),
		"cobweb": _cobweb(),
	}
	for name: String in decor:
		var image: Image = decor[name]
		image.save_png(ProjectSettings.globalize_path(DECOR_DIR + name + ".png"))
		print("made ", name)
	quit()


# --- Patterns ---
func _wallpaper() -> Image:
	# Muted purple with thin paired stripes and a darker diamond damask on a staggered grid.
	var base := Color("5b4a7a")
	var motif := Color("4a3c66")
	var paper: PackedFloat32Array = _noise_grid(32, 1)
	var image := _blank()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var colour: Color = base.darkened(_sample(paper, 32, x, y) * 0.06)
			var stripe: int = x % 64
			if stripe == 0 or stripe == 3:
				colour = motif
			var row: int = floori(y / 64.0)
			var cell_x: float = fposmod(x + (32 if row % 2 == 1 else 0), 64) - 32.0
			var cell_y: float = fposmod(y, 64) - 32.0
			var diamond: float = absf(cell_x) * 1.4 + absf(cell_y)
			if (diamond > 15.0 and diamond < 19.0) or diamond < 4.0:
				colour = motif
			image.set_pixel(x, y, colour)
	return image


func _planks() -> Image:
	# Four 20 cm planks per tile, each its own tone, with grain, dark seams and staggered end joints.
	var grain: PackedFloat32Array = _noise_grid(16, 2)
	var random := RandomNumberGenerator.new()
	random.seed = 21
	var tones: Array[float] = []
	var joints: Array[int] = []
	for plank: int in range(4):
		tones.append(random.randf_range(-0.08, 0.08))
		joints.append(random.randi_range(0, SIZE - 1))
	var image := _blank()
	for y: int in range(SIZE):
		var plank: int = floori(y / 64.0)
		for x: int in range(SIZE):
			var colour := Color("8a6240").lightened(tones[plank]) if tones[plank] > 0.0 else Color("8a6240").darkened(-tones[plank])
			var streak: float = _sample(grain, 16, x, y * 8.0)
			colour = colour.darkened(streak * 0.12)
			var seam: bool = y % 64 < 2 or absi(x - joints[plank]) < 2
			image.set_pixel(x, y, Color("4e3422") if seam else colour)
	return image


func _tiles() -> Image:
	# 2 × 2 stone tiles of 50 cm, each a slightly different grey-green, with grout and a darker rim.
	var mottle: PackedFloat32Array = _noise_grid(24, 3)
	var random := RandomNumberGenerator.new()
	random.seed = 31
	var tones: Array[Color] = []
	for tile: int in range(4):
		tones.append(Color("8d8a84").lerp(Color("7f8a84"), random.randf()).darkened(random.randf_range(0.0, 0.1)))
	var image := _blank()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var local_x: int = x % 128
			var local_y: int = y % 128
			var edge: int = mini(mini(local_x, 127 - local_x), mini(local_y, 127 - local_y))
			var colour: Color = tones[floori(y / 128.0) * 2 + floori(x / 128.0)].darkened(_sample(mottle, 24, x, y) * 0.1)
			if edge < 3:
				colour = Color("5f5c57")
			elif edge < 6:
				colour = colour.darkened(0.12)
			image.set_pixel(x, y, colour)
	return image


func _gravel() -> Image:
	# Fine pebbles: two noise layers between dark and light grey-beige, plus single-pixel speckles.
	var coarse: PackedFloat32Array = _noise_grid(32, 4)
	var fine: PackedFloat32Array = _noise_grid(128, 5)
	var random := RandomNumberGenerator.new()
	random.seed = 41
	var image := _blank()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var amount: float = _sample(coarse, 32, x, y) * 0.5 + _sample(fine, 128, x, y) * 0.5
			var colour: Color = Color("7b746b").lerp(Color("b0a99f"), amount)
			var speckle: float = random.randf()
			if speckle < 0.05:
				colour = colour.darkened(0.25)
			elif speckle > 0.96:
				colour = colour.lightened(0.15)
			image.set_pixel(x, y, colour)
	return image


func _grass(base: Color, dark: Color, light: Color, seed_value: int) -> Image:
	# Mottled ground colour with short vertical blade strokes, lighter and darker.
	var mottle: PackedFloat32Array = _noise_grid(16, seed_value)
	var image := _blank()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var amount: float = _sample(mottle, 16, x, y)
			image.set_pixel(x, y, dark.lerp(base, amount * 1.5) if amount < 0.66 else base.lerp(light, (amount - 0.66) * 3.0))
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for blade: int in range(900):
		var x: int = random.randi_range(0, SIZE - 1)
		var y: int = random.randi_range(0, SIZE - 1)
		var stroke: Color = dark if random.randf() < 0.5 else light
		for step: int in range(random.randi_range(3, 6)):
			image.set_pixel(x, posmod(y - step, SIZE), stroke)
	return image


func _wood(base: Color, seed_value: int) -> Image:
	# Plain walnut with long horizontal grain.
	var grain: PackedFloat32Array = _noise_grid(16, seed_value)
	var image := _blank()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			image.set_pixel(x, y, base.darkened(_sample(grain, 16, x, y * 8.0) * 0.18))
	return image


func _beadboard() -> Image:
	# Vertical tongue-and-groove boards (12.5 cm) for the wainscoting: a groove with a highlight beside it.
	var grain: PackedFloat32Array = _noise_grid(16, 6)
	var image := _blank()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var colour: Color = Color("5a3a29").darkened(_sample(grain, 16, x * 8.0, y) * 0.15)
			var board_x: int = x % 32
			if board_x < 2:
				colour = Color("33201a")
			elif board_x == 2:
				colour = colour.lightened(0.12)
			image.set_pixel(x, y, colour)
	return image


func _plaster() -> Image:
	# Soft, mottled sage plaster for the kitchen.
	var mottle: PackedFloat32Array = _noise_grid(12, 8)
	var fine: PackedFloat32Array = _noise_grid(64, 9)
	var image := _blank()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var amount: float = _sample(mottle, 12, x, y) * 0.7 + _sample(fine, 64, x, y) * 0.3
			image.set_pixel(x, y, Color("6f7c63").lerp(Color("8e9a80"), amount))
	return image


func _ashlar() -> Image:
	# Weathered grey stone blocks, 25 cm rows, staggered by half a block, with dark mortar.
	var mottle: PackedFloat32Array = _noise_grid(32, 10)
	var random := RandomNumberGenerator.new()
	random.seed = 51
	var tones: Array[float] = []
	for block: int in range(32):
		tones.append(random.randf_range(0.0, 0.14))
	var image := _blank()
	for y: int in range(SIZE):
		var row: int = floori(y / 32.0)
		for x: int in range(SIZE):
			var shifted: int = posmod(x + (32 if row % 2 == 1 else 0), SIZE)
			var block: int = row * 4 + floori(shifted / 64.0)
			var colour: Color = Color("706a66").darkened(tones[block] + _sample(mottle, 32, x, y) * 0.08)
			if y % 32 < 3 or shifted % 64 < 3:
				colour = Color("3d3836")
			image.set_pixel(x, y, colour)
	return image


# --- Decor images ---
func _portrait(dark: Color, light: Color, top_hat: bool) -> Image:
	# A gilt frame around a dim painted background and a black silhouette bust (a bun, or a top hat).
	var width: int = 128
	var height: int = 160
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var head := Vector2(64, 66)
	for y: int in range(height):
		for x: int in range(width):
			var colour: Color = dark.lerp(light, clampf(1.0 - Vector2(x, y).distance_to(Vector2(64, 60)) / 90.0, 0.0, 1.0))
			var point := Vector2(x, y)
			var shoulders: bool = y > 104 and pow((x - 64) / 44.0, 2.0) + pow((y - 150) / 46.0, 2.0) < 1.0
			var neck: bool = absf(x - 64) < 9 and y > 80 and y < 110
			var face: bool = pow((x - head.x) / 20.0, 2.0) + pow((y - head.y) / 25.0, 2.0) < 1.0
			var extra: bool = (absf(x - 64) < 16 and y > 18 and y < 46) or (absf(x - 64) < 26 and y > 42 and y < 48) if top_hat else point.distance_to(Vector2(64, 38)) < 13.0
			if shoulders or neck or face or extra:
				colour = Color("120c10")
			var edge: int = mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
			if edge < 10:
				colour = Color("8a6a2c").lightened(0.25 if edge % 4 == 1 else 0.0).darkened(0.3 if edge < 2 else 0.0)
			image.set_pixel(x, y, colour)
	return image


func _cobweb() -> Image:
	# Pale threads on a transparent background: rays fanning down from the top edge, crossed by sagging strands.
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var thread := Color(0.85, 0.85, 0.9, 0.7)
	var hub := Vector2(64, 0)
	for ray: int in range(7):
		var angle: float = PI * (ray + 0.5) / 7.0
		for step: int in range(110):
			var point: Vector2 = hub + Vector2(cos(angle), sin(angle)) * step
			if point.x >= 0 and point.x < 128 and point.y < 128:
				image.set_pixel(int(point.x), int(point.y), thread)
	for ring: int in range(1, 6):
		var radius: float = ring * 18.0
		for step: int in range(200):
			var angle: float = PI * step / 199.0
			var sag: float = sin(angle * 7.0) * 3.0 * ring / 5.0
			var point: Vector2 = hub + Vector2(cos(angle), sin(angle)) * (radius + absf(sag))
			if point.x >= 0 and point.x < 128 and point.y >= 0 and point.y < 128:
				image.set_pixel(int(point.x), int(point.y), thread)
	return image


# --- Noise helpers (periodic, so every texture tiles; stretch grain only by whole-number factors) ---
func _noise_grid(cells: int, seed_value: int) -> PackedFloat32Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var grid := PackedFloat32Array()
	grid.resize(cells * cells)
	for index: int in range(cells * cells):
		grid[index] = random.randf()
	return grid


func _sample(grid: PackedFloat32Array, cells: int, x: float, y: float) -> float:
	# Smooth value noise at pixel (x, y); the lattice wraps every SIZE pixels.
	var u: float = fposmod(x, SIZE) / SIZE * cells
	var v: float = fposmod(y, SIZE) / SIZE * cells
	var x0: int = floori(u)
	var y0: int = floori(v)
	var fx: float = smoothstep(0.0, 1.0, u - x0)
	var fy: float = smoothstep(0.0, 1.0, v - y0)
	var a: float = grid[(y0 % cells) * cells + x0 % cells]
	var b: float = grid[(y0 % cells) * cells + (x0 + 1) % cells]
	var c: float = grid[((y0 + 1) % cells) * cells + x0 % cells]
	var d: float = grid[((y0 + 1) % cells) * cells + (x0 + 1) % cells]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _blank() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)


# --- Output helpers ---
func _write_import_settings(surface: String) -> void:
	# Mipmaps on, lossless: small textures that stay clean at a distance. Only for a new image, so an existing
	# image keeps its import file (and its uid).
	var path: String = TEXTURE_DIR + surface + ".png.import"
	if FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\ndetect_3d/compress_to=0\n")


func _write_material(surface: String, settings: Dictionary) -> void:
	# A triplanar material in world space, so the builder's boxes need no UVs and the pattern lines up across them.
	var scale: float = 1.0 / settings.tile
	var text: String = "[gd_resource type=\"StandardMaterial3D\" load_steps=2 format=3]\n\n"
	text += "[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1\"]\n\n" % (TEXTURE_DIR + surface + ".png")
	text += "[resource]\nalbedo_texture = ExtResource(\"1\")\nroughness = %s\n" % settings.roughness
	text += "uv1_scale = Vector3(%s, %s, %s)\nuv1_triplanar = true\nuv1_world_triplanar = true\n" % [scale, scale, scale]
	var file := FileAccess.open(MATERIAL_DIR + surface + ".tres", FileAccess.WRITE)
	file.store_string(text)
