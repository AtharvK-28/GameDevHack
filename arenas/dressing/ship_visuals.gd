# Small shared helpers for Ship dressing: instance repeated blocks and keep imported decor muted.
class_name ShipVisuals
extends RefCounted

static var materials: Dictionary = {}

static func material(colour: Color) -> StandardMaterial3D:
	if not materials.has(colour):
		var result := StandardMaterial3D.new()
		result.albedo_color = colour
		result.roughness = 0.85
		materials[colour] = result
	return materials[colour]


static func blocks(parent: Node3D, parts: Array, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.material = material(colour)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = parts.size()
	for index: int in range(parts.size()):
		var part: Array = parts[index]
		var basis := Basis.from_euler(part[2] if part.size() > 2 else Vector3.ZERO).scaled(part[0])
		instances.set_instance_transform(index, Transform3D(basis, part[1]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	parent.add_child(node)


static func kit(parent: Node3D, name: String, at: Vector3, size: float, yaw: float = 0.0) -> Node3D:
	var model: Node3D = load("res://assets/models/pirate/kenney/%s.glb" % name).instantiate()
	model.position = at
	model.scale = Vector3.ONE * size
	model.rotation.y = yaw
	parent.add_child(model)
	ArenaBuilder.mute_colours(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return model


static func label(parent: Node3D, text: String, at: Vector3, colour: Color, size: float) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.position = at
	sign.font = load(Balance.COMIC_FONT_PATH)
	sign.font_size = Balance.PRICE_FONT_SIZE
	sign.pixel_size = size
	sign.modulate = colour
	sign.outline_modulate = Balance.COMIC_INK
	sign.outline_size = Balance.COMIC_OUTLINE_SIZE
	parent.add_child(sign)
	return sign


static func hull(parent: Node3D, outline: Array[Vector2], top: float, depth: float, colour: Color) -> void:
	var centre := Vector2.ZERO
	for point: Vector2 in outline:
		centre += point
	centre /= outline.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(outline.size()):
		var next: int = (index + 1) % outline.size()
		var a := Vector3(outline[index].x, top, outline[index].y)
		var b := Vector3(outline[next].x, top, outline[next].y)
		var low_a: Vector2 = centre + (outline[index] - centre) * Balance.SHIP_HULL_TAPER
		var low_b: Vector2 = centre + (outline[next] - centre) * Balance.SHIP_HULL_TAPER
		var c := Vector3(low_a.x, top - depth, low_a.y)
		var d := Vector3(low_b.x, top - depth, low_b.y)
		for vertex: Vector3 in [a, b, c, b, d, c]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	var hull_material: StandardMaterial3D = material(colour).duplicate()
	hull_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = hull_material
	parent.add_child(node)
