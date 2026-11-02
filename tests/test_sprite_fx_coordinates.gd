extends TestCase

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	tree.root.add_child(scene)
	var timeline: Variant = scene.get_node("SpriteCombatPresentation")
	timeline.set_process(false)
	var actor: Node3D = scene.get_unit_node(&"fenn-1")
	var target: Node3D = scene.get_unit_node(&"blade-1")
	actor.position = Vector3(3, 0.7, 4)
	target.position = Vector3(5, 0.7, 4)
	for role: StringName in [&"fenn", &"elio", &"heal"]:
		actor.set_meta("definition_id", role)
		var heal := role == &"heal"
		var events: Array[Dictionary] = [
			{"type": &"support_started" if heal else &"attack_started", "actor_id": &"fenn-1", "target_id": &"blade-1"},
			{"type": &"unit_healed" if heal else &"damage_applied", "actor_id": &"fenn-1", "target_id": &"blade-1", "payload": {"amount": 3}},
		]
		if not heal: events.append({"type": &"attack_finished", "actor_id": &"fenn-1", "target_id": &"blade-1"})
		timeline.enqueue(events)
		timeline.advance(0.26)
		var effect: Dictionary = timeline._effects[0]
		var vertices: PackedVector3Array = effect.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var center := Vector3.ZERO
		for vertex in vertices: center += effect.node.to_global(vertex)
		center /= vertices.size()
		if role == &"fenn":
			var expected: Vector3 = effect.origin.lerp(effect.target, (0.26 - 0.18) / (0.42 - 0.18))
			assert_true(center.distance_to(expected) < 0.4, "arrow world geometry follows source-target segment without double translation")
		else:
			var expected: Vector3 = effect.origin if heal else effect.origin.lerp(effect.target, 0.5)
			if heal: expected.y = 0.3
			assert_true(center.distance_to(expected) < 0.02, "ring world center has exactly one translation")
		timeline.advance(0.16 if role == &"fenn" else 0.08)
		for impact: Dictionary in timeline._effects:
			if impact.kind != &"impact": continue
			var impact_vertices: PackedVector3Array = impact.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for vertex in impact_vertices:
				assert_true(impact.node.to_global(vertex).distance_to(impact.target) < 0.8, "impact sparks stay at victim")
		if role != &"fenn":
			var ring_vertices: PackedVector3Array = effect.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var ring_center := Vector3.ZERO
			for vertex in ring_vertices: ring_center += effect.node.to_global(vertex)
			ring_center /= ring_vertices.size()
			assert_true(ring_center.distance_to(Vector3(target.position.x, 0.3, target.position.z)) < 0.02, "spell/heal ring arrives at target at impact")
		timeline.clear()
	actor.set_meta("definition_id", &"aurelia")
	target.position = Vector3(4, 0.7, 4)
	var victim: Sprite3D = target.get_node("ProductionVisual")
	var home := victim.transform
	var tint := victim.modulate
	timeline.enqueue([
		{"type": &"attack_started", "actor_id": &"fenn-1", "target_id": &"blade-1"},
		{"type": &"attack_missed", "actor_id": &"fenn-1", "target_id": &"blade-1"},
		{"type": &"attack_finished", "actor_id": &"fenn-1", "target_id": &"blade-1"},
	] as Array[Dictionary])
	timeline.advance(0.34)
	assert_true(victim.transform.is_equal_approx(home), "miss must not recoil victim")
	assert_true(victim.modulate.is_equal_approx(tint), "miss must not flash victim")
	scene.free()
