# Weather and reactions for the Mansion's surroundings: lightning every LIGHTNING_INTERVAL seconds (a double
# flash of the moonlight and sky, then thunder a beat later), never while a haunting is warning or running.
# House Shake scatters the crows, makes the lamps flicker and shakes dust off the walls; a shattering item scares
# nearby birds; a ghost win brings a thunderclap and flickering windows.
extends Node

# --- State ---
var arena: Node3D
var environment: Node3D
var wildlife: Node3D
var random := RandomNumberGenerator.new()
var lightning_left: float = 0.0
var shaking: bool = false
var shown_phase: String = ""

# --- Setup ---
func _ready() -> void:
	environment = get_parent()
	arena = environment.get_parent()
	wildlife = environment.get_node("Wildlife")
	random.randomize()
	lightning_left = random.randf_range(Balance.LIGHTNING_INTERVAL.x, Balance.LIGHTNING_INTERVAL.y)
	get_tree().node_added.connect(_on_node_added)
	Game.changed.connect(_on_game_changed)


# --- Lightning and haunting reactions ---
func _process(delta: float) -> void:
	var haunting_now: bool = false
	var house_shake: bool = false
	for ghost: Node in get_tree().get_nodes_in_group("ghosts"):
		for haunting: Haunting in ghost.hauntings:
			haunting_now = haunting_now or haunting.is_active()
			house_shake = house_shake or (haunting is HouseShake and haunting.phase == Haunting.Phase.RUNNING)
	if house_shake and not shaking:
		wildlife.scatter()
		environment.storm(2.0)
		environment.dust_from_walls()
	shaking = house_shake

	lightning_left -= delta
	if lightning_left <= 0.0:
		if haunting_now:
			lightning_left = Balance.LIGHTNING_RETRY # Never over a haunting's warning or a Lights Out.
		else:
			lightning_left = random.randf_range(Balance.LIGHTNING_INTERVAL.x, Balance.LIGHTNING_INTERVAL.y)
			strike(random.randf_range(Balance.THUNDER_DELAY.x, Balance.THUNDER_DELAY.y))


func strike(thunder_delay: float) -> void:
	# Two flashes of the moonlight and ambient light, each fading out (so a slow frame can't swallow it), then
	# thunder after the delay.
	var moon: DirectionalLight3D = arena.get_node_or_null("Moonlight")
	var world: WorldEnvironment = arena.get_node_or_null("WorldEnvironment")
	if moon == null or world == null:
		return
	var flash: Tween = create_tween()
	for repeat: int in range(2):
		flash.tween_callback(func() -> void:
			moon.light_energy = Balance.LIGHTNING_FLASH_ENERGY
			world.environment.ambient_light_energy = Balance.MOOD_AMBIENT_ENERGY * Balance.LIGHTNING_AMBIENT_BOOST
		)
		flash.tween_property(moon, "light_energy", Balance.MOON_ENERGY, Balance.LIGHTNING_FLASH_TIME).set_ease(Tween.EASE_IN)
		flash.parallel().tween_property(world.environment, "ambient_light_energy", Balance.MOOD_AMBIENT_ENERGY, Balance.LIGHTNING_FLASH_TIME).set_ease(Tween.EASE_IN)
	flash.tween_interval(thunder_delay)
	flash.tween_callback(func() -> void: Sfx.play("thunder", random.randf_range(0.85, 1.05), Balance.THUNDER_VOLUME_DB))


# --- Smashes and round results ---
func _on_node_added(node: Node) -> void:
	if node is Loot:
		node.shattered.connect(func(_slot: int) -> void:
			if is_instance_valid(node):
				wildlife.scatter(node.global_position, Balance.SMASH_SCARE_DISTANCE)
		)


func _on_game_changed() -> void:
	if Game.phase == shown_phase:
		return
	shown_phase = Game.phase
	if Game.phase == "result" and not Game.result.get("moversWon", true):
		strike(0.0) # A thunderclap for the ghost's win.
		environment.storm(3.0)
