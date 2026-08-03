extends TestCase

const DIRECTOR := preload("res://src/presentation/combat_vfx_director.gd")

func run() -> void:
	var capture_script := load("res://tools/capture_combat_vfx.gd") as Script
	assert_true(capture_script != null, "Runnable capture harness parses")
	if capture_script != null:
		assert_equal(capture_script.get_script_constant_map()["CAPTURE_NAMES"], ["attack", "heal", "resonance", "boss-hit", "defeat", "victory"], "Capture harness routes all six fixed evidence paths")
		assert_equal(capture_script.get_script_constant_map()["FAILURE_EXIT_CODE"], 1, "Capture harness exposes nonzero failure exit")
		assert_true(int(capture_script.get_script_constant_map().get("PRESENTATION_SETTLE_FRAMES", 0)) >= 2, "Capture harness waits for presentation and GPU visibility before reading pixels")
		var fixtures: Array = capture_script.get_script_constant_map().get("CAPTURE_FIXTURES", [])
		assert_equal(fixtures.size(), 6, "Capture fixtures are inspectable and complete")
		if fixtures.size() == 6:
			assert_equal(fixtures[3][1].get("actor_id"), &"fenn-1", "Boss-hit fixture uses the visible Chapter One attacker")
			assert_equal(fixtures[3][1].get("target_id"), &"captain-1", "Boss-hit fixture targets the canonical boss instance")
			assert_equal(fixtures[4][1].get("target_id"), &"captain-1", "Defeat fixture targets the canonical boss instance")
			assert_equal(fixtures[5][1].get("payload", {}).get("status"), &"victory", "Victory fixture uses the canonical battle-status payload")
		await _test_capture_fixtures_execute(capture_script)
	var first := await _replay()
	var second := await _replay()
	assert_equal(first, second, "Deterministic mixed-event metrics are reproducible")
	assert_equal(first["active"], 0, "All presentations retire after cleanup")
	assert_true(first["pool_children"] <= 128, "Effect host remains within pool node cap")
	assert_true(first["peak_host_children"] <= 128, "Effect host remains within node cap while effects are active")
	assert_true(first["metrics"]["peak_active"] <= 64, "Active presentation cap is respected")
	assert_true(first["metrics"]["peak_particles"] <= 640, "Particle peak is bounded by active cap")
	var low := DIRECTOR.new()
	low.set_quality_tier(&"low")
	low.play_events([{"type": &"hit_confirmed"}, {"type": &"unit_healed"}, {"type": &"unit_defeated"}] as Array[Dictionary])
	assert_equal(low.get("_active")[0].effects.size(), 1, "Low hit keeps only primary primitive")
	assert_equal(low.get("_active")[1].effects.size(), 1, "Low heal keeps primary ring")
	assert_equal(low.get("_active")[2].effects.size(), 1, "Low defeat keeps primary burst")
	low.clear_active_presentations()
	low.play_events([{"type": &"resonance_finished"}, {"type": &"resonance_changed", "payload": {"partner_id": &"missing"}}] as Array[Dictionary])
	assert_equal(low.get("_active")[0].effects[0].get_meta("effect_category"), &"ring", "Low resonance fade retains a ring and suppresses trail")
	assert_equal(low.get("_active")[1].effects.map(func(effect: Node3D) -> StringName: return effect.get_meta("effect_category")), [&"ring"], "Low resonance pulse keeps only the primary ring")
	var boss_effects: Array[Node3D] = low._spawn_effects(&"boss_weak_point", {})
	assert_equal(boss_effects.map(func(effect: Node3D) -> StringName: return effect.get_meta("effect_category")), [&"ring"], "Low boss hit keeps pulse and suppresses weak-point trail")
	low.reset_metrics()
	low.get("_metrics")["unknown_events"] = 2147483647
	low.play_events([{"type": &"not_known"}] as Array[Dictionary])
	assert_equal(low.metrics()["unknown_events"], 2147483647, "Metric counters saturate at the documented maximum")
	low.clear_active_presentations()
	low.free()

func _test_capture_fixtures_execute(capture_script: Script) -> void:
	var packed := load("res://src/scenes/battle/battle_scene.tscn") as PackedScene
	assert_true(packed != null, "Capture fixture regression scene loads")
	if packed == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var fixtures: Array = capture_script.get_script_constant_map()["CAPTURE_FIXTURES"]
	assert_equal(fixtures.size(), 6, "Executable capture fixture table remains complete")
	if fixtures.size() < 6:
		return
	for index in [3, 4, 5]:
		var scene := packed.instantiate()
		var chapter: Variant = load("res://src/content/chapter_one.gd").build()
		var session: Variant = load("res://src/tactics/battle_session.gd").new(chapter, 1701)
		tree.root.add_child(scene)
		scene.setup_battle(chapter, session)
		await tree.process_frame
		var director := scene.get_node("CombatVfxDirector")
		var camera := scene.get_node("TacticalCamera") as Camera3D
		var fixture: Array = fixtures[index]
		director.reset_metrics()
		assert_equal(director.active_presentation_count(), 0, "%s fixture starts without active remnants" % fixture[0])
		assert_equal(int(director.get("_pooled_effect_count")), 0, "%s fixture starts with an empty pool" % fixture[0])
		if fixture[0] in ["boss-hit", "defeat"]:
			camera.focus(scene.get_unit_node(&"captain-1").global_position)
		else:
			camera.focus(director.board_center)
		director.play_events([fixture[1]] as Array[Dictionary])
		for _frame in int(capture_script.get_script_constant_map()["PRESENTATION_SETTLE_FRAMES"]):
			await tree.process_frame
		assert_equal(director.active_presentation_count(), 1, "%s fixture retains an active presentation after settling" % fixture[0])
		if director.active_presentation_count() == 1:
			var record: Dictionary = director.get("_active")[0]
			var expected_key: StringName = [&"boss_weak_point", &"defeat_dissolve", &"battle_status_ring"][index - 3]
			var expected_categories: Array = [[&"ring", &"trail"], [&"burst", &"particles"], [&"ring"]][index - 3]
			assert_equal(record.get("effect_key"), expected_key, "%s fixture routes to %s" % [fixture[0], expected_key])
			assert_true(not record.get("effects", []).is_empty(), "%s fixture creates effect roots" % fixture[0])
			assert_equal(record.get("effects", []).map(func(effect: Node3D) -> StringName: return effect.get_meta("effect_category")), expected_categories, "%s fixture keeps its exact effect composition" % fixture[0])
			for effect: Node3D in record.get("effects", []):
				assert_true(is_instance_valid(effect) and effect.visible, "%s fixture effect root is visible" % fixture[0])
			assert_equal(director.metrics().get("peak_active"), 1, "%s fixture records one active presentation" % fixture[0])
			_assert_capture_primitive_state(fixture[0], director, record)
		scene.queue_free()
		await tree.process_frame

func _assert_capture_primitive_state(capture_name: String, director: Node, record: Dictionary) -> void:
	var effects: Array = record.get("effects", [])
	if capture_name == "boss-hit":
		var ring := effects[0] as Node3D
		var mesh := ring.get_node("Mesh") as MeshInstance3D
		assert_true(mesh.mesh is CylinderMesh, "Boss-hit weak point uses a ring cylinder")
		assert_equal((mesh.mesh as CylinderMesh).top_radius, 0.45, "Boss-hit weak-point ring has its capture radius")
		assert_true(_color_close((mesh.material_override as StandardMaterial3D).albedo_color, Color(0.85, 0.55, 0.95)), "Boss-hit ring keeps the lavender weak-point color")
		assert_true(ring.global_position.y > 0.7, "Boss-hit ring is elevated over the boss weak point")
	elif capture_name == "defeat":
		var burst := effects[0] as Node3D
		var particles := effects[1] as Node3D
		var burst_mesh := burst.get_node("Mesh") as MeshInstance3D
		assert_true(burst_mesh.mesh is QuadMesh, "Defeat uses a burst quad")
		assert_equal((burst_mesh.mesh as QuadMesh).size, Vector2(0.45, 0.45), "Defeat burst is the critical large primitive")
		assert_true(_color_close((burst_mesh.material_override as StandardMaterial3D).albedo_color, Color(0.5, 0.18, 0.62)), "Defeat burst keeps the dark violet dissolve color")
		assert_equal((particles.get_node("Particles") as GPUParticles3D).amount, 16, "Defeat emits the full sixteen-particle dissolve")
	elif capture_name == "victory":
		var ring := effects[0] as Node3D
		var mesh := ring.get_node("Mesh") as MeshInstance3D
		assert_true(mesh.mesh is CylinderMesh, "Victory uses a center ring cylinder")
		assert_equal((mesh.mesh as CylinderMesh).top_radius, 0.55, "Victory center ring is wider than the boss weak-point ring")
		assert_true(_color_close((mesh.material_override as StandardMaterial3D).albedo_color, Color(0.92, 0.32, 0.12)), "Victory ring keeps the ember-orange status color")
		assert_true(ring.global_position.is_equal_approx(director.board_center), "Victory ring is centered on the board, not the boss")

func _color_close(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) and is_equal_approx(actual.b, expected.b)

func _replay() -> Dictionary:
	var director := DIRECTOR.new()
	director.reset_metrics()
	var batch: Array[Dictionary] = []
	var peak_host_children := 0
	for index: int in 100:
		batch = [{"type": &"attack_started", "payload": {"index": index}}, {"type": &"hit_confirmed"}, {"type": &"unit_healed"}, {"type": &"damage_applied", "payload": {"amount": index % 9 + 1}}] as Array[Dictionary]
		director.play_events(batch)
		peak_host_children = maxi(peak_host_children, (director.get("_effect_host") as Node3D).get_child_count())
		director.clear_active_presentations()
	var result := {"active": director.active_presentation_count(), "pool_children": (director.get("_effect_host") as Node3D).get_child_count(), "peak_host_children": peak_host_children, "metrics": director.metrics()}
	director.free()
	return result
