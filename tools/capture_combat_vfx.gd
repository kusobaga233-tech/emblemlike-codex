extends SceneTree

const OUTPUT_ROOT := "res://build/evidence/combat-vfx-v01"
const SCENE := preload("res://src/scenes/battle/battle_scene.tscn")
const CHAPTER := preload("res://src/content/chapter_one.gd")
const SESSION := preload("res://src/tactics/battle_session.gd")
const CAPTURE_NAMES := ["attack", "heal", "resonance", "boss-hit", "defeat", "victory"]

func _init() -> void:
	call_deferred("_capture_all")

func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var scene := SCENE.instantiate()
	root.add_child(scene)
	var chapter := CHAPTER.build()
	scene.setup_battle(chapter, SESSION.new(chapter, 1701))
	await process_frame
	var fixtures := [
		["attack", {"type": &"attack_started", "actor_id": &"aurelia-1", "target_id": &"captain-1"}],
		["heal", {"type": &"unit_healed", "target_id": &"aurelia-1", "payload": {"position": Vector3(1, 0.7, 7)}}],
		["resonance", {"type": &"resonance_changed", "actor_id": &"fenn-1", "payload": {"partner_id": &"aurelia-1"}}],
		["boss-hit", {"type": &"hit_confirmed", "actor_id": &"blade-1", "target_id": &"captain-1", "payload": {"critical": true}}],
		["defeat", {"type": &"unit_defeated", "target_id": &"captain-1"}],
		["victory", {"type": &"battle_status_changed", "payload": {"status": &"victory"}}],
	]
	for fixture in fixtures:
		var director := scene.get_node("CombatVfxDirector")
		director.clear_active_presentations()
		director.play_events([fixture[1]] as Array[Dictionary])
		await process_frame
		var image := get_root().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_ROOT, fixture[0]]))
	scene.queue_free()
	quit(0)
