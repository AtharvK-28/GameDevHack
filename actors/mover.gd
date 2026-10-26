# Moves a player and owns one grab at a time; the carried item applies its own spring.
# On a two-person handle the mover follows its handle and its stick steers the item instead.
# A tumble drops whatever is held and lies the mover down for TUMBLE_DURATION seconds. On slime the mover keeps
# its momentum. While its player is the ghost, the mover is out of play. The character model (MoverModel) only
# shows this state: every frame it is told the speed, what is held and whether the mover braces or slides.
# Walking eases in and out (MOVER_ACCELERATION / MOVER_DECELERATION) and the stick has a response curve, so small
# tilts walk gently. Goofy physics: movers that walk into each other are shoved apart a little, without falling.
extends CharacterBody3D

signal tumbled(slot: int)

# --- Player state ---
var slot: int = 0
var facing := Vector3.FORWARD
var stick := Vector2.ZERO # This frame's movement input; zero while bracing or down.
var bracing: bool = false
var in_play: bool = true
var held_item: Carryable
var grab_released: bool = true
var tumble_time_left: float = 0.0
var name_label := Label3D.new()
var shout_left: float = 0.0 # Cooldown before the next shout.
var hold_point: Marker3D
var model: MoverModel
var shove := Vector3.ZERO # Fading push from bumping into another mover.
var bump_cooldown: float = 0.0
var last_velocity := Vector3.ZERO
var bounds := Rect2(-Balance.FLOOR_SIZE / 2.0, -Balance.FLOOR_SIZE / 2.0, Balance.FLOOR_SIZE, Balance.FLOOR_SIZE) # Set from the arena.

# --- Setup ---
func _ready() -> void:
	add_to_group("movers")
	collision_layer = Balance.MOVER_LAYER
	collision_mask = Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER
	hold_point = $HoldPoint
	_build_collider()
	_build_model()
	name_label.position.y = Balance.LABEL_HEIGHT
	name_label.font_size = Balance.LABEL_FONT_SIZE
	name_label.pixel_size = Balance.LABEL_PIXEL_SIZE
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.modulate = Color(Balance.PLAYER_COLOURS[slot]) # The player's colour with an ink outline.
	name_label.outline_size = Balance.LABEL_OUTLINE
	name_label.outline_modulate = Balance.COMIC_INK
	add_child(name_label)
	_update_hold_point()


func _label_stack() -> int:
	# Movers standing close together stack their name tags upward in slot order, so the tags never overlap.
	var below: int = 0
	for other: Node3D in get_tree().get_nodes_in_group("movers"):
		if other != self and other.visible and other.slot < slot:
			var gap := Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z)
			if gap.length() < Balance.LABEL_SPREAD_DISTANCE:
				below += 1
	return below


# --- Movement and controls ---
func _physics_process(delta: float) -> void:
	shout_left = maxf(0.0, shout_left - delta)
	var player_input: InputRouter.PlayerInput = InputRouter.for_slot(slot)
	if is_instance_valid(held_item) and (held_item.finished or not held_item.is_held_by(self)):
		held_item = null

	stick = player_input.direction
	bracing = player_input.buttons.get("brace", false)
	if bracing or is_tumbling():
		stick = Vector2.ZERO
	if is_tumbling():
		tumble_time_left -= delta
		if not is_tumbling():
			model.squish(Balance.SQUASH_GET_UP)
		if not player_input.buttons.get("grab", false):
			grab_released = true # Letting go while down allows a fresh grab after standing.
	else:
		_handle_carry_input(player_input)

	if _on_team_handle():
		_follow_handle()
	else:
		_turn_toward_stick(delta)
		_walk(delta)
	_apply_arena_wind()
	_update_hold_point()
	if not is_on_floor():
		velocity.y -= Balance.GRAVITY * delta
	var was_airborne: bool = not is_on_floor()
	var fall_speed: float = -velocity.y
	var before_slide: Vector3 = velocity
	move_and_slide()
	if was_airborne and is_on_floor():
		model.squish(Balance.SQUASH_LAND * clampf(fall_speed / Balance.LAND_SQUASH_SPEED, 0.0, 1.0))
		if fall_speed > Balance.FX_LAND_SPEED:
			Fx.burst(_feet(), Fx.Kind.DUST, get_parent())
	_check_bumps(before_slide, delta)

	position.x = clampf(position.x, bounds.position.x + Balance.CAPSULE_RADIUS, bounds.end.x - Balance.CAPSULE_RADIUS)
	position.z = clampf(position.z, bounds.position.y + Balance.CAPSULE_RADIUS, bounds.end.y - Balance.CAPSULE_RADIUS)
	var player := Net.player_for_slot(slot)
	var full_name: String = player.get("name", "Unclaimed")
	name_label.text = full_name if full_name.length() <= Balance.NAME_MAX_CHARS else full_name.left(Balance.NAME_MAX_CHARS - 1) + "…"
	name_label.position.y = Balance.LABEL_HEIGHT + _label_stack() * Balance.LABEL_STACK_STEP
	_update_model(delta)


func movement_speed() -> float:
	if is_instance_valid(held_item):
		return Balance.MOVER_SPEED * Balance.CARRY_SPEEDS[held_item.weight_class] * held_item.carry_speed_ratio()
	return Balance.MOVER_SPEED


func carry_stick() -> Vector3:
	# The stick as a world direction; two-person items read this to steer.
	return Vector3(stick.x, 0.0, stick.y)


func _walk(delta: float) -> void:
	var target: Vector3 = _shaped_stick() * movement_speed()
	if on_slime():
		# Slime keeps the mover's momentum: the stick only nudges the slide.
		var grip: float = 1.0 - exp(-Balance.SLIME_GRIP * delta)
		velocity.x = lerpf(velocity.x, target.x, grip)
		velocity.z = lerpf(velocity.z, target.z, grip)
	else:
		# Ease toward the target speed; stopping and reversing are quicker than speeding up.
		var current := Vector2(velocity.x, velocity.z) - Vector2(shove.x, shove.z)
		var wanted := Vector2(target.x, target.z)
		var speeding_up: bool = wanted.length() > current.length() and wanted.dot(current) >= 0.0
		var rate: float = Balance.MOVER_ACCELERATION if speeding_up else Balance.MOVER_DECELERATION
		current = current.move_toward(wanted, rate * delta)
		if bracing:
			current = Vector2.ZERO # Bracing plants the feet at once.
		velocity.x = current.x + shove.x
		velocity.z = current.y + shove.z


func _shaped_stick() -> Vector3:
	# The response curve: direction unchanged, magnitude raised to STICK_RESPONSE_EXPONENT.
	var tilt: float = minf(stick.length(), 1.0)
	if tilt < 0.001:
		return Vector3.ZERO
	var direction: Vector3 = carry_stick() / stick.length()
	return direction * pow(tilt, Balance.STICK_RESPONSE_EXPONENT)


func on_slime() -> bool:
	for patch: Node3D in get_tree().get_nodes_in_group("slime"):
		var offset: Vector3 = patch.global_position - global_position
		if Vector2(offset.x, offset.z).length() < Balance.SLIME_PATCH_RADIUS:
			return true
	return false


# --- House Shake queries ---
func is_bracing() -> bool:
	return bracing


func is_moving() -> bool:
	# Pushing the stick, or sliding: on slime, or pulled along by a two-person handle.
	return not stick.is_zero_approx() or Vector2(velocity.x, velocity.z).length() > Balance.SHAKE_MOVING_SPEED


# --- The ghost's slot ---
func set_in_play(active: bool) -> void:
	# While this player is the ghost, the mover leaves the board: no collisions, input, hauntings or tumbles.
	if not active:
		_let_go()
		tumble_time_left = 0.0
		model.reset()
		remove_from_group("movers")
	else:
		add_to_group("movers")
	in_play = active
	visible = active
	velocity = Vector3.ZERO
	shove = Vector3.ZERO
	stick = Vector2.ZERO
	bracing = false
	collision_layer = Balance.MOVER_LAYER if active else 0
	collision_mask = (Balance.WORLD_LAYER | Balance.MOVER_LAYER | Balance.LOOT_LAYER) if active else 0
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func reset_for_round(location: Vector3, playing: bool) -> void:
	# Hands empty, standing up, facing the house, at a fresh spot; out of play if this player is not a mover.
	set_in_play(false)
	position = location
	facing = Vector3.FORWARD
	grab_released = true
	_update_hold_point()
	if playing:
		set_in_play(true)


func _turn_toward_stick(delta: float) -> void:
	if stick.is_zero_approx():
		return
	# Swing the facing round instead of snapping, so a carried item is never yanked across.
	var current_angle: float = atan2(facing.x, facing.z)
	var target_angle: float = atan2(stick.x, stick.y)
	var angle: float = rotate_toward(current_angle, target_angle, Balance.TURN_SPEED * delta)
	facing = Vector3(sin(angle), 0.0, cos(angle))


func _handle_carry_input(input: InputRouter.PlayerInput) -> void:
	var grabbing: bool = input.buttons.get("grab", false)
	if not grabbing:
		grab_released = true
		_let_go()
		return
	if input.pressed.get("throw", false) and is_instance_valid(held_item):
		if held_item.can_throw():
			held_item.release(facing * Balance.THROW_SPEED + Vector3.UP * Balance.THROW_LIFT, self)
			held_item = null
			model.play_throw()
			model.squish(Balance.SQUASH_THROW)
			Sfx.varied("whoosh", Balance.SFX_WHOOSH_DB)
			grab_released = false # Holding GRAB must not catch the item just thrown.
		return
	if not is_instance_valid(held_item) and grab_released:
		var candidate := _nearest_carryable()
		if candidate != null and candidate.try_grab(self, hold_point, slot):
			held_item = candidate
			model.play_grab()
			Sfx.varied("grab", Balance.SFX_GRAB_DB)
			model.squish(Balance.SQUASH_GRAB)


func _let_go() -> void:
	if is_instance_valid(held_item):
		var item: Carryable = held_item
		item.release(Vector3.ZERO, self)
		if item.finished:
			model.play_bank() # Let go in the truck: it banked.
	held_item = null


# --- Two-person handles ---
func _on_team_handle() -> bool:
	return is_instance_valid(held_item) and held_item.weight_class == Balance.TWO_PERSON


func _follow_handle() -> void:
	# Keep to our spot at the handle; let go if the item drags us too far off it.
	var gap: Vector3 = held_item.stand_point_for(self) - global_position
	gap.y = 0.0
	if gap.length() > Balance.TEAM_LEASH:
		print("Player %d lost their grip on the %s" % [slot + 1, held_item.item_name])
		_let_go()
		grab_released = false
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var follow: Vector3 = (gap * Balance.TEAM_FOLLOW_GAIN).limit_length(Balance.MOVER_SPEED)
	velocity.x = follow.x
	velocity.z = follow.z
	var to_item: Vector3 = held_item.global_position - global_position
	to_item.y = 0.0
	if to_item.length() > 0.01:
		facing = to_item.normalized()


# --- Tumbling ---
func is_tumbling() -> bool:
	return tumble_time_left > 0.0


func _feet() -> Vector3:
	return global_position + Vector3.DOWN * Balance.CAPSULE_HEIGHT / 2.0


func tumble(_push: Vector3 = Vector3.ZERO) -> void:
	# Drop whatever we hold and lie still for TUMBLE_DURATION; the model falls and gets up in that time.
	if is_tumbling():
		return
	_let_go()
	grab_released = false # Getting up must not instantly re-grab.
	tumble_time_left = Balance.TUMBLE_DURATION
	velocity = Vector3.ZERO
	shove = Vector3.ZERO
	model.play_tumble(Balance.TUMBLE_DURATION)
	Fx.burst(_feet(), Fx.Kind.DUST, get_parent(), 1.8)
	Sfx.varied("boing", Balance.SFX_BOING_DB)
	tumbled.emit(slot)
	var player := Net.player_for_slot(slot)
	if not player.is_empty():
		Net.send_to_player(player, {"type": "buzz", "ms": Balance.TUMBLE_BUZZ_MS})
	print("Player %d tumbled" % (slot + 1))



func wash(direction: Vector3, distance: float) -> void:
	# A wave knocks the mover down and carries them this far sideways; the shove decays, so this speed travels it.
	tumble(direction)
	shove = direction.normalized() * distance * Balance.BUMP_SHOVE_DECAY
	velocity.x = shove.x # Walking speed stays zero, so the whole push carries the mover.
	velocity.z = shove.z



# --- Shouts ---
func shout(words: String) -> bool:
	# Pops the words over this mover's head in comic lettering, unless they shouted a moment ago.
	if shout_left > 0.0 or not in_play:
		return false
	shout_left = Balance.SHOUT_COOLDOWN
	var bubble := Label3D.new()
	bubble.text = words
	bubble.font = load(Balance.COMIC_FONT_PATH)
	bubble.font_size = Balance.PRICE_FONT_SIZE
	bubble.pixel_size = Balance.SHOUT_PIXEL_SIZE
	bubble.modulate = Color.WHITE
	bubble.outline_size = Balance.VALUE_POPUP_OUTLINE
	bubble.outline_modulate = Color(Balance.PLAYER_COLOURS[slot]).darkened(0.55) # Tinted toward who shouted.
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.position.y = name_label.position.y + Balance.SHOUT_HEIGHT
	bubble.scale = Vector3.ONE * Balance.VALUE_POPUP_PUNCH
	add_child(bubble)
	var punch := bubble.create_tween()
	punch.tween_property(bubble, "scale", Vector3.ONE, Balance.VALUE_POPUP_PUNCH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade := bubble.create_tween()
	fade.tween_interval(Balance.SHOUT_LIFETIME * 0.6)
	fade.tween_property(bubble, "modulate:a", 0.0, Balance.SHOUT_LIFETIME * 0.4)
	fade.tween_callback(bubble.queue_free)
	Sfx.play("grab", 1.4, -8.0) # A small chirp so heads turn.
	return true


# --- Bumping (goofy physics) ---
func _check_bumps(before_slide: Vector3, delta: float) -> void:
	# Walking into another mover shoves both apart a little and squashes them; nobody falls over.
	bump_cooldown = maxf(0.0, bump_cooldown - delta)
	shove *= exp(-Balance.BUMP_SHOVE_DECAY * delta)
	if bump_cooldown > 0.0 or is_tumbling() or _on_team_handle():
		return
	for index: int in range(get_slide_collision_count()):
		var other: Object = get_slide_collision(index).get_collider()
		if not (other is CharacterBody3D and other.is_in_group("movers")) or other.is_tumbling() or other.bump_cooldown > 0.0:
			continue
		var apart: Vector3 = global_position - other.global_position
		apart.y = 0.0
		if apart.length() < 0.01:
			continue
		apart = apart.normalized()
		var closing: float = (other.velocity - before_slide).dot(apart)
		if closing < Balance.BUMP_MIN_SPEED:
			continue
		receive_bump(apart)
		other.receive_bump(-apart)
		return


func receive_bump(direction: Vector3) -> void:
	shove = direction * Balance.BUMP_SHOVE * Balance.GOOFINESS
	bump_cooldown = Balance.BUMP_COOLDOWN
	model.squish(Balance.SQUASH_BUMP)


# --- Grab selection ---
func _nearest_carryable() -> Carryable:
	var nearest: Carryable
	var nearest_distance: float = Balance.GRAB_RANGE
	for item: Carryable in get_tree().get_nodes_in_group("carryables"):
		var point: Vector3 = item.grab_point_for(self)
		if point == Vector3.INF:
			continue
		var offset: Vector3 = point - global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance: float = offset.length()
		if distance > nearest_distance or horizontal.normalized().dot(facing) < cos(deg_to_rad(Balance.GRAB_HALF_ANGLE)):
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position, point, Balance.WORLD_LAYER)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		nearest = item
		nearest_distance = distance
	return nearest


func _update_hold_point() -> void:
	# The hold point marks the bottom of the carried item, a fixed gap above the floor.
	var clearance: float = Balance.CARRY_CLEARANCE - Balance.CAPSULE_HEIGHT / 2.0
	hold_point.position = facing * Balance.HOLD_DISTANCE + Vector3.UP * clearance


# --- Model ---
func _update_model(delta: float) -> void:
	model.carry_reach.item = held_item if is_instance_valid(held_item) else null
	model.face(facing)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	model.update_wobble((flat - last_velocity) / delta, delta)
	last_velocity = flat
	model.update_locomotion(Vector2(velocity.x, velocity.z).length(), _carry_pose(), bracing, on_slime() and is_moving())


func _carry_pose() -> MoverModel.Carry:
	if not is_instance_valid(held_item):
		return MoverModel.Carry.NONE
	if held_item.weight_class == Balance.TWO_PERSON:
		return MoverModel.Carry.TEAM if held_item.holder_count() == 2 else MoverModel.Carry.DRAG
	# A cursed item looks one weight class heavier (decision 52); its speed is unchanged by this.
	var weight: int = held_item.weight_class
	if held_item is Loot and held_item.curse_left > 0.0:
		weight = mini(weight + 1, Balance.HEAVY)
	var poses: Array[MoverModel.Carry] = [MoverModel.Carry.LIGHT, MoverModel.Carry.MEDIUM, MoverModel.Carry.HEAVY]
	return poses[weight]


# --- Setup helpers ---
func _build_collider() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = Balance.CAPSULE_RADIUS
	shape.height = Balance.CAPSULE_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func _build_model() -> void:
	# Feet at the capsule's base, scaled to the capsule, in this slot's shirt and overall colours.
	model = $Model
	model.position.y = -Balance.CAPSULE_HEIGHT / 2.0
	model.scale = Vector3.ONE * Balance.MOVER_MODEL_SCALE
	var scene: PackedScene = load(Balance.MOVER_MODEL_PATH % Balance.MOVER_SHIRTS[slot])
	model.setup(scene, Color(Balance.PLAYER_COLOURS[slot]))


# --- Ship wind ---
func _apply_arena_wind() -> void:
	var world: Node = get_parent()
	var arena: Node = world.get("arena")
	if arena == null or arena.get("wind_active") != true or bracing:
		return
	var direction: Vector3 = arena.wind_direction
	var walking := Vector3(stick.x, 0.0, stick.y)
	if walking.dot(direction) > Balance.SHIP_GUST_WITH_DOT:
		tumble(direction)
	elif walking.is_zero_approx():
		velocity.x = direction.x * Balance.SHIP_GUST_PUSH_SPEED
		velocity.z = direction.z * Balance.SHIP_GUST_PUSH_SPEED
