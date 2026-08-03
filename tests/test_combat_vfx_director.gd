extends TestCase

const DIRECTOR_PATH := "res://src/presentation/combat_vfx_director.gd"
const SCENE_PATH := "res://src/scenes/battle/battle_scene.tscn"

func run() -> void:
	var script := load(DIRECTOR_PATH) as Script
	assert_true(script != null, "CombatVfxDirector script loads")
	if script == null:
		return
	var director: Node = script.new()
	var started_events: Array[Dictionary] = []
	director.presentation_started.connect(func(event: Dictionary, _id: StringName) -> void: started_events.append(event))
	var types := [&"attack_started", &"hit_confirmed", &"attack_missed", &"damage_applied", &"unit_healed", &"resonance_started", &"resonance_changed", &"resonance_finished", &"unit_defeated", &"battle_status_changed"]
	var keys := [&"attack_trail", &"hit_impact", &"attack_miss", &"damage_flash", &"heal_ring", &"resonance_arc", &"resonance_pulse", &"resonance_fade", &"defeat_dissolve", &"battle_status_ring"]
	for event_type: StringName in types:
		var one: Array[Dictionary] = [{"type": event_type}]
		director.play_events(one)
		assert_equal(director._effect_key_for_event({"type": event_type, "payload": {"identity": event_type}}), keys[types.find(event_type)], "Deterministic effect key for %s" % event_type)
	assert_equal(director.active_presentation_count(), 10, "All ten event types create presentations")
	assert_equal(started_events[0].get("type"), &"attack_started", "Started signal preserves event identity")
	var unknowns: Array[Dictionary] = [{"type": &"future_unknown"}, {"type": &"future_unknown"}]
	director.play_events(unknowns)
	assert_equal(director.diagnostic_count(&"future_unknown"), 2, "Unknown events are diagnosed")
	director.set_quality_tier(&"low")
	assert_equal(director.get("quality_tier"), &"low", "Quality tier is retained")
	director.set_quality_tier(&"unsupported")
	assert_equal(director.get("quality_tier"), &"default", "Unsupported quality falls back to default")
	director.clear_active_presentations()
	assert_equal(director.active_presentation_count(), 0, "Cleanup clears active presentations")
	director.free()
	_test_reentrant_cleanup(script)
	_test_bounded_diagnostics(script)

	var packed := load(SCENE_PATH) as PackedScene
	assert_true(packed != null, "Battle scene loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	var chapter: Variant = load("res://src/content/chapter_one.gd").build()
	var session: Variant = load("res://src/tactics/battle_session.gd").new(chapter, 123)
	scene.setup_battle(chapter, session)
	scene.setup_battle(chapter, session)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	var batch: Array[Dictionary] = [{"type": &"attack_started"}, {"type": &"future_unknown"}]
	session.events_flushed.emit(batch)
	var integrated := scene.get_node("CombatVfxDirector")
	assert_equal(integrated.active_presentation_count(), 1, "BattleScene routes each batch once")
	assert_equal(integrated.diagnostic_count(&"future_unknown"), 1, "BattleScene routes unknown diagnostics")
	var finished_ids: Array[StringName] = []
	integrated.presentation_finished.connect(func(id: StringName) -> void: finished_ids.append(id))
	scene.queue_free()
	await tree.process_frame
	assert_equal(finished_ids.size(), 1, "Scene unload clears active director presentations")

func _test_reentrant_cleanup(script: Script) -> void:
	var director: Node = script.new()
	var initial: Array[Dictionary] = [{"type": &"attack_started"}, {"type": &"hit_confirmed"}, {"type": &"attack_missed"}]
	director.play_events(initial)
	var finished: Array[StringName] = []
	var reentered: Array[bool] = [false]
	director.presentation_finished.connect(func(id: StringName) -> void:
		finished.append(id)
		if not reentered[0]:
			reentered[0] = true
			var nested: Array[Dictionary] = [{"type": &"damage_applied"}]
			director.play_events(nested)
			director.clear_active_presentations()
	)
	director.clear_active_presentations()
	assert_equal(finished.size(), 4, "Reentrant cleanup finishes snapshot and nested presentation exactly once")
	assert_equal(director.active_presentation_count(), 0, "Reentrant cleanup leaves deterministic empty state")
	var fill: Array[Dictionary] = []
	for index: int in 64:
		fill.append({"type": &"attack_started", "payload": {"index": index}})
	director.play_events(fill)
	var eviction_reentered: Array[bool] = [false]
	director.presentation_finished.connect(func(_id: StringName) -> void:
		if not eviction_reentered[0]:
			eviction_reentered[0] = true
			director.clear_active_presentations()
			var replacement: Array[Dictionary] = [{"type": &"unit_healed"}]
			director.play_events(replacement)
	)
	var overflow: Array[Dictionary] = [{"type": &"battle_status_changed"}]
	director.play_events(overflow)
	assert_equal(director.active_presentation_count(), 1, "Reentrant eviction leaves the listener replacement deterministically active")
	director.free()

func _test_bounded_diagnostics(script: Script) -> void:
	var director: Node = script.new()
	var unknowns: Array[Dictionary] = []
	for index: int in 256:
		unknowns.append({"type": StringName("unknown_%d" % index)})
	director.play_events(unknowns)
	assert_true(director.get("_diagnostics").size() <= 65, "Unknown diagnostic keys remain bounded")
	assert_equal(director.diagnostic_count(&"unknown_0"), 1, "Early unknown type retains its diagnostic count")
	assert_equal(director.diagnostic_count(&"__other__"), 192, "Excess unknown types aggregate under a stable key")
	director.free()
