# The galleon's look: Kenney's ship-pirate-large as hull, castles, rails, masts and ghostly sails, plus deck
# lanterns and the salvage tug. The layout builds every walkable floor and collider; nothing here collides.
extends Node3D

# --- Setup ---
func _ready() -> void:
	_build_galleon()
	ShipVisuals.hull(self, Balance.SHIP_TUG_OUTLINE, Balance.SHIP_TUG_TOP, Balance.SHIP_TUG_DEPTH, Balance.SHIP_TUG_COLOUR)
	_build_tug()
	_build_lanterns()
	_build_details()


func _build_galleon() -> void:
	var ship: Node3D = load(Balance.SHIP_MODEL_PATH).instantiate()
	ship.name = "Galleon"
	ship.scale = Balance.SHIP_MODEL_SCALE
	ship.rotation.y = PI / 2.0 # The model's bow points +z; the arena's bow is +x.
	ship.position = Balance.SHIP_MODEL_AT
	add_child(ship)
	for part: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
		if part.name == "ship-pirate-large":
			part.mesh = _without_deck_faces(part.mesh)
			var wood: StandardMaterial3D = part.mesh.surface_get_material(0).duplicate()
			wood.albedo_color = Balance.SHIP_MODEL_TINT
			part.material_override = wood
		else:
			# Sails and flags: see-through, so the party camera always sees the deck beneath them.
			var cloth: StandardMaterial3D = part.mesh.surface_get_material(0).duplicate()
			cloth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cloth.albedo_color.a = Balance.SHIP_GHOST_SAIL_ALPHA
			cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
			part.material_override = cloth
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _without_deck_faces(source_mesh: Mesh) -> ArrayMesh:
	# Drops the model's own flat deck and step faces inside the rails, so the layout's floors (which match the
	# colliders exactly) show instead of fighting them. Rail tops, castle walls and the hatch grate stay.
	var source := MeshDataTool.new()
	source.create_from_surface(source_mesh, 0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: int in source.get_face_count():
		var centre := Vector3.ZERO
		for corner: int in 3:
			centre += source.get_vertex(source.get_face_vertex(face, corner)) / 3.0
		if source.get_face_normal(face).y > 0.95 and absf(centre.x) < Balance.SHIP_MODEL_DECK_HALF_WIDTH and _is_deck_level(centre.y):
			continue
		for corner: int in 3:
			var vertex: int = source.get_face_vertex(face, corner)
			tool.set_normal(source.get_vertex_normal(vertex))
			tool.set_uv(source.get_vertex_uv(vertex))
			tool.add_vertex(source.get_vertex(vertex))
	tool.set_material(source_mesh.surface_get_material(0))
	return tool.commit()


func _is_deck_level(height: float) -> bool:
	for level: float in Balance.SHIP_MODEL_DECK_LEVELS:
		if absf(height - level) < 0.03:
			return true
	return false


func _build_tug() -> void:
	# The wheelhouse and tyres stay at the far end, outside the clear delivery/turning pad.
	ShipVisuals.blocks(self, [[Vector3(2.4, 1.5, 0.7), Vector3(12, 0.75, 20.3)], [Vector3(2.7, 0.15, 1), Vector3(12, 1.55, 20.3)]], Balance.SHIP_TUG_COLOUR)
	ShipVisuals.blocks(self, [[Vector3(0.75, 0.55, 0.03), Vector3(11.5, 1.0, 19.93)], [Vector3(0.75, 0.55, 0.03), Vector3(12.5, 1.0, 19.93)]], Balance.SHIP_LANTERN_COLOUR)
	var sign: Label3D = ShipVisuals.label(self, "SASTA SALVAGE", Vector3(12, 0.3, 20.9), Balance.COMIC_PAPER, Balance.SHIP_SIGN_SIZE)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Mooring lines from the galleon's side to the tug, either side of the plank.
	var ropes: Array = []
	for x: float in [8.4, 15.6]:
		ropes.append([Vector3(0.07, 0.07, 3.8), Vector3(x, 0.2, 13.9)])
	ShipVisuals.blocks(self, ropes, Balance.SHIP_GOLD_COLOUR)


func _build_lanterns() -> void:
	var frames: Array = []
	var glass: Array = []
	for point: Vector3 in Balance.SHIP_LAMP_SPOTS:
		frames.append([Vector3(0.15, 1.8, 0.15), point + Vector3.UP * 0.9])
		frames.append([Vector3(0.5, 0.08, 0.5), point + Vector3.UP * 2.05])
		glass.append([Vector3(0.28, 0.4, 0.28), point + Vector3.UP * 1.8])
		var lamp := OmniLight3D.new()
		lamp.position = point + Vector3.UP * 1.8
		lamp.light_color = Balance.SHIP_LANTERN_COLOUR if point.z < 12 else Balance.WINDOW_GLOW_COLOUR
		lamp.light_energy = Balance.SHIP_LAMP_ENERGY
		lamp.omni_range = Balance.SHIP_LAMP_RANGE
		lamp.shadow_enabled = false
		add_child(lamp)
	ShipVisuals.blocks(self, frames, Balance.SHIP_METAL_COLOUR)
	ShipVisuals.blocks(self, glass, Balance.SHIP_LANTERN_COLOUR)


func _build_details() -> void:
	var danger: Label3D = ShipVisuals.label(self, "MIND THE GAP!", Vector3(12, 0.06, 11.3), Balance.SHIP_GOLD_COLOUR, Balance.SHIP_FLOOR_SIGN_SIZE)
	danger.rotation_degrees = Vector3(-90, Balance.SHIP_CAMERA_YAW, 0)
