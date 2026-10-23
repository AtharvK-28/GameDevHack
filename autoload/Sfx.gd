# Small procedural sounds, all on the SFX bus: the banking chime, and the Mansion's night (a looping bed of wind
# and crickets, plus thunder, an owl, a distant howl and crows). Everything is synthesized here at start-up, so
# there are no sound files to license; full sound design belongs to the polish phase.
extends Node

# --- Synthesis settings ---
const RATE: int = 22050 # Samples per second for the night sounds.
const AMBIENT_SECONDS: float = 8.0 # Length of the looping night bed.
const WIND_SMOOTHING: float = 0.985 # 0 to 1: higher is a deeper, softer wind.
const CRICKET_PITCH: float = 4300.0 # Hz.
const CRICKET_CHIRPS_PER_SECOND: float = 2.6

# --- Audio state ---
var bank_sound: AudioStreamWAV
var sounds: Dictionary = {} # Night sounds by name.
var ambient := AudioStreamPlayer.new()
var noise := RandomNumberGenerator.new()

# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	noise.seed = 1
	bank_sound = _bank_chime()
	sounds = {
		"thunder": _thunder(), "owl": _owl(), "howl": _howl(), "caw": _caw(),
	}
	ambient.stream = _night_bed()
	ambient.bus = &"SFX"
	ambient.volume_db = Balance.AMBIENT_VOLUME_DB
	add_child(ambient)


# --- Playback ---
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = bank_sound if sound == "bank" else sounds.get(sound)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = &"SFX" # The options menu's SFX volume.
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func start_ambient() -> void:
	if not ambient.playing:
		ambient.play()


func stop_ambient() -> void:
	ambient.stop()


# --- Sounds ---
func _bank_chime() -> AudioStreamWAV:
	var sample_count: int = int(Balance.BANK_SAMPLE_RATE * Balance.BANK_SOUND_DURATION)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / Balance.BANK_SAMPLE_RATE
		var note_duration: float = Balance.BANK_SOUND_DURATION / Balance.BANK_SOUND_FREQUENCIES.size()
		var note: int = mini(int(time / note_duration), Balance.BANK_SOUND_FREQUENCIES.size() - 1)
		var note_time: float = fmod(time, note_duration)
		samples[index] = sin(TAU * Balance.BANK_SOUND_FREQUENCIES[note] * note_time) * exp(-Balance.BANK_SOUND_DECAY * note_time) * Balance.BANK_SOUND_VOLUME
	return _stream(samples, Balance.BANK_SAMPLE_RATE, false)


func _night_bed() -> AudioStreamWAV:
	# Soft wind that swells and falls once per loop, with cricket chirps on top. The swell starts and ends quiet,
	# so the loop point is seamless.
	var count: int = int(RATE * AMBIENT_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var wind: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		wind = wind * WIND_SMOOTHING + noise.randf_range(-1.0, 1.0) * (1.0 - WIND_SMOOTHING)
		var swell: float = 0.35 + 0.65 * pow(sin(PI * time / AMBIENT_SECONDS), 2.0)
		var chirp_phase: float = fmod(time * CRICKET_CHIRPS_PER_SECOND, 1.0)
		var chirp: float = sin(TAU * CRICKET_PITCH * time) * (0.05 if chirp_phase < 0.12 and int(time * 40.0) % 2 == 0 else 0.0)
		samples[index] = wind * 6.0 * swell + chirp
	return _stream(samples, RATE, true)


func _thunder() -> AudioStreamWAV:
	# A sharp crack, then a long low rumble.
	var count: int = int(RATE * 3.0)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rumble: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		rumble = rumble * 0.995 + noise.randf_range(-1.0, 1.0) * 0.005
		var crack: float = noise.randf_range(-1.0, 1.0) * exp(-time * 25.0) * 0.6
		samples[index] = crack + rumble * 14.0 * exp(-time * 1.1) * (0.7 + 0.3 * sin(time * 9.0))
	return _stream(samples, RATE, false)


func _owl() -> AudioStreamWAV:
	# A cartoon "hoo-hoo": two soft wobbling notes.
	var count: int = int(RATE * 1.2)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index: int in range(count):
		var time: float = float(index) / RATE
		var note_time: float = time if time < 0.45 else time - 0.55
		var on: bool = time < 0.45 or (time > 0.55 and time < 1.15)
		var envelope: float = sin(PI * clampf(note_time / 0.5, 0.0, 1.0)) if on else 0.0
		samples[index] = sin(TAU * (390.0 + 12.0 * sin(TAU * 6.0 * time)) * time) * envelope * 0.35
	return _stream(samples, RATE, false)


func _howl() -> AudioStreamWAV:
	# A distant wolf: a slow rising and falling glide.
	var count: int = int(RATE * 2.6)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var pitch: float = 300.0 + 280.0 * sin(PI * clampf(time / 2.6, 0.0, 1.0) * 0.8)
		phase += TAU * pitch / RATE
		samples[index] = sin(phase) * sin(PI * time / 2.6) * 0.25
	return _stream(samples, RATE, false)


func _caw() -> AudioStreamWAV:
	# Two harsh crow caws.
	var count: int = int(RATE * 0.7)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index: int in range(count):
		var time: float = float(index) / RATE
		var note_time: float = fmod(time, 0.35)
		var envelope: float = exp(-note_time * 9.0) if note_time < 0.25 else 0.0
		var buzz: float = signf(sin(TAU * (620.0 - note_time * 500.0) * time))
		samples[index] = (buzz * 0.6 + noise.randf_range(-1.0, 1.0) * 0.4) * envelope * 0.3
	return _stream(samples, RATE, false)


func _stream(samples: PackedFloat32Array, rate: int, looping: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		data.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0)) # Signed 16-bit PCM range.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream
