# Valuable carryable. Distinct physical impacts reduce its rupee value; releasing it in the truck banks it.
# Two-person items have a handle at each end: both held carries it, one held drags it and scrapes value off.
class_name Loot
extends Carryable

signal damaged(amount: int, remaining: int)
signal shattered(last_carrier_slot: int)

# --- Item settings ---
@export_enum("Vase", "TV", "Clock", "Piano") var loot_kind: int = 0
@export var catalog_item: CatalogItem # When set (the Mansion's pool), it replaces the kind's numbers and look.

# Set by the match flow; one mover alone drags two-person items faster.
static var lone_mover: bool = false

# --- Value and handle state ---
var value: int
var initial_value: int
var fragility: int
var handle_holders: Array[CharacterBody3D] = [null, null]
var touching_floor: bool = false
var scrape_distance: float = 0.0
var scrape_remainder: float = 0.0
var scrape_unshown: int = 0
var scrape_popup_time: float = 0.0
var price_label := Label3D.new()
var price_reveal: float = 0.0 # 0 hidden to 1 shown; fades with nearby movers and the ghost.
var curse_left: float = 0.0
var curse_targeted: bool = false
var body_material: StandardMaterial3D
var model: Node3D # A catalog item's model, when there is one.
var model_meshes: Array[MeshInstance3D] = []
var curse_overlay: StandardMaterial3D
var delivery_slots: Array[int] = [] # Last two-person team; retained while its last holder releases.

# --- Setup ---
func _ready() -> void:
	if catalog_item != null:
		item_name = catalog_item.display_name
		item_size = catalog_item.footprint
		weight_class = catalog_item.weight_class
		initial_value = catalog_item.value
		fragility = catalog_item.fragility
	else:
		item_name = Balance.LOOT_NAMES[loot_kind]
		item_size = Balance.LOOT_SIZES[loot_kind]
		weight_class = Balance.LOOT_WEIGHTS[loot_kind]
		initial_value = Balance.LOOT_VALUES[loot_kind]
		fragility = Balance.LOOT_FRAGILITIES[loot_kind]
	value = initial_value
	add_to_group("loot")
	super()
	_build_shape()
	_build_price_label()


# --- Feedback ---
func _process(delta: float) -> void:
	price_label.global_position = global_position + Vector3.UP * (item_size.y / 2.0 + Balance.PRICE_LABEL_HEIGHT)
	price_label.text = rupees(value)
	var shown: float = 1.0 if is_held() or _someone_near() else 0.0
	price_reveal = move_toward(price_reveal, shown, delta / Balance.PRICE_FADE_TIME)
	price_label.visible = price_reveal > 0.0
	price_label.modulate = Color.WHITE.lerp(Balance.DAMAGE_COLOUR, 1.0 - float(value) / initial_value)
	price_label.modulate.a = price_reveal * Balance.PRICE_OPACITY
	price_label.outline_modulate.a = price_reveal * Balance.PRICE_OPACITY
	if body_material != null:
		body_material.emission_enabled = curse_left > 0.0 or curse_targeted
		body_material.emission = Balance.CURSE_COLOUR
		body_material.albedo_color = Balance.CURSE_COLOUR if curse_left > 0.0 else Balance.LOOT_COLOURS[loot_kind]
	elif model != null:
		# A catalog model keeps its own colours; a curse glows over it.
		var cursed: bool = curse_left > 0.0 or curse_targeted
		for mesh: MeshInstance3D in model_meshes:
			mesh.material_overlay = curse_overlay if cursed else null


func _physics_process(delta: float) -> void:
	curse_left = maxf(0.0, curse_left - delta)
	if scrape_distance > 0.0:
		_apply_scrape()
	scrape_popup_time += delta
	if scrape_unshown > 0 and scrape_popup_time >= Balance.SCRAPE_POPUP_INTERVAL:
		show_popup("−" + rupees(scrape_unshown), Balance.DAMAGE_COLOUR)
		scrape_unshown = 0
		scrape_popup_time = 0.0


# --- Two-person physics ---
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	touching_floor = false
	super(state)
	if weight_class == Balance.TWO_PERSON and holder_count() == 1 and touching_floor:
		var horizontal := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
		scrape_distance += horizontal.length() * state.step


func _apply_carry(state: PhysicsDirectBodyState3D) -> void:
	if weight_class != Balance.TWO_PERSON:
		super(state)
		return

	var holders: int = holder_count()
	var speed_ratio: float = Balance.CARRY_SPEEDS[Balance.TWO_PERSON]
	if holders == 1:
		speed_ratio = Balance.LONE_DRAG_SPEED if lone_mover else Balance.DRAG_SPEED
	speed_ratio *= carry_speed_ratio()

	# Each held handle is pushed toward its holder's stick: the average moves the item, a difference turns it.
	for index: int in range(2):
		var mover: CharacterBody3D = handle_holders[index]
		if not is_instance_valid(mover):
			continue
		var offset: Vector3 = state.transform.basis * _handle_local(index)
		var handle_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(offset)
		var error: Vector3 = mover.carry_stick() * Balance.MOVER_SPEED * speed_ratio - handle_velocity
		error.y = 0.0
		var force: Vector3 = error * Balance.TEAM_DRIVE_GAIN * mass / 2.0
		state.apply_force(force.limit_length(Balance.TEAM_MAX_FORCE), offset)

	# Both handles lift it to carry height; one handle only takes most of the weight off the floor.
	var weight: Vector3 = -state.total_gravity * mass
	if holders == 2:
		var floor_y: float = (handle_holders[0].global_position.y + handle_holders[1].global_position.y) / 2.0 - Balance.CAPSULE_HEIGHT / 2.0
		var target_y: float = floor_y + Balance.CARRY_CLEARANCE + item_size.y / 2.0
		var lift: float = (target_y - state.transform.origin.y) * Balance.CARRY_STIFFNESS - state.linear_velocity.y * Balance.CARRY_DAMPING
		state.apply_central_force((weight + Vector3.UP * lift * mass).limit_length(Balance.TEAM_LIFT_MAX_FORCE))
	else:
		state.apply_central_force(weight * Balance.DRAG_SUPPORT)
	_apply_upright(state)


func _on_contact(normal: Vector3) -> void:
	if absf(normal.y) > Balance.FLOOR_NORMAL_MIN:
		touching_floor = true


# --- Grabbing, handles and banking ---
func carry_speed_ratio() -> float:
	return Balance.CURSE_CARRY_RATIO if curse_left > 0.0 else 1.0


func curse() -> void:
	curse_left = Balance.CURSE_DURATION
	print("Cursed %s for %.0f seconds" % [item_name, curse_left])


func holder_count() -> int:
	var count: int = 0
	for mover: CharacterBody3D in handle_holders:
		if is_instance_valid(mover):
			count += 1
	return count


func is_held() -> bool:
	if weight_class == Balance.TWO_PERSON:
		return holder_count() > 0
	return super()


func is_held_by(mover: CharacterBody3D) -> bool:
	if weight_class == Balance.TWO_PERSON:
		return mover in handle_holders
	return super(mover)


func grab_point_for(mover: CharacterBody3D) -> Vector3:
	if weight_class != Balance.TWO_PERSON:
		return super(mover)
	var index: int = _free_handle_nearest(mover.global_position)
	return Vector3.INF if index < 0 or haunted else handle_position(index)


func try_grab(mover: CharacterBody3D, target: Node3D, slot: int) -> bool:
	if weight_class != Balance.TWO_PERSON:
		return super(mover, target, slot)
	var index: int = _free_handle_nearest(mover.global_position)
	if finished or haunted or index < 0:
		return false
	handle_holders[index] = mover
	if holder_count() == 1:
		delivery_slots = [slot]
	else:
		delivery_slots.clear()
		for carrier: CharacterBody3D in handle_holders:
			if is_instance_valid(carrier):
				delivery_slots.append(carrier.slot)
	last_carrier_slot = slot
	add_collision_exception_with(mover)
	can_sleep = false
	sleeping = false
	print("Player %d grabbed a %s handle" % [slot + 1, item_name])
	return true


func release(throw_velocity: Vector3 = Vector3.ZERO, by: CharacterBody3D = null) -> void:
	if weight_class != Balance.TWO_PERSON:
		super(throw_velocity, by)
		return
	if finished:
		return
	# Two-person items cannot be thrown; they bank once the last hand lets go inside the truck.
	for index: int in range(2):
		var mover: CharacterBody3D = handle_holders[index]
		if is_instance_valid(mover) and (by == null or mover == by):
			remove_collision_exception_with(mover)
			handle_holders[index] = null
	if holder_count() == 0:
		can_sleep = true
		_on_released()


func handle_position(index: int) -> Vector3:
	return global_transform * _handle_local(index)


func stand_point_for(mover: CharacterBody3D) -> Vector3:
	# Where a handle's holder stands: just beyond the end of the item.
	var index: int = handle_holders.find(mover)
	var handle: Vector3 = handle_position(index)
	var outward: Vector3 = handle - global_position
	outward.y = 0.0
	return handle + outward.normalized() * Balance.TEAM_STAND_DISTANCE


func _handle_local(index: int) -> Vector3:
	return Vector3((item_size.x / 2.0) * (-1.0 if index == 0 else 1.0), 0.0, 0.0)


func _free_handle_nearest(point: Vector3) -> int:
	var best: int = -1
	var best_distance: float = INF
	for index: int in range(2):
		if is_instance_valid(handle_holders[index]):
			continue
		var distance: float = handle_position(index).distance_to(point)
		if distance < best_distance:
			best = index
			best_distance = distance
	return best


func _on_released() -> bool:
	for zone: Node in get_tree().get_nodes_in_group("truck_zones"):
		if zone.try_bank(self):
			return true
	print("Released %s at %s" % [item_name, rupees(value)])
	return false


func _detach() -> void:
	super()
	for index: int in range(2):
		if is_instance_valid(handle_holders[index]):
			remove_collision_exception_with(handle_holders[index])
		handle_holders[index] = null


# --- Damage ---
func _on_impact(speed: float) -> void:
	apply_impact(speed)


func apply_impact(speed: float) -> void:
	if finished or speed <= Balance.DAMAGE_SPEED_THRESHOLD:
		return
	var loss: int = mini(value, ceili(speed * fragility * Balance.DAMAGE_MULTIPLIER * value))
	show_popup("−" + rupees(loss), Balance.DAMAGE_COLOUR)
	print("%s impact %.2f m/s: -₹%d, remaining ₹%d" % [item_name, speed, loss, value - loss])
	_lose_value(loss)


func _apply_scrape() -> void:
	# Scraping takes a share of the current value per metre; keep the fraction for next time.
	var exact_loss: float = value * Balance.SCRAPE_RATE * scrape_distance + scrape_remainder
	scrape_distance = 0.0
	var loss: int = mini(value, floori(exact_loss))
	scrape_remainder = exact_loss - loss
	if loss > 0:
		scrape_unshown += loss
		_lose_value(loss)


func _lose_value(loss: int) -> void:
	value -= loss
	damaged.emit(loss, value)
	if is_held():
		var player := Net.player_for_slot(last_carrier_slot)
		if not player.is_empty():
			Net.send_to_player(player, {"type": "buzz", "ms": Balance.DAMAGE_BUZZ_MS})
	if value == 0:
		shattered.emit(last_carrier_slot)
		retire("SHATTERED", Balance.DAMAGE_COLOUR)


func retire(message: String, colour: Color) -> void:
	if finished:
		return
	finished = true
	_detach()
	show_popup(message, colour)
	remove_from_group("loot")
	remove_from_group("carryables")
	hide()
	queue_free()


# --- Visual helpers ---
func show_popup(message: String, colour: Color) -> void:
	var popup := Label3D.new()
	popup.text = message
	popup.modulate = colour
	popup.font_size = Balance.PRICE_FONT_SIZE
	popup.pixel_size = Balance.VALUE_POPUP_PIXEL_SIZE
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	get_parent().add_child(popup)
	popup.global_position = price_label.global_position + Vector3.UP * Balance.VALUE_POPUP_START
	var tween := popup.create_tween().set_parallel()
	tween.tween_property(popup, "position:y", popup.position.y + Balance.VALUE_POPUP_RISE, Balance.VALUE_POPUP_LIFETIME)
	tween.tween_property(popup, "modulate:a", 0.0, Balance.VALUE_POPUP_LIFETIME)
	tween.chain().tween_callback(popup.queue_free)


static func rupees(amount: int) -> String:
	# Indian digit grouping, as in the spec: ₹1,200 and ₹1,20,000.
	var digits: String = str(amount)
	var grouped: String = digits.right(3)
	digits = digits.left(-3)
	while not digits.is_empty():
		grouped = digits.right(2) + "," + grouped
		digits = digits.left(-2)
	return "₹" + grouped


func _build_shape() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = item_size
	collision.shape = shape
	add_child(collision)
	if catalog_item != null:
		model = catalog_item.model.instantiate()
		model.position.y = -item_size.y / 2.0 # Models are bottom-centred; the body's origin is its centre.
		model.scale = Vector3.ONE * catalog_item.model_scale
		add_child(model)
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			model_meshes.append(mesh)
		curse_overlay = StandardMaterial3D.new()
		curse_overlay.albedo_color = Color(Balance.CURSE_COLOUR, 0.55)
		curse_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		curse_overlay.emission_enabled = true
		curse_overlay.emission = Balance.CURSE_COLOUR
		return
	var mesh := MeshInstance3D.new()
	if loot_kind == 0:
		var vase := CylinderMesh.new()
		vase.height = item_size.y
		vase.top_radius = item_size.x / 4.0
		vase.bottom_radius = item_size.x / 2.0
		mesh.mesh = vase
	else:
		var box := BoxMesh.new()
		box.size = item_size
		mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Balance.LOOT_COLOURS[loot_kind]
	body_material = material
	mesh.material_override = material
	add_child(mesh)


func _build_price_label() -> void:
	price_label.font_size = Balance.PRICE_FONT_SIZE
	price_label.pixel_size = Balance.PRICE_PIXEL_SIZE
	price_label.outline_size = Balance.PRICE_OUTLINE_SIZE
	price_label.visible = false
	price_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	price_label.no_depth_test = true # Walls never hide a price.
	add_child(price_label)
	price_label.top_level = true


func _someone_near() -> bool:
	# Movers and the ghost reveal prices around them; the rest of the house stays clean.
	var tree := get_tree()
	for player: Node3D in tree.get_nodes_in_group("movers") + tree.get_nodes_in_group("ghosts"):
		if player.global_position.distance_to(global_position) <= Balance.PRICE_SHOW_DISTANCE:
			return true
	return false
