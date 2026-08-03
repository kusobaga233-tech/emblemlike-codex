extends SceneTree

const OUTPUT_ROOT := "res://build/evidence/combat-vfx-v01"
const SCENE := preload("res://src/scenes/battle/battle_scene.tscn")
const CHAPTER := preload("res://src/content/chapter_one.gd")
const SESSION := preload("res://src/tactics/battle_session.gd")
const CAPTURE_NAMES := ["attack", "heal", "resonance", "boss-hit", "defeat", "victory"]
const PRESENTATION_SETTLE_FRAMES := 2
const CAPTURE_FIXTURES := [
	["attack", {"type": &"attack_started", "actor_id": &"aurelia-1", "target_id": &"captain-1"}],
	["heal", {"type": &"unit_healed", "target_id": &"aurelia-1", "payload": {"position": Vector3(1, 0.7, 7)}}],
	["resonance", {"type": &"resonance_changed", "actor_id": &"fenn-1", "payload": {"partner_id": &"aurelia-1"}}],
	["boss-hit", {"type": &"hit_confirmed", "actor_id": &"fenn-1", "target_id": &"captain-1", "payload": {"critical": true}}],
	["defeat", {"type": &"unit_defeated", "target_id": &"captain-1"}],
	["victory", {"type": &"battle_status_changed", "payload": {"status": &"victory"}}],
]
const FAILURE_EXIT_CODE := 1

func _init() -> void:
	call_deferred("_capture_all")

func _capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Combat VFX capture requires a rendering display; rerun without --headless.")
		quit(FAILURE_EXIT_CODE)
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		quit(FAILURE_EXIT_CODE)
		return
	for fixture in CAPTURE_FIXTURES:
		# Use a fresh scene per fixture. This guarantees no pooled roots, tweens, camera
		# state, or previous presentation can contaminate the pixels being captured.
		var scene := SCENE.instantiate()
		if scene == null:
			quit(FAILURE_EXIT_CODE)
			return
		root.add_child(scene)
		var chapter := CHAPTER.build()
		var session := SESSION.new(chapter, 1701)
		if not scene.has_method("setup_battle") or session == null:
			scene.queue_free()
			quit(FAILURE_EXIT_CODE)
			return
		scene.setup_battle(chapter, session)
		await process_frame
		var director := scene.get_node_or_null("CombatVfxDirector")
		if director == null:
			scene.queue_free()
			quit(FAILURE_EXIT_CODE)
			return
		var camera := scene.get_node("TacticalCamera") as Camera3D
		if fixture[0] in ["boss-hit", "defeat"]:
			camera.focus(scene.get_unit_node(&"captain-1").global_position)
		elif fixture[0] == "victory":
			camera.focus(director.board_center)
		director.play_events([fixture[1]] as Array[Dictionary])
		for _frame in PRESENTATION_SETTLE_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var texture := get_root().get_texture()
		if texture == null:
			scene.queue_free()
			quit(FAILURE_EXIT_CODE)
			return
		var image := texture.get_image()
		if image == null or image.is_empty():
			scene.queue_free()
			quit(FAILURE_EXIT_CODE)
			return
		var save_error := image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_ROOT, fixture[0]]))
		if save_error != OK:
			scene.queue_free()
			quit(FAILURE_EXIT_CODE)
			return
		scene.queue_free()
		await process_frame
	quit(0)
