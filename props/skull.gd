# The T-Rex skull (Museum of Mostly Real Things): damage you can see. Every share of value it loses knocks out one of
# its teeth, which pops off and clatters across the floor; and while two movers carry it, its jaw clacks open and
# shut in step with their walk. Otherwise ordinary two-person loot.
class_name TRexSkull
extends Loot

var teeth: Array[Node3D] = []
var lost_teeth: int = 0
var jaw: Node3D
var clack_time: float = 0.0


func _ready() -> void:
	super()
	if model != null:
		jaw = model.find_child("Jaw", true, false)
		var row: Node = model.find_child("Teeth", true, false)
		if row != null:
			for tooth: Node in row.get_children():
				teeth.append(tooth)


func _process(delta: float) -> void:
	super(delta)
	if jaw == null:
		return
	# The jaw clacks while the skull travels in two movers' hands, and closes when it stops.
	var travelling: bool = holder_count() == 2 and Vector2(linear_velocity.x, linear_velocity.z).length() > Balance.SKULL_CLACK_SPEED
	clack_time = clack_time + delta if travelling else 0.0
	var open: float = absf(sin(clack_time * PI * Balance.SKULL_CLACK_RATE)) * Balance.SKULL_JAW_OPEN if travelling else 0.0
	jaw.rotation.z = lerpf(jaw.rotation.z, -open, minf(1.0, delta * 20.0))


func _lose_value(loss: int) -> void:
	super(loss)
	if finished:
		return
	# One tooth per equal share of the starting value, so the last tooth goes with the last rupee.
	var due: int = mini(teeth.size(), floori((1.0 - float(value) / initial_value) * teeth.size()))
	while lost_teeth < due:
		_knock_out(teeth[lost_teeth])
		lost_teeth += 1


func _knock_out(tooth: Node3D) -> void:
	if not tooth.visible:
		return
	tooth.visible = false
	var loose := RigidBody3D.new()
	loose.collision_layer = 0
	loose.collision_mask = Balance.WORLD_LAYER
	loose.mass = 0.05
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.04
	shape.shape = sphere
	loose.add_child(shape)
	var look: MeshInstance3D = (tooth as MeshInstance3D).duplicate() if tooth is MeshInstance3D else MeshInstance3D.new()
	look.position = Vector3.ZERO
	look.visible = true
	loose.add_child(look)
	get_parent().add_child(loose)
	loose.global_transform = tooth.global_transform
	loose.scale = Vector3.ONE
	var random := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	loose.apply_central_impulse((random * Balance.SKULL_TOOTH_KICK + Vector3.UP * Balance.SKULL_TOOTH_POP) * loose.mass)
	loose.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 0.002)
	Sfx.varied("boing", Balance.SKULL_TOOTH_DB)
	get_tree().create_timer(Balance.SKULL_TOOTH_LIFETIME).timeout.connect(loose.queue_free)
