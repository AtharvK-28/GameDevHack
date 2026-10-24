# The galleon's visual shell, tattered rig and salvage tug. No moving colliders or loot-like clutter.
extends Node3D

var sails: Array[Node3D] = []
var elapsed: float = 0.0
var cloths: Array[MeshInstance3D] = []

# --- Setup ---
func _ready() -> void:
	ShipVisuals.hull(self, Balance.SHIP_HULL_OUTLINE, 0.0, Balance.SHIP_HULL_DEPTH, Balance.SHIP_HULL_COLOUR)
	ShipVisuals.hull(self, Balance.SHIP_TUG_OUTLINE, 0.0, Balance.SHIP_TUG_DEPTH, Balance.SHIP_TUG_COLOUR)
	_build_tug()
	_build_rig()
	_build_lanterns()
	_build_details()


func _build_tug() -> void:
	# The wheelhouse and tyres stay at the far end, outside the clear delivery/turning pad.
	ShipVisuals.blocks(self, [[Vector3(2.4, 1.5, 0.7), Vector3(14, 0.75, 18.1)], [Vector3(2.7, 0.15, 1), Vector3(14, 1.55, 18.1)]], Balance.SHIP_TUG_COLOUR)
	ShipVisuals.blocks(self, [[Vector3(0.75, 0.55, 0.03), Vector3(13.5, 1.0, 17.73)], [Vector3(0.75, 0.55, 0.03), Vector3(14.5, 1.0, 17.73)]], Balance.SHIP_LANTERN_COLOUR)
	var sign: Label3D = ShipVisuals.label(self, "SASTA SALVAGE", Vector3(14, 0.3, 18.7), Balance.COMIC_PAPER, Balance.SHIP_SIGN_SIZE)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var ropes: Array = []
	for x: float in [10.2, 17.8]:
		ropes.append([Vector3(0.07, 0.07, 3.6), Vector3(x, 0.2, 11.8)])
	ShipVisuals.blocks(self, ropes, Balance.SHIP_GOLD_COLOUR)


func _build_rig() -> void:
	# The tall silhouette is on the back edge; sails face the sea and leave the playfield visible.
	for point: Vector3 in Balance.SHIP_MAST_SPOTS:
		var mast: Node3D = ShipVisuals.kit(self, "mast", point, Balance.SHIP_MAST_SCALE)
		sails.append(mast)
		_build_sail(point)
		ShipVisuals.kit(self, "mast-ropes", point, Balance.SHIP_MAST_SCALE)
	var lines: Array = []
	for x: float in [7.0, 19.0]:
		lines.append([Vector3(0.06, 3.0, 0.06), Vector3(x - 1.4, 1.5, -0.3), Vector3(0, 0, -0.5)])
		lines.append([Vector3(0.06, 3.0, 0.06), Vector3(x + 1.4, 1.5, -0.3), Vector3(0, 0, 0.5)])
	ShipVisuals.blocks(self, lines, Balance.SHIP_WOOD_COLOUR)


func _build_lanterns() -> void:
	var frames: Array = []
	var glass: Array = []
	for point: Vector3 in Balance.SHIP_LAMP_SPOTS:
		frames.append([Vector3(0.15, 1.8, 0.15), point + Vector3.UP * 0.9])
		frames.append([Vector3(0.5, 0.08, 0.5), point + Vector3.UP * 2.05])
		glass.append([Vector3(0.28, 0.4, 0.28), point + Vector3.UP * 1.8])
		var lamp := OmniLight3D.new()
		lamp.position = point + Vector3.UP * 1.8
		lamp.light_color = Balance.SHIP_LANTERN_COLOUR if point.z < 10 else Balance.WINDOW_GLOW_COLOUR
		lamp.light_energy = Balance.SHIP_LAMP_ENERGY
		lamp.omni_range = Balance.SHIP_LAMP_RANGE
		lamp.shadow_enabled = false
		add_child(lamp)
	ShipVisuals.blocks(self, frames, Balance.SHIP_METAL_COLOUR)
	ShipVisuals.blocks(self, glass, Balance.SHIP_LANTERN_COLOUR)


func _build_details() -> void:
	# Fixed cannons point out to sea and sit beyond the playable back edge, never amongst valuables.
	for x: float in [11.0, 15.5]:
		ShipVisuals.kit(self, "cannon-mobile", Vector3(x, 0.0, -0.7), Balance.SHIP_CANNON_SCALE, PI)
	var planks: Array = []
	# Subtle seams stay on the main deck, away from the hold opening.
	for index: int in range(6):
		planks.append([Vector3(7.6, 0.008, 0.025), Vector3(13, 0.012, 7.2 + index * 0.45)])
	ShipVisuals.blocks(self, planks, Balance.SHIP_WOOD_COLOUR)
	var danger: Label3D = ShipVisuals.label(self, "MIND THE GAP!", Vector3(14, 0.06, 9.1), Balance.SHIP_GOLD_COLOUR, Balance.SHIP_FLOOR_SIGN_SIZE)
	danger.rotation_degrees = Vector3(-90, Balance.SHIP_CAMERA_YAW, 0)
	var hold_sign: Label3D = ShipVisuals.label(self, "CARGO HOLD", Vector3(11.5, -1.17, 3), Balance.SHIP_SAIL_COLOUR, Balance.SHIP_FLOOR_SIGN_SIZE)
	hold_sign.rotation_degrees = Vector3(-90, Balance.SHIP_CAMERA_YAW, 0)


# --- Cosmetic motion ---
func _process(delta: float) -> void:
	elapsed += delta
	_fade_sails()
	for index: int in range(sails.size()):
		sails[index].rotation.z = sin(elapsed + index) * Balance.SHIP_SAIL_SWAY


func _build_sail(at: Vector3) -> void:
	# Jagged lower hems make the silhouette read as an abandoned galleon from the party camera.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(Balance.SHIP_SAIL_HEM.size() - 1):
		var left: Vector2 = Balance.SHIP_SAIL_HEM[index]
		var right: Vector2 = Balance.SHIP_SAIL_HEM[index + 1]
		for vertex: Vector3 in [Vector3(left.x, Balance.SHIP_SAIL_TOP, 0), Vector3(right.x, Balance.SHIP_SAIL_TOP, 0), Vector3(left.x, left.y, 0), Vector3(right.x, Balance.SHIP_SAIL_TOP, 0), Vector3(right.x, right.y, 0), Vector3(left.x, left.y, 0)]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var cloth := MeshInstance3D.new()
	cloth.mesh = surface.commit()
	cloth.position = at + Vector3.FORWARD * Balance.SHIP_SAIL_OFFSET
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = ShipVisuals.material(Balance.SHIP_SAIL_COLOUR).duplicate()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloth.material_override = material
	add_child(cloth)
	cloths.append(cloth)


func _fade_sails() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	for cloth: MeshInstance3D in cloths:
		var box: AABB = cloth.global_transform * cloth.get_aabb().grow(Balance.SHIP_SAIL_OCCLUSION_MARGIN)
		var hidden_player: bool = false
		for player: Node3D in get_tree().get_nodes_in_group("movers"):
			if box.intersects_segment(camera.global_position, player.global_position):
				hidden_player = true
		var material: StandardMaterial3D = cloth.material_override
		material.albedo_color.a = Balance.SHIP_SAIL_FADE_ALPHA if hidden_player else 1.0
