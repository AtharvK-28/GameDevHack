# The fuse box (decision 158): the Mansion mission's two-sided switch, the one object both sides work.
#   Movers  - hold GRAB at it. The first time this opens the wire puzzle on their phone (step three); afterwards
#             it simply throws the breaker back on, which takes MISSION_RESTORE_SECONDS.
#   Ghost   - possess it and press ACTION to cut the power, for MISSION_CUT_COST energy and a long cooldown, so
#             it is a decision rather than something to lean on.
# Power open the stair gate and lights the gallery; cutting it shuts the gate again, with whoever is upstairs
# stuck behind it. A mover throwing it back on is the counter the crew has to one of the ghost's abilities.
extends Node3D

const POSSESSABLE := preload("res://props/Possessable.gd")

signal power_changed(on: bool)
signal puzzle_wanted(slot: int)

# --- State ---
var mission: Mission
var powered: bool = false
var cut_cooldown_left: float = 0.0
var restoring: float = 0.0 # Seconds a mover has held GRAB at the box.
var item_name: String = "Fuse box"
var lever: MeshInstance3D
var meter := Label3D.new()

# --- Setup ---
func _ready() -> void:
	add_to_group("furniture") # So the ghost can find it like any other possessable prop.
	var case_mesh := MeshInstance3D.new()
	var case_box := BoxMesh.new()
	case_box.size = Balance.MISSION_FUSE_SIZE
	case_mesh.mesh = case_box
	case_mesh.position.y = Balance.MISSION_FUSE_SIZE.y
	case_mesh.material_override = _material(Balance.BATTERY_METAL)
	add_child(case_mesh)

	lever = MeshInstance3D.new()
	var lever_box := BoxMesh.new()
	lever_box.size = Vector3(0.08, 0.26, 0.08)
	lever.mesh = lever_box
	lever.position = Vector3(0.0, Balance.MISSION_FUSE_SIZE.y, Balance.MISSION_FUSE_SIZE.z / 2.0 + 0.05)
	lever.material_override = _material(Balance.DAMAGE_COLOUR)
	add_child(lever)

	var body := StaticBody3D.new()
	body.collision_layer = Balance.WORLD_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Balance.MISSION_FUSE_SIZE
	shape.shape = box
	shape.position = case_mesh.position
	body.add_child(shape)
	add_child(body)

	meter.font = load(Balance.COMIC_FONT_PATH)
	meter.font_size = Balance.PRICE_FONT_SIZE
	meter.pixel_size = Balance.TASK_LABEL_PIXEL_SIZE
	meter.outline_size = Balance.LABEL_OUTLINE
	meter.outline_modulate = Balance.COMIC_INK
	meter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	meter.position.y = Balance.MISSION_FUSE_SIZE.y * 2.0 + 0.3
	add_child(meter)

	# The ghost's half of the switch: a Possessable of the door kind, so ACTION comes through to act() below.
	var possessable: Node3D = POSSESSABLE.new()
	possessable.name = "Possessable"
	possessable.kind = 1 # Possessable.Kind.DOOR: the prop supplies its own action.
	add_child(possessable)
	_refresh()


# --- The movers' side ---
func _physics_process(delta: float) -> void:
	cut_cooldown_left = maxf(0.0, cut_cooldown_left - delta)
	if mission == null or not _usable():
		restoring = 0.0
		_refresh()
		return
	var holder: Node3D = _mover_at_the_box()
	if holder == null:
		restoring = 0.0
		_refresh()
		return
	if not powered and mission.is_open("wires"):
		puzzle_wanted.emit(holder.slot) # Step three: the wire puzzle opens on that mover's phone.
		return
	if not powered and mission.is_done("wires"):
		# The power has been cut since; throwing the breaker back on is quick, because the wires are already right.
		restoring += delta
		if restoring >= Balance.MISSION_RESTORE_SECONDS:
			restoring = 0.0
			set_powered(true)
	_refresh()


func _mover_at_the_box() -> Node3D:
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		if not mover.in_play or is_instance_valid(mover.held_item):
			continue
		if Vector2(mover.global_position.x - global_position.x, mover.global_position.z - global_position.z).length() > Balance.MISSION_FUSE_REACH:
			continue
		if InputRouter.for_slot(mover.slot).buttons.get("grab", false):
			return mover
	return null


# --- The ghost's side ---
func can_cut() -> bool:
	return powered and cut_cooldown_left <= 0.0


func cut_power() -> bool:
	if not can_cut():
		return false
	cut_cooldown_left = Balance.MISSION_CUT_COOLDOWN
	set_powered(false)
	Sfx.play("creak", 0.6)
	print("The ghost cut the power")
	return true


# --- The ghost's ACTION, through its Possessable child ---
func action_label() -> String:
	return "CUT POWER"


func can_act() -> bool:
	return can_cut()


func act() -> void:
	cut_power()


func is_spent() -> bool:
	# Nothing for the ghost to do here until the crew has the power on in the first place.
	return not powered


# --- Shared ---
func set_powered(on: bool) -> void:
	if powered == on:
		return
	powered = on
	lever.rotation_degrees.x = -35.0 if on else 35.0
	_refresh()
	power_changed.emit(on)


func solved_puzzle() -> void:
	# The wire puzzle came back solved: step three is done and the power comes on for the first time.
	if mission != null and mission.is_open("wires"):
		mission.complete("wires")
	set_powered(true)
	Sfx.play("bank")


func hud_text() -> String:
	return "Power ON" if powered else "Power OFF"


func _usable() -> bool:
	# Nothing can be done at the box until the cupboard in front of it is open.
	return mission.is_done("cupboard")


func _refresh() -> void:
	if mission == null or not _usable():
		meter.text = ""
		meter.modulate = Balance.UI_MUTED
		return
	if powered:
		meter.text = "POWER ON"
		meter.modulate = Balance.GENERATOR_COLOUR
		return
	if restoring > 0.0:
		var steps: int = clampi(int(restoring / Balance.MISSION_RESTORE_SECONDS * 5.0), 0, 5)
		meter.text = "RESETTING " + "▮".repeat(steps) + "▯".repeat(5 - steps)
	else:
		meter.text = "HOLD GRAB" if mission.is_open("wires") else "POWER CUT · HOLD GRAB"
	meter.modulate = Balance.MISSION_KEY_COLOUR


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
