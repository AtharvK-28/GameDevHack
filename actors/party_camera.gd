# The shared screen's camera. Phase 4: the fixed greybox view plus trauma shake (shake = trauma² × noise).
# Following the movers, punch-in and wall fade arrive in Phase 6.
extends Camera3D

# --- Shake state ---
var trauma: float = 0.0
var rest := Transform3D()
var noise := FastNoiseLite.new()
var time: float = 0.0

# --- Setup ---
func _ready() -> void:
	add_to_group("party_camera")
	var angle: float = deg_to_rad(Balance.CAMERA_ANGLE)
	var eye: Vector3 = Balance.CAMERA_TARGET + Vector3(0.0, sin(angle), cos(angle)) * Balance.CAMERA_DISTANCE
	look_at_from_position(eye, Balance.CAMERA_TARGET)
	rest = transform
	noise.frequency = 1.0 # Sampled at CAMERA_SHAKE_FREQUENCY units per second.
	current = true


# --- Shake ---
func shake(amount: float) -> void:
	# Raise the trauma to at least this much, 0 to 1; it then fades at TRAUMA_DECAY per second.
	trauma = clampf(maxf(trauma, amount), 0.0, 1.0)


func _process(delta: float) -> void:
	time += delta
	trauma = maxf(0.0, trauma - Balance.TRAUMA_DECAY * delta)
	var strength: float = trauma * trauma
	var sample: float = time * Balance.CAMERA_SHAKE_FREQUENCY
	var offset := Vector3(noise.get_noise_2d(sample, 0.0), noise.get_noise_2d(sample, 100.0), 0.0) * Balance.CAMERA_SHAKE_OFFSET * strength
	var roll: float = noise.get_noise_2d(sample, 200.0) * deg_to_rad(Balance.CAMERA_SHAKE_ROLL) * strength
	transform = rest.translated_local(offset).rotated_local(Vector3.BACK, roll)
