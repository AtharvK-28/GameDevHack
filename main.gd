# Four-capsule plumbing playground, replaced by match flow in Phase 5.
extends Node3D

# --- Resources and display state ---
const MOVER_SCENE := preload("res://actors/Mover.tscn")
var status_label := Label.new()

# --- Setup ---
func _ready() -> void:
	_build_floor()
	_build_camera()
	_build_overlay()
	for slot: int in range(Balance.MAX_PLAYERS):
		var mover := MOVER_SCENE.instantiate()
		mover.slot = slot
		mover.position = Vector3((slot - (Balance.MAX_PLAYERS - 1) / 2.0) * Balance.SPAWN_SPACING, Balance.CAPSULE_HEIGHT / 2.0, 0.0)
		add_child(mover)
	Net.players_changed.connect(_start_ready_controllers)
	print("Phase 1: four capsules ready. Keys 1-4 select an unconnected slot.")


# --- Test feedback ---
func _process(_delta: float) -> void:
	var lines: PackedStringArray = ["GHOSTED MOVERS · CONTROLLER CHECK"]
	if Net.listen_error != OK:
		lines.append("PORT %d BUSY — close the other game instance, then restart." % Balance.SOCKET_PORT)
	else:
		for address: String in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
				lines.append("Phone page: http://%s:%d (start the page server first)" % [address, Balance.WEB_PORT])
	lines.append("Keyboard: 1–4 select · WASD/arrows move · Space grab · E throw · Shift brace")
	lines.append("Grab / throw show input only. Carrying comes in Phase 2.")
	for slot: int in range(Balance.MAX_PLAYERS):
		var input: InputRouter.PlayerInput = InputRouter.for_slot(slot)
		var player := Net.player_for_slot(slot)
		var source: String = "idle"
		if player.get("socket") != null:
			source = "phone"
		elif slot == InputRouter.selected_slot:
			source = "keyboard"
		var held: PackedStringArray = []
		for button: String in input.buttons:
			if input.buttons[button]:
				held.append(button.to_upper())
		lines.append("%d · %s · %s  %s" % [slot + 1, player.get("name", "Unclaimed"), source, " + ".join(held)])
	status_label.text = "\n".join(lines)


func _start_ready_controllers() -> void:
	# This harness assigns mover controls only; real roles belong to Game in Phase 5.
	for player: Dictionary in Net.players:
		if player.ready and player.role.is_empty():
			Net.set_role(player.slot, "mover", "Plumbing test")


# --- Scene helpers ---
func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -Balance.FLOOR_THICKNESS / 2.0
	var size := Vector3(Balance.FLOOR_SIZE, Balance.FLOOR_THICKNESS, Balance.FLOOR_SIZE)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("384b4b")
	mesh.material_override = material
	floor_body.add_child(mesh)
	add_child(floor_body)


func _build_camera() -> void:
	var camera := Camera3D.new()
	var angle: float = deg_to_rad(Balance.CAMERA_ANGLE)
	camera.position = Vector3(0.0, sin(angle), cos(angle)) * Balance.CAMERA_DISTANCE
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Balance.LIGHT_ROTATION
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("162a2b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	add_child(environment)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2.ONE * Balance.OVERLAY_MARGIN
	canvas.add_child(panel)
	panel.add_child(status_label)
