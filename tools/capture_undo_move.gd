extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(scene)
	var camera: Variant = scene.get_node("TacticalCamera")
	camera.controls_enabled = false
	var out := "res://build/qa/right-click-move-20261029"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	scene.session.select_unit(&"aurelia-1")
	await _save(viewport, out + "/before-move.png")
	scene._on_hud_command({"type": &"move", "destination": Vector2i(2, 6)})
	if not scene.last_command_result.get("ok", false):
		quit(1)
		return
	var unit: Variant = scene.get_unit_node(&"aurelia-1")
	unit.position_animation.custom_step(1.0)
	await _save(viewport, out + "/moved.png")
	await physics_frame
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = camera.unproject_position(scene.get_unit_node(&"blade-1").global_position)
	viewport.push_input(right, true)
	await process_frame
	await process_frame
	if not scene.last_command_result.get("ok", false):
		quit(1)
		return
	unit.position_animation.custom_step(1.0)
	await _save(viewport, out + "/restored.png")
	scene._on_hud_command({"type": &"move", "destination": Vector2i(2, 6)})
	unit.position_animation.custom_step(1.0)
	var wait_button: Button = scene.get_node("BattleHud/Layout/Commands/Wait")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = wait_button.get_global_rect().get_center()
	click.pressed = true
	viewport.push_input(click, true)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	viewport.push_input(click, true)
	await process_frame
	await _save(viewport, out + "/wait-committed.png")
	viewport.push_input(right, true)
	await process_frame
	if unit.position != Vector3(2, 0.7, 6):
		push_error("Committed unit unexpectedly moved")
		quit(1)
		return
	await create_timer(0.3).timeout
	scene.free()
	await process_frame
	viewport.free()
	await process_frame
	print("CAPTURE PASS right-click move: initial, pending, character-right-click restored, Wait committed")
	quit(0)

func _save(viewport: SubViewport, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var err := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Capture failed: " + path)
		quit(1)
