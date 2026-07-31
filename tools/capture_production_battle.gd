extends SceneTree

const BATTLE_SCENE := preload("res://src/scenes/battle/battle_scene.tscn")
const OUTPUT_PATH := "res://tests/evidence/production-battle-v01.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var battle := BATTLE_SCENE.instantiate()
	viewport.add_child(battle)
	for frame in 8:
		await process_frame
		if frame == 2:
			RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		printerr("Failed to save capture: %s" % error_string(error))
		quit(1)
		return
	print("Saved production battle capture: %s" % OUTPUT_PATH)
	viewport.free()
	quit(0)
