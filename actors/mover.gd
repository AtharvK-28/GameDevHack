# Minimal capsule for the Phase 1 input check; carrying is added in Phase 2.
extends CharacterBody3D

# --- Player settings ---
var slot: int = 0
var name_label := Label3D.new()

# --- Setup ---
func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = Balance.CAPSULE_RADIUS
	shape.height = Balance.CAPSULE_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var capsule := CapsuleMesh.new()
	capsule.radius = Balance.CAPSULE_RADIUS
	capsule.height = Balance.CAPSULE_HEIGHT
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(Balance.PLAYER_COLOURS[slot])
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.material_override = material
	add_child(mesh)

	name_label.position.y = Balance.LABEL_HEIGHT
	name_label.font_size = Balance.LABEL_FONT_SIZE
	name_label.pixel_size = Balance.LABEL_PIXEL_SIZE
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(name_label)


# --- Movement ---
func _physics_process(delta: float) -> void:
	var player_input: InputRouter.PlayerInput = InputRouter.for_slot(slot)
	var direction: Vector2 = player_input.direction
	if player_input.buttons.get("brace", false):
		direction = Vector2.ZERO
	velocity.x = direction.x * Balance.MOVER_SPEED
	velocity.z = direction.y * Balance.MOVER_SPEED
	if not is_on_floor():
		velocity.y -= Balance.GRAVITY * delta
	move_and_slide()

	# Keep the temporary test floor usable without introducing arena walls.
	var edge: float = Balance.FLOOR_SIZE / 2.0 - Balance.CAPSULE_RADIUS
	position.x = clampf(position.x, -edge, edge)
	position.z = clampf(position.z, -edge, edge)
	var player := Net.player_for_slot(slot)
	name_label.text = "%d · %s" % [slot + 1, player.get("name", "Unclaimed")]
