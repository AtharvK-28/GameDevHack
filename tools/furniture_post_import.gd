# Import script for the Kenney furniture models (set in each model's .import file): scales the model to the
# game's furniture size (the kit is about half life-size next to the 1.6 m movers) and moves its pivot from
# Kenney's front corner to the bottom-centre, so every piece can be placed by its footprint's centre.
# The model's front stays facing +Z.
@tool
extends EditorScenePostImport

const FURNITURE_SCALE: float = 1.9

func _post_import(scene: Node) -> Object:
	var bounds := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = _transform_to_root(mesh, scene) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var offset := Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	for child: Node in scene.get_children():
		if child is Node3D:
			child.transform = Transform3D(Basis().scaled(Vector3.ONE * FURNITURE_SCALE), offset * FURNITURE_SCALE) * child.transform
	return scene


func _transform_to_root(node: Node3D, root: Node) -> Transform3D:
	var transform: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != root and parent is Node3D:
		transform = parent.transform * transform
		parent = parent.get_parent()
	return transform
