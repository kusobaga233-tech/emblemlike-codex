extends SceneTree

const PROTOTYPE := preload("res://src/qa/cutout_character_billboard_3d.tscn")
const OUTPUT_ROOT := "res://build/qa/cutout-2p5d-prototype"
const CAPTURES := [
	[&"idle", 0.35, "default", 3.15],
	[&"attack_primary", 0.31, "default", 3.15],
	[&"idle", 0.35, "close", 2.55],
	[&"attack_primary", 0.31, "close", 2.55],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.position = Vector3(0, 1.9, 3.4)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.3, 0), Vector3.UP)
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.075, 0.095, 0.13)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.7, 0.78, 0.92)
	environment_resource.ambient_light_energy = 0.65
	environment.environment = environment_resource
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.5
	viewport.add_child(light)
	var billboard := PROTOTYPE.instantiate()
	billboard.auto_face_camera = true
	viewport.add_child(billboard)
	var output_absolute_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	DirAccess.make_dir_recursive_absolute(output_absolute_root)
	for capture in CAPTURES:
		var clip: StringName = capture[0]
		var seek_time: float = capture[1]
		var framing: String = capture[2]
		var camera_distance: float = capture[3]
		camera.position = Vector3(0, 1.9, camera_distance)
		camera.look_at(Vector3(0, 1.3, 0), Vector3.UP)
		if not billboard.play_animation(clip):
			printerr("Missing cutout clip: %s" % clip)
			quit(1)
			return
		billboard.cutout_character.animation_player.seek(seek_time, true)
		await process_frame
		await process_frame
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			printerr("Empty cutout capture: %s" % clip)
			quit(1)
			return
		var output_path := "%s/%s-%s-3d.png" % [OUTPUT_ROOT, clip, framing]
		if image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
			printerr("Failed to save cutout capture: %s" % clip)
			quit(1)
			return
		print("Saved cutout 2.5D capture: %s" % output_path)
	quit(0)
