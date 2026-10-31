# Small procedural sounds, all on the SFX bus: the banking chime, and the Mansion's night (a looping bed of wind
# and crickets, plus thunder, an owl, a distant howl and crows), the Museum's city night (traffic and a far siren), and the intro cutscene's goat, whoosh, rumble,
# walkie crackle and organ chord, the boing, theremin and sad trombone, plus Kenney CC0 sound files (thuds, glass,
# coins, creaks, ticks, jingles) and the round music. The synthesized ones are made here at start-up, so
# there are no sound files to license; full sound design belongs to the polish phase.
extends Node

# --- Synthesis settings ---
const RATE: int = 22050 # Samples per second for the night sounds.
const AMBIENT_SECONDS: float = 8.0 # Length of the looping night bed.
const WIND_SMOOTHING: float = 0.985 # 0 to 1: higher is a deeper, softer wind.
const CRICKET_PITCH: float = 4300.0 # Hz.
const CRICKET_CHIRPS_PER_SECOND: float = 2.6
const CITY_SECONDS: float = 12.0 # Length of the looping city bed.
const CITY_CARS: Array[Vector2] = [Vector2(3.0, 1.0), Vector2(8.5, 0.55)] # Cars passing: second in the loop, loudness.
const CITY_FADE: float = 0.5 # Seconds crossfaded at the loop point.

# --- Sound files (res://assets/audio/sfx/, Kenney CC0): name → variant count; "name_1.ogg" … when more than one ---
const SFX_FOLDER: String = "res://assets/audio/sfx/"
const FILE_SOUNDS: Dictionary = {
	"thud": 3, "glass": 3, "coins": 2, "creak": 2, "grab": 2, "smash_glass": 1, "smash_wood": 1,
	"tick": 1, "count": 1, "go": 1, "win": 1, "lose": 1, "final": 1,
}
const MUSIC_TRACKS: Dictionary = {
	"lobby": "res://assets/audio/cutscene/music_cozy.ogg", "round": "res://assets/audio/cutscene/music_spooky.ogg",
	"round_ship": "res://assets/audio/ship/music_shanty.ogg", "round_museum": "res://assets/audio/museum/music_heist.ogg",
}

# --- Audio state ---
var bank_sound: AudioStreamWAV
var sounds: Dictionary = {} # Night sounds by name.
var ambient := AudioStreamPlayer.new()
var night_bed: AudioStreamWAV
var city_bed: AudioStreamWAV # Built the first time an arena asks for it (a third of a second).
var noise := RandomNumberGenerator.new()
var files: Dictionary = {} # Name → Array of AudioStream variants.
var music := AudioStreamPlayer.new()
var music_name: String = ""
var shown_phase: String = "" # The match phase the music last reacted to.
var last_tick: int = -1 # The whole second the last-seconds tick last played for.

# --- Setup ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	noise.seed = 1
	bank_sound = _bank_chime()
	sounds = {
		"thunder": _thunder(), "owl": _owl(), "howl": _howl(), "caw": _caw(),
		"goat": _goat(), "whoosh": _whoosh(), "rumble": _rumble(), "crackle": _crackle(), "organ": _organ(),
		"boing": _boing(), "theremin": _theremin(), "trombone": _trombone(), "ship_bell": _ship_bell(), "wave_crash": _wave_crash(),
		"squawk": _squawk(), "whistle": _whistle(), "roar": _roar(), "scream": _scream(), "siren": _siren(),
		"meow": _meow(), "slosh": _slosh(), "chime": _chime(), "giggle": _giggle(), "rewind": _rewind(),
	}
	for sound: String in FILE_SOUNDS:
		var variants: Array[AudioStream] = []
		var count: int = FILE_SOUNDS[sound]
		for index: int in count:
			variants.append(load(SFX_FOLDER + (sound + ".ogg" if count == 1 else "%s_%d.ogg" % [sound, index + 1])))
		files[sound] = variants
	music.bus = &"Music"
	add_child(music)
	night_bed = _night_bed()
	ambient.stream = night_bed
	ambient.bus = &"SFX"
	ambient.volume_db = Balance.AMBIENT_VOLUME_DB
	add_child(ambient)


# --- Playback ---
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	# A synthesized sound, or a random variant of a sound file.
	var stream: AudioStream = bank_sound if sound == "bank" else sounds.get(sound)
	if stream == null and files.has(sound):
		stream = files[sound].pick_random()
	if stream == null:
		return
	DisasterCam.note_sound(sound, pitch, volume_db)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = &"SFX" # The options menu's SFX volume.
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func varied(sound: String, volume_db: float = 0.0) -> void:
	# The same sound at a slightly different pitch each time, so repeats don't drone.
	play(sound, noise.randf_range(1.0 - Balance.SFX_PITCH_JITTER, 1.0 + Balance.SFX_PITCH_JITTER), volume_db)


func damage(loss: int, value_before: int, fragility: int) -> void:
	# Glass for fragile items, a thud for sturdy ones; louder the bigger the share of value lost.
	var share: float = clampf(float(loss) / maxi(1, value_before), 0.0, 1.0)
	varied("glass" if fragility >= Balance.SFX_FRAGILE else "thud", lerpf(Balance.SFX_DAMAGE_QUIET_DB, 0.0, sqrt(share)))


func shatter(initial_value: int, fragility: int) -> void:
	varied("smash_glass" if fragility >= Balance.SFX_FRAGILE else "smash_wood")
	if initial_value >= Balance.SFX_TROMBONE_VALUE:
		play("trombone", 1.0, Balance.SFX_TROMBONE_DB) # Wah-wah-wah-waaah for a big loss.


func banked(amount: int, chime: String = "bank") -> void:
	var pitch: float = Balance.BANK_LARGE_PITCH if amount >= Balance.BANK_LARGE_VALUE else 1.0
	play(chime, pitch)
	play("coins", pitch, Balance.SFX_COINS_DB)


# --- Music: the cozy loop in the lobby, the spooky waltz in rounds (faster in the last 30 s), jingles after ---
func _process(_delta: float) -> void:
	if not is_instance_valid(Game.host):
		return
	if Game.phase != shown_phase:
		shown_phase = Game.phase
		_on_phase(Game.phase)
	var late: bool = Game.phase == "live" and Game.seconds_left <= Balance.HUD_WARNING_SECONDS
	music.pitch_scale = Balance.MUSIC_RUSH_PITCH if late else 1.0
	var whole: int = ceili(Game.seconds_left)
	if Game.phase == "live" and whole <= Balance.SFX_TICK_SECONDS and whole != last_tick and whole > 0:
		last_tick = whole
		play("tick", 1.0, Balance.SFX_TICK_DB)


func _on_phase(phase: String) -> void:
	match phase:
		"lobby":
			_set_music("lobby", Balance.MUSIC_LOBBY_DB)
		"intro", "outro":
			_set_music("", 0.0) # The cutscene plays its own music.
		"reveal", "live", "paused":
			# An arena may bring its own round music (the Ship's shanty); otherwise the spooky waltz.
			var arena: Node = Game.host.get("arena") if is_instance_valid(Game.host) else null
			var track: Variant = arena.get("MUSIC_TRACK") if is_instance_valid(arena) else null
			_set_music(track if track is String else "round", Balance.MUSIC_ROUND_DB)
		"result":
			_set_music("", 0.0)
			if Game.replay.is_empty(): # Otherwise the Disaster Cam replay plays it as the page shows.
				phase_jingle(phase)
		"final":
			if Game.replay.is_empty():
				phase_jingle(phase)


func phase_jingle(phase: String) -> void:
	if phase == "result":
		play("win" if Game.result.get("moversWon", false) else "lose", 1.0, Balance.SFX_JINGLE_DB)
	elif phase == "final":
		play("final", 1.0, Balance.SFX_JINGLE_DB)


func _set_music(track: String, volume_db: float) -> void:
	if track == music_name:
		return
	music_name = track
	if track.is_empty():
		music.stop()
		return
	var stream: AudioStreamOggVorbis = load(MUSIC_TRACKS[track])
	stream.loop = true
	music.stream = stream
	music.volume_db = volume_db
	music.play()


func start_ambient() -> void:
	# An arena may bring its own bed (the Museum's city night); otherwise the Mansion's wind and crickets.
	var arena: Node = Game.host.get("arena") if is_instance_valid(Game.host) else null
	var bed: Variant = arena.get("AMBIENT_BED") if is_instance_valid(arena) else null
	if bed == "city" and city_bed == null:
		city_bed = _city_bed()
	var stream: AudioStreamWAV = city_bed if bed == "city" else night_bed
	if ambient.playing and ambient.stream == stream:
		return
	ambient.stream = stream
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


func _city_bed() -> AudioStreamWAV:
	# The Museum's city at night: a low traffic rumble, two cars swishing past at different distances, and the faint
	# hum of the street lamps. The last half second is crossfaded into the start, so the loop point is seamless.
	var count: int = int(RATE * CITY_SECONDS)
	var fade: int = int(RATE * CITY_FADE)
	var samples := PackedFloat32Array()
	samples.resize(count + fade)
	var rumble: float = 0.0
	var tyres: float = 0.0
	var tyres_slow: float = 0.0
	for index: int in range(count + fade):
		var time: float = float(index) / RATE
		rumble = rumble * 0.98 + noise.randf_range(-1.0, 1.0) * 0.02
		tyres = tyres * 0.75 + noise.randf_range(-1.0, 1.0) * 0.25
		tyres_slow = tyres_slow * 0.97 + tyres * 0.03
		var passing: float = 0.0
		for car: Vector2 in CITY_CARS:
			passing += car.y * exp(-pow(fmod(time - car.x + CITY_SECONDS * 1.5, CITY_SECONDS) - CITY_SECONDS * 0.5, 2.0) / 1.4)
		var hum: float = (sin(TAU * 100.0 * time) + 0.4 * sin(TAU * 200.0 * time)) * 0.006
		samples[index] = rumble * (3.0 + 2.0 * passing) + (tyres - tyres_slow) * 0.35 * passing + hum
	for index: int in range(fade):
		var mix: float = float(index) / fade
		samples[index] = samples[index] * mix + samples[count + index] * (1.0 - mix)
	samples.resize(count)
	return _stream(samples, RATE, true)


func _siren() -> AudioStreamWAV:
	# A police siren far across the city: a slow wail that swells as it nears a few streets away and fades again.
	var count: int = int(RATE * 6.0)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var soft: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		phase += TAU * (640.0 + 330.0 * (0.5 - 0.5 * cos(TAU * time / 2.4))) / RATE
		var tone: float = sin(phase) * 0.8 + sin(phase * 2.0) * 0.2
		soft = soft * 0.6 + tone * 0.4 # Distance takes the edge off.
		samples[index] = soft * sin(PI * time / 6.0) * 0.3
	return _stream(samples, RATE, false)


func _meow() -> AudioStreamWAV:
	# The Mansion's cat: a nasal "mi-aow" that rises, holds and falls, with a little vibrato.
	var count: int = int(RATE * 0.6)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var shape: float = sin(PI * time / 0.6)
		phase += TAU * (480.0 + 340.0 * shape - 120.0 * maxf(0.0, time - 0.35) + 12.0 * sin(TAU * 7.0 * time)) / RATE
		var voice: float = sin(phase) * 0.5 + sin(phase * 2.0) * 0.3 * shape + sin(phase * 3.0) * 0.2
		samples[index] = voice * minf(1.0, time * 30.0) * minf(1.0, (0.6 - time) * 8.0) * 0.32
	return _stream(samples, RATE, false)


func _slosh() -> AudioStreamWAV:
	# The fish tank: two slaps of water, low rushing noise that surges and drains.
	var count: int = int(RATE * 0.7)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var water: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		water = water * 0.92 + noise.randf_range(-1.0, 1.0) * 0.08
		var surge: float = exp(-pow((time - 0.12) / 0.07, 2.0)) + 0.7 * exp(-pow((time - 0.42) / 0.09, 2.0))
		samples[index] = water * surge * (1.0 + 0.5 * sin(TAU * 18.0 * time)) * 2.2
	return _stream(samples, RATE, false)


func _chime() -> AudioStreamWAV:
	# The grandfather clock: two deep bongs, a few inharmonic partials ringing down at their own rates.
	var count: int = int(RATE * 2.6)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index: int in range(count):
		var time: float = float(index) / RATE
		var value: float = 0.0
		for strike: float in [0.0, 0.9]:
			var since: float = time - strike
			if since < 0.0:
				continue
			for partial: Vector2 in [Vector2(1.0, 1.6), Vector2(2.0, 2.4), Vector2(2.76, 3.2), Vector2(4.1, 4.5), Vector2(5.4, 6.0)]:
				value += sin(TAU * 196.0 * partial.x * since) * exp(-partial.y * since) / partial.x
		samples[index] = value * 0.22
	return _stream(samples, RATE, false)


func _giggle() -> AudioStreamWAV:
	# The cursed doll: "hee hee hee", three thin breathy notes, each a little lower, with a creepy tremble.
	var count: int = int(RATE * 0.75)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var note: int = mini(int(time / 0.25), 2)
		var local: float = time - note * 0.25
		var on: float = sin(PI * clampf(local / 0.16, 0.0, 1.0)) if local < 0.16 else 0.0
		phase += TAU * (1180.0 - note * 90.0 - local * 400.0 + 25.0 * sin(TAU * 13.0 * time)) / RATE
		var voice: float = sin(phase) * 0.7 + sin(phase * 2.0) * 0.15 + noise.randf_range(-1.0, 1.0) * 0.15
		samples[index] = voice * on * 0.22
	return _stream(samples, RATE, false)


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


func _squawk() -> AudioStreamWAV:
	# The parrot: a harsh two-part "squa-AWK", a buzzy tone that leaps up then falls, roughened with noise.
	var count: int = int(RATE * 0.45)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var second: bool = time >= 0.13
		var local: float = time - (0.13 if second else 0.0)
		var pitch: float = (1500.0 - local * 1800.0) if second else (900.0 + local * 2500.0)
		phase += TAU * (pitch + 60.0 * sin(TAU * 55.0 * time)) / RATE
		var envelope: float = minf(1.0, local * 80.0) * exp(-local * (7.0 if second else 14.0))
		var tone: float = clampf(sin(phase) * 3.0, -1.0, 1.0) # Clipped sine: a reedy buzz.
		samples[index] = (tone * 0.7 + noise.randf_range(-1.0, 1.0) * 0.3) * envelope * 0.35
	return _stream(samples, RATE, false)


func _scream() -> AudioStreamWAV:
	# Mona Lisa's cousin: a shrill cartoon shriek that rises, wobbles and cracks off.
	var count: int = int(RATE * 0.9)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		phase += TAU * (820.0 + 520.0 * minf(1.0, time * 3.0) + 60.0 * sin(TAU * 11.0 * time)) / RATE
		var envelope: float = minf(1.0, time * 25.0) * minf(1.0, (0.9 - time) * 4.0)
		var voice: float = sin(phase) * 0.7 + sin(phase * 2.0) * 0.2 + noise.randf_range(-1.0, 1.0) * 0.1
		samples[index] = voice * envelope * 0.3
	return _stream(samples, RATE, false)


func _roar() -> AudioStreamWAV:
	# The animatronic T-Rex: a low, gravelly roar that swells and falls, with a mechanical whirr under it.
	var count: int = int(RATE * 1.4)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var smooth: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		phase += TAU * (95.0 - 35.0 * time + 12.0 * sin(TAU * 9.0 * time)) / RATE
		var envelope: float = minf(1.0, time * 6.0) * minf(1.0, (1.4 - time) * 2.5)
		smooth = smooth * 0.82 + noise.randf_range(-1.0, 1.0) * 0.18 # Low-passed noise: the gravel in the throat.
		var growl: float = clampf(sin(phase) * 2.2, -1.0, 1.0) * 0.55 + smooth * 1.6
		var whirr: float = sin(TAU * 440.0 * time) * 0.04 * minf(1.0, time * 10.0)
		samples[index] = (growl * envelope + whirr) * 0.45
	return _stream(samples, RATE, false)


func _whistle() -> AudioStreamWAV:
	# Bahadur's pea whistle: a shrill tone trilled by the rolling pea, in a short blast and a long one.
	var count: int = int(RATE * 1.0)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var on: bool = time < 0.22 or (time > 0.32 and time < 0.95)
		var local: float = time if time < 0.22 else time - 0.32
		var length: float = 0.22 if time < 0.22 else 0.63
		phase += TAU * (2850.0 + 90.0 * sin(TAU * 31.0 * time)) / RATE
		var trill: float = 0.6 + 0.4 * sin(TAU * 31.0 * time)
		var envelope: float = minf(1.0, local * 60.0) * minf(1.0, (length - local) * 25.0) if on else 0.0
		samples[index] = (sin(phase) * 0.85 + noise.randf_range(-1.0, 1.0) * 0.15) * trill * maxf(envelope, 0.0) * 0.3
	return _stream(samples, RATE, false)


# --- Intro cutscene sounds ---
func _goat() -> AudioStreamWAV:
	# A cartoon "meh-eh-eh": a nasal buzz that falls in pitch, pulsing three times.
	var count: int = int(RATE * 0.9)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var smooth: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		phase += TAU * (560.0 - 120.0 * time + 18.0 * sin(TAU * 7.0 * time)) / RATE
		var pulse: float = 0.55 + 0.45 * sin(TAU * 3.3 * time)
		var envelope: float = minf(1.0, time * 30.0) * minf(1.0, (0.9 - time) * 6.0)
		smooth = smooth * 0.6 + (fmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.4 # Softened sawtooth.
		samples[index] = smooth * pulse * envelope * 0.4
	return _stream(samples, RATE, false)


func _rewind() -> AudioStreamWAV:
	# A tape rewinding: a fast warbling squeal over hiss, rising as the reel spins up (Disaster Cam, decision 144).
	var count: int = int(RATE * 0.7)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var hiss: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var envelope: float = minf(1.0, time / 0.05) * minf(1.0, (0.7 - time) / 0.12)
		var pitch: float = lerpf(900.0, 2600.0, time / 0.7) * (1.0 + 0.12 * sin(TAU * 23.0 * time))
		phase += TAU * pitch / RATE
		hiss = hiss * 0.6 + noise.randf_range(-1.0, 1.0) * 0.4
		samples[index] = (sin(phase) * 0.35 + hiss * 0.25) * envelope
	return _stream(samples, RATE, false)


func _whoosh() -> AudioStreamWAV:
	# Wind rushing past: noise that brightens then darkens as it swells and fades.
	var count: int = int(RATE * 0.7)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var air: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var shape: float = sin(PI * time / 0.7)
		var smoothing: float = 0.97 - 0.25 * shape
		air = air * smoothing + noise.randf_range(-1.0, 1.0) * (1.0 - smoothing)
		samples[index] = air * shape * 2.5
	return _stream(samples, RATE, false)



func _wave_crash() -> AudioStreamWAV:
	# A wave breaking over the plank: a sharp, bright slap of noise, then a long hiss of water draining away.
	var count: int = int(RATE * 1.8)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var water: float = 0.0
	var low: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var envelope: float = minf(1.0, time / 0.03) * (0.75 * exp(-time * 6.0) + 0.25 * exp(-time * 1.4))
		var brightness: float = 0.55 + 0.4 * exp(-time * 3.0) # Starts bright, darkens as it drains.
		water = water * (1.0 - brightness) + noise.randf_range(-1.0, 1.0) * brightness
		low = low * 0.985 + water * 0.015 # A body of low thump under the hiss.
		samples[index] = (water * 0.6 + low * 3.0) * envelope * 0.8
	return _stream(samples, RATE, false)


func _rumble() -> AudioStreamWAV:
	# The House Shake: a deep, uneven rumble that swells and dies away.
	var count: int = int(RATE * 2.2)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		low = low * 0.996 + noise.randf_range(-1.0, 1.0) * 0.004
		var shake: float = 0.6 + 0.4 * sin(TAU * 5.0 * time) * sin(TAU * 1.3 * time)
		samples[index] = low * 22.0 * shake * minf(1.0, time * 4.0) * exp(-time * 0.9)
	return _stream(samples, RATE, false)


func _crackle() -> AudioStreamWAV:
	# A walkie-talkie squelch: a burst of thin hiss with clicks in it.
	var count: int = int(RATE * 0.45)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var hiss: float = noise.randf_range(-1.0, 1.0)
		low = low * 0.8 + hiss * 0.2
		var click: float = noise.randf_range(-1.0, 1.0) if noise.randf() < 0.004 else 0.0
		var envelope: float = minf(1.0, time * 60.0) * (0.7 + 0.3 * sin(TAU * 23.0 * time)) * exp(-time * 3.0)
		samples[index] = ((hiss - low) * 0.5 + click) * envelope * 0.5 # Hiss minus its lows sounds thin, like a radio.
	return _stream(samples, RATE, false)


func _organ() -> AudioStreamWAV:
	# A spooky D minor organ chord that swells in, wobbles and fades.
	var count: int = int(RATE * 3.0)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [146.8, 174.6, 220.0, 293.7]
	for index: int in range(count):
		var time: float = float(index) / RATE
		var value: float = 0.0
		for note: float in notes:
			for harmonic: int in [1, 2, 4]: # Organ stops at the note, an octave and two octaves up.
				value += sin(TAU * note * harmonic * time) / harmonic
		var envelope: float = minf(1.0, time * 3.0) * exp(-maxf(0.0, time - 1.2) * 1.8)
		samples[index] = value * envelope * (0.85 + 0.15 * sin(TAU * 5.5 * time)) * 0.07
	return _stream(samples, RATE, false)



func _ship_bell() -> AudioStreamWAV:
	# A ship's bell struck twice: a handful of inharmonic partials, each ringing down at its own rate.
	var count: int = int(RATE * Balance.SHIP_BELL_LENGTH)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index: int in range(count):
		var time: float = float(index) / RATE
		var value: float = 0.0
		for strike: float in Balance.SHIP_BELL_STRIKES:
			var since: float = time - strike
			if since < 0.0:
				continue
			for partial: Vector2 in Balance.SHIP_BELL_PARTIALS:
				value += sin(TAU * Balance.SHIP_BELL_NOTE * partial.x * since) * exp(-partial.y * since) / partial.x
		samples[index] = value * Balance.SHIP_BELL_VOLUME
	return _stream(samples, RATE, false)


func _boing() -> AudioStreamWAV:
	# A cartoon spring: a wobbling tone that drops in pitch.
	var count: int = int(RATE * 0.6)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		phase += TAU * (520.0 * exp(-time * 2.2) + 90.0) * (1.0 + 0.08 * sin(TAU * 18.0 * time)) / RATE
		samples[index] = sin(phase) * exp(-time * 4.0) * 0.45
	return _stream(samples, RATE, false)


func _theremin() -> AudioStreamWAV:
	# A spooky theremin swell: a pure tone gliding up with a wide vibrato.
	var count: int = int(RATE * 1.4)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		phase += TAU * (330.0 + 260.0 * minf(1.0, time / 0.9) + 14.0 * sin(TAU * 6.5 * time)) / RATE
		samples[index] = sin(phase) * sin(PI * time / 1.4) * 0.3
	return _stream(samples, RATE, false)


func _trombone() -> AudioStreamWAV:
	# The sad trombone: three falling notes, then a long drooping one.
	var count: int = int(RATE * 2.2)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var notes: Array[float] = [233.1, 220.0, 207.7, 196.0]
	var phase: float = 0.0
	var smooth: float = 0.0
	for index: int in range(count):
		var time: float = float(index) / RATE
		var note: int = mini(int(time / 0.4), 3)
		var note_time: float = time - note * 0.4
		var pitch: float = notes[note] * (1.0 - (0.06 * note_time if note == 3 else 0.0)) * (1.0 + (0.012 * sin(TAU * 5.0 * note_time) if note == 3 else 0.0))
		phase += TAU * pitch / RATE
		smooth = smooth * 0.7 + (fmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.3 # A soft brassy sawtooth.
		var envelope: float = minf(1.0, note_time * 25.0) * (exp(-maxf(0.0, note_time - 0.3) * 18.0) if note < 3 else exp(-note_time * 0.9))
		samples[index] = smooth * envelope * 0.5
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
