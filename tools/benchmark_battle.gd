extends SceneTree

const BATTLE_SCENE := preload("res://src/scenes/battle/battle_scene.tscn")
const OUTPUT_PATH := "res://tests/evidence/production-battle-benchmark.json"
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 300
const RUN_COUNT := 2
const PERFORMANCE_THRESHOLD_MS := 50.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_state := {
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"low_processor_usage_mode": OS.low_processor_usage_mode,
		"low_processor_usage_mode_sleep_usec": OS.low_processor_usage_mode_sleep_usec,
	}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(BATTLE_SCENE.instantiate())
	var runs: Array[Dictionary] = []
	for run_index in RUN_COUNT:
		runs.append(await _measure_run(run_index + 1))
	var total_elapsed_ms := 0.0
	var average_frame_ms := 0.0
	var p95_frame_ms := 0.0
	var peak_frame_ms := 0.0
	var focus_loss_frames := 0
	var max_draw_calls := 0
	var max_primitives := 0
	var max_objects := 0
	for run in runs:
		total_elapsed_ms += run.elapsed_ms
		average_frame_ms += run.average_frame_ms
		p95_frame_ms = maxf(p95_frame_ms, run.p95_frame_ms)
		peak_frame_ms = maxf(peak_frame_ms, run.peak_frame_ms)
		focus_loss_frames += run.focus_loss_frames
		max_draw_calls = maxi(max_draw_calls, run.max_draw_calls)
		max_primitives = maxi(max_primitives, run.max_primitives)
		max_objects = maxi(max_objects, run.max_objects)
	average_frame_ms /= RUN_COUNT
	var relative_difference := absf(runs[0].average_frame_ms - runs[1].average_frame_ms) / average_frame_ms
	var runtime_configuration := {
		"vsync_disabled": DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,
		"max_fps": Engine.max_fps,
		"low_processor_usage_mode": OS.low_processor_usage_mode,
	}
	var focused_at_start: bool = runs.all(func(run: Dictionary) -> bool: return run.window_focused_at_start)
	var focused_at_end: bool = runs.all(func(run: Dictionary) -> bool: return run.window_focused_at_end)
	var measurement_valid: bool = (
		runtime_configuration.vsync_disabled
		and runtime_configuration.max_fps == 0
		and not runtime_configuration.low_processor_usage_mode
		and focused_at_start
		and focused_at_end
		and focus_loss_frames == 0
	)
	var performance_pass := average_frame_ms <= PERFORMANCE_THRESHOLD_MS
	var version := Engine.get_version_info()
	var report := {
		"schema_version": 3,
		"run_id": "%s-%s" % [Time.get_datetime_string_from_system(false, true), OS.get_process_id()],
		"godot_version": version.string,
		"godot_build": version.build,
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"graphics_api": RenderingServer.get_current_rendering_driver_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"source_commit": _source_commit(),
		"launch_mode": "visible_window_script",
		"launch_command": "Godot --path <project> --script res://tools/benchmark_battle.gd",
		"resolution": [viewport.size.x, viewport.size.y],
		"warmup_frames": WARMUP_FRAMES,
		"sample_frames": SAMPLE_FRAMES,
		"run_count": RUN_COUNT,
		"runs": runs,
		"relative_difference": relative_difference,
		"average_fps": 1000.0 / average_frame_ms,
		"average_frame_ms": average_frame_ms,
		"p95_frame_ms": p95_frame_ms,
		"peak_frame_ms": peak_frame_ms,
		"max_draw_calls": max_draw_calls,
		"max_primitives": max_primitives,
		"max_objects": max_objects,
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"timestamp_unix": Time.get_unix_time_from_system(),
		"measurement_method": "render_frame_post_draw_wall_clock",
		"measurement_elapsed_ms": total_elapsed_ms,
		"measurement_valid": measurement_valid,
		"measurement_validity_reason": "runtime configuration and per-frame focus integrity confirmed" if measurement_valid else "invalid measurement: runtime configuration or focus integrity failed",
		"window_focused_at_start": focused_at_start,
		"window_focused_at_end": focused_at_end,
		"focus_loss_frames": focus_loss_frames,
		"runtime_configuration": runtime_configuration,
		"performance_threshold_ms": PERFORMANCE_THRESHOLD_MS,
		"performance_pass": performance_pass,
		"qualification": "development baseline only; target-hardware certification still required",
	}
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Unable to write benchmark report")
		_finish(1, viewport, previous_state)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report, "\t"))
	_finish(0, viewport, previous_state)


func _measure_run(run_number: int) -> Dictionary:
	for _frame in WARMUP_FRAMES:
		await process_frame
		await RenderingServer.frame_post_draw
	var focused_at_start := DisplayServer.window_is_focused()
	var frame_times: Array[float] = []
	var focus_loss_frames := 0
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
		if not DisplayServer.window_is_focused():
			focus_loss_frames += 1
		max_draw_calls = maxi(max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_primitives = maxi(max_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		max_objects = maxi(max_objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	frame_times.sort()
	return {
		"run_number": run_number,
		"elapsed_ms": elapsed_ms,
		"average_frame_ms": elapsed_ms / SAMPLE_FRAMES,
		"p95_frame_ms": frame_times[int(floor((frame_times.size() - 1) * 0.95))],
		"peak_frame_ms": frame_times[-1],
		"window_focused_at_start": focused_at_start,
		"window_focused_at_end": DisplayServer.window_is_focused(),
		"focus_loss_frames": focus_loss_frames,
		"max_draw_calls": max_draw_calls,
		"max_primitives": max_primitives,
		"max_objects": max_objects,
	}


func _source_commit() -> String:
	var output: Array = []
	var exit_code := OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true)
	return str(output[0]).strip_edges() if exit_code == 0 and not output.is_empty() else "unavailable"


func _finish(exit_code: int, viewport: SubViewport, previous_state: Dictionary) -> void:
	DisplayServer.window_set_vsync_mode(previous_state.vsync_mode)
	Engine.max_fps = previous_state.max_fps
	OS.low_processor_usage_mode = previous_state.low_processor_usage_mode
	OS.low_processor_usage_mode_sleep_usec = previous_state.low_processor_usage_mode_sleep_usec
	viewport.free()
	quit(exit_code)
