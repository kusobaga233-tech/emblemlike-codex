extends TestCase

const DIRECTOR := preload("res://src/presentation/combat_vfx_director.gd")

func run() -> void:
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
