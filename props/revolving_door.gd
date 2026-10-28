# The Museum's revolving door, in the lobby's front doorway (decision 132): four glass wings turning slowly round a
# brass post under a canopy, so movers time their way through. The two-person skull and its carriers cannot fit in
# one quarter, so the skull goes out through the laser hall. Possessed, its ACTION is SPIN: the wings whip round for
# a moment and knock down any mover inside the drum.
extends Node3D

var item_name: String = "Revolving door"
var wings := AnimatableBody3D.new()
var spin_left: float = 0.0
var cooldown_left: float = 0.0
var knocked: Array[Node] = [] # Movers already knocked down by this spin.

func _ready() -> void:
	add_to_group("furniture")
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Balance.REVOLVE_GLASS
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Balance.MUSEUM_GOLD
	brass.metallic = 0.6
	brass.roughness = 0.35
	wings.name = "Wings"
	wings.sync_to_physics = true
	wings.collision_layer = Balance.WORLD_LAYER
	wings.collision_mask = 0
	add_child(wings)
	var radius: float = Balance.REVOLVE_RADIUS
	for index: int in range(4):
		var turn: float = index * PI / 2.0
		var wing := Node3D.new()
		wing.rotation.y = turn
		wings.add_child(wing)
		var panel := MeshInstance3D.new()
		var pane := BoxMesh.new()
		pane.size = Vector3(radius, Balance.REVOLVE_HEIGHT, 0.06)
		panel.mesh = pane
		panel.material_override = glass
		panel.position = Vector3(radius / 2.0, Balance.REVOLVE_HEIGHT / 2.0, 0.0)
		wing.add_child(panel)
		var frame := MeshInstance3D.new()
		var rail := BoxMesh.new()
		rail.size = Vector3(radius, 0.06, 0.08)
		frame.mesh = rail
		frame.material_override = brass
		frame.position = Vector3(radius / 2.0, Balance.REVOLVE_HEIGHT - 0.03, 0.0)
		wing.add_child(frame)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(radius, Balance.REVOLVE_HEIGHT, 0.12)
		shape.shape = box
		shape.position = Vector3(cos(turn) * radius / 2.0, Balance.REVOLVE_HEIGHT / 2.0, -sin(turn) * radius / 2.0)
		shape.rotation.y = turn
		wings.add_child(shape)
	var post := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.08
	rod.bottom_radius = 0.08
	rod.height = Balance.REVOLVE_HEIGHT
	post.mesh = rod
	post.material_override = brass
	post.position.y = Balance.REVOLVE_HEIGHT / 2.0
	wings.add_child(post)
	var canopy := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius + 0.1
	disc.bottom_radius = radius + 0.1
	disc.height = 0.12
	canopy.mesh = disc
	canopy.material_override = brass
	canopy.position.y = Balance.REVOLVE_HEIGHT + 0.06
	add_child(canopy)
	ComicLook.apply(self, true)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	spin_left = maxf(0.0, spin_left - delta)
	var speed: float = Balance.REVOLVE_SPIN_SPEED if spin_left > 0.0 else Balance.REVOLVE_IDLE_SPEED
	wings.rotation.y += deg_to_rad(speed) * delta
	if spin_left <= 0.0:
		return
	# A spinning door knocks down whoever is inside the drum, once per spin.
	for mover: Node in get_tree().get_nodes_in_group("movers"):
		var gap := Vector2(mover.global_position.x - global_position.x, mover.global_position.z - global_position.z)
		if mover.in_play and gap.length() < Balance.REVOLVE_RADIUS and mover not in knocked:
			knocked.append(mover)
			var push := Vector3(-gap.y, 0.0, gap.x).normalized() * Balance.REVOLVE_KNOCK_SPEED
			mover.tumble(push)


# --- The ghost's ACTION (Possessable kind DOOR) ---
func action_label() -> String:
	return "SPIN"


func can_act() -> bool:
	return cooldown_left <= 0.0 and spin_left <= 0.0


func act() -> void:
	spin_left = Balance.REVOLVE_SPIN_SECONDS
	cooldown_left = Balance.REVOLVE_COOLDOWN
	knocked.clear()
	Sfx.play("whoosh", 1.2, Balance.REVOLVE_WHOOSH_DB)
	print("The revolving door spins")
