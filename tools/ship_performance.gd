# Measures the Ghost Ship's worst case at 1080p: four movers, the ship riding the swell, two breaking gangplank
# waves and a fog bank. Prints average, 5th-percentile and minimum FPS plus peak draw calls and triangles.
# Needs a window (the real renderer):  godot --path . --script res://tools/ship_performance.gd
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.get_node("InputRouter").process_mode = Node.PROCESS_MODE_DISABLED
	var world: Node3D = load("res://Main.tscn").instantiate()
	world.match_mode = false
	world.arena_scene = load("res://arenas/Ship.tscn")
	root.add_child(world)
	world.status_label.get_parent().get_parent().hide()
	world.ghost_panel.hide()
	var spots: Array[Vector3] = [Vector3(12, 0.8, 13.5), Vector3(16, 0.8, 8), Vector3(4, 2.0, 6), Vector3(24, 1.5, 6)]
	for slot: int in range(4):
		world.movers[slot].reset_for_round(spots[slot], true)
	await create_timer(2.0).timeout
	var arena: Node3D = world.arena
	arena.get_node("ShipEnvironment").roll_fog_bank()
	arena.get_node("ShipEnvironment").fog_bank.position.x = 6.0
	var fps: Array[float] = []
	var worst_frame: float = 0.0
	var draws: int = 0
	var triangles: int = 0
	var wave_at: int = 60
	for frame: int in range(600):
		if frame == wave_at or frame == 360:
			arena.start_wave(Vector3.RIGHT if frame == wave_at else Vector3.LEFT)
		await process_frame
		var delta: float = Performance.get_monitor(Performance.TIME_PROCESS)
		worst_frame = maxf(worst_frame, delta)
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		triangles = maxi(triangles, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	fps.sort()
	var total: float = 0.0
	for value: float in fps.slice(60):
		total += value
	print("PERF 1080p adapter=%s fps_avg=%.0f fps_p05=%.0f fps_min=%.0f draws=%d triangles=%d" % [RenderingServer.get_video_adapter_name(), total / (fps.size() - 60), fps[30], fps[0], draws, triangles])
	quit()
