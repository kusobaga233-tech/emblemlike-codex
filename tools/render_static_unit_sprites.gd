extends SceneTree

func _init() -> void:
	call_deferred("_render")

func _render() -> void:
	var out := "res://assets/production/sprites/units_v01"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var unit_script = load("res://src/presentation/greybox_unit.gd")
	var helper = unit_script.new()
	for id in unit_script.PRODUCTION_VISUALS:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512, 640)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var model: Node3D = load(unit_script.PRODUCTION_VISUALS[id]).instantiate()
		viewport.add_child(model)
		var player = helper._find_animation_player(model)
		if player != null:
			player.stop()
			if player.has_animation("idle"):
				player.play("idle")
				player.seek(0.0, true)
				player.pause()
		var bounds: AABB = helper._mesh_bounds(model, Transform3D.IDENTITY)
		var scale_factor: float = 2.0 / maxf(bounds.size.y, 0.001)
		model.scale = Vector3.ONE * scale_factor
		model.position = -bounds.get_center() * scale_factor
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(2.5, bounds.size.x * scale_factor * 1.4)
		viewport.add_child(camera)
		camera.look_at_from_position(Vector3(2.0, 0.9, 5.0), Vector3.ZERO)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-35, -25, 0)
		key.light_energy = 1.0
		viewport.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20, 150, 0)
		fill.light_energy = 0.55
		viewport.add_child(fill)
		for frame in 5:
			await process_frame
			RenderingServer.force_draw(false)
		var image := viewport.get_texture().get_image()
		var err := image.save_png(ProjectSettings.globalize_path(out + "/" + String(id) + ".png"))
		if err != OK:
			quit(1)
			return
		print("SPRITE ", id)
		viewport.free()
		await process_frame
	helper.free()
	quit(0)
