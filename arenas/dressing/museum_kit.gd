# Places the Museum's imported models at real sizes. The CC0 models come in at odd scales (centimetre units under
# ×100 and ×300 nodes), so each is measured through its own node transforms and scaled to a height in metres,
# standing on the given point and centred on it. Also builds the plain boxes the dressing needs (pedestal colliders).
class_name MuseumKit
extends RefCounted

static func place(parent: Node3D, path: String, at: Vector3, height: float, yaw_degrees: float = 0.0, outline: bool = true) -> Node3D:
	var model: Node3D = load(path).instantiate()
	var box: AABB = bounds(model)
	var fit: float = height / maxf(box.size.y, 0.0001)
	model.scale *= fit
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) * fit
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename().to_pascal_case()
	holder.add_child(model)
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw_degrees)
	parent.add_child(holder)
	ComicLook.apply(model, outline)
	# Kenney's Space Kit is fully metallic, which reads black without reflections in the dark galleries.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for index: int in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_surface_override_material(index) as BaseMaterial3D
			if material != null:
				material.metallic = 0.0
	# An animated model stands frozen in its idle pose, like a life-size exhibit.
	for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		for animation: String in player.get_animation_list():
			if animation.ends_with("Idle"):
				player.play(animation)
				player.seek(0.0, true)
				player.pause()
	return holder


# The model's bounds in its own root's space, from the transforms of every node between a mesh and the root.
# An animated model's mesh bounds are in its bind space, not where the skeleton puts it, so its bones are measured
# instead, padded out to the flesh around them.
static func bounds(model: Node3D) -> AABB:
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		return _bone_bounds(model, skeletons[0])
	var box := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = _to_root(mesh, model) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


static func _bone_bounds(model: Node3D, skeleton: Skeleton3D) -> AABB:
	var to_root: Transform3D = _to_root(skeleton, model)
	var box := AABB(to_root * skeleton.get_bone_global_rest(0).origin, Vector3.ZERO)
	for bone: int in range(skeleton.get_bone_count()):
		box = box.expand(to_root * skeleton.get_bone_global_rest(bone).origin)
	var pad: float = box.size.length() * Balance.MUSEUM_BONE_PAD
	box = box.grow(pad)
	box.position.y += pad # Feet bones sit at the soles: no padding below them.
	box.size.y -= pad
	return box


static func _to_root(node: Node3D, model: Node3D) -> Transform3D:
	var transform: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != model and parent is Node3D:
		transform = (parent as Node3D).transform * transform
		parent = parent.get_parent()
	return transform


# An invisible solid box, so loot can rest on a pedestal and movers bump into exhibits.
static func solid(parent: Node3D, node_name: String, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = Balance.WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	parent.add_child(body)
	return body
