# The Museum's ALARM (decision 137): lasers, screams and torch-beam catches fill a bar shown on the big screen. When it
# fills, police lights flash outside and a countdown runs; then steel shutters drop over the three doorways between the
# back galleries and the rest of the museum, cutting off the rotunda, Egypt and the Jurassic Hall (and any loot in
# them) for the lockdown. Then the shutters rise and the alarm resets. Movers standing in a doorway as its shutter
# drops are pushed out to the front side.
extends Node3D

var enabled: bool = true # Checks switch it off while they test other things.
var level: float = 0.0
var state: String = "" # "", "warning" (police on the way), "lockdown".
var left: float = 0.0
var shutters: Array[StaticBody3D] = []
var police: Array[OmniLight3D] = []
var flash_time: float = 0.0
var meter := Label.new()
var banner := Label.new()

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	for label: Label in [meter, banner]:
		label.add_theme_font_override("font", load(Balance.COMIC_FONT_PATH))
		label.add_theme_color_override("font_outline_color", Balance.COMIC_INK)
		label.add_theme_constant_override("outline_size", Balance.BANNER_OUTLINE_SIZE)
		canvas.add_child(label)
	meter.add_theme_font_size_override("font_size", Balance.ALARM_METER_FONT_SIZE)
	meter.add_theme_color_override("font_color", Balance.LASER_COLOUR)
	meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, Balance.ALARM_METER_MARGIN)
	meter.hide()
	banner.add_theme_font_size_override("font_size", Balance.BANNER_FONT_SIZE)
	banner.add_theme_color_override("font_color", Balance.LASER_COLOUR)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, Balance.BANNER_TOP + Balance.ALARM_BANNER_DROP)
	banner.hide()
	for at: Vector3 in Balance.ALARM_POLICE_LIGHTS:
		var light := OmniLight3D.new()
		light.position = at
		light.omni_range = Balance.ALARM_POLICE_RANGE
		light.light_energy = 0.0
		light.shadow_enabled = false
		add_child(light)
		police.append(light)


func add(amount: float) -> void:
	if not enabled or state != "":
		return # Already coming.
	level = minf(100.0, level + amount)
	meter.show()
	if level >= 100.0:
		state = "warning"
		left = Balance.ALARM_WARNING
		Sfx.play("whistle", 0.5, Balance.LASER_ALARM_DB)
		print("ALARM full: police on the way")


func _process(delta: float) -> void:
	flash_time += delta
	var blocks: int = int(level / 10.0)
	meter.text = "ALARM " + "▮".repeat(blocks) + "▯".repeat(10 - blocks)
	var flashing: bool = state != ""
	for index: int in police.size():
		var light: OmniLight3D = police[index]
		var red: bool = int(flash_time * Balance.ALARM_FLASH_RATE + index) % 2 == 0
		light.light_color = Balance.LASER_COLOUR if red else Balance.ALARM_POLICE_BLUE
		light.light_energy = Balance.ALARM_POLICE_ENERGY if flashing else 0.0


func _physics_process(delta: float) -> void:
	if state == "":
		banner.hide()
		return
	left -= delta
	banner.show()
	if state == "warning":
		banner.text = "POLICE ON THE WAY! LOCKDOWN IN %d" % ceili(left)
		if left <= 0.0:
			_close()
	elif state == "lockdown":
		banner.text = "LOCKDOWN! %d" % ceili(left)
		if left <= 0.0:
			_open()


func _close() -> void:
	state = "lockdown"
	left = Balance.ALARM_LOCKDOWN
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("5b636c")
	steel.metallic = 0.5
	steel.roughness = 0.4
	for door: Vector2 in Balance.ALARM_SHUTTER_DOORS:
		var width: float = door.y - door.x
		var centre := Vector3((door.x + door.y) / 2.0, Balance.ALARM_SHUTTER_HEIGHT / 2.0, Balance.ALARM_SHUTTER_Z)
		# Anyone in the doorway is pushed out to the front side first.
		for mover: Node3D in get_tree().get_nodes_in_group("movers"):
			var at: Vector3 = mover.global_position
			if at.x > door.x - 0.3 and at.x < door.y + 0.3 and absf(at.z - centre.z) < 0.6:
				mover.global_position.z = centre.z + 0.8
		var shutter := StaticBody3D.new()
		shutter.collision_layer = Balance.WORLD_LAYER
		shutter.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, Balance.ALARM_SHUTTER_HEIGHT, 0.15)
		shape.shape = box
		shutter.add_child(shape)
		var mesh := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = box.size
		mesh.mesh = slab
		mesh.material_override = steel
		shutter.add_child(mesh)
		shutter.position = centre
		add_child(shutter)
		shutters.append(shutter)
		mesh.position.y = Balance.ALARM_SHUTTER_HEIGHT # The look drops in; the body is solid at once.
		mesh.create_tween().tween_property(mesh, "position:y", 0.0, Balance.ALARM_SHUTTER_DROP)
	Sfx.play("rumble", 1.3, Balance.LASER_ALARM_DB)
	print("LOCKDOWN: the back galleries are shut")


func _open() -> void:
	for shutter: StaticBody3D in shutters:
		shutter.queue_free()
	shutters.clear()
	state = ""
	level = 0.0
	meter.hide()
	print("Lockdown over: the shutters rise")
