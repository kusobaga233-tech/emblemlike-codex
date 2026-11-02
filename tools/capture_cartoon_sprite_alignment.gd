extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var battle: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(battle)
	var camera: Variant = battle.get_node("TacticalCamera")
	camera.set_process(false)
	var out := "res://build/qa/cartoon4-alignment-20261023"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	battle.session.select_unit(&"aurelia-1")
	await _save(viewport, out + "/battle-default.png")
	camera.rotate_steps(1)
	camera.advance_rotation(10.0)
	await _save(viewport, out + "/battle-orbit.png")
	for child in battle.get_node("Units").get_children():
		child.visible = false
	var metrics: Array[Dictionary] = []
	for child in battle.get_node("Units").get_children():
		child.visible = true
		child.position = Vector3(3.0, 0.7, 6.0)
		child.set_selected(true)
		camera.focus_target = child
		camera.frame_group([child.position])
		camera.focus(Vector3(3.0, 0.25, 6.0))
		var sprite: Sprite3D = child.get_node("ProductionVisual")
		var foot_world: Vector3 = child.global_position + sprite.position
		var ring: Node3D = child.get_node("SelectionOutline")
		var difference: float = foot_world.distance_to(ring.global_position)
		metrics.append({"id": String(child.unit_id), "foot_world": [foot_world.x, foot_world.y, foot_world.z], "ring_world": [ring.global_position.x, ring.global_position.y, ring.global_position.z], "pivot_error_world": difference})
		if difference > 0.00001:
			printerr("Alignment failure ", child.unit_id)
			quit(1)
			return
		await _save(viewport, out + "/" + String(child.unit_id) + ".png")
		camera.rotate_steps(3)
		camera.advance_rotation(10.0)
		await _save(viewport, out + "/" + String(child.unit_id) + "-orbit.png")
		child.visible = false
	var report := FileAccess.open(out + "/alignment.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "  "))
	report.close()
	viewport.free()
	await process_frame
	print("CAPTURE PASS: 7 individual units at a shared tile center, two angles each")
	quit(0)

func _save(viewport: SubViewport, path: String) -> void:
	for frame in 8:
		await process_frame
		RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		printerr("Capture failed ", path)
		quit(1)
