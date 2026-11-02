extends SceneTree

const PREVIEW := preload("res://src/qa/bb_test_character_preview.tscn")
const OUTPUT_ROOT := "res://build/qa/bb-test-character"
const CAPTURES := [
	[&"idle", 0.0],
	[&"locomotion", 0.34],
	[&"attack_primary", 0.52],
	[&"attack_secondary", 0.58],
	[&"hit", 0.42],
	[&"defeat", 0.78],
	[&"select", 0.48],
	[&"victory", 0.72],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var preview := PREVIEW.instantiate()
	preview.auto_cycle = false
	viewport.add_child(preview)
	var output_absolute_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute_root)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		printerr("Failed to create BB diagnostic capture directory.")
		quit(1)
		return
	for capture in CAPTURES:
		var clip: StringName = capture[0]
		var normalized_time: float = capture[1]
		if not preview.seek_clip(clip, normalized_time):
			printerr("Could not seek BB diagnostic clip: %s" % clip)
			quit(1)
			return
		for frame in 6:
			await process_frame
			if frame in [1, 3, 5]:
				RenderingServer.force_draw(false)
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			printerr("BB diagnostic capture returned no pixels for %s." % clip)
			quit(1)
			return
		var output_path := "%s/%s-front.png" % [OUTPUT_ROOT, clip]
		var error := image.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			printerr("Failed to save BB diagnostic capture for %s: %s" % [clip, error_string(error)])
			quit(1)
			return
		print("Saved BB diagnostic capture: %s" % output_path)
	viewport.free()
	await process_frame
	quit(0)
