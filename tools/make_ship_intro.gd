# Renders the Ghost Ship intro's panel pictures (assets/cutscenes/ship/), staged in the real Ship scene with the
# drowned captain and movers, through a comic grade. Captions and speech bubbles are not baked in: the cutscene
# letters them from Balance.SHIP_INTRO_PANELS, so painted panels can replace these files without code changes.
# Needs a window, so run it without --headless:
#   godot --path . --script res://tools/make_ship_intro.gd
extends SceneTree

# --- Settings ---
const SETTINGS := preload("res://autoload/Balance.gd") # Autoloads are looked up at run time; this compiles first.
const CAPTAIN := preload("res://actors/ghost_captain_model.gd")
const OUT_FOLDER: String = "res://assets/cutscenes/ship/"
const PICTURE_SIZE := Vector2i(1920, 1080)
const SETTLE_SECONDS: float = 2.5 # For the arena to build, loot to settle and the sea to start moving.
const JPEG_QUALITY: float = 0.9
const ROLL_EASE_SECONDS: float = 2.0 # The ship eases to each shot's roll; a jump would jolt loot into breaking.

# Each shot: where the camera sits and looks, the ship's roll, who stands where doing what, and the captain.
const SHOTS: Array[Dictionary] = [
	{ # The tug in the fog with the galleon looming behind it.
		"file": "01_the_wreck.jpg", "camera": Vector3(25.0, 1.1, 29.0), "look": Vector3(13.0, 2.6, 5.0), "fov": 48.0,
		"roll": 0.4, "fog": true, "lightning": true,
		"movers": [[1, Vector3(10.4, 0.0, 17.2), 200.0, "idle"], [3, Vector3(13.6, 0.0, 17.4), 160.0, "defeat"]],
	},
	{ # Crossing the plank onto the rocking deck.
		"file": "02_boarding.jpg", "camera": Vector3(18.5, 4.2, 20.0), "look": Vector3(12.0, 0.6, 11.0), "fov": 50.0,
		"roll": 1.0,
		"movers": [[1, Vector3(12.2, 0.0, 12.9), 0.0, "walk"], [3, Vector3(11.8, 0.0, 14.9), 10.0, "walk"]],
	},
	{ # The drowned captain rises over the main deck.
		"file": "03_the_captain.jpg", "camera": Vector3(12.4, 1.0, 15.2), "look": Vector3(13.8, 2.5, 8.5), "fov": 50.0,
		"roll": -0.6, "captain": Vector3(13.8, 1.4, 9.4), "captain_scale": 1.5,
		"movers": [[1, Vector3(11.4, 0.0, 10.0), 160.0, "brace"], [3, Vector3(16.6, 0.0, 9.8), 200.0, "tumble"]],
	},
	{ # The whole job from above, as a wave breaks over the plank.
		"file": "04_the_job.jpg", "camera": Vector3(16.0 + 22.0 * sin(deg_to_rad(-20.0)), 19.0, 9.0 + 22.0 * cos(deg_to_rad(-20.0))),
		"look": Vector3(16.0, 0.0, 9.5), "fov": 55.0, "roll": 0.8, "wave": true, "captain": Vector3(22.0, 2.0, 5.0),
		"movers": [[1, Vector3(22.6, 0.7, 9.0), 270.0, "team_carry_walk"], [3, Vector3(25.0, 0.7, 8.4), 270.0, "team_carry_walk"],
			[0, Vector3(4.0, 1.2, 4.0), 90.0, "carry_idle"]],
	},
]

# --- Run state ---
var arena: Node3D
var camera: Camera3D
var props: Array[Node] = []

# --- Setup ---
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = PICTURE_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_FOLDER))
	arena = load("res://arenas/Ship.tscn").instantiate()
	root.add_child(arena)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	_add_comic_grade()
	await create_timer(SETTLE_SECONDS).timeout
	for shot: Dictionary in SHOTS:
		await _stage(shot)
		var picture: Image = root.get_texture().get_image()
		picture.save_jpg(ProjectSettings.globalize_path(OUT_FOLDER + shot.file), JPEG_QUALITY)
		print("Ship intro: saved %s" % shot.file)
	quit()


# --- Staging ---
func _stage(shot: Dictionary) -> void:
	for prop: Node in props:
		prop.queue_free()
	props.clear()
	camera.position = shot.camera
	camera.fov = shot.fov
	camera.look_at(shot.look)
	var roll := create_tween()
	roll.tween_property(arena, "sway_override", shot.roll, ROLL_EASE_SECONDS).from(arena.sway() if is_nan(arena.sway_override) else arena.sway_override)
	await roll.finished
	var environment: Node = arena.get_node("ShipEnvironment")
	if shot.get("fog", false):
		environment.roll_fog_bank()
		environment.fog_bank.position.x = 8.0 # Already drifting over the ship.
	for mover: Array in shot.movers:
		_add_mover(mover[0], mover[1], mover[2], mover[3])
	if shot.has("captain"):
		var captain: Node3D = CAPTAIN.new()
		captain.position = shot.captain
		captain.scale = Vector3.ONE * shot.get("captain_scale", 1.0)
		root.add_child(captain)
		captain.look_at(camera.position * Vector3(1, 0, 1) + Vector3(0, captain.position.y, 0), Vector3.UP, true)
		captain.apply_shimmer(Color.WHITE, SETTINGS.WISP_ALPHA_MAX)
		props.append(captain)
	if shot.get("wave", false):
		arena.start_wave(Vector3.RIGHT)
		await create_timer(SETTINGS.SHIP_WAVE_WARNING + 0.1).timeout # Just as it breaks.
	else:
		await create_timer(0.6).timeout
	if shot.get("lightning", false):
		environment.flash_lightning()
		await create_timer(0.05).timeout
	await process_frame
	await process_frame


func _add_mover(slot: int, at: Vector3, yaw_degrees: float, clip: String) -> void:
	var model: Node3D = load(SETTINGS.MOVER_MODEL_PATH % SETTINGS.MOVER_SHIRTS[slot]).instantiate()
	model.scale = Vector3.ONE * SETTINGS.MOVER_MODEL_SCALE
	model.position = arena.from_ship(at)
	model.rotation.y = deg_to_rad(yaw_degrees)
	root.add_child(model)
	props.append(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for name: StringName in player.get_animation_list():
		if String(name).begins_with("mover_" + clip):
			player.play(name)
			player.seek(0.4, true)
			player.pause() # A held pose, like a drawn frame.
			return


func _add_comic_grade() -> void:
	# A little more colour, a dark vignette and halftone dots in the shadows.
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var grade := ColorRect.new()
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.size = PICTURE_SIZE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
void fragment() {
	vec3 colour = texture(screen, SCREEN_UV).rgb;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(vec3(grey), colour, 1.2);
	vec2 cell = fract(FRAGCOORD.xy / 7.0) - 0.5;
	float dot_size = clamp(0.55 - grey * 1.6, 0.0, 0.5);
	colour *= 1.0 - 0.35 * step(length(cell), dot_size);
	vec2 edge = SCREEN_UV - 0.5;
	colour *= 1.0 - smoothstep(0.35, 0.75, length(edge * vec2(1.0, 0.8)));
	COLOR = vec4(colour, 1.0);
}
"""
	grade.material = material
	layer.add_child(grade)
