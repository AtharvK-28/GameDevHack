# The Museum's security cameras (decision 138): three CCTV cameras sweeping Egypt, the Art Gallery and the Space
# Gallery, each showing a faint red cone. A mover inside a camera's cone, in its gallery, is spotted: SPOTTED! over them
# on the big screen, a little ALARM, and on their own phone a red "REC: you're on camera" until they get out of view.
# The ghost's phone lists who each camera sees, so Bahadur knows where the crew is. Phones get {"type": "cam", "on",
# "where"} and the ghost {"type": "cams", "seen": [{"where", "name"}]}.
extends Node3D

var cameras: Array[Dictionary] = [] # {name, at, base_yaw, head: Node3D, room: Rect2}
var spotted: Dictionary = {} # Mover slot -> the camera's name that sees them, or "".
var alarm_rest: Dictionary = {} # Mover slot -> seconds before being spotted again raises the alarm.
var ghost_view: String = "" # Last list sent to the ghost, to send only changes.
var sweep_time: float = 0.0

func _ready() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color("2a2e33")
	var led := StandardMaterial3D.new()
	led.albedo_color = Balance.LASER_COLOUR
	led.emission_enabled = true
	led.emission = Balance.LASER_COLOUR
	led.emission_energy_multiplier = 3.0
	var cone_material := StandardMaterial3D.new()
	cone_material.albedo_color = Color(Balance.LASER_COLOUR, Balance.CAMERA_CONE_ALPHA)
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for spec: Array in Balance.CAMERAS:
		var head := Node3D.new()
		head.position = spec[1]
		add_child(head)
		var box := MeshInstance3D.new()
		var shell := BoxMesh.new()
		shell.size = Vector3(0.22, 0.18, 0.4)
		box.mesh = shell
		box.material_override = body
		box.position = Vector3(0, 0, -0.15)
		head.add_child(box)
		var light := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.035
		dot.height = 0.07
		light.mesh = dot
		light.material_override = led
		light.position = Vector3(0.07, 0.06, -0.36)
		head.add_child(light)
		# The view cone, lying along the camera's forward (−Z) and tipped down toward the floor.
		var cone := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.0
		shape.bottom_radius = Balance.CAMERA_RANGE * tan(deg_to_rad(Balance.CAMERA_HALF_ANGLE))
		shape.height = Balance.CAMERA_RANGE
		shape.radial_segments = 16
		cone.mesh = shape
		cone.material_override = cone_material
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = -PI / 2.0
		cone.position = Vector3(0, 0, -Balance.CAMERA_RANGE / 2.0)
		var tilt := Node3D.new()
		tilt.rotation.x = -deg_to_rad(Balance.CAMERA_TILT)
		tilt.add_child(cone)
		head.add_child(tilt)
		var look: Vector2 = spec[2] - Vector2(spec[1].x, spec[1].z)
		cameras.append({"name": spec[0], "base_yaw": atan2(-look.x, -look.y), "head": head, "room": spec[3]}) # Faces its gallery.


func _physics_process(delta: float) -> void:
	sweep_time += delta
	for camera: Dictionary in cameras:
		camera.head.rotation.y = camera.base_yaw + sin(sweep_time * TAU / Balance.CAMERA_PERIOD) * deg_to_rad(Balance.CAMERA_SWEEP)
	for slot: int in alarm_rest.keys():
		alarm_rest[slot] = maxf(0.0, alarm_rest[slot] - delta)
	var seen: Array[Dictionary] = []
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		var where: String = sees(mover) if mover.in_play else ""
		if where != "":
			seen.append({"where": where, "name": String(Net.player_for_slot(mover.slot).get("name", "Player %d" % (mover.slot + 1)))})
		if where == spotted.get(mover.slot, ""):
			continue
		spotted[mover.slot] = where
		_tell_mover(mover.slot, where)
		if where != "" and alarm_rest.get(mover.slot, 0.0) <= 0.0:
			alarm_rest[mover.slot] = Balance.CAMERA_ALARM_REST
			_popup(mover)
			var arena: Node = get_parent()
			if arena.has_method("raise_alarm"):
				arena.raise_alarm(0.0, -1, Balance.ALARM_CAMERA)
	_tell_ghost(seen)


# The camera that sees this mover, or "": inside its gallery, within range and within its cone.
func sees(mover: Node3D) -> String:
	var at := Vector2(mover.global_position.x, mover.global_position.z)
	for camera: Dictionary in cameras:
		var head: Node3D = camera.head
		if not (camera.room as Rect2).has_point(at):
			continue
		var to := at - Vector2(head.global_position.x, head.global_position.z)
		if to.length() > Balance.CAMERA_RANGE:
			continue
		var forward := Vector2(-sin(head.rotation.y), -cos(head.rotation.y)) # The head's −Z on the floor.
		if rad_to_deg(absf(forward.angle_to(to))) <= Balance.CAMERA_HALF_ANGLE:
			return camera.name
	return ""


func _tell_mover(slot: int, where: String) -> void:
	var player: Dictionary = Net.player_for_slot(slot)
	if not player.is_empty():
		Net.send_to_player(player, {"type": "cam", "on": where != "", "where": where})


func _tell_ghost(seen: Array[Dictionary]) -> void:
	var view: String = JSON.stringify(seen)
	if view == ghost_view:
		return
	ghost_view = view
	var player: Dictionary = Net.player_for_slot(Game.ghost_slot) if Game.ghost_slot >= 0 else {}
	if not player.is_empty():
		Net.send_to_player(player, {"type": "cams", "seen": seen})


func _popup(mover: Node3D) -> void:
	var popup := Label3D.new()
	popup.text = "SPOTTED!"
	popup.font = load(Balance.COMIC_FONT_PATH)
	popup.font_size = Balance.PRICE_FONT_SIZE
	popup.modulate = Balance.LASER_COLOUR
	popup.outline_size = Balance.VALUE_POPUP_OUTLINE
	popup.outline_modulate = Balance.COMIC_INK
	popup.pixel_size = Balance.VALUE_POPUP_PIXEL_SIZE
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	add_child(popup)
	popup.global_position = mover.global_position + Vector3.UP * Balance.JAAGTE_POPUP_HEIGHT
	var tween := popup.create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 0.4)
	tween.tween_callback(popup.queue_free)
