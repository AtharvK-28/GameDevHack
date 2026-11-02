# A glass display case over one Museum exhibit (decision 138). While it is shut, nobody can grab the exhibit and the
# ghost cannot possess it. A mover opens it one of two ways: hold GRAB at the case for CASE_UNLOCK_SECONDS to pick the
# lock quietly (a meter shows the progress), or shove the glass in to smash it at once, which is loud: it fills the
# ALARM bar and gives the ghost energy. A shove is a quick jab of GRAB let go with the stick pushed at the case, the
# same flick that throws an item (decision 151), so the case needs no button of its own. Hold GRAB any longer than
# that and you are picking the lock, so letting go part way through costs you nothing but the progress.
extends Node3D

var item: Loot
var closed: bool = true
var progress: float = 0.0
var glass: MeshInstance3D
var body := StaticBody3D.new()
var meter := Label3D.new()

func setup(exhibit: Loot) -> void:
	# Called by the arena before the case enters the tree: the case stands over the exhibit's pedestal top.
	item = exhibit
	exhibit.case = self


func _ready() -> void:
	var size: Vector3 = Balance.CASE_SIZE
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Balance.MUSEUM_GOLD
	frame.metallic = 0.6
	frame.roughness = 0.35
	var pane := StandardMaterial3D.new()
	pane.albedo_color = Balance.CASE_GLASS
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.roughness = 0.05
	glass = _box(size, Vector3.UP * size.y / 2.0, pane)
	_box(Vector3(size.x + 0.04, 0.04, size.z + 0.04), Vector3.UP * size.y, frame)
	_box(Vector3(size.x + 0.04, 0.04, size.z + 0.04), Vector3.UP * 0.02, frame)
	body.collision_layer = Balance.WORLD_LAYER
	body.collision_mask = 0
	# Hollow: four thin glass walls and a lid, so the exhibit inside rests untouched.
	var t: float = 0.04
	for wall: Array in [[Vector3(size.x, size.y, t), Vector3(0, size.y / 2.0, size.z / 2.0)], [Vector3(size.x, size.y, t), Vector3(0, size.y / 2.0, -size.z / 2.0)],
			[Vector3(t, size.y, size.z), Vector3(size.x / 2.0, size.y / 2.0, 0)], [Vector3(t, size.y, size.z), Vector3(-size.x / 2.0, size.y / 2.0, 0)],
			[Vector3(size.x, t, size.z), Vector3(0, size.y, 0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[0]
		shape.shape = box
		shape.position = wall[1]
		body.add_child(shape)
	add_child(body)
	meter.font = load(Balance.COMIC_FONT_PATH)
	meter.font_size = Balance.PRICE_FONT_SIZE
	meter.pixel_size = Balance.VALUE_POPUP_PIXEL_SIZE
	meter.modulate = Balance.MUSEUM_SIGN_COLOUR
	meter.outline_modulate = Balance.COMIC_INK
	meter.outline_size = Balance.VALUE_POPUP_OUTLINE
	meter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	meter.no_depth_test = true
	meter.position = Vector3.UP * (size.y + 0.45)
	meter.visible = false
	add_child(meter)


func _physics_process(delta: float) -> void:
	if not closed:
		return
	var picking: bool = false
	for mover: Node3D in get_tree().get_nodes_in_group("movers"):
		if not mover.in_play or is_instance_valid(mover.held_item):
			continue
		if Vector2(mover.global_position.x - global_position.x, mover.global_position.z - global_position.z).length() > Balance.CASE_REACH:
			continue
		var input: RefCounted = InputRouter.for_slot(mover.slot)
		if input.buttons.get("grab", false):
			picking = true
		elif input.released.get("grab", false) and progress < Balance.CASE_SHOVE_WINDOW and _shoved_by(mover):
			smash(mover.slot)
			return
	progress = progress + delta if picking else maxf(0.0, progress - delta * Balance.CASE_PROGRESS_DECAY)
	meter.visible = progress > 0.0
	var steps: int = clampi(int(progress / Balance.CASE_UNLOCK_SECONDS * 5.0), 0, 5)
	meter.text = "UNLOCKING " + "▮".repeat(steps) + "▯".repeat(5 - steps)
	if progress >= Balance.CASE_UNLOCK_SECONDS:
		_open()


func _shoved_by(mover: Node3D) -> bool:
	# A shove is the throw flick aimed at the glass: pushed hard enough, and pointing at the case rather than away
	# from it, so walking off with the stick still pushed never breaks a case by accident.
	# The caller also checks it was a jab, not the tail of a lock-pick.
	if mover.stick.length() < Balance.THROW_FLICK_STICK:
		return false
	var toward := Vector2(global_position.x - mover.global_position.x, global_position.z - mover.global_position.z)
	if toward.length() < 0.01:
		return false
	return mover.stick.normalized().dot(toward.normalized()) > Balance.CASE_SMASH_AIM


func smash(slot: int) -> void:
	if not closed:
		return
	_release()
	glass.hide()
	Fx.burst(global_position + Vector3.UP * Balance.CASE_SIZE.y / 2.0, Fx.Kind.SHARDS, get_parent())
	Sfx.shatter(Balance.CASE_SMASH_SOUND_VALUE, 3)
	_popup("SMASH!", Balance.DAMAGE_COLOUR)
	var arena: Node = get_parent()
	if arena.has_method("raise_alarm"):
		arena.raise_alarm(Balance.CASE_SMASH_ENERGY, slot, Balance.ALARM_CASE)
	print("A display case was smashed")


func _open() -> void:
	_release()
	var lift := glass.create_tween()
	lift.tween_property(glass, "position:y", glass.position.y + Balance.CASE_SIZE.y, 0.5)
	lift.tween_callback(glass.hide)
	Sfx.play("creak", 1.6, Balance.CASE_CLICK_DB)
	_popup("UNLOCKED", Balance.MUSEUM_SIGN_COLOUR)
	print("A display case was unlocked")


func _release() -> void:
	closed = false
	progress = 0.0
	meter.visible = false
	body.queue_free()


func _popup(text: String, colour: Color) -> void:
	meter.text = text
	meter.modulate = colour
	meter.visible = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void: if is_instance_valid(meter): meter.visible = false)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	return mesh
