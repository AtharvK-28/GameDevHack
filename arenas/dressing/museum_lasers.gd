# The laser hall's tripwires (decision 133): three gates of red beams across the hall, the short way to the van,
# blinking on and off in a rolling rhythm, so a crew times its crossing. A mover crossing a lit gate trips the alarm:
# a siren, the hall flashing red, ALARM! over them, and a gift of energy to the ghost. The Museum reports each trip
# (alarm_tripped), for the round's awards. The emitters are dark steel boxes on the hall's walls.
extends Node3D

var gates: Array[Dictionary] = [] # {x, beams: Array[MeshInstance3D], on}
var cycle_time: float = 0.0 # Checks may set this to put the gates in a known state.
var cooldowns: Dictionary = {} # "slot:gate" -> seconds before that mover can trip that gate again.
var flash := OmniLight3D.new()
var flash_left: float = 0.0
var beam_material := StandardMaterial3D.new()

func _ready() -> void:
	beam_material.albedo_color = Balance.LASER_COLOUR
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.emission_enabled = true
	beam_material.emission = Balance.LASER_COLOUR
	beam_material.emission_energy_multiplier = Balance.LASER_GLOW
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("2a2e33")
	for x: float in Balance.LASER_GATES_X:
		var beams: Array[MeshInstance3D] = []
		for z: float in [Balance.LASER_HALL_Z.x, Balance.LASER_HALL_Z.y]:
			var emitter := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.18, Balance.LASER_HEIGHTS[-1] + 0.3, 0.12)
			emitter.mesh = box
			emitter.material_override = steel
			emitter.position = Vector3(x, box.size.y / 2.0, z)
			add_child(emitter)
		for height: float in Balance.LASER_HEIGHTS:
			var beam := MeshInstance3D.new()
			var line := CylinderMesh.new()
			line.top_radius = Balance.LASER_RADIUS
			line.bottom_radius = Balance.LASER_RADIUS
			line.height = Balance.LASER_HALL_Z.y - Balance.LASER_HALL_Z.x
			line.radial_segments = 6
			beam.mesh = line
			beam.material_override = beam_material
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.rotation.x = PI / 2.0
			beam.position = Vector3(x, height, (Balance.LASER_HALL_Z.x + Balance.LASER_HALL_Z.y) / 2.0)
			add_child(beam)
			beams.append(beam)
		gates.append({"x": x, "beams": beams, "on": true})
	flash.light_color = Balance.LASER_COLOUR
	flash.light_energy = 0.0
	flash.omni_range = 9.0
	flash.position = Vector3(6.0, 2.6, 17.5)
	add_child(flash)


func is_on(index: int) -> bool:
	# Each gate is lit for LASER_ON_SHARE of the cycle, the next gate a step behind, so a gap rolls down the hall.
	var phase: float = fposmod(cycle_time - index * Balance.LASER_STAGGER, Balance.LASER_PERIOD) / Balance.LASER_PERIOD
	return phase < Balance.LASER_ON_SHARE


func dark_for(index: int) -> float:
	# Seconds the gate stays dark from now; 0 while it is lit.
	if is_on(index):
		return 0.0
	var phase: float = fposmod(cycle_time - index * Balance.LASER_STAGGER, Balance.LASER_PERIOD)
	return Balance.LASER_PERIOD - phase


func should_wait(at: Vector3, stick: Vector2) -> bool:
	# For the bots: true while the gate just ahead of a mover is lit, or about to light while the mover is still a step
	# away; once close to a dark gate, they commit and cross.
	if at.z < Balance.LASER_HALL_Z.x or at.z > Balance.LASER_HALL_Z.y or absf(stick.x) < 0.2:
		return false
	for index: int in gates.size():
		var ahead: float = (gates[index].x - at.x) * signf(stick.x)
		if ahead <= Balance.LASER_TRIP_WIDTH or ahead > Balance.LASER_WAIT_DISTANCE:
			continue # Behind, already crossing, or still far off.
		if is_on(index) and ahead > Balance.LASER_STOP_MARGIN:
			return true # Stop short, so the slow-down never carries a mover into the beams.
		if ahead > Balance.LASER_COMMIT_DISTANCE and dark_for(index) < Balance.LASER_SAFE_WINDOW:
			return true # About to light, and too far to make it.
	return false


func _physics_process(delta: float) -> void:
	cycle_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	flash.light_energy = Balance.LASER_FLASH_ENERGY * absf(sin(flash_left * TAU * 2.0)) if flash_left > 0.0 else 0.0
	for key: String in cooldowns.keys():
		cooldowns[key] = maxf(0.0, cooldowns[key] - delta)
	for index: int in gates.size():
		var gate: Dictionary = gates[index]
		gate.on = is_on(index)
		for beam: MeshInstance3D in gate.beams:
			beam.visible = gate.on
		if not gate.on:
			continue
		for mover: Node in get_tree().get_nodes_in_group("movers"):
			if not mover.in_play or absf(mover.global_position.x - gate.x) > Balance.LASER_TRIP_WIDTH:
				continue
			if mover.global_position.z < Balance.LASER_HALL_Z.x or mover.global_position.z > Balance.LASER_HALL_Z.y:
				continue
			var key: String = "%d:%d" % [mover.slot, index]
			if cooldowns.get(key, 0.0) > 0.0:
				continue
			cooldowns[key] = Balance.LASER_TRIP_GAP
			_trip(mover)


func _trip(mover: Node3D) -> void:
	flash_left = Balance.LASER_FLASH_SECONDS
	Sfx.play("whistle", 0.6, Balance.LASER_ALARM_DB) # A low, wailing alarm from the whistle, pitched down.
	var popup := Label3D.new()
	popup.text = "ALARM!"
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
	var arena: Node = get_parent()
	for ghost: Node in get_tree().get_nodes_in_group("ghosts"):
		if ghost.get("arena") == arena:
			ghost.energy = minf(Balance.ENERGY_MAX, ghost.energy + Balance.LASER_ALARM_ENERGY)
	if arena.has_signal("alarm_tripped"):
		arena.alarm_tripped.emit(mover.slot)
	print("Player %d tripped a laser" % (mover.slot + 1))
