# Intro cutscene: the arena's story panels (Balance.INTRO_PANELS for the Mansion, SHIP_INTRO_PANELS for the Ship),
# full screen, each slowly zooming and drifting while its cues play over a music bed and looping beds. Panels may
# carry lettering (caption, speech bubble, title) drawn over the picture. Shown in the "intro" phase, once per match.
# Host keys: Enter for the next panel, Esc to skip to the first round.
extends Control

const Style := preload("res://screens/screen_style.gd")
const SOUND_FOLDER: String = "res://assets/audio/cutscene/"
const MUSIC_FILES: Dictionary = {
	"cozy": SOUND_FOLDER + "music_cozy.ogg", "spooky": SOUND_FOLDER + "music_spooky.ogg",
	"shanty": "res://assets/audio/ship/music_shanty.ogg",
}
const BED_FILES: Dictionary = {
	"rain": SOUND_FOLDER + "rain_loop.ogg", "engine": SOUND_FOLDER + "engine_loop.ogg",
	"sea": "res://assets/audio/ship/waves.ogg",
}

# --- Display state ---
var stage := Control.new() # Holds the panels; shaken on "shake" panels.
var lettering := Control.new() # Captions, bubbles and titles over the current panel.
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
	var cues: Array = _panels()[panel_index].cues
	while next_cue < cues.size() and panel_time >= cues[next_cue][0]:
		_play_cue(cues[next_cue][1], cues[next_cue][2])
		next_cue += 1
	if shake_left > 0.0:
		shake_left = maxf(0.0, shake_left - delta)
		var strength: float = Balance.INTRO_SHAKE_PIXELS * shake_left / Balance.INTRO_SHAKE_TIME
		stage.position = Vector2(shake_noise.randf_range(-1.0, 1.0), shake_noise.randf_range(-1.0, 1.0)) * strength
	else:
		stage.position = Vector2.ZERO
	if panel_time >= _panels()[panel_index].hold:
		_show_panel(panel_index + 1)


# --- Refresh ---
func _refresh() -> void:
	var showing: bool = Game.phase == "intro"
	if showing and not playing:
		_start()
	elif not showing and playing:
		_stop_sound()
		playing = false
	visible = Game.phase == "intro" # Read again: starting an empty intro may already have moved on.


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
func _panels() -> Array[Dictionary]:
	if Game.selected_arena == Game.MUSEUM_ARENA:
		var none: Array[Dictionary] = [] # The Museum's story panels come with the story work; until then, straight to the round.
		return none
	return Balance.SHIP_INTRO_PANELS if Game.selected_arena == Game.SHIP_ARENA else Balance.INTRO_PANELS


func _show_panel(index: int) -> void:
	var panels: Array[Dictionary] = _panels()
	if index >= panels.size():
		_finish.call_deferred() # Never inside the phase change that started the intro (an arena with no panels).
		return
	panel_index = index
	panel_time = 0.0
	next_cue = 0
	var panel: Dictionary = panels[index]
	var picture := TextureRect.new()
	var folder: String = Balance.SHIP_INTRO_FOLDER if panels == Balance.SHIP_INTRO_PANELS else Balance.INTRO_FOLDER
	picture.texture = load(folder + panel.image)
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
	for bed: String in BED_FILES:
		_fade(beds[bed], panel.beds.get(bed, Balance.INTRO_SILENT_DB))
	_letter(panel)
	hint_label.text = "%d / %d   ·   Enter: next   ·   Esc: skip" % [index + 1, panels.size()]


func _letter(panel: Dictionary) -> void:
	# Lettering drawn in the game for panels whose pictures carry none: a caption box along the top, a speech
	# bubble where the panel puts it, and a title stamp near the bottom.
	for child: Node in lettering.get_children():
		child.queue_free()
	if panel.has("caption"):
		# Dark text on the parchment box, with [b]…[/b] in comic lettering, like a speech bubble's.
		var caption: PanelContainer = Style.caption()
		var words := RichTextLabel.new()
		words.bbcode_enabled = true
		words.fit_content = true
		words.scroll_active = false
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size.x = size.x * 0.62
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_color_override("default_color", Balance.COMIC_INK)
		words.add_theme_font_size_override("normal_font_size", Balance.INTRO_LETTERING_SIZE)
		words.add_theme_font_size_override("bold_font_size", roundi(Balance.INTRO_LETTERING_SIZE * 1.3))
		words.add_theme_font_override("bold_font", load(Balance.COMIC_FONT_PATH))
		words.text = panel.caption
		caption.add_child(words)
		caption.position = Vector2(size.x * 0.03, size.y * 0.04)
		lettering.add_child(caption)
		_pop_in(caption, 0.15)
	if panel.has("bubble"):
		var bubble: VBoxContainer = Style.bubble(panel.bubble.text, Balance.INTRO_LETTERING_SIZE)
		bubble.position = Vector2(size.x * panel.bubble.at.x, size.y * panel.bubble.at.y)
		lettering.add_child(bubble)
		_pop_in(bubble, 0.9)
	if panel.has("title"):
		var title: Control = Style.stamp(panel.title, Balance.SHIP_GOLD_COLOUR, Balance.COMIC_HEADING_SIZE * 2)
		var holder := CenterContainer.new()
		holder.position = Vector2(0.0, size.y * 0.7)
		holder.size = Vector2(size.x, size.y * 0.2)
		holder.add_child(title)
		lettering.add_child(holder)
		_pop_in(holder, 1.2)


func _pop_in(item: Control, delay: float) -> void:
	item.modulate.a = 0.0
	var tween: Tween = item.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(item, "modulate:a", 1.0, Balance.INTRO_FADE_TIME)


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
	var path: String = ("res://assets/audio/" if sound.begins_with("ship/") else SOUND_FOLDER) + sound + ".ogg"
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
	lettering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lettering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_sibling(lettering)
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
	for track: String in MUSIC_FILES:
		music[track] = _loop_player(MUSIC_FILES[track], &"Music")
	for bed: String in BED_FILES:
		beds[bed] = _loop_player(BED_FILES[bed], &"SFX")


func _loop_player(path: String, bus: StringName) -> AudioStreamPlayer:
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = Balance.INTRO_SILENT_DB
	add_child(player)
	return player
