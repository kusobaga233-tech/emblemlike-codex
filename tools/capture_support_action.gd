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
	scene.get_node("TacticalCamera").controls_enabled = false
	var presenter: Variant = scene.get_node("SpriteCombatPresentation")
	presenter.set_process(false)
	var out := "res://build/qa/support-action-20261102"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var target: Variant = scene.session._find_unit(&"aurelia-1")
	target.grid_position.x = 3
	target.grid_position.y = 7
	target.current_hp = 18
	scene.get_unit_node(&"aurelia-1").position = Vector3(3, 0.7, 7)
	scene._present_event({"type": &"damage_applied", "actor_id": &"blade-1", "target_id": &"aurelia-1", "payload": {"amount": 6, "remaining_hp": 18}})
	scene.session.select_unit(&"elio-1")
	scene.get_node("BattleHud/Layout/Commands/Support").pressed.emit()
	scene.handle_board_pick(&"unit", &"aurelia-1")
	await _save(viewport, out + "/heal-preview-landscape.png")
	viewport.size = Vector2i(720, 1280)
	await _save(viewport, out + "/heal-preview-portrait.png")
	viewport.size = Vector2i(1280, 800)
	await process_frame
	var confirm: Button = scene.get_node("CombatForecastPanel/Layout/Actions/Confirm")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = confirm.get_global_rect().get_center()
	click.pressed = true
	viewport.push_input(click, true)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	viewport.push_input(click, true)
	await process_frame
	if not scene.combat_presentation_busy():
		push_error("Confirm pointer did not start support playback")
		quit(1)
		return
	presenter.advance(0.36)
	await _save(viewport, out + "/heal-impact.png")
	presenter.advance(1.0)
	await _save(viewport, out + "/heal-complete.png")
	await create_timer(0.35).timeout
	scene.free()
	await process_frame
	viewport.free()
	await process_frame
	print("CAPTURE PASS support selection/preview/confirm/heal, landscape and portrait")
	quit(0)

func _save(viewport: SubViewport, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("capture failed: " + path)
		quit(1)
