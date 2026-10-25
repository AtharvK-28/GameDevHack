# Mobile-renderer Ship review. Pass -- --output=<absolute directory> to keep captures outside the repo.
extends SceneTree

const SETTINGS := preload("res://autoload/Balance.gd")
var output: String = ""
var world: Node3D
var camera: Camera3D
var samples: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Ship review needs a real renderer and --output=<absolute directory>.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var router: Node = root.get_node("InputRouter")
	router.process_mode = Node.PROCESS_MODE_DISABLED
	world = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Ship.tscn")
	root.add_child(world)
	world.status_label.get_parent().get_parent().hide()
	world.ghost_panel.hide()
	camera = world.camera
	camera.follow_movers = false
	for slot: int in range(4):
		world.movers[slot].reset_for_round(Vector3(11.5 + slot, 0.8, 7.5), true)
		world.movers[slot].name_label.hide()
	if "--reference-water" in OS.get_cmdline_user_args():
		_reference_water()
	await _frames(90)
	await _view("overview", Vector3(13, 0, 8), 26)
	await _measure("wide")
	await _view("main_deck", Vector3(13, 0, 6), 16)
	await _measure("close")
	await _view("quarterdeck", Vector3(3, 1.2, 5), 12)
	await _view("cargo_hold", Vector3(12, -0.5, 3), 12)
	await _view("forecastle", Vector3(23, 0.8, 5), 12)
	await _view("tug", Vector3(14, 0, 15), 12)
	var bounds: Rect2 = world.arena.camera_bounds()
	var corners: Array[Vector2] = [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for index: int in range(corners.size()):
		await _view("camera_corner_%d" % index, Vector3(corners[index].x, 0, corners[index].y), 26)
	camera.focus = Vector3(13, 0, 8)
	camera.distance = 26
	world.arena.get_node("ShipEnvironment").flash_lightning()
	await _frames(2)
	await _save("lightning")
	await _ghost_views()
	await _crossing()
	await _lineup()
	var file := FileAccess.open(output.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "samples": samples, "prop_triangles": _prop_triangles()}, "  "))
	print("SHIP REVIEW: ", JSON.stringify(samples))
	quit()


func _measure(label: String) -> void:
	await create_timer(1.2, false).timeout # Let the FPS monitor discard startup/import frames.
	var triangles: int = 0
	var draws: int = 0
	var minimum_fps: float = INF
	var maximum_fps: float = 0
	var start: int = Time.get_ticks_usec()
	for frame: int in range(180):
		await process_frame
		triangles = maxi(triangles, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var fps: float = Performance.get_monitor(Performance.TIME_FPS)
		minimum_fps = minf(minimum_fps, fps)
		maximum_fps = maxf(maximum_fps, fps)
	var average: float = 180.0 / (float(Time.get_ticks_usec() - start) / 1000000.0)
	samples.append({"view": label, "triangles": triangles, "draw_calls": draws, "average_fps": snappedf(average, 0.1), "monitor_fps_min": minimum_fps, "monitor_fps_max": maximum_fps, "budget_pass": triangles <= SETTINGS.SHIP_TRIANGLE_BUDGET and draws <= SETTINGS.SHIP_DRAW_CALL_BUDGET})


func _view(label: String, focus: Vector3, distance: float) -> void:
	camera.focus = focus
	camera.distance = distance
	await _frames(20)
	await _save(label)


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))


func _lineup() -> void:
	world.arena.hide()
	for mover: Node3D in world.movers:
		mover.hide()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = SETTINGS.MOON_ROTATION
	world.add_child(light)
	var visuals: Script = load("res://arenas/dressing/ship_visuals.gd")
	visuals.blocks(world, [[Vector3(14, 0.2, 7), Vector3(12, 2.85, 4.5)]], SETTINGS.UI_NIGHT)
	for item: Node3D in get_nodes_in_group("loot"):
		item.hide()
	var index: int = 0
	for entry: CatalogItem in Catalog.items(&"ship", CatalogItem.Category.LOOT):
		var model: Node3D = entry.model.instantiate()
		model.position = Vector3(7 + (index % 5) * 2.5, 3, 3 + (index / 5) * 2.5)
		world.add_child(model)
		ComicLook.apply(model, true)
		var label := Label3D.new()
		label.text = entry.display_name
		label.font_size = 32
		label.pixel_size = 0.008
		label.position.y = entry.footprint.y + 0.3
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		model.add_child(label)
		index += 1
	await _view("loot_lineup", Vector3(12, 3, 5), 20)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame


func _reference_water() -> void:
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://assets/shaders/ship_water_reference.gdshader")
	var water := ShaderMaterial.new()
	water.shader = shader
	water.set_shader_parameter("color", Color(0.15, 0.3, 0.45, 0.8))
	water.set_shader_parameter("deep_water", Color(0.04, 0.1, 0.25, 1))
	water.set_shader_parameter("edge_color", Color(0.6, 0.75, 0.85, 1))
	var noise := NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	noise.seamless = true
	for parameter: String in ["noise1", "noise2", "wave"]:
		water.set_shader_parameter(parameter, noise)
	var normals := NoiseTexture2D.new()
	normals.noise = FastNoiseLite.new()
	normals.as_normal_map = true
	normals.seamless = true
	water.set_shader_parameter("normalmap", normals)
	for mesh: MeshInstance3D in world.arena.get_node("ShipEnvironment").find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh is PlaneMesh:
			mesh.material_override = water


func _crossing() -> void:
	for item: Node3D in get_nodes_in_group("loot"):
		if item.weight_class == SETTINGS.TWO_PERSON:
			item.queue_free()
	await physics_frame
	await physics_frame
	var chest: Node3D = load("res://props/Loot.tscn").instantiate()
	chest.catalog_item = load("res://props/catalog/ship/chest.tres")
	chest.position = Vector3(14, SETTINGS.CARRY_CLEARANCE + chest.catalog_item.footprint.y / 2.0, 11.8)
	chest.rotation = Vector3(0, PI / 2, 0)
	world.arena.add_child(chest)
	for slot: int in [0, 1]:
		var mover: CharacterBody3D = world.movers[slot]
		mover.reset_for_round(Vector3(14, 0.8, 11.8 + (-1.6 if slot == 0 else 1.6)), true)
		mover.facing = Vector3.BACK if slot == 0 else Vector3.FORWARD
		mover._update_hold_point()
		chest.try_grab(mover, mover.hold_point, slot)
		mover.held_item = chest
		var router: Node = root.get_node("InputRouter")
		router.snapshots[slot].buttons = {"grab": true}
	for frame: int in range(30):
		await physics_frame
	print("Crossing capture: holders=", chest.holder_count(), " position=", chest.position)
	await _view("gangplank_crossing", Vector3(14, 0, 11.8), 13)
	for slot: int in [0, 1]:
		world.movers[slot]._let_go()


func _prop_triangles() -> Dictionary:
	var result: Dictionary = {}
	for category: CatalogItem.Category in [CatalogItem.Category.LOOT, CatalogItem.Category.FURNITURE]:
		for entry: CatalogItem in Catalog.items(&"ship", category):
			var model: Node3D = entry.model.instantiate()
			var count: int = 0
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh != null:
					count += mesh.mesh.get_faces().size() / 3
			result[entry.id] = count
			model.free()
	return result


func _ghost_views() -> void:
	# Davy Jones beside a mover for scale, facing all four ways so the captures show which way the
	# model points, and through each of his actions.
	world.set_ghost_slot(3)
	var ghost: Node3D = world.ghost
	for slot: int in range(3):
		world.movers[slot].set_in_play(slot == 0)
	world.movers[0].reset_for_round(Vector3(11.8, 0.8, 6.5), true)
	ghost.position = Vector3(13.2, 0.8 + SETTINGS.WISP_HEIGHT, 6.5)
	await _frames(40)

	await _view("ghost_scale", Vector3(12.5, 1.0, 6.5), 8)
	# Frame out to the widest view so this reading compares with the ghost-free "wide" sample.
	camera.focus = Vector3(13, 0, 8)
	camera.distance = 26
	await _frames(20)
	await _save("ghost_overview")
	await _measure("wide_with_ghost")
	camera.focus = Vector3(12.5, 1.0, 6.5)
	camera.distance = 8
	await _frames(15)
	for index: int in range(4):
		ghost.model.rotation.y = index * PI / 2.0
		await _frames(5)
		await _save("ghost_yaw_%d" % index)

	ghost.model.rotation.y = 0.0
	ghost.model.play_cast()
	await _frames(12)
	await _save("ghost_cast")
	ghost.model.play_emerge()
	await _frames(10)
	await _save("ghost_emerge")
	ghost.model.play_exorcised(1.5)
	await _frames(12)
	await _save("ghost_eject")
	await _frames(45)
	await _save("ghost_dizzy")

	world.set_ghost_slot(-1)
	for slot: int in range(4):
		world.movers[slot].reset_for_round(Vector3(11.5 + slot, 0.8, 7.5), true)
	await _frames(20)
