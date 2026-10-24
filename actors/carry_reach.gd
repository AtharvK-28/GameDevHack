# Reaches the animated arms toward held loot after animation evaluation; only the visible skeleton changes.
@tool
extends SkeletonModifier3D

# --- State ---
var item: Node3D
var mover: CharacterBody3D

# --- Visual pose ---
func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(item) or not is_instance_valid(mover) or mover.is_tumbling():
		get_skeleton().clear_bones_global_pose_override()
		return
	var skeleton: Skeleton3D = get_skeleton()
	skeleton.clear_bones_global_pose_override()
	skeleton.force_update_all_bone_transforms()
	for side: String in ["L", "R"]:
		var hand: int = skeleton.find_bone("hand." + side)
		var hand_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
		var local_hand: Vector3 = item.to_local(hand_world)
		var half: Vector3 = item.item_size / 2.0
		var grip := Vector3(clampf(local_hand.x, -half.x, half.x), clampf(local_hand.y, -half.y, half.y), clampf(local_hand.z, -half.z, half.z))
		if item.weight_class == Balance.TWO_PERSON:
			var index: int = item.handle_holders.find(mover)
			if index >= 0:
				grip = item.to_local(item.handle_position(index))
		_reach(skeleton, side, skeleton.to_local(item.to_global(grip)))


# --- Two-bone arm solve ---
func _reach(skeleton: Skeleton3D, side: String, target: Vector3) -> void:
	var upper: int = skeleton.find_bone("upper_arm." + side)
	var lower: int = skeleton.find_bone("forearm." + side)
	var hand: int = skeleton.find_bone("hand." + side)
	var shoulder: Transform3D = skeleton.get_bone_global_pose(upper)
	var elbow: Transform3D = skeleton.get_bone_global_pose(lower)
	var wrist: Transform3D = skeleton.get_bone_global_pose(hand)
	var upper_length: float = skeleton.get_bone_rest(lower).origin.length()
	var lower_length: float = skeleton.get_bone_rest(hand).origin.length()
	var offset: Vector3 = target - shoulder.origin
	var distance: float = offset.length()
	if distance < Balance.MODEL_REACH_EPSILON:
		return
	var stretch: float = clampf(distance / (upper_length + lower_length) * Balance.MODEL_REACH_BEND, 1.0, Balance.MODEL_REACH_STRETCH)
	upper_length *= stretch
	lower_length *= stretch
	distance = clampf(distance, absf(upper_length - lower_length) + Balance.MODEL_REACH_EPSILON, upper_length + lower_length - Balance.MODEL_REACH_EPSILON)
	var direction: Vector3 = offset.normalized()
	var bend: Vector3 = Vector3.DOWN.slide(direction).normalized()
	if bend.is_zero_approx():
		bend = Vector3.FORWARD.slide(direction).normalized()
	var along: float = (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var elbow_target: Vector3 = shoulder.origin + direction * along + bend * height
	var hand_target: Vector3 = shoulder.origin + direction * distance
	shoulder.basis = Basis(Quaternion((elbow.origin - shoulder.origin).normalized(), (elbow_target - shoulder.origin).normalized())) * shoulder.basis
	shoulder.basis = shoulder.basis * Basis.from_scale(Vector3(1.0, stretch, 1.0))
	skeleton.set_bone_global_pose_override(upper, shoulder, 1.0, true)
	skeleton.force_update_all_bone_transforms()
	elbow.basis = Basis(Quaternion((wrist.origin - elbow.origin).normalized(), (hand_target - elbow_target).normalized())) * elbow.basis
	elbow.basis = elbow.basis * Basis.from_scale(Vector3(1.0, stretch, 1.0))
	elbow.origin = elbow_target
	skeleton.set_bone_global_pose_override(lower, elbow, 1.0, true)
	skeleton.force_update_all_bone_transforms()
	wrist.origin = hand_target
	skeleton.set_bone_global_pose_override(hand, wrist, 1.0, true)
	skeleton.force_update_all_bone_transforms()
