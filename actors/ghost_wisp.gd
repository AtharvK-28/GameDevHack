# The ghost player: a faint wisp that flies through walls, possesses props and triggers hauntings.
# Every ghost button is checked here against energy, cooldowns and the possession rules; refused presses cost nothing.
extends Node3D

signal exorcised(slot: int)

# --- Ghost state ---
var slot: int = 0
var signature_haunting: Script = HouseShake # The arena's own haunting, on haunt1; Ecto Slime is always haunt2.
var energy: float = Balance.ENERGY_MAX
var stick := Vector2.ZERO # This frame's input; zero while frozen.
var possessing: Possessable
var target: Possessable # The prop POSSESS would take, shown with a bright outline.
var freeze_left: float = 0.0
var lockout_left: float = 0.0
var hauntings: Array[Haunting] = []
var shimmer_time: float = 0.0
var body_mesh := MeshInstance3D.new()
var material := StandardMaterial3D.new()
var demo_rules: bool = false # Archived harnesses retain all five furniture actions and slime.
var mover_count: int = 1
var opening_left: float = 0.0
var shared_lock_left: float = 0.0
var curse_cooldown_left: float = 0.0
var curse_target: Loot

# --- Setup ---
func _ready() -> void:
	add_to_group("ghosts")
	if demo_rules:
		opening_left = Balance.HAUNT_OPENING_GRACE
	for script: Script in [signature_haunting, EctoSlime]:
		var haunting: Haunting = script.new()
		hauntings.append(haunting)
		add_child(haunting)
	_build_body()


func _exit_tree() -> void:
	if is_instance_valid(curse_target):
		curse_target.curse_targeted = false
	# Leaving play when the role passes on hands any possessed prop back.
	if is_instance_valid(possessing):
		possessing.release()
	possessing = null
	if is_instance_valid(target):
		target.set_highlighted(false)
	target = null


# --- Controls ---
func _physics_process(delta: float) -> void:
	opening_left = maxf(0.0, opening_left - delta)
	shared_lock_left = maxf(0.0, shared_lock_left - delta)
	curse_cooldown_left = maxf(0.0, curse_cooldown_left - delta)
	var input: InputRouter.PlayerInput = InputRouter.for_slot(slot)
	freeze_left = maxf(0.0, freeze_left - delta)
	lockout_left = maxf(0.0, lockout_left - delta)
	if possessing != null and not is_instance_valid(possessing):
		possessing = null # The prop left play without telling us.
		body_mesh.show()
	stick = Vector2.ZERO if is_frozen() else input.direction
	if not is_frozen():
		if input.pressed.get("possess", false):
			_toggle_possession()
		if input.pressed.get("action", false):
			_try_action()
		for index: int in range(hauntings.size()):
			if input.pressed.get("haunt%d" % (index + 1), false):
				_try_haunting(index)
		if input.pressed.get("haunt3", false):
			_try_curse()
	_update_energy(delta)
	if is_instance_valid(possessing):
		possessing.drive(stick, delta)
		var at: Vector3 = possessing.global_position
		global_position = Vector3(at.x, Balance.WISP_HEIGHT, at.z)
	else:
		position += Vector3(stick.x, 0.0, stick.y) * Balance.WISP_SPEED * delta
		_clamp_to_bounds()
	_update_target()
	_update_curse_target()


func is_frozen() -> bool:
	return freeze_left > 0.0


func _update_energy(delta: float) -> void:
	if is_instance_valid(possessing):
		energy = maxf(0.0, energy - Balance.POSSESS_DRAIN * delta)
		if energy <= 0.0:
			print("Ghost ran out of energy")
			leave()
	else:
		var regen: float = Balance.MATCH_ENERGY_REGEN[clampi(mover_count - 1, 0, 2)] if demo_rules else Balance.ENERGY_REGEN
		energy = minf(Balance.ENERGY_MAX, energy + regen * delta)


# --- Possession ---
func can_toggle_possession() -> bool:
	if is_frozen():
		return false
	if is_instance_valid(possessing):
		return true # Leaving is always free.
	return lockout_left <= 0.0 and energy > 0.0 and is_instance_valid(target) and target.can_be_possessed()


func _toggle_possession() -> void:
	if not can_toggle_possession():
		return
	if is_instance_valid(possessing):
		leave()
	else:
		possess(target)


func possess(prop: Possessable) -> void:
	if is_instance_valid(target):
		target.set_highlighted(false)
	target = null
	possessing = prop
	prop.possess(self)
	body_mesh.hide()


func leave() -> void:
	if not is_instance_valid(possessing):
		possessing = null
		return
	var at: Vector3 = possessing.global_position
	possessing.release()
	possessing = null
	position = Vector3(at.x, Balance.WISP_HEIGHT, at.z)
	_clamp_to_bounds()
	body_mesh.show()


func exorcised_from(prop: Possessable) -> void:
	if prop != possessing:
		return
	leave()
	freeze_left = Balance.EXORCISE_FREEZE
	lockout_left = Balance.POSSESS_LOCKOUT
	print("Ghost exorcised: frozen for %.0f s, no possessing for %.0f s" % [Balance.EXORCISE_FREEZE, Balance.POSSESS_LOCKOUT])
	exorcised.emit(slot)


func _update_target() -> void:
	# The nearest prop in reach that the rules allow; none while possessing, frozen or locked out.
	var best: Possessable = null
	if not is_instance_valid(possessing) and not is_frozen() and lockout_left <= 0.0:
		var best_distance: float = Balance.POSSESS_RANGE
		for node: Node in get_tree().get_nodes_in_group("possessables"):
			if node is Possessable and node.can_be_possessed():
				if demo_rules and node.kind != Possessable.Kind.SLIDER:
					continue
				var distance: float = node.reach_distance(global_position)
				if distance <= best_distance:
					best = node
					best_distance = distance
	if best == target:
		return
	if is_instance_valid(target):
		target.set_highlighted(false)
	target = best
	if best != null:
		best.set_highlighted(true)


# --- ACTION and hauntings ---
func can_act() -> bool:
	return not is_frozen() and is_instance_valid(possessing) and possessing.can_act() and energy >= possessing.action_cost()


func _try_action() -> void:
	if not can_act():
		return
	energy -= possessing.action_cost()
	possessing.act(stick)


func can_haunt(index: int) -> bool:
	if demo_rules and (index != 0 or opening_left > 0.0 or shared_lock_left > 0.0):
		return false
	var haunting: Haunting = hauntings[index]
	return not is_frozen() and haunting.can_trigger() and energy >= haunting.cost


func _try_haunting(index: int) -> void:
	if not can_haunt(index):
		return
	energy -= hauntings[index].cost
	hauntings[index].trigger(self)
	if demo_rules:
		shared_lock_left = Balance.HAUNT_SHARED_LOCK


# --- Temporary heavy-item Curse ---
func _update_curse_target() -> void:
	var best: Loot = null
	var nearest: float = Balance.POSSESS_RANGE
	if demo_rules and not is_instance_valid(possessing) and not is_frozen():
		for node: Node in get_tree().get_nodes_in_group("possessables"):
			if not node is Possessable or not node.prop is Loot:
				continue
			var item: Loot = node.prop
			if item.finished or item.curse_left > 0.0 or node._in_truck():
				continue
			var distance: float = node.reach_distance(global_position)
			if distance <= nearest:
				nearest = distance
				best = item
	if is_instance_valid(curse_target):
		curse_target.curse_targeted = false
	curse_target = best
	if best != null:
		best.curse_targeted = true


func can_curse() -> bool:
	return demo_rules and not is_frozen() and not is_instance_valid(possessing) and opening_left <= 0.0 and shared_lock_left <= 0.0 and curse_cooldown_left <= 0.0 and energy >= Balance.CURSE_COST and is_instance_valid(curse_target) and not curse_target.finished and curse_target.curse_left <= 0.0


func _try_curse() -> void:
	if not can_curse():
		return
	energy -= Balance.CURSE_COST
	curse_target.curse()
	curse_cooldown_left = Balance.CURSE_COOLDOWN
	shared_lock_left = Balance.HAUNT_SHARED_LOCK
	_update_curse_target()


# --- Phone feedback ---
func hud() -> Dictionary:
	# What the ghost's phone shows; ok mirrors the checks above, so greying matches what the host accepts.
	var label: String = ""
	var cost: int = 0
	if is_instance_valid(possessing):
		label = possessing.action_label()
		cost = possessing.action_cost()
	var message: Dictionary = {
		"type": "hud", "energy": floori(energy), "action": label,
		"costs": {"action": cost, "haunt1": hauntings[0].cost, "haunt2": hauntings[1].cost},
		"cd": {
			"possess": snappedf(lockout_left / Balance.POSSESS_LOCKOUT, 0.01),
			"haunt1": snappedf(hauntings[0].cooldown_fraction(), 0.01),
			"haunt2": snappedf(hauntings[1].cooldown_fraction(), 0.01),
		},
		"ok": {"possess": can_toggle_possession(), "action": can_act(), "haunt1": can_haunt(0), "haunt2": can_haunt(1)},
		"t": 0,
	}
	message.costs.haunt3 = Balance.CURSE_COST
	message.cd.haunt3 = curse_cooldown_left / Balance.CURSE_COOLDOWN
	message.ok.haunt3 = can_curse()
	message.simple = demo_rules
	message.target = curse_target.item_name if is_instance_valid(curse_target) else ""
	message.seconds = {"opening": ceilf(opening_left), "shared": ceilf(shared_lock_left), "possess": ceilf(lockout_left), "haunt1": ceilf(hauntings[0].cooldown_left), "haunt3": ceilf(curse_cooldown_left)}
	message.reasons = {}
	for button: String in ["possess", "action", "haunt1", "haunt3"]:
		message.reasons[button] = _button_reason(button)
	return message


func _button_reason(button: String) -> String:
	if is_frozen():
		return "Exorcised: %ds" % ceili(freeze_left)
	if button == "possess":
		if is_instance_valid(possessing):
			return "Leave for free"
		if lockout_left > 0.0:
			return "Exorcised: %ds" % ceili(lockout_left)
		return "Ready" if can_toggle_possession() else "Move near a loose prop"
	if button == "action":
		if not is_instance_valid(possessing):
			return "Possess a prop first"
		if energy < possessing.action_cost():
			return "Need %d energy" % possessing.action_cost()
		return "Ready" if can_act() else "Action recovering"
	if demo_rules and opening_left > 0.0:
		return "Opening protection: %ds" % ceili(opening_left)
	if demo_rules and shared_lock_left > 0.0:
		return "Haunting lock: %ds" % ceili(shared_lock_left)
	var cooldown: float = curse_cooldown_left if button == "haunt3" else hauntings[0].cooldown_left
	if cooldown > 0.0:
		return "Cooldown: %ds" % ceili(cooldown)
	if button == "haunt3" and is_instance_valid(possessing):
		return "Leave prop first"
	var required: int = Balance.CURSE_COST if button == "haunt3" else hauntings[0].cost
	if energy < required:
		return "Need %d energy" % required
	if button == "haunt3" and not is_instance_valid(curse_target):
		return "Move near uncursed loot"
	return "Ready"


# --- Visual helpers ---
func _process(delta: float) -> void:
	# Hard to see but not invisible: a pale shimmer that bobs gently.
	shimmer_time += delta
	var wave: float = sin(TAU * Balance.WISP_SHIMMER_RATE * shimmer_time)
	var colour: Color = Balance.WISP_FROZEN_COLOUR if is_frozen() else Balance.WISP_COLOUR
	material.albedo_color = Color(colour, lerpf(Balance.WISP_ALPHA_MIN, Balance.WISP_ALPHA_MAX, 0.5 + 0.5 * wave))
	body_mesh.position.y = wave * Balance.WISP_BOB_HEIGHT


func _clamp_to_bounds() -> void:
	var bounds: Rect2 = Balance.GHOST_BOUNDS
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)


func _build_body() -> void:
	var egg := SphereMesh.new()
	egg.radius = Balance.WISP_RADIUS
	egg.height = Balance.WISP_BODY_HEIGHT
	body_mesh.mesh = egg
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mesh.material_override = material
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # A shadow would give the wisp away.
	add_child(body_mesh)
