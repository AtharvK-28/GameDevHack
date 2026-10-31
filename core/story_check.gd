# Checks the story cutscenes (decision 145): every panel of the three intros has its picture or video, each ghost
# video leads to a held last frame, the lettering stays on screen, a video plays and moves on by itself, and Esc
# during a video stops it and starts the round. After the final results each map plays its ending (decision 146).
extends "res://core/match_check.gd"

const VIDEO_SECONDS: float = 7.4 # Seth-ji's video, the shortest.

var cutscene: Control

func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	router = root.get_node("InputRouter")
	if net.listen_error != OK:
		push_error("Close the running host before this check.")
		quit(1)
		return
	for set: Array in [[SETTINGS.INTRO_PANELS, SETTINGS.INTRO_FOLDER, "Mansion"], [SETTINGS.SHIP_INTRO_PANELS, SETTINGS.SHIP_INTRO_FOLDER, "Ship"], [SETTINGS.MUSEUM_INTRO_PANELS, SETTINGS.MUSEUM_INTRO_FOLDER, "Museum"]]:
		_check_panels(set[0], set[1], set[2])
	for set: Array in [[SETTINGS.MANSION_OUTRO_PANELS, SETTINGS.INTRO_FOLDER, "Mansion"], [SETTINGS.SHIP_OUTRO_PANELS, SETTINGS.SHIP_INTRO_FOLDER, "Ship"], [SETTINGS.MUSEUM_OUTRO_PANELS, SETTINGS.MUSEUM_OUTRO_FOLDER, "Museum"]]:
		_check_ending(set[0], set[1], set[2])

	game.selected_arena = "res://arenas/Mansion.tscn"
	playground = load("res://Main.tscn").instantiate()
	root.add_child(playground)
	await _wait(SETTLE_SECONDS)
	for control: Node in playground.find_children("*", "Control", true, false):
		if control.get_script() != null and control.get_script().resource_path == "res://screens/cutscene.gd":
			cutscene = control
	var dev: CanvasLayer = playground.dev_tools
	dev.forced = true
	for count: int in range(2):
		await _key(KEY_F10)
	await _wait(0.5)
	await _key(KEY_ENTER)
	await _wait(0.2)
	_check(game.phase == "intro" and cutscene.panel_index == 0, "START plays the Mansion's story")

	# Every panel's lettering fits on screen, and Enter walks to the video.
	var video_index: int = _video_index(SETTINGS.INTRO_PANELS)
	for index: int in range(video_index):
		await _wait(0.1)
		_check(_lettering_on_screen(), "Mansion panel %d's lettering stays on screen" % (index + 1))
		await _key(KEY_ENTER)
	await _wait(1.0)
	var video: VideoStreamPlayer = _video()
	_check(video != null and video.is_playing(), "The ghost's entrance plays as a video")
	await _wait(VIDEO_SECONDS)
	await _wait(0.3)
	_check(cutscene.panel_index == video_index + 1 and _video() == null, "When the video ends the held last frame follows")
	_check(_lettering_on_screen() and cutscene.lettering.get_child_count() > 0, "The ghost's line lands on the held frame")
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	_check(game.phase == "reveal", "Esc skips the rest of the story")

	# The Museum has a story now; Esc during its video silences it.
	game.return_to_lobby()
	game.selected_arena = game.MUSEUM_ARENA
	await _wait(0.5)
	await _key(KEY_ENTER)
	await _wait(0.2)
	_check(game.phase == "intro" and cutscene._panels() == SETTINGS.MUSEUM_INTRO_PANELS, "The Museum plays its own story")
	for index: int in range(_video_index(SETTINGS.MUSEUM_INTRO_PANELS)):
		await _key(KEY_ENTER)
	await _wait(0.5)
	video = _video()
	_check(video != null and video.is_playing(), "Bahadur's entrance plays as a video")
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	_check(game.phase == "reveal" and not video.is_playing(), "Esc during a video stops it and its sound")

	# The Museum's ending: Enter on the final results walks the epilogue, panel by panel, to the lobby.
	await _ending_from_results()
	_check(game.phase == "outro" and cutscene._panels() == SETTINGS.MUSEUM_OUTRO_PANELS, "Enter on the final results plays the Museum's epilogue")
	for index: int in range(SETTINGS.MUSEUM_OUTRO_PANELS.size()):
		_check(cutscene.panel_index == index, "Epilogue panel %d shows" % (index + 1))
		await _wait(0.2)
		_check(_lettering_on_screen(), "Epilogue panel %d's lettering stays on screen" % (index + 1))
		await _key(KEY_ENTER)
	await _wait(0.2)
	_check(game.phase == "lobby", "After the epilogue comes the lobby")

	# The Mansion's diary, and L going straight to the lobby.
	game.selected_arena = "res://arenas/Mansion.tscn"
	await _wait(0.5)
	await _key(KEY_ENTER)
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _ending_from_results()
	await _wait(1.0)
	_check(game.phase == "outro" and cutscene._panels() == SETTINGS.MANSION_OUTRO_PANELS and _lettering_on_screen(), "The Mansion ends on Seth-ji's diary, on screen")
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	await _key(KEY_ENTER)
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	game._set_phase("final")
	await _wait(0.2)
	await _key(KEY_L)
	await _wait(0.2)
	_check(game.phase == "lobby", "L on the final results skips the ending")
	print("STORY CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _check_panels(panels: Array[Dictionary], folder: String, arena: String) -> void:
	var missing: Array[String] = []
	var videos: int = 0
	for index: int in range(panels.size()):
		var panel: Dictionary = panels[index]
		var file: String = folder + panel.get("video", panel.get("image", ""))
		if not ResourceLoader.exists(file):
			missing.append(file)
		if panel.has("video"):
			videos += 1
			_check(index + 1 < panels.size() and panels[index + 1].get("held", false) and panels[index + 1].has("bubble"), "%s's video leads to a held frame with the ghost's line" % arena)
	_check(missing.is_empty(), "All %d of the %s's panels have their art %s" % [panels.size(), arena, missing])
	_check(videos == 1, "The %s has one ghost video" % arena)
	_check(panels[-1].has("title"), "The %s's story ends on its title" % arena)


func _check_ending(panels: Array[Dictionary], folder: String, arena: String) -> void:
	var missing: Array[String] = []
	for panel: Dictionary in panels:
		if not ResourceLoader.exists(folder + panel.image):
			missing.append(panel.image)
	_check(not panels.is_empty() and missing.is_empty(), "The %s's ending has its %d panels %s" % [arena, panels.size(), missing])


func _ending_from_results() -> void:
	game._set_phase("final")
	await _wait(0.2)
	await _key(KEY_ENTER)
	await _wait(0.2)


func _video_index(panels: Array[Dictionary]) -> int:
	for index: int in range(panels.size()):
		if panels[index].has("video"):
			return index
	return -1


func _video() -> VideoStreamPlayer:
	for child: Node in cutscene.stage.get_children():
		if child is VideoStreamPlayer and not child.is_queued_for_deletion():
			return child
	return null


func _lettering_on_screen() -> bool:
	var screen := Rect2(Vector2.ZERO, cutscene.size)
	for item: Node in cutscene.lettering.get_children():
		if not item.is_queued_for_deletion() and not screen.encloses(item.get_global_rect()):
			return false
	return true
