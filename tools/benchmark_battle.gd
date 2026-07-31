extends SceneTree

const BATTLE_SCENE := preload("res://src/scenes/battle/battle_scene.tscn")
const OUTPUT_PATH := "res://tests/evidence/production-battle-benchmark.json"
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 300


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(BATTLE_SCENE.instantiate())
	for _frame in WARMUP_FRAMES:
		await process_frame
	var frame_times: Array[float] = []
	var max_draw_calls := 0
	var max_primitives := 0
	var max_objects := 0
	var started := Time.get_ticks_usec()
	var previous := started
	for _frame in SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
		max_draw_calls = maxi(max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_primitives = maxi(max_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		max_objects = maxi(max_objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	frame_times.sort()
	var report := {
		"schema_version": 1,
		"renderer": RenderingServer.get_video_adapter_name(),
		"resolution": [viewport.size.x, viewport.size.y],
		"warmup_frames": WARMUP_FRAMES,
		"sample_frames": SAMPLE_FRAMES,
		"average_fps": SAMPLE_FRAMES * 1000.0 / maxf(elapsed_ms, 0.001),
		"average_frame_ms": elapsed_ms / SAMPLE_FRAMES,
		"p95_frame_ms": frame_times[int(floor((frame_times.size() - 1) * 0.95))],
		"peak_frame_ms": frame_times[-1],
		"max_draw_calls": max_draw_calls,
		"max_primitives": max_primitives,
		"max_objects": max_objects,
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"timestamp_unix": Time.get_unix_time_from_system(),
		"qualification": "development baseline only; target-hardware certification still required",
	}
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Unable to write benchmark report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report, "\t"))
	viewport.free()
	quit(0)
