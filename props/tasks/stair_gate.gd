# The iron gate across the foot of the gallery stairs (decision 158). Shut, it is solid to movers and to loot, so
# the gallery and Seth-ji's strongbox are genuinely out of reach until the power is on: the mission is a sequence,
# not a dark room you can wander into. Power swings it open; the ghost cutting the power swings it shut again,
# which can leave a mover stranded upstairs until the crew throws the breaker back.
extends StaticBody3D

const BAR_COUNT: int = 7
const BAR_RADIUS: float = 0.035
const SWING_SECONDS: float = 0.6

# --- State ---
var shut: bool = true
var leaf := Node3D.new() # The bars, swung aside as one.
var blocker := CollisionShape3D.new()

# --- Setup ---
func _ready() -> void:
	collision_layer = Balance.WORLD_LAYER
	collision_mask = 0
	add_child(leaf)
	# The hinge is at the wall end, so the leaf folds flat against the wall instead of spinning about its middle.
	leaf.position.x = Balance.MISSION_GATE_HINGE_INSET - Balance.MISSION_GATE_WIDTH / 2.0
	var length: float = Balance.MISSION_GATE_WIDTH - Balance.MISSION_GATE_HINGE_INSET
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Balance.FURNITURE_COLOURS[1].darkened(0.45) # Wrought iron, darker than the furniture grey.
	iron.metallic = 0.7
	iron.roughness = 0.4
	var height: float = Balance.ARENA_WALL_HEIGHT * 0.62
	for index: int in BAR_COUNT:
		var bar := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = BAR_RADIUS
		rod.bottom_radius = BAR_RADIUS
		rod.height = height
		bar.mesh = rod
		bar.material_override = iron
		bar.position = Vector3(length * float(index) / (BAR_COUNT - 1), height / 2.0, 0.0)
		leaf.add_child(bar)
	for rail: float in [0.12, height - 0.12]: # Top and bottom rails tie the bars together.
		var bar := MeshInstance3D.new()
		var rod := BoxMesh.new()
		rod.size = Vector3(length, BAR_RADIUS * 2.0, BAR_RADIUS * 2.0)
		bar.mesh = rod
		bar.material_override = iron
		bar.position = Vector3(length / 2.0, rail, 0.0)
		leaf.add_child(bar)

	var box := BoxShape3D.new()
	box.size = Vector3(Balance.MISSION_GATE_WIDTH, height, 0.16)
	blocker.shape = box
	blocker.position.y = height / 2.0
	add_child(blocker)


# --- Opening and shutting ---
func set_shut(closed: bool) -> void:
	if shut == closed:
		return
	shut = closed
	blocker.set_deferred("disabled", not closed) # Deferred: the shape cannot change mid physics step.
	var swing := leaf.create_tween()
	swing.tween_property(leaf, "rotation:y", 0.0 if closed else deg_to_rad(Balance.MISSION_GATE_OPEN_ANGLE), SWING_SECONDS)
	Sfx.play("creak", 0.8 if closed else 1.1)
	print("The stair gate is %s" % ("shut" if closed else "open"))
