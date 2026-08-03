extends TestCase

const DIRECTOR := preload("res://src/presentation/combat_vfx_director.gd")

func run() -> void:
	var capture_script := load("res://tools/capture_combat_vfx.gd") as Script
	assert_true(capture_script != null, "Runnable capture harness parses")
	if capture_script != null:
		assert_equal(capture_script.get_script_constant_map()["CAPTURE_NAMES"], ["attack", "heal", "resonance", "boss-hit", "defeat", "victory"], "Capture harness routes all six fixed evidence paths")
	var first := await _replay()
	var second := await _replay()
	assert_equal(first, second, "Deterministic mixed-event metrics are reproducible")
	assert_equal(first["active"], 0, "All presentations retire after cleanup")
	assert_true(first["pool_children"] <= 128, "Effect host remains within pool node cap")
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

func _replay() -> Dictionary:
	var director := DIRECTOR.new()
	director.reset_metrics()
	var batch: Array[Dictionary] = []
	for index: int in 100:
		batch = [{"type": &"attack_started", "payload": {"index": index}}, {"type": &"hit_confirmed"}, {"type": &"unit_healed"}, {"type": &"damage_applied", "payload": {"amount": index % 9 + 1}}] as Array[Dictionary]
		director.play_events(batch)
		director.clear_active_presentations()
	var result := {"active": director.active_presentation_count(), "pool_children": (director.get("_effect_host") as Node3D).get_child_count(), "metrics": director.metrics()}
	director.free()
	return result
