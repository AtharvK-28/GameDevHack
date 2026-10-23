# Small procedural banking cue; full sound design belongs to the polish phase.
extends Node

# --- Audio state ---
var bank_sound: AudioStreamWAV

# --- Setup ---
func _ready() -> void:
	bank_sound = AudioStreamWAV.new()
	bank_sound.format = AudioStreamWAV.FORMAT_16_BITS
	bank_sound.mix_rate = Balance.BANK_SAMPLE_RATE
	var sample_count: int = int(Balance.BANK_SAMPLE_RATE * Balance.BANK_SOUND_DURATION)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index: int in range(sample_count):
		var time: float = float(index) / Balance.BANK_SAMPLE_RATE
		var note_duration: float = Balance.BANK_SOUND_DURATION / Balance.BANK_SOUND_FREQUENCIES.size()
		var note: int = mini(int(time / note_duration), Balance.BANK_SOUND_FREQUENCIES.size() - 1)
		var note_time: float = fmod(time, note_duration)
		var amplitude: float = sin(TAU * Balance.BANK_SOUND_FREQUENCIES[note] * note_time)
		amplitude *= exp(-Balance.BANK_SOUND_DECAY * note_time) * Balance.BANK_SOUND_VOLUME
		samples.encode_s16(index * 2, int(amplitude * 32767.0)) # Signed 16-bit PCM range.
	bank_sound.data = samples


# --- Playback ---
func play(sound: String, pitch: float = 1.0) -> void:
	if sound != "bank":
		return
	var player := AudioStreamPlayer.new()
	player.stream = bank_sound
	player.pitch_scale = pitch
	player.bus = &"SFX" # The options menu's SFX volume.
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
