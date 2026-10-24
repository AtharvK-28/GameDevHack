# Makes a model look like the intro's comic art (STYLE.md): banded toon light on its materials and, optionally, an
# ink outline drawn as a second pass. Visual only. Used on the playfield (movers, loot, possessable furniture), not
# on background decor, so the background stays calmer than the action.
class_name ComicLook
extends RefCounted

static var outline_material: ShaderMaterial # Shared by every outlined model.


static func apply(root: Node, outline: bool) -> void:
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for mesh: MeshInstance3D in meshes:
		if mesh.material_override != null:
			mesh.material_override = _comic(mesh.material_override, outline)
			continue
		for index: int in mesh.get_surface_override_material_count():
			var source: Material = mesh.get_active_material(index)
			if source != null:
				mesh.set_surface_override_material(index, _comic(source, outline))


static func _comic(source: Material, outline: bool) -> Material:
	if not source is BaseMaterial3D:
		return source
	var material: BaseMaterial3D = source.duplicate()
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if outline and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		material.next_pass = _outline()
	return material


static func _outline() -> ShaderMaterial:
	if outline_material == null:
		outline_material = ShaderMaterial.new()
		outline_material.shader = preload("res://assets/shaders/ink_outline.gdshader")
		outline_material.set_shader_parameter("ink", Balance.OUTLINE_INK)
		outline_material.set_shader_parameter("width", Balance.PROP_OUTLINE_WIDTH)
	return outline_material
