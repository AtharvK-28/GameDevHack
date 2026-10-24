# The delivery truck: the scanned pickup (assets/models/truck/truck.obj), turned square, scaled to the movers
# and placed so its tailgate sits at this node's origin facing −X, wheels on the ground. Two simple boxes
# (the bed and the cab) make it solid. Delivery happens in the TruckZone half-circle behind the tailgate.
# Its headlights are on and its hazard lamps blink, like a mover's truck left running at the kerb.
extends StaticBody3D

# --- Light placement (metres in the truck's frame: tailgate at x 0, cab toward +X) ---
const LIGHT_HEIGHT: float = 0.75
const LIGHT_SPREAD: float = 0.65 # Either side of the centre line.
const HAZARD_SIZE: float = 0.1
const HEADLIGHT_ANGLE: float = 35.0 # Degrees: the beam's half-angle.

var hazards: Array[MeshInstance3D] = []

# --- Setup ---
func _ready() -> void:
	collision_layer = Balance.WORLD_LAYER
	collision_mask = Balance.MOVER_LAYER | Balance.LOOT_LAYER
	_build_model()
	var bed := Vector3(Balance.TRUCK_BED_LENGTH, Balance.TRUCK_BED_HEIGHT, Balance.TRUCK_WIDTH)
	_add_box(bed, Vector3(bed.x / 2.0, bed.y / 2.0, 0.0))
	var cab_length: float = Balance.TRUCK_LENGTH - Balance.TRUCK_BED_LENGTH
	var cab := Vector3(cab_length, Balance.TRUCK_CAB_HEIGHT, Balance.TRUCK_WIDTH)
	_add_box(cab, Vector3(Balance.TRUCK_BED_LENGTH + cab_length / 2.0, cab.y / 2.0, 0.0))
	_add_lights()


func _build_model() -> void:
	# Rotate the scan's cab-to-tailgate line onto −X, scale it to TRUCK_LENGTH, then move its tailgate to the origin.
	var scale_factor: float = Balance.TRUCK_LENGTH / Balance.TRUCK_MODEL_LENGTH
	var turn: float = deg_to_rad(Balance.TRUCK_MODEL_HEADING) - PI
	var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * scale_factor)
	var origin: Vector3 = -(basis * Balance.TRUCK_MODEL_TAILGATE)
	origin.y = -Balance.TRUCK_MODEL_FLOOR * scale_factor - Balance.TRUCK_SINK
	var model := MeshInstance3D.new()
	model.mesh = load(Balance.TRUCK_MODEL_PATH)
	model.transform = Transform3D(basis, origin)
	# Repainted Sasta Shifters orange, like the intro's comic truck; the scan's photo only adds shading (STYLE.md).
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://assets/shaders/posterize.gdshader")
	paint.set_shader_parameter("albedo_texture", load("res://assets/models/truck/truck.jpg"))
	paint.set_shader_parameter("levels", Balance.TRUCK_POSTER_LEVELS)
	paint.set_shader_parameter("paint", Balance.TRUCK_PAINT)
	model.material_override = paint
	add_child(model)


func _add_box(size: Vector3, centre: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	add_child(shape)


# --- Lights ---
func _add_lights() -> void:
	var hazard_glow := StandardMaterial3D.new()
	hazard_glow.albedo_color = Balance.TRUCK_HAZARD_COLOUR
	hazard_glow.emission_enabled = true
	hazard_glow.emission = Balance.TRUCK_HAZARD_COLOUR
	hazard_glow.emission_energy_multiplier = Balance.GLOW_ENERGY
	for side: float in [-1.0, 1.0]:
		var headlight := SpotLight3D.new()
		headlight.position = Vector3(Balance.TRUCK_LENGTH, LIGHT_HEIGHT, side * LIGHT_SPREAD)
		headlight.rotation_degrees.y = -90.0 # Spot lights shine along -Z; this turns them forward (+X).
		headlight.light_energy = Balance.TRUCK_HEADLIGHT_ENERGY
		headlight.spot_range = Balance.TRUCK_HEADLIGHT_RANGE
		headlight.spot_angle = HEADLIGHT_ANGLE
		add_child(headlight)
		for end: float in [0.0, Balance.TRUCK_LENGTH]:
			var lamp := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3.ONE * HAZARD_SIZE
			lamp.mesh = box
			lamp.material_override = hazard_glow
			lamp.position = Vector3(end, LIGHT_HEIGHT, side * (Balance.TRUCK_WIDTH / 2.0))
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(lamp)
			hazards.append(lamp)
	var blink := Timer.new()
	blink.wait_time = Balance.TRUCK_HAZARD_SECONDS
	blink.autostart = true
	blink.timeout.connect(func() -> void:
		for lamp: MeshInstance3D in hazards:
			lamp.visible = not lamp.visible
	)
	add_child(blink)
