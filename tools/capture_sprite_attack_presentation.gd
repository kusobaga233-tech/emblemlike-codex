extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var out := "res://build/qa/sprite-attack-20261029-fixed"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var cases := [
		{"name": "melee", "actor": &"aurelia-1", "target": &"blade-1", "distance": 1, "impact": 0.30},
		{"name": "thrust", "actor": &"brann-1", "target": &"blade-1", "distance": 1, "impact": 0.30},
		{"name": "bow", "actor": &"fenn-1", "target": &"blade-1", "distance": 2, "impact": 0.42},
		{"name": "magic", "actor": &"elio-1", "target": &"blade-1", "distance": 2, "impact": 0.34},
		{"name": "heal", "actor": &"elio-1", "target": &"aurelia-1", "distance": 1, "impact": 0.34},
	]
	var records: Array[Dictionary] = []
	for item: Dictionary in cases:
		for yaw in [0, 90, 180, 270]:
			var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
			viewport.add_child(scene)
			var presenter: Variant = scene.get_node("SpriteCombatPresentation")
			presenter.set_process(false)
			var actor: Node3D = scene.get_unit_node(item.actor)
			var target: Node3D = scene.get_unit_node(item.target)
			actor.position = Vector3(3, 0.7, 4)
			target.position = Vector3(3 + item.distance, 0.7, 4)
			for unit: Node3D in scene.get_node("Units").get_children():
				unit.visible = unit == actor or unit == target
			scene.get_node("BattleHud").hide()
			scene.get_node("CombatForecastPanel").hide()
			var camera: Variant = scene.get_node("TacticalCamera")
			camera.set_process(false)
			camera.controls_enabled = false
			camera.focus_point = (actor.position + target.position) * 0.5
			camera.focus_point.y = 0.5
			camera.distance = 5.0
			camera.yaw_degrees = float(yaw)
			camera._target_yaw_degrees = float(yaw)
			camera._apply_transform()
			var heal: bool = item.name == "heal"
			var events: Array[Dictionary] = [
				{"type": &"support_started" if heal else &"attack_started", "actor_id": item.actor, "target_id": item.target, "payload": {"distance": item.distance}},
				{"type": &"unit_healed" if heal else &"damage_applied", "actor_id": item.actor, "target_id": item.target, "payload": {"amount": 3, "remaining_hp": 18}},
			]
			if not heal: events.append({"type": &"attack_finished", "actor_id": item.actor, "target_id": item.target})
			scene.session.events_flushed.emit(events)
			var clock := 0.0
			for sample: Dictionary in [{"name": "windup", "time": 0.10}, {"name": "release", "time": 0.26}, {"name": "impact", "time": item.impact + 0.025}, {"name": "recovery", "time": 0.70}]:
				presenter.advance(sample.time - clock)
				clock = sample.time
				await process_frame
				await RenderingServer.frame_post_draw
				var file := "%s/%s-yaw%d-%s.png" % [out, item.name, yaw, sample.name]
				var err := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
				if err != OK:
					printerr("capture failed: ", file)
					quit(1)
					return
				records.append({"file": file, "style": item.name, "yaw": yaw, "time": clock, "distance": item.distance, "fixture_only": true})
			scene.free()
			await process_frame
	var manifest := FileAccess.open(out + "/capture-manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(records, "  "))
	manifest.close()
	viewport.free()
	await process_frame
	print("CAPTURE PASS 80 fixed-time style/orbit frames; presentation fixtures, not legal-rule gameplay acceptance")
	quit(0)
