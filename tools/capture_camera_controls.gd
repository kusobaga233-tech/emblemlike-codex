extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var battle: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(battle)
	var camera: Variant = battle.get_node("TacticalCamera")
	camera.set_process(false)
	battle.session.select_unit(&"aurelia-1")
	var out := "res://build/qa/camera-controls-20261022"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for index in 3:
		if index == 1:
			camera.rotate_steps(1)
		elif index == 2:
			camera.rotate_steps(-3)
		camera.advance_rotation(10.0)
		for frame in 12:
			await process_frame
			RenderingServer.force_draw(false)
		var image := viewport.get_texture().get_image()
		var error := image.save_png(ProjectSettings.globalize_path(out + "/view-%d.png" % index))
		if error != OK:
			quit(1)
			return
		print("CAPTURE index=%d yaw=%.1f pitch=%.1f selection=%s" % [index, camera.yaw_degrees, camera.pitch_degrees, battle.session.selected_unit_id])
	viewport.free()
	await process_frame
	quit(0)
