extends SceneTree

const BATTLE_SCENE := preload("res://src/scenes/battle/battle_scene.tscn")
const OUTPUT_PATH := "res://tests/evidence/production-battle-benchmark.json"
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 300
const MAX_VALID_AVERAGE_FRAME_MS := 50.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	var focused_at_start := DisplayServer.window_is_focused()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(BATTLE_SCENE.instantiate())
	for _frame in WARMUP_FRAMES:
		await process_frame
		await RenderingServer.frame_post_draw
	var frame_times: Array[float] = []
	var max_draw_calls := 0
	var max_primitives := 0
	var max_objects := 0
	var started := Time.get_ticks_usec()
	var previous := started
	for _frame in SAMPLE_FRAMES:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
		max_draw_calls = maxi(max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_primitives = maxi(max_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		max_objects = maxi(max_objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var focused_at_end := DisplayServer.window_is_focused()
	var runtime_configuration := {
		"vsync_disabled": DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
		"max_fps": Engine.max_fps,
		"low_processor_usage_mode": OS.low_processor_usage_mode,
	}
	var average_frame_ms := elapsed_ms / SAMPLE_FRAMES
	var measurement_valid: bool = (
		runtime_configuration.vsync_disabled
		and runtime_configuration.max_fps == 0
		and not runtime_configuration.low_processor_usage_mode
		and average_frame_ms < MAX_VALID_AVERAGE_FRAME_MS
	)
	var validity_reason := "unthrottled runtime configuration confirmed; render-completion cadence plausible"
	if not measurement_valid:
		validity_reason = "invalid development measurement: runtime throttle configuration failed or render cadence exceeded %.1f ms/frame" % MAX_VALID_AVERAGE_FRAME_MS
	frame_times.sort()
	var report := {
		"schema_version": 2,
		"renderer": RenderingServer.get_video_adapter_name(),
		"resolution": [viewport.size.x, viewport.size.y],
		"warmup_frames": WARMUP_FRAMES,
		"sample_frames": SAMPLE_FRAMES,
		"average_fps": SAMPLE_FRAMES * 1000.0 / maxf(elapsed_ms, 0.001),
		"average_frame_ms": average_frame_ms,
		"p95_frame_ms": frame_times[int(floor((frame_times.size() - 1) * 0.95))],
		"peak_frame_ms": frame_times[-1],
		"max_draw_calls": max_draw_calls,
		"max_primitives": max_primitives,
		"max_objects": max_objects,
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"timestamp_unix": Time.get_unix_time_from_system(),
		"measurement_method": "render_frame_post_draw_wall_clock",
		"measurement_elapsed_ms": elapsed_ms,
		"measurement_valid": measurement_valid,
		"measurement_validity_reason": validity_reason,
		"window_focused_at_start": focused_at_start,
		"window_focused_at_end": focused_at_end,
		"runtime_configuration": runtime_configuration,
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
