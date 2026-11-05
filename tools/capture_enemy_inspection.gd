extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.physics_object_picking = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(scene)
	var camera: Variant = scene.get_node("TacticalCamera")
	camera.controls_enabled = false
	camera.set_process(false)
	camera.focus_point = Vector3(3.5, 0, 4.5)
	camera.yaw_degrees = 0.0
	camera._target_yaw_degrees = 0.0
	camera.distance = 13.0
	camera._apply_transform()
	var out := "res://build/qa/enemy-inspection-20261102"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	scene.session.select_unit(&"aurelia-1")
	scene.session.move_selected(Vector2i(2, 6))
	scene.get_unit_node(&"aurelia-1").position_animation.custom_step(1.0)
	for id: StringName in [&"blade-1", &"bow-1", &"captain-1"]:
		await _hover(viewport, scene.get_unit_node(id).global_position, camera)
		if not scene.get_node("EnemyInspectionPanel").visible:
			push_error("Enemy hover failed: " + String(id))
			quit(1)
			return
		await _save(viewport, "%s/%s-landscape.png" % [out, id])
	viewport.size = Vector2i(720, 1280)
	await process_frame
	await _hover(viewport, scene.get_unit_node(&"bow-1").global_position, camera)
	await _save(viewport, out + "/bow-portrait.png")
	await _hover(viewport, Vector3(7, 0.1, 9), camera)
	await _save(viewport, out + "/empty-cleared.png")
	await create_timer(0.3).timeout
	scene.free()
	await process_frame
	viewport.free()
	await process_frame
	print("CAPTURE PASS enemy hover: melee, ranged, boss, portrait and empty clear")
	quit(0)

func _hover(viewport: SubViewport, world: Vector3, camera: Camera3D) -> void:
	await physics_frame
	var motion := InputEventMouseMotion.new()
	motion.position = camera.unproject_position(world)
	viewport.push_input(motion, true)
	await physics_frame
	await process_frame

func _save(viewport: SubViewport, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture failed: " + path)
		quit(1)
