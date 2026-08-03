extends TestCase

const DIRECTOR_PATH := "res://src/presentation/combat_vfx_director.gd"
const SCENE_PATH := "res://src/scenes/battle/battle_scene.tscn"

func run() -> void:
	var effects := load("res://src/presentation/combat_vfx_effects.gd") as Script
	assert_true(effects != null, "Combat VFX primitive script loads")
	if effects != null:
		var host := Node3D.new()
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child(host)
		var ring: Node3D = effects.spawn_ring(host, Vector3.ZERO, Color(0.8, 0.2, 0.1), 0.1, 1.0)
		assert_equal(ring.get_meta("effect_category"), &"ring", "Ring builder creates ring category")
		assert_true(ring.get_node_or_null("Mesh") is MeshInstance3D, "Ring builder creates mesh primitive")
		var burst: Node3D = effects.spawn_burst(host, Vector3.ZERO, Color(0.8, 0.2, 0.1), 0.1, true)
		assert_equal(burst.get_meta("effect_category"), &"burst", "Burst builder creates burst category")
		var reused_burst: Node3D = effects.spawn_burst(host, Vector3.ONE, Color(0.1, 0.4, 0.9), 0.6, false, burst)
		assert_true(reused_burst == burst, "Burst reconfiguration preserves object identity")
		assert_equal(reused_burst.get_meta("critical"), false, "Burst reconfiguration updates critical state")
		assert_equal((reused_burst.get_node("Mesh") as MeshInstance3D).mesh.size, Vector2(0.3, 0.3), "Burst reconfiguration updates geometry")
		var burst_material := (reused_burst.get_node("Mesh") as MeshInstance3D).material_override as StandardMaterial3D
		assert_equal(burst_material.albedo_color, Color(0.1, 0.4, 0.9), "Burst reconfiguration updates material color")
		var reused_ring: Node3D = effects.spawn_ring(host, Vector3.ONE, Color(0.2, 0.7, 0.4), 0.8, 2.25, ring)
		assert_true(reused_ring == ring, "Ring reconfiguration preserves object identity")
		assert_equal(((reused_ring.get_node("Mesh") as MeshInstance3D).mesh as CylinderMesh).top_radius, 2.25, "Ring reconfiguration updates radius")
		var particles: Node3D = effects.spawn_particles(host, Vector3.ZERO, Color.RED, 0.2, 3)
		var reused_particles: Node3D = effects.spawn_particles(host, Vector3.ONE, Color.BLUE, 0.9, 17, particles)
		assert_true(reused_particles == particles, "Particle reconfiguration preserves object identity")
		var particle_node := reused_particles.get_node("Particles") as GPUParticles3D
		assert_equal(particle_node.amount, 17, "Particle reconfiguration updates count")
		assert_equal(particle_node.lifetime, 0.9, "Particle reconfiguration updates duration")
		assert_equal((particle_node.process_material as ParticleProcessMaterial).color, Color.BLUE, "Particle reconfiguration updates color")
		assert_true(particle_node.draw_pass_1 is QuadMesh, "Particles use a QuadMesh draw pass")
		assert_equal((particle_node.draw_pass_1 as QuadMesh).size, Vector2(0.12, 0.12), "Particles draw mesh size is exact")
		assert_equal(((particle_node.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color, Color.BLUE, "Particles draw material color is exact")
		var trail: Node3D = effects.spawn_trail(host, Vector3.ZERO, Vector3.ONE, Color.RED, 0.2, false)
		var reused_trail: Node3D = effects.spawn_trail(host, Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Color.BLUE, 0.4, true, trail)
		assert_true(reused_trail == trail, "Trail reconfiguration preserves object identity")
		assert_equal((reused_trail.get_node("Mesh") as MeshInstance3D).mesh.size, Vector2(2.0, 0.08), "Trail geometry updates for target and secondary")
		assert_equal(((reused_trail.get_node("Mesh") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color, Color.BLUE, "Trail material color updates")
		assert_equal(((reused_ring.get_node("Mesh") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color, Color(0.2, 0.7, 0.4), "Ring material color updates")
		var detached_host := Node3D.new()
		var detached_effect: Node3D = effects.spawn_ring(detached_host, Vector3.ZERO, Color.WHITE, 0.0, 0.5)
		assert_true(is_instance_valid(detached_effect), "Primitive creation is safe for an out-of-tree host")
		detached_host.free()
		host.queue_free()

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
	var pooled_director: Node = script.new()
	var pooled_event: Array[Dictionary] = [{"type": &"hit_confirmed", "critical": true}]
	pooled_director.play_events(pooled_event)
	var first_effect: Node = pooled_director.get("_active")[0].get("effects")[0]
	pooled_director.clear_active_presentations()
	pooled_director.play_events(pooled_event)
	var reused_effect: Node = pooled_director.get("_active")[0].get("effects")[0]
	assert_true(first_effect == reused_effect, "Released effect node is reused by primitive kind")
	pooled_director.clear_active_presentations()
	pooled_director.play_events([{"type": &"hit_confirmed", "critical": false}] as Array[Dictionary])
	var reconfigured_effect: Node3D = pooled_director.get("_active")[0].get("effects")[0]
	assert_equal(reconfigured_effect.get_meta("critical"), false, "Reused burst is reconfigured for the new event")
	pooled_director.clear_active_presentations()
	var quality_director: Node = script.new()
	var impact_event: Array[Dictionary] = [{"type": &"hit_confirmed"}]
	quality_director.set_quality_tier(&"default")
	quality_director.play_events(impact_event)
	var default_effects: Array = quality_director.get("_active")[0].get("effects")
	assert_equal(default_effects.size(), 2, "Default quality spawns primary and secondary primitives")
	assert_equal(default_effects.map(func(effect: Node3D) -> StringName: return effect.get_meta("effect_category")), [&"burst", &"particles"], "Default quality composition is exact")
	quality_director.clear_active_presentations()
	quality_director.set_quality_tier(&"low")
	quality_director.play_events(impact_event)
	var low_effects: Array = quality_director.get("_active")[0].get("effects")
	assert_equal(low_effects.size(), 1, "Low quality spawns only the primary primitive")
	assert_equal(low_effects[0].get_meta("effect_category"), &"burst", "Low quality composition is exact")
	quality_director.free()
	var pressure: Array[Dictionary] = []
	for index: int in 256:
		pressure.append({"type": &"attack_started", "payload": {"index": index}})
	pooled_director.play_events(pressure)
	var host: Node3D = pooled_director.get("_effect_host")
	assert_true(host.get_child_count() <= int(script.get_script_constant_map().get("MAX_POOLED_EFFECTS", 128)), "Effect allocation never exceeds the pool cap under pressure")
	pooled_director.clear_active_presentations()
	assert_true(int(pooled_director.get("_pooled_effect_count")) > 0, "Cleanup retains reusable pooled nodes")
	var pooled_node: Node3D
	for bucket: Array in pooled_director.get("_effect_pool").values():
		if not bucket.is_empty():
			pooled_node = bucket[0]
			break
	assert_true(pooled_node != null, "Pool bookkeeping references a retained node")
	assert_true(not pooled_node.visible, "Released pooled node is hidden")
	assert_equal(float(pooled_node.get_meta("vfx_elapsed")), 0.0, "Released pooled node elapsed state resets")
	assert_true(int(pooled_director.get("_pooled_effect_count")) <= 128, "Pool bookkeeping remains capped")
	pooled_director.free()
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
	assert_equal(integrated.owner, scene, "BattleScene assigns owner to dynamically added VFX director")
	assert_equal(integrated.diagnostic_count(&"future_unknown"), 1, "BattleScene routes unknown diagnostics")
	var fenn: Node3D = scene.get_unit_node(&"fenn-1")
	var blade: Node3D = scene.get_unit_node(&"blade-1")
	var impacts: Array = []
	integrated.camera_impact_requested.connect(func(origin: Vector3, strength: float, duration: float) -> void: impacts.append([origin, strength, duration]))
	session.events_flushed.emit([{"type": &"damage_applied", "actor_id": &"blade-1", "target_id": &"fenn-1", "payload": {"amount": 20}}] as Array[Dictionary])
	assert_equal((integrated.get("_active")[-1].effects[0] as Node3D).global_position, fenn.global_position, "Director routes damage to target position")
	assert_true(impacts.size() == 1 and impacts[0][1] <= 0.08 and impacts[0][2] <= 0.18, "Damage emits bounded camera impact request")
	session.events_flushed.emit([{"type": &"battle_status_changed", "payload": {"status": &"victory"}}] as Array[Dictionary])
	assert_equal((integrated.get("_active")[-1].effects[0] as Node3D).global_position, Vector3(3.5, 0.0, 4.5), "Battle status falls back to board center")
	integrated.set_quality_tier(&"low")
	impacts.clear()
	session.events_flushed.emit([{"type": &"damage_applied", "actor_id": &"blade-1", "target_id": &"fenn-1", "payload": {"amount": 4}}] as Array[Dictionary])
	assert_equal(impacts.size(), 0, "Low quality suppresses camera impact requests")
	integrated.set_quality_tier(&"default")
	session.events_flushed.emit([{"type": &"hit_confirmed", "actor_id": &"fenn-1", "target_id": &"captain-1", "payload": {"critical": true}}] as Array[Dictionary])
	var boss_record: Dictionary = integrated.get("_active")[-1]
	assert_equal(boss_record.effect_key, &"boss_weak_point", "Boss hit uses a distinct weak-point presentation key")
	assert_equal(boss_record.effects.map(func(effect: Node3D) -> StringName: return effect.get_meta("effect_category")), [&"ring", &"trail"], "Boss weak point uses pulse and crack categories")
	assert_equal((boss_record.effects[0] as Node3D).global_position, scene.get_unit_node(&"captain-1").global_position + Vector3(0.0, 0.75, 0.0), "Boss weak point is offset above the target root")
	session.events_flushed.emit([{"type": &"resonance_changed", "actor_id": &"fenn-1", "target_id": &"blade-1", "payload": {"partner_id": &"aurelia-1", "from": 25, "to": 75}}] as Array[Dictionary])
	var pulse_record: Dictionary = integrated.get("_active")[-1]
	assert_equal(pulse_record.effect_key, &"resonance_pulse", "Resonance change uses explicit pulse behavior")
	assert_equal(pulse_record.effects.size(), 2, "Resonance pulse routes actor and partner endpoints")
	session.events_flushed.emit([{"type": &"resonance_finished", "actor_id": &"fenn-1", "target_id": &"blade-1", "payload": {"partner_id": &"aurelia-1"}}] as Array[Dictionary])
	var fade_record: Dictionary = integrated.get("_active")[-1]
	assert_equal(fade_record.effect_key, &"resonance_fade", "Resonance finish uses explicit fade behavior")
	assert_equal(fade_record.effects[0].get_meta("effect_category"), &"trail", "Resonance fade contracts along the partner route")
	session.events_flushed.emit([{"type": &"unit_healed", "actor_id": &"missing", "target_id": &"missing", "payload": {"position": Vector3(2.0, 0.0, 2.0)}}] as Array[Dictionary])
	assert_equal((integrated.get("_active")[-1].effects[0] as Node3D).global_position, Vector3(2.0, 0.0, 2.0), "Missing nodes safely use payload position fallback")
	assert_true(is_instance_valid(blade), "Actor and target nodes remain safe during routing")
	var finished_ids: Array[StringName] = []
	integrated.presentation_finished.connect(func(id: StringName) -> void: finished_ids.append(id))
	scene.queue_free()
	await tree.process_frame
	assert_true(finished_ids.size() >= 1, "Scene unload clears active director presentations")

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
	var started_ids: Array[StringName] = []
	director.presentation_started.connect(func(_event: Dictionary, id: StringName) -> void: started_ids.append(id))
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
	assert_equal(started_ids.size(), 65, "Evicted record is not reported started after reentrant clear")
	assert_equal(finished[4], started_ids[0], "Capacity eviction finishes the oldest started presentation")
	assert_equal(director.get("_active")[0].get("id"), started_ids[-1], "Final active record matches the last started presentation")
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
