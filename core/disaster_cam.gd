# Disaster Cam's recorder (decision 144). During live play it keeps the last few seconds of everything that moves:
# every physics body in the arena (loot, furniture, doors, the ghost), the movers with their animation, and the
# Ship's rig, plus the sounds, effects and comic popups. The loot's damage picks the round's worst disaster; a few
# seconds after it, the recorder saves a clip with a visual copy (a puppet) of every body in it, so the replay
# (screens/disaster_replay.gd) can show even loot that has since shattered, and the final reel can show past rounds.
class_name DisasterCam
extends Node

static var current: DisasterCam # The match's recorder, for the sound, effect and popup hooks.

# --- State ---
var host: Node3D # Main.
var clock: float = 0.0 # Seconds of live play this round, in game time.
var step: int = 0
var arena_id: int = 0 # The arena being recorded; a new round builds a new one.
var bodies: Array[Node3D] = [] # Tracked nodes by index; an entry may have been freed since.
var body_index: Dictionary = {} # Instance id -> index.
var exit_puppets: Dictionary = {} # Index -> {t, puppet}: copies of bodies that left the tree during play.
var frames: Array[Dictionary] = [] # {t, x: Array of Transform3D or null per body, m: mover states, rig}.
var events: Array[Dictionary] = [] # {t, kind: "sound" | "burst" | "label", ...}.
var cluster: Dictionary = {} # The losses landing together now.
var best: Dictionary = {} # The round's worst disaster so far, once it qualifies.
var capture_at: float = -1.0 # Clock time to save the clip of best; -1 when nothing is waiting.
var clips: Dictionary = {} # Round index -> that round's clip.

# --- Setup ---
func _ready() -> void:
	current = self
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if current == self:
		current = null
	_free_exit_puppets()
	forget_match()


# --- Recording, every physics frame of live play ---
func _physics_process(delta: float) -> void:
	if Game.phase != "live" or not is_instance_valid(host) or not is_instance_valid(host.arena):
		return
	if host.arena.get_instance_id() != arena_id:
		_start_round()
	if is_instance_valid(host.ghost) and not body_index.has(host.ghost.get_instance_id()):
		_track(host.ghost)
	clock += delta
	step += 1
	if step % Balance.DISASTER_CAM_STEP == 0:
		_record_frame()
	if capture_at >= 0.0 and clock >= capture_at:
		_capture()


func _start_round() -> void:
	arena_id = host.arena.get_instance_id()
	clock = 0.0
	step = 0
	bodies.clear()
	body_index.clear()
	_free_exit_puppets()
	frames.clear()
	events.clear()
	cluster = {}
	best = {}
	capture_at = -1.0
	for node: Node in host.arena.find_children("*", "PhysicsBody3D", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	# Bodies spawned during play (an escaped cat, a hatched raptor) are tracked from then on.
	if node is PhysicsBody3D and not node is StaticBody3D and is_instance_valid(host) and is_instance_valid(host.arena) \
			and host.arena.get_instance_id() == arena_id and host.arena.is_ancestor_of(node) and not body_index.has(node.get_instance_id()):
		_track(node)


func _track(node: Node3D) -> void:
	var index: int = bodies.size()
	bodies.append(node)
	body_index[node.get_instance_id()] = index
	node.tree_exiting.connect(_on_body_exiting.bind(index))
	if node.has_signal("damaged"):
		node.damaged.connect(_on_damaged.bind(index))


func _record_frame() -> void:
	var transforms: Array = []
	transforms.resize(bodies.size())
	for index: int in range(bodies.size()):
		var body: Node3D = bodies[index]
		if is_instance_valid(body) and body.is_inside_tree() and body.is_visible_in_tree():
			transforms[index] = body.global_transform
	var movers: Array[Dictionary] = []
	for mover: CharacterBody3D in host.movers:
		movers.append(mover_state(mover))
	var rig: Variant = host.arena.rig.transform if host.arena.get("rig") is Node3D else null
	frames.append({"t": clock, "x": transforms, "m": movers, "rig": rig})
	var oldest: float = clock - Balance.DISASTER_CAM_BUFFER
	while not frames.is_empty() and frames[0].t < oldest:
		frames.pop_front()
	while not events.is_empty() and events[0].t < oldest:
		events.pop_front()
	for index: int in exit_puppets.keys():
		if exit_puppets[index].t < oldest:
			exit_puppets[index].puppet.free()
			exit_puppets.erase(index)


static func mover_state(mover: CharacterBody3D) -> Dictionary:
	var model: MoverModel = mover.model
	var player: AnimationPlayer = model.player
	return {"v": mover.visible, "x": mover.global_transform, "f": model.transform, "b": model.body.transform,
		"a": player.current_animation, "p": player.current_animation_position if player.current_animation != "" else 0.0}


# --- Hooks: sounds, effects and popups (no-ops outside live play) ---
static func note_sound(sound: String, pitch: float, volume_db: float) -> void:
	if _recording() and sound not in Balance.DISASTER_CAM_SKIP_SOUNDS:
		current.events.append({"t": current.clock, "kind": "sound", "sound": sound, "pitch": pitch, "db": volume_db})


static func note_burst(at: Vector3, kind: int, amount_scale: float) -> void:
	if _recording():
		current.events.append({"t": current.clock, "kind": "burst", "at": at, "fx": kind, "scale": amount_scale})


static func note_label(label: Label3D, mover: CharacterBody3D = null) -> void:
	# A loot popup rises from where it appeared; a mover's shout rides over their head.
	if not _recording():
		return
	current.events.append({"t": current.clock, "kind": "label", "text": label.text, "fill": label.modulate,
		"outline": label.outline_modulate, "size": label.font_size, "pixel": label.pixel_size,
		"at": label.global_position if mover == null else label.position, "slot": mover.slot if mover != null else -1})


static func _recording() -> bool:
	return is_instance_valid(current) and Game.phase == "live"


# --- Picking the disaster ---
func _on_damaged(loss: int, remaining: int, index: int) -> void:
	if Game.phase != "live" or loss <= 0:
		return
	var item: Node3D = bodies[index]
	if cluster.is_empty() or clock > cluster.start + Balance.DISASTER_CAM_WINDOW:
		cluster = {"start": clock, "total": 0, "biggest": 0, "smashed": false}
	cluster.total += loss
	cluster.smashed = cluster.smashed or remaining == 0
	if loss > cluster.biggest:
		# The clip centres on the cluster's biggest single loss.
		cluster.biggest = loss
		cluster.t = clock
		cluster.at = item.global_position
		cluster.item = String(item.item_name)
		cluster.blame = blame_for(item)
	var qualifies: bool = cluster.total >= Balance.DISASTER_CAM_MIN_LOSS or cluster.smashed
	if qualifies and (best.is_empty() or is_same(cluster, best) or cluster.total > best.total):
		best = cluster
		capture_at = cluster.t + Balance.DISASTER_CAM_TAIL


static func blame_for(item: Node3D) -> String:
	var slots: Array[int] = []
	if item.get("handle_holders") is Array and item.weight_class == Balance.TWO_PERSON:
		for holder: CharacterBody3D in item.handle_holders:
			if is_instance_valid(holder):
				slots.append(holder.slot)
	elif is_instance_valid(item.holder):
		slots.append(item.holder.slot)
	if not slots.is_empty():
		var names := PackedStringArray()
		for slot: int in slots:
			names.append(_name_of(slot))
		return "IN THE HANDS OF %s" % " & ".join(names)
	if item.haunted and Game.ghost_slot >= 0:
		return "POSSESSED BY %s" % _name_of(Game.ghost_slot)
	if item.thrown and item.last_carrier_slot >= 0:
		return "THROWN BY %s" % _name_of(item.last_carrier_slot)
	return Balance.DISASTER_CAM_NOBODY


static func _name_of(slot: int) -> String:
	return String(Net.player_for_slot(slot).get("name", "PLAYER %d" % (slot + 1))).to_upper()


# --- Clips ---
func _on_body_exiting(index: int) -> void:
	# Loot that shatters or is banked leaves the tree; keep a copy while it may still be in a clip.
	if Game.phase == "live" and is_instance_valid(bodies[index]) and not exit_puppets.has(index):
		exit_puppets[index] = {"t": clock, "puppet": make_puppet(bodies[index])}


func _capture() -> void:
	capture_at = -1.0
	if best.is_empty():
		return
	var start: float = best.t - Balance.DISASTER_CAM_LEAD
	var clip_frames: Array = frames.filter(func(frame: Dictionary) -> bool: return frame.t >= start)
	if clip_frames.size() < 2:
		return
	var puppets: Array = []
	puppets.resize(bodies.size())
	for index: int in range(bodies.size()):
		if not clip_frames.any(func(frame: Dictionary) -> bool: return index < frame.x.size() and frame.x[index] != null):
			continue
		var body: Node3D = bodies[index]
		if is_instance_valid(body) and body.is_inside_tree():
			puppets[index] = make_puppet(body)
		elif exit_puppets.has(index):
			puppets[index] = exit_puppets[index].puppet.duplicate()
	forget_round(Game.round_index)
	clips[Game.round_index] = {"frames": clip_frames, "events": events.filter(func(event: Dictionary) -> bool: return event.t >= start),
		"puppets": puppets, "focal": best.duplicate(), "round": Game.round_index}


func finish_round() -> Array[Dictionary]:
	# Called as the round ends: saves a clip still waiting for its aftermath, and returns this round's clip to replay.
	if capture_at >= 0.0:
		_capture()
	var replay: Array[Dictionary] = []
	if clips.has(Game.round_index):
		replay.append(clips[Game.round_index])
	return replay


func reel() -> Array[Dictionary]:
	# The match's worst disasters, the worst last; only when there is more than one to show.
	var all: Array = clips.values()
	if all.size() < 2:
		return []
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.focal.total > b.focal.total)
	var top: Array[Dictionary] = []
	for clip: Dictionary in all.slice(0, Balance.DISASTER_CAM_REEL_SIZE):
		top.push_front(clip)
	return top


func forget_round(round_index: int) -> void:
	if clips.has(round_index):
		_free_puppets(clips[round_index])
		clips.erase(round_index)


func forget_match() -> void:
	for clip: Dictionary in clips.values():
		_free_puppets(clip)
	clips.clear()


func _free_puppets(clip: Dictionary) -> void:
	for puppet: Variant in clip.puppets:
		if puppet is Node and is_instance_valid(puppet) and not puppet.is_inside_tree():
			puppet.free()


func _free_exit_puppets() -> void:
	for entry: Dictionary in exit_puppets.values():
		entry.puppet.free()
	exit_puppets.clear()


static func make_puppet(body: Node3D) -> Node3D:
	# A visual-only copy: every mesh shown under the body, at its offset from the body, sharing meshes and materials.
	var puppet := Node3D.new()
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if not _shown_under(mesh, body):
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.skin = mesh.skin
		copy.material_override = mesh.material_override
		copy.material_overlay = mesh.material_overlay
		copy.cast_shadow = mesh.cast_shadow
		for surface: int in range(mesh.get_surface_override_material_count()):
			copy.set_surface_override_material(surface, mesh.get_surface_override_material(surface))
		copy.transform = _offset(mesh, body)
		puppet.add_child(copy)
	return puppet


static func _offset(node: Node3D, body: Node3D) -> Transform3D:
	# The node's transform in the body's frame, from local transforms, so it holds while they leave the tree.
	var offset := Transform3D.IDENTITY
	var walk: Node = node
	while walk != body and walk != null:
		if walk is Node3D:
			offset = walk.transform * offset
		walk = walk.get_parent()
	return offset


static func _shown_under(node: Node3D, body: Node3D) -> bool:
	# Shown as far as the body itself; the body may be hidden as it leaves (shattered loot hides first).
	var check: Node = node
	while check != body and check != null:
		if check is Node3D and not check.visible:
			return false
		check = check.get_parent()
	return true
