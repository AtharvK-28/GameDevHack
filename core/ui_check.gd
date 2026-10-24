# Exercises the real launch path, host menus, match screens and pause navigation.
# Run with a renderer to also save review captures in the ignored .verification folder.
extends SceneTree

# --- Check settings ---
const BASE_SIZE := Vector2i(1152, 648)
const MENU_PATH := "res://menus/main_menu/main_menu.tscn"
const MAIN_PATH := "res://Main.tscn"
const LONG_NAME := "WWWWWWWWWWWWWWWW"
const SETTLE_SECONDS: float = 0.6
const LOAD_ATTEMPTS: int = 60

# --- State ---
var failures: int = 0
var game: Node
var net: Node

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	net = root.get_node("Net")
	root.size = BASE_SIZE
	root.content_scale_size = BASE_SIZE
	_check(root.theme != null and root.theme.default_font != null, "Runtime theme and font load")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _wait_for_scene(MENU_PATH)
	if current_scene == null or current_scene.scene_file_path != MENU_PATH:
		quit(1)
		return
	var menu: Control = current_scene
	_check(menu.get_node("%NewGameButton").text == "Play", "Launch opens Home with Play")
	await _review("home")
	menu.get_node("%GuideButton").pressed.emit()
	await _review("guide")
	_check(menu.sub_menu != null and not menu.get_node("%MenuContainer").visible, "Guide hides title buttons")
	_cancel()
	await _wait()
	_check(menu.sub_menu == null and menu.get_node("%NewGameButton").has_focus(), "Guide Escape restores Play focus")
	menu.get_node("%OptionsButton").pressed.emit()
	await _review("options")
	menu.sub_menu.close()
	await _wait()
	menu.get_node("%CreditsButton").pressed.emit()
	await _review("credits")
	menu.sub_menu.close()
	await _wait()
	menu.new_game()
	await _review("maps")
	menu.sub_menu.map_chosen.emit("res://arenas/Mansion.tscn")
	await _wait_for_scene(MAIN_PATH)
	if current_scene == null or current_scene.scene_file_path != MAIN_PATH:
		quit(1)
		return
	await _review("lobby")
	await _match_screens()
	game.return_to_lobby()
	await _review("returned_lobby")
	current_scene.queue_free()
	await process_frame
	paused = false
	print("UI CHECK: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(0 if failures == 0 else 1)


# --- Match screens ---
func _match_screens() -> void:
	# Isolate visual state from networking; plumbing_check covers real phone traffic.
	game.set_process(false)
	for slot: int in 4:
		var player: Dictionary = net._new_player(LONG_NAME)
		player.socket = WebSocketPeer.new()
		net.players.append(player)
		game.scores[slot] = 100.0
	game.participants.assign([0, 1, 2, 3])
	game.round_count = 4
	game._begin_round(false)
	await _review("reveal")
	game._set_phase("live")
	game.seconds_left = 76
	await _review("hud")
	_key(KEY_ESCAPE)
	await _wait()
	_check(game.phase == "paused" and game.host_paused, "Escape opens host pause")
	await _review("pause")
	var hud: Control = current_scene.find_child("HUD", true, false)
	var pause_menu: Control = hud.pause_menu
	pause_menu._on_options_button_pressed()
	await _review("pause_options")
	_check(game.phase == "paused", "Options keeps the round paused")
	pause_menu.open_window.close()
	await _wait()
	pause_menu.close()
	await _wait()
	_check(game.phase == "live" and not game.host_paused, "Resume closes pause and resumes the round")
	game.banked_value = game.target_value()
	game._finish_round(true, "All items are accounted for.")
	await _review("result")
	game._set_phase("final")
	await _review("final")


# --- Verification helpers ---
func _wait() -> void:
	await create_timer(SETTLE_SECONDS, true).timeout


func _wait_for_scene(path: String) -> void:
	for attempt: int in LOAD_ATTEMPTS:
		if current_scene != null and current_scene.scene_file_path == path:
			await _wait()
			_check(true, "Loaded " + path)
			return
		await _wait()
	_check(false, "Timed out loading " + path)


func _review(label: String) -> void:
	await _wait()
	var screen: Rect2 = root.get_visible_rect()
	for control: Node in current_scene.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or not (control is Label or control is BaseButton):
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			_check(screen.grow(1.0).encloses(rect), "%s: %s fits the viewport" % [label, control.name])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.verification")
		root.get_texture().get_image().save_png("res://.verification/audit_ui_%s.png" % label)


func _cancel() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)


func _check(ok: bool, description: String) -> void:
	print("PASS: " if ok else "FAIL: ", description)
	if not ok:
		failures += 1
