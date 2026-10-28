# Disaster Cam's replay (decision 144): before the round-end page, a letterboxed security-camera replay of the round's
# worst disaster: a quick rewind, the build-up at full speed, the moment itself in slow motion, then the aftermath.
# After the last round, a reel of the match's worst three. The recorder (core/disaster_cam.gd) supplies the clips;
# the world stays paused while puppets and the real movers act each clip out, and everything is put back after.
# Host keys: Enter or Space skips.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var top_bar := ColorRect.new()
var bottom_bar := ColorRect.new()
var rec_label: Label
var hint_label: Label
var item_label: Label
var blame_label: Label
var rewind_label: Label
var flash := ColorRect.new()

# --- Playback state ---
var host: Node3D
var queue: Array[Dictionary] = []
var clip: Dictionary = {}
var playing: bool = false
var reel_mode: bool = false
var reel_place: int = 0 # The reel's countdown: #3, #2, then #1, the worst.
var stage: String = "" # wait, rewind, play, hold
var first_clip: bool = false
var stage_left: float = 0.0
var playhead: float = 0.0 # Clip time, in the recorder's game seconds.
var start_time: float = 0.0
var end_time: float = 0.0
var hit_shown: bool = false
var blink: float = 0.0
var stage_root := Node3D.new() # Holds the puppets and the replayed effects; runs while the world is paused.
var swallow_key: Key = KEY_NONE # The skipping key, until it is released.

# --- What the replay changed, to put back ---
var hidden_nodes: Array[Node3D] = []
var saved_movers: Array[Dictionary] = []
var saved_rig: Variant = null
var saved_camera: Dictionary = {}

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.use_theme(self)
	stage_root.name = "DisasterReplayStage"
	stage_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	Game.changed.connect(_refresh)


func _build() -> void:
	for bar: ColorRect in [top_bar, bottom_bar]:
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
	_span(top_bar, 0.0, Balance.DISASTER_CAM_BAR)
	_span(bottom_bar, 1.0 - Balance.DISASTER_CAM_BAR, 1.0)

	var top_row := HBoxContainer.new()
	top_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_row.offset_left = Balance.UI_PANEL_MARGIN * 2
	top_row.offset_right = -Balance.UI_PANEL_MARGIN * 2
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(top_row)
	rec_label = Style.lettering("", Balance.COMIC_HEADING_SIZE, Balance.DISASTER_CAM_REC_COLOUR)
	rec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_row.add_child(rec_label)
	hint_label = Style.label("ENTER: SKIP", Balance.UI_BODY_SIZE, Color(Balance.UI_TEXT, 0.7))
	top_row.add_child(hint_label)
	for line: Label in [rec_label, hint_label]:
		line.autowrap_mode = TextServer.AUTOWRAP_OFF # One line each, so the row keeps the bar's height.

	var lines := VBoxContainer.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	bottom_bar.add_child(lines)
	item_label = Style.lettering("", Balance.COMIC_HEADING_SIZE, Balance.UI_DANGER)
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(item_label)
	blame_label = Style.label("", Balance.UI_BODY_SIZE, Balance.UI_TEXT)
	blame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(blame_label)

	rewind_label = Style.lettering("<< REWIND", Balance.COMIC_TITLE_SIZE, Color.WHITE)
	rewind_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rewind_label.anchor_top = Balance.DISASTER_CAM_BAR
	rewind_label.anchor_bottom = Balance.DISASTER_CAM_BAR
	rewind_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rewind_label.offset_right = -Balance.UI_PANEL_MARGIN * 2
	rewind_label.offset_top = Balance.UI_PANEL_MARGIN
	add_child(rewind_label)

	flash.color = Color(Color.WHITE, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)


static func _span(bar: Control, top: float, bottom: float) -> void:
	# Full width, between two shares of the screen height.
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = top
	bar.anchor_bottom = bottom
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = 0.0


func _input(event: InputEvent) -> void:
	# Ahead of the pages' buttons: the release of the skipping key must not press the button that just took focus.
	if event is InputEventKey and not event.pressed and event.physical_keycode == swallow_key:
		swallow_key = KEY_NONE
		get_viewport().set_input_as_handled()
		return
	var key: Key = Style.pressed_key(event)
	if not playing or key not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return
	swallow_key = key
	queue.clear()
	_end_clip()
	_finish()
	get_viewport().set_input_as_handled()


# --- Starting and finishing ---
func _refresh() -> void:
	if playing or Game.phase not in ["result", "final"] or Game.replay.is_empty() or not is_instance_valid(Game.host):
		return
	host = Game.host
	queue.assign(Game.replay)
	reel_mode = Game.phase == "final"
	reel_place = queue.size()
	first_clip = true
	playing = true
	visible = true
	_hold_world()
	_next_clip()


func _next_clip() -> void:
	if queue.is_empty():
		_finish()
		return
	clip = queue.pop_front()
	var frames: Array = clip.frames
	var focal: Dictionary = clip.focal
	start_time = frames[0].t
	end_time = frames[-1].t
	if reel_mode:
		start_time = maxf(start_time, focal.t - Balance.DISASTER_CAM_REEL_LEAD)
		end_time = minf(end_time, focal.t + Balance.DISASTER_CAM_REEL_TAIL)
	for puppet: Variant in clip.puppets:
		if puppet is Node3D:
			stage_root.add_child(puppet)
	rec_label.text = "WORST DISASTER #%d" % reel_place if reel_mode else "REC  DISASTER CAM"
	reel_place -= 1
	item_label.text = "%s  -%s" % [String(focal.item).to_upper(), Loot.rupees(focal.total)]
	blame_label.text = String(focal.blame)
	item_label.visible = false
	blame_label.visible = false
	hit_shown = false
	stage = "wait"
	stage_left = Balance.UI_WIPE_TIME * 2.0 if first_clip else 0.0 # The first waits out the screen wipe.
	first_clip = false
	playhead = end_time
	rewind_label.visible = false
	_apply(playhead)


func _end_clip() -> void:
	# Puppets go back to the clip (the reel may show it again); replayed popups and effects go.
	for child: Node in stage_root.get_children():
		stage_root.remove_child(child)
		if not child in clip.get("puppets", []):
			child.queue_free()


func _finish() -> void:
	playing = false
	visible = false
	clip = {}
	_release_world()
	Game.replay = []
	Sfx.phase_jingle(Game.phase)
	Game.changed.emit() # The round-end page or the final results now show.


# --- Every frame ---
func _process(delta: float) -> void:
	if not playing:
		return
	blink += delta
	rec_label.modulate.a = 1.0 if fmod(blink, Balance.DISASTER_CAM_BLINK * 2.0) < Balance.DISASTER_CAM_BLINK else 0.55
	match stage:
		"wait":
			stage_left -= delta
			if stage_left <= 0.0:
				stage = "rewind"
				stage_left = Balance.DISASTER_CAM_REWIND_SECONDS
				Sfx.play("rewind", 1.0, Balance.DISASTER_CAM_REWIND_DB)
		"rewind":
			stage_left -= delta
			rewind_label.visible = fmod(blink, 0.3) < 0.2
			playhead = lerpf(start_time, end_time, clampf(stage_left / Balance.DISASTER_CAM_REWIND_SECONDS, 0.0, 1.0))
			if stage_left <= 0.0:
				stage = "play"
				playhead = start_time
				rewind_label.visible = false
				_flash(Balance.DISASTER_CAM_FLASH_ALPHA * 0.5)
		"play":
			var speed: float = _speed_at(playhead)
			var next: float = minf(end_time, playhead + delta * speed)
			_fire_events(playhead, next, speed)
			playhead = next
			if not hit_shown and playhead >= clip.focal.t:
				_show_hit()
			if playhead >= end_time:
				stage = "hold"
				stage_left = Balance.DISASTER_CAM_HOLD
		"hold":
			stage_left -= delta
			if stage_left <= 0.0:
				_end_clip()
				_next_clip()
				return
	_apply(playhead)
	_aim_camera()


func _speed_at(time: float) -> float:
	var focal: float = clip.focal.t
	if time >= focal - Balance.DISASTER_CAM_SLOW_BEFORE and time <= focal + Balance.DISASTER_CAM_SLOW_AFTER:
		return Balance.DISASTER_CAM_SLOW
	return 1.0


func _show_hit() -> void:
	hit_shown = true
	item_label.visible = true
	blame_label.visible = true
	item_label.pivot_offset = item_label.size / 2.0
	item_label.scale = Vector2.ONE * Balance.COMIC_STAMP_START
	item_label.create_tween().tween_property(item_label, "scale", Vector2.ONE, Balance.COMIC_STAMP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash(Balance.DISASTER_CAM_FLASH_ALPHA)
	if is_instance_valid(host.camera):
		host.camera.shake(Balance.DISASTER_CAM_SHAKE)


func _flash(alpha: float) -> void:
	flash.color.a = alpha
	flash.create_tween().tween_property(flash, "color:a", 0.0, Balance.DISASTER_CAM_FLASH_TIME)


# --- Acting the clip out ---
func _apply(time: float) -> void:
	var frames: Array = clip.frames
	var low: int = 0
	var high: int = frames.size() - 1
	while low < high: # The last frame at or before the time.
		var middle: int = (low + high + 1) / 2
		if frames[middle].t <= time:
			low = middle
		else:
			high = middle - 1
	var a: Dictionary = frames[low]
	var b: Dictionary = frames[mini(low + 1, frames.size() - 1)]
	var weight: float = clampf((time - a.t) / (b.t - a.t), 0.0, 1.0) if b.t > a.t else 0.0

	var puppets: Array = clip.puppets
	for index: int in range(puppets.size()):
		var puppet: Node3D = puppets[index]
		if puppet == null:
			continue
		var from: Variant = a.x[index] if index < a.x.size() else null
		var to: Variant = b.x[index] if index < b.x.size() else null
		puppet.visible = from != null or to != null
		if from != null and to != null:
			puppet.global_transform = (from as Transform3D).interpolate_with(to, weight)
		elif puppet.visible:
			puppet.global_transform = from if from != null else to

	for slot: int in range(host.movers.size()):
		_pose_mover(host.movers[slot], a.m[slot], b.m[slot], weight)
	var arena: Node3D = host.arena
	if a.rig != null and b.rig != null and arena.get("rig") is Node3D:
		arena.rig.transform = (a.rig as Transform3D).interpolate_with(b.rig, weight)


static func _pose_mover(mover: CharacterBody3D, from: Dictionary, to: Dictionary, weight: float) -> void:
	mover.visible = from.v
	if not from.v:
		return
	mover.global_transform = (from.x as Transform3D).interpolate_with(to.x, weight)
	mover.model.transform = (from.f as Transform3D).interpolate_with(to.f, weight)
	mover.model.body.transform = (from.b as Transform3D).interpolate_with(to.b, weight)
	var player: AnimationPlayer = mover.model.player
	if String(from.a) == "":
		return
	if player.current_animation != from.a:
		player.play(from.a)
	var clip_time: float = from.p
	if to.a == from.a and to.p >= from.p:
		clip_time = lerpf(from.p, to.p, weight)
	player.seek(clip_time, true)


func _fire_events(from: float, to: float, speed: float) -> void:
	for event: Dictionary in clip.events:
		if event.t <= from or event.t > to:
			continue
		match event.kind:
			"sound":
				Sfx.play(event.sound, event.pitch * (Balance.DISASTER_CAM_SLOW_PITCH if speed < 1.0 else 1.0), event.db)
			"burst":
				Fx.burst(event.at, event.fx, stage_root, event.scale)
			"label":
				_replay_label(event, speed)


func _replay_label(event: Dictionary, speed: float) -> void:
	# The popup as it was: a loot popup rises and fades where it appeared; a shout punches in over its mover.
	var label := Label3D.new()
	label.text = event.text
	label.font = load(Balance.COMIC_FONT_PATH)
	label.font_size = event.size
	label.pixel_size = event.pixel
	label.modulate = event.fill
	label.outline_size = Balance.VALUE_POPUP_OUTLINE
	label.outline_modulate = event.outline
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	var mover: CharacterBody3D = host.movers[event.slot] if event.slot >= 0 else null
	if mover != null:
		label.position = event.at
		mover.add_child(label)
		stage_root.tree_exiting.connect(label.queue_free, CONNECT_ONE_SHOT)
	else:
		stage_root.add_child(label)
		label.global_position = event.at
	label.scale = Vector3.ONE * Balance.VALUE_POPUP_PUNCH
	var lifetime: float = Balance.SHOUT_LIFETIME if mover != null else Balance.VALUE_POPUP_LIFETIME
	var punch := label.create_tween().set_speed_scale(speed)
	punch.tween_property(label, "scale", Vector3.ONE, Balance.VALUE_POPUP_PUNCH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade := label.create_tween().set_parallel().set_speed_scale(speed)
	if mover == null:
		fade.tween_property(label, "position:y", label.position.y + Balance.VALUE_POPUP_RISE, lifetime)
	fade.tween_property(label, "modulate:a", 0.0, lifetime * 0.4).set_delay(lifetime * 0.6)
	fade.chain().tween_callback(label.queue_free)


func _aim_camera() -> void:
	# Eases in on the disaster across the clip, swinging a little round it.
	var camera: Camera3D = host.camera
	if not is_instance_valid(camera):
		return
	var progress: float = clampf((playhead - start_time) / maxf(end_time - start_time, 0.01), 0.0, 1.0)
	var at: Vector3 = clip.focal.at
	camera.focus = Vector3(at.x, 0.0, at.z)
	camera.distance = lerpf(Balance.DISASTER_CAM_FAR, Balance.DISASTER_CAM_NEAR, smoothstep(0.0, 1.0, progress))
	camera.arena_yaw = saved_camera.yaw + Balance.DISASTER_CAM_ORBIT * (progress * 2.0 - 1.0)


# --- Holding the world still, and putting it back ---
func _hold_world() -> void:
	hidden_nodes.clear()
	var to_hide: Array[Node] = host.arena.find_children("*", "PhysicsBody3D", true, false)
	to_hide.append_array(get_tree().get_nodes_in_group("popups"))
	if is_instance_valid(host.ghost):
		to_hide.append(host.ghost)
	for node: Node in to_hide:
		if node is Node3D and not node is StaticBody3D and node.visible:
			node.visible = false
			hidden_nodes.append(node)
	saved_movers.clear()
	for mover: CharacterBody3D in host.movers:
		var state: Dictionary = DisasterCam.mover_state(mover)
		state.speed = mover.model.player.speed_scale
		saved_movers.append(state)
		mover.model.process_mode = Node.PROCESS_MODE_ALWAYS # The skeleton shows each seeked pose while paused.
		mover.model.player.speed_scale = 0.0
	saved_rig = host.arena.rig.transform if host.arena.get("rig") is Node3D else null
	var camera: Camera3D = host.camera
	saved_camera = {"follow": camera.follow_movers, "yaw": camera.arena_yaw, "focus": camera.focus, "distance": camera.distance}
	camera.follow_movers = false
	host.add_child(stage_root)


func _release_world() -> void:
	if stage_root.is_inside_tree():
		stage_root.get_parent().remove_child(stage_root)
	if not is_instance_valid(host):
		return
	for node: Node3D in hidden_nodes:
		if is_instance_valid(node):
			node.visible = true
	hidden_nodes.clear()
	for slot: int in range(mini(saved_movers.size(), host.movers.size())):
		var mover: CharacterBody3D = host.movers[slot]
		var state: Dictionary = saved_movers[slot]
		_pose_mover(mover, state, state, 0.0)
		mover.visible = state.v
		mover.model.player.speed_scale = state.speed
		mover.model.process_mode = Node.PROCESS_MODE_INHERIT
	if saved_rig != null and host.arena.get("rig") is Node3D:
		host.arena.rig.transform = saved_rig
	var camera: Camera3D = host.camera
	if is_instance_valid(camera) and not saved_camera.is_empty():
		camera.follow_movers = saved_camera.follow
		camera.arena_yaw = saved_camera.yaw
		camera.focus = saved_camera.focus
		camera.distance = saved_camera.distance
