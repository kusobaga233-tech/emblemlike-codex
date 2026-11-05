extends SceneTree

const BATTLE_SCENE := "res://src/scenes/battle/battle_scene.tscn"
const QA_LOADER := preload("res://src/qa/qa_state_loader.gd")
const OUT := "res://build/qa/chapter-one-tutorial-20261105"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	var scene: Variant = load(BATTLE_SCENE).instantiate()
	viewport.add_child(scene)
	await _settle()
	_setup_camera(scene, 13.0)
	await _settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	# 1. Opening tutorial with the threat toggle and the objective/turn HUD.
	var hud: Variant = scene.get_node("BattleHud")
	hud.get_node("Layout/Threat").button_pressed = true
	await _settle()
	await _save(viewport, OUT + "/01-tutorial-move-1280x800.png")

	# 2. Full-resonance QA state so the partner/target flow is genuinely legal.
	var qa: Variant = QA_LOADER.load_state("chapter_one_resonance")
	if qa == null:
		push_error("Could not load chapter_one_resonance QA state")
		quit(1)
		return
	scene.setup_battle(scene.chapter, qa)
	scene.tutorial.skip()
	await _settle()
	_setup_camera(scene, 13.0)
	await _settle()
	hud = scene.get_node("BattleHud")
	hud._refresh()
	scene._on_hud_command(&"resonance")
	await _settle()
	await _save(viewport, OUT + "/02-resonance-partner-1280x800.png")
	if not scene.handle_board_pick(&"unit", &"brann-1"):
		push_error("Partner pick failed during capture")
		quit(1)
		return
	if not scene.handle_board_pick(&"unit", &"captain-1"):
		push_error("Resonance target pick failed during capture")
		quit(1)
		return
	await _settle()
	await _save(viewport, OUT + "/03-resonance-confirm-1280x800.png")

	# 3. Portrait framing of the same confirmation.
	viewport.size = Vector2i(720, 1280)
	_setup_camera(scene, 22.0)
	await _settle()
	await _settle()
	await _save(viewport, OUT + "/04-resonance-confirm-720x1280.png")

	# 4. Portrait opening tutorial for responsive layout evidence.
	scene.setup_battle(scene.chapter)
	await _settle()
	_setup_camera(scene, 20.0)
	await _settle()
	await _save(viewport, OUT + "/05-tutorial-move-720x1280.png")

	scene.free()
	await process_frame
	viewport.free()
	await process_frame
	print("CAPTURE PASS chapter one tutorial: opening, resonance partner, confirm, portrait")
	quit(0)


func _settle() -> void:
	await process_frame
	await process_frame
	await physics_frame
	await process_frame


func _setup_camera(scene: Variant, camera_distance: float) -> void:
	var camera: Variant = scene.get_node("TacticalCamera")
	camera.controls_enabled = false
	camera.set_process(false)
	camera.focus_point = Vector3(3.5, 0.0, 4.5)
	camera.yaw_degrees = 0.0
	camera._target_yaw_degrees = 0.0
	camera.distance = camera_distance
	camera._apply_transform()


func _save(viewport: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Empty capture: " + path)
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture failed: " + path)
		quit(1)
