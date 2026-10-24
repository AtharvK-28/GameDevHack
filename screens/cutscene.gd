# Intro cutscene: the story panels from Balance.INTRO_PANELS, full screen, each slowly zooming and drifting while
# its cues play over a music bed and looping rain and engine. Shown in the "intro" phase, once per match.
# Host keys: Enter for the next panel, Esc to skip to the first round.
extends Control

const Style := preload("res://screens/screen_style.gd")
const SOUND_FOLDER: String = "res://assets/audio/cutscene/"
const BEDS: Array[String] = ["rain", "engine"]

# --- Display state ---
var stage := Control.new() # Holds the panels; shaken on "shake" panels.
var flash := ColorRect.new()
var hint_label: Label
var panel_index: int = -1
var panel_time: float = 0.0
var next_cue: int = 0
var shake_left: float = 0.0
var shake_noise := RandomNumberGenerator.new()
var playing: bool = false

# --- Audio state ---
var music: Dictionary = {} # AudioStreamPlayer by music name.
var music_name: String = ""
var beds: Dictionary = {} # AudioStreamPlayer by bed name.

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_build_audio()
	Game.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	match Style.pressed_key(event):
		KEY_ENTER, KEY_KP_ENTER:
			_show_panel(panel_index + 1)
		KEY_ESCAPE:
			_finish()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not playing:
		return
	panel_time += delta
	var cues: Array = Balance.INTRO_PANELS[panel_index].cues
	while next_cue < cues.size() and panel_time >= cues[next_cue][0]:
		_play_cue(cues[next_cue][1], cues[next_cue][2])
		next_cue += 1
	if shake_left > 0.0:
		shake_left = maxf(0.0, shake_left - delta)
		var strength: float = Balance.INTRO_SHAKE_PIXELS * shake_left / Balance.INTRO_SHAKE_TIME
		stage.position = Vector2(shake_noise.randf_range(-1.0, 1.0), shake_noise.randf_range(-1.0, 1.0)) * strength
	else:
		stage.position = Vector2.ZERO
	if panel_time >= Balance.INTRO_PANELS[panel_index].hold:
		_show_panel(panel_index + 1)


# --- Refresh ---
func _refresh() -> void:
	var showing: bool = Game.phase == "intro"
	if showing and not playing:
		_start()
	elif not showing and playing:
		_stop_sound()
		playing = false
	visible = showing


func _start() -> void:
	playing = true
	for child: Node in stage.get_children():
		child.queue_free()
	Sfx.stop_ambient() # The Mansion's night loop returns when the round starts.
	_show_panel(0)


func _finish() -> void:
	# The last panel ended, or the host skipped: on to the first round.
	_stop_sound()
	playing = false
	Game.finish_intro()


# --- Panels ---
func _show_panel(index: int) -> void:
	if index >= Balance.INTRO_PANELS.size():
		_finish()
		return
	panel_index = index
	panel_time = 0.0
	next_cue = 0
	var panel: Dictionary = Balance.INTRO_PANELS[index]
	var picture := TextureRect.new()
	picture.texture = load(Balance.INTRO_FOLDER + panel.image)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(picture)
	_animate_panel(picture, panel.hold)
	if panel.get("flash", false):
		flash.modulate.a = 1.0
		create_tween().tween_property(flash, "modulate:a", 0.0, Balance.INTRO_FLASH_TIME)
	shake_left = Balance.INTRO_SHAKE_TIME if panel.get("shake", false) else 0.0
	_set_music(panel.music)
	for bed: String in BEDS:
		_fade(beds[bed], panel.beds.get(bed, Balance.INTRO_SILENT_DB))
	hint_label.text = "%d / %d   ·   Enter: next   ·   Esc: skip" % [index + 1, Balance.INTRO_PANELS.size()]


func _animate_panel(picture: TextureRect, hold: float) -> void:
	# Fades in over the previous panel, which is freed once covered, then slowly zooms and drifts.
	var previous: Array = stage.get_children().filter(func(child: Node) -> bool: return child != picture)
	var drift: float = size.x * Balance.INTRO_DRIFT * (1.0 if panel_index % 2 == 0 else -1.0)
	picture.modulate.a = 0.0
	picture.pivot_offset = size / 2.0
	picture.position.x = -drift / 2.0
	var tween: Tween = picture.create_tween().set_parallel()
	tween.tween_property(picture, "modulate:a", 1.0, Balance.INTRO_FADE_TIME)
	tween.tween_property(picture, "scale", Vector2.ONE * Balance.INTRO_ZOOM, hold + Balance.INTRO_FADE_TIME).from(Vector2.ONE)
	tween.tween_property(picture, "position:x", drift / 2.0, hold + Balance.INTRO_FADE_TIME)
	var cleanup: Tween = create_tween()
	cleanup.tween_interval(Balance.INTRO_FADE_TIME)
	cleanup.tween_callback(func() -> void:
		for old: Variant in previous: # Untyped: a new match may already have freed it.
			if is_instance_valid(old):
				old.queue_free())


# --- Sound ---
func _play_cue(sound: String, volume_db: float) -> void:
	var path: String = SOUND_FOLDER + sound + ".ogg"
	if not ResourceLoader.exists(path):
		Sfx.play(sound, 1.0, volume_db) # Synthesized in Sfx.
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume_db
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _set_music(next: String) -> void:
	if next == music_name:
		return
	music_name = next
	for track: String in music:
		_fade(music[track], Balance.INTRO_MUSIC_DB if track == next else Balance.INTRO_SILENT_DB)


func _fade(player: AudioStreamPlayer, volume_db: float, seconds: float = Balance.INTRO_MUSIC_FADE) -> void:
	# Fades a looping player to volume_db, starting it if needed and stopping it once silent. A new fade
	# replaces any fade still running on the same player.
	if player.has_meta("fade"):
		(player.get_meta("fade") as Tween).kill()
	var audible: bool = volume_db > Balance.INTRO_SILENT_DB
	if audible and not player.playing:
		player.volume_db = Balance.INTRO_SILENT_DB
		player.play()
	elif not audible and not player.playing:
		return
	var tween: Tween = player.create_tween()
	tween.tween_property(player, "volume_db", volume_db, seconds)
	if not audible:
		tween.tween_callback(player.stop)
	player.set_meta("fade", tween)


func _stop_sound() -> void:
	for player: AudioStreamPlayer in music.values() + beds.values():
		_fade(player, Balance.INTRO_SILENT_DB, Balance.INTRO_END_FADE)
	music_name = ""


# --- Layout ---
func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	hint_label = Style.label("", Balance.HOST_SMALL_SIZE, Balance.HOST_MUTED_COLOUR)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(Balance.HUD_MARGIN))
	add_child(hint_label)


func _build_audio() -> void:
	for track: String in ["cozy", "spooky"]:
		music[track] = _loop_player("music_" + track, &"Music")
	for bed: String in BEDS:
		beds[bed] = _loop_player(bed + "_loop", &"SFX")


func _loop_player(file: String, bus: StringName) -> AudioStreamPlayer:
	var stream: AudioStreamOggVorbis = load(SOUND_FOLDER + file + ".ogg")
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = Balance.INTRO_SILENT_DB
	add_child(player)
	return player
