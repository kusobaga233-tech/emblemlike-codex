class_name CombatVfxDirector
extends Node

const CombatVfxEffects := preload("res://src/presentation/combat_vfx_effects.gd")

signal presentation_started(event: Dictionary, presentation_id: StringName)
signal presentation_finished(presentation_id: StringName)
signal camera_impact_requested(origin: Vector3, strength: float, duration: float)

const MAX_ACTIVE_PRESENTATIONS := 64
const MAX_DIAGNOSTIC_TYPES := 64
const MAX_POOLED_EFFECTS := 128
const EXCESS_DIAGNOSTIC_KEY := &"__other__"
var quality_tier: StringName = &"default"
var _active: Array[Dictionary] = []
var _diagnostics: Dictionary = {}
var _sequence: int = 0
var _effect_host: Node3D
var _effect_pool: Dictionary = {}
var _pooled_effect_count := 0
var board_center: Vector3 = Vector3.ZERO
var _metrics: Dictionary = {
	"peak_active": 0,
	"peak_particles": 0,
	"unknown_events": 0,
	"released_effects": 0,
	"camera_requests": 0,
}

func _ready() -> void:
	_ensure_effect_host()

func _process(_delta: float) -> void:
	for record: Dictionary in _active:
		for effect: Node3D in record.get("effects", []):
			if is_instance_valid(effect) and not effect.is_queued_for_deletion():
				effect.set_meta("vfx_elapsed", float(effect.get_meta("vfx_elapsed", 0.0)) + _delta)
	var finished: Array[Dictionary] = []
	for record: Dictionary in _active:
		var effects: Array = record.get("effects", [])
		if not effects.is_empty() and effects.all(func(effect: Node3D) -> bool: return not is_instance_valid(effect) or effect.is_queued_for_deletion() or float(effect.get_meta("vfx_elapsed", 0.0)) >= float(effect.get_meta("vfx_duration", 0.0))):
			finished.append(record)
	for record: Dictionary in finished:
		_active.erase(record)
		_release_effects(record)
		presentation_finished.emit(StringName(record.get("id", &"")))

func play_events(events: Array[Dictionary]) -> void:
	_trim_pool_to_cap()
	for event: Dictionary in events:
		var effect_key := _presentation_key_for_event(event)
		if effect_key == &"":
			_metrics["unknown_events"] = int(_metrics["unknown_events"]) + 1
			var event_type := StringName(event.get("type", &""))
			var diagnostic_key := event_type
			if not _diagnostics.has(event_type) and _diagnostics.size() >= MAX_DIAGNOSTIC_TYPES:
				diagnostic_key = EXCESS_DIAGNOSTIC_KEY
			_diagnostics[diagnostic_key] = int(_diagnostics.get(diagnostic_key, 0)) + 1
			continue
		_sequence += 1
		var presentation_id := StringName("%s_%d" % [effect_key, _sequence])
		if _active.size() >= MAX_ACTIVE_PRESENTATIONS:
			var evicted: Dictionary = _active.pop_front()
			_release_effects(evicted)
			_active.append(_make_record(presentation_id, event, effect_key))
			presentation_finished.emit(StringName(evicted.get("id", &"")))
		else:
			_active.append(_make_record(presentation_id, event, effect_key))
		for record: Dictionary in _active:
			if StringName(record.get("id", &"")) == presentation_id:
				presentation_started.emit(event, presentation_id)
				break
	_update_peak_metrics()

func metrics() -> Dictionary:
	_update_peak_metrics()
	return _metrics.duplicate(true)

func reset_metrics() -> void:
	_metrics = {"peak_active": 0, "peak_particles": 0, "unknown_events": 0, "released_effects": 0, "camera_requests": 0}

func set_quality_tier(tier: StringName) -> void:
	quality_tier = tier if tier in [&"default", &"low"] else &"default"

func set_board_center(value: Vector3) -> void:
	board_center = value

func clear_active_presentations() -> void:
	var finishing := _active.duplicate()
	_active.clear()
	for record: Dictionary in finishing:
		_release_effects(record)
		presentation_finished.emit(StringName(record.get("id", &"")))

func active_presentation_count() -> int:
	return _active.size()

func diagnostic_count(event_type: StringName) -> int:
	return int(_diagnostics.get(event_type, 0))

func active_effect_count() -> int:
	var count := 0
	for record: Dictionary in _active:
		for effect: Node3D in record.get("effects", []):
			if is_instance_valid(effect) and not effect.is_queued_for_deletion():
				count += 1
	return count

func _ensure_effect_host() -> Node3D:
	if is_instance_valid(_effect_host):
		return _effect_host
	_effect_host = Node3D.new()
	_effect_host.name = "ActiveCombatVfx"
	add_child(_effect_host)
	_effect_host.owner = get_parent() if get_parent() != null else owner
	return _effect_host

func _make_record(presentation_id: StringName, event: Dictionary, effect_key: StringName) -> Dictionary:
	return {"id": presentation_id, "event": event, "effect_key": effect_key, "effects": _spawn_effects(effect_key, event)}

func _spawn_effects(effect_key: StringName, event: Dictionary) -> Array[Node3D]:
	var effects: Array[Node3D] = []
	var host := _ensure_effect_host()
	var position := _event_position(event)
	var color := Color(0.92, 0.32, 0.12)
	match effect_key:
		&"attack_trail", &"resonance_arc":
			var end_position := _secondary_position(event, position)
			effects.append(_acquire(&"trail", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_trail(host, position, end_position, color, 0.35, false, existing), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"trail", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_trail(host, position + Vector3(0.0, 0.12, 0.0), end_position + Vector3(0.0, 0.12, 0.0), color.darkened(0.2), 0.3, true, existing), position))
		&"hit_impact", &"attack_miss", &"damage_flash":
			if effect_key == &"attack_miss": position += Vector3(0.35, 0.15, -0.25)
			effects.append(_acquire(&"burst", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_burst(host, position, color, 0.3, bool(event.get("critical", false)), existing), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"particles", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_particles(host, position, color, 0.3, 10, existing), position))
			if effect_key == &"damage_flash" and _is_boss_target(event):
				effects.append(_acquire(&"ring", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_ring(host, position + Vector3(0.0, 0.75, 0.0), Color(0.85, 0.55, 0.95), 0.38, 0.45, existing), position))
		&"heal_ring":
			effects.append(_acquire(&"ring", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_ring(host, position, Color(0.2, 0.85, 0.55), 0.45, 0.7, existing), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"particles", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_particles(host, position, Color(0.2, 0.85, 0.55), 0.4, 8, existing), position))
		&"defeat_dissolve":
			effects.append(_acquire(&"burst", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_burst(host, position, Color(0.5, 0.18, 0.62), 0.5, true, existing), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"particles", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_particles(host, position, Color(0.5, 0.18, 0.62), 0.5, 16, existing), position))
		&"resonance_pulse":
			effects.append(_acquire(&"ring", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_ring(host, position, Color(0.95, 0.72, 0.95), 0.32, 0.75, existing), position))
			var partner_position := _secondary_position(event, position)
			if partner_position != position:
				effects.append(_acquire(&"ring", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_ring(host, partner_position, Color(0.95, 0.72, 0.95), 0.32, 0.55, existing), partner_position))
		&"resonance_fade":
			var fade_target := _secondary_position(event, position)
			effects.append(_acquire(&"trail", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_trail(host, position, fade_target, Color(0.58, 0.32, 0.72), 0.42, true, existing), position))
		&"boss_weak_point":
			position += Vector3(0.0, 0.75, 0.0)
			effects.append(_acquire(&"ring", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_ring(host, position, Color(0.85, 0.55, 0.95), 0.38, 0.45, existing), position))
			effects.append(_acquire(&"trail", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_trail(host, position + Vector3(-0.3, 0.2, 0.0), position + Vector3(0.3, -0.2, 0.0), Color(0.65, 0.22, 0.82), 0.38, true, existing), position))
		_:
			effects.append(_acquire(&"ring", func(existing: Node3D = null) -> Node3D: return CombatVfxEffects.spawn_ring(host, position, color, 0.35, 0.55, existing), position))
	if StringName(event.get("type", &"")) == &"damage_applied" and quality_tier != &"low":
		var payload: Dictionary = event.get("payload", {})
		camera_impact_requested.emit(position, clampf(float(payload.get("amount", 1)) * 0.01, 0.0, 0.08), 0.12)
		_metrics["camera_requests"] = int(_metrics["camera_requests"]) + 1
	return effects

func _event_position(event: Dictionary) -> Vector3:
	var target_id := StringName(event.get("target_id", &""))
	var actor_id := StringName(event.get("actor_id", &""))
	var target := _resolve_unit(target_id)
	var actor := _resolve_unit(actor_id)
	var event_type := StringName(event.get("type", &""))
	if event_type == &"attack_started" and actor != null and target != null:
		return actor.global_position
	if target != null and event_type in [&"hit_confirmed", &"attack_missed", &"damage_applied", &"unit_healed", &"unit_defeated"]:
		return target.global_position
	if event_type == &"battle_status_changed":
		return board_center
	if actor != null:
		return actor.global_position
	var payload: Dictionary = event.get("payload", {})
	if payload.get("position") is Vector3:
		return payload.position
	return Vector3.ZERO

func _resolve_unit(instance_id: StringName) -> Node3D:
	if instance_id == &"": return null
	var scene := get_parent()
	if scene != null and scene.has_method("get_unit_node"):
		return scene.get_unit_node(instance_id)
	return null

func _secondary_position(event: Dictionary, fallback: Vector3) -> Vector3:
	var payload: Dictionary = event.get("payload", {})
	var partner := _resolve_unit(StringName(payload.get("partner_id", &"")))
	if partner != null:
		return partner.global_position
	var target := _resolve_unit(StringName(event.get("target_id", &"")))
	return target.global_position if target != null else fallback + Vector3(0.8, 0.0, 0.0)

func _is_boss_target(event: Dictionary) -> bool:
	var target := _resolve_unit(StringName(event.get("target_id", &"")))
	if target == null:
		return false
	var state: Variant = target.get("unit_state")
	if state == null:
		state = target.get("state")
	if state != null and state.get("definition") != null:
		return StringName(state.definition.id) in [&"bridge-captain", &"star-eater"]
	return StringName(target.name).contains("captain") or StringName(target.name).contains("boss")

func _acquire(kind: StringName, factory: Callable, position: Vector3) -> Node3D:
	var bucket: Array = _effect_pool.get(kind, [])
	if not bucket.is_empty():
		var node: Node3D = bucket.pop_back()
		_effect_pool[kind] = bucket
		_pooled_effect_count -= 1
		return factory.call(node)
	while _ensure_effect_host().get_child_count() >= MAX_POOLED_EFFECTS and _pooled_effect_count > 0:
		_evict_one_pooled_effect()
	return factory.call()

func _trim_pool_to_cap() -> void:
	while _ensure_effect_host().get_child_count() > MAX_POOLED_EFFECTS and _pooled_effect_count > 0:
		_evict_one_pooled_effect()

func _evict_one_pooled_effect() -> void:
	for kind: StringName in _effect_pool.keys():
		var bucket: Array = _effect_pool[kind]
		if bucket.is_empty():
			continue
		var node: Node3D = bucket.pop_back()
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
		_effect_pool[kind] = bucket
		_pooled_effect_count = maxi(_pooled_effect_count - 1, 0)
		return

func _release_effects(record: Dictionary) -> void:
	for effect: Node3D in record.get("effects", []):
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			_metrics["released_effects"] = int(_metrics["released_effects"]) + 1
			var kind := StringName(effect.get_meta("effect_category", &"ring"))
			if _pooled_effect_count < MAX_POOLED_EFFECTS:
				CombatVfxEffects.reset(effect)
				var bucket: Array = _effect_pool.get(kind, [])
				bucket.append(effect)
				_effect_pool[kind] = bucket
				_pooled_effect_count += 1
			else:
				effect.queue_free()
	_update_peak_metrics()

func _update_peak_metrics() -> void:
	_metrics["peak_active"] = maxi(int(_metrics["peak_active"]), _active.size())
	var particle_count := 0
	for record: Dictionary in _active:
		for effect: Node3D in record.get("effects", []):
			if is_instance_valid(effect) and effect.get_meta("effect_category", &"") == &"particles":
				var particles := effect.get_node_or_null("Particles") as GPUParticles3D
				if particles != null:
					particle_count += particles.amount
	_metrics["peak_particles"] = maxi(int(_metrics["peak_particles"]), particle_count)

func _effect_key_for_event(event: Dictionary) -> StringName:
	match StringName(event.get("type", &"")):
		&"attack_started": return &"attack_trail"
		&"hit_confirmed": return &"hit_impact"
		&"attack_missed": return &"attack_miss"
		&"damage_applied": return &"damage_flash"
		&"unit_healed": return &"heal_ring"
		&"resonance_started": return &"resonance_arc"
		&"resonance_changed": return &"resonance_pulse"
		&"resonance_finished": return &"resonance_fade"
		&"unit_defeated": return &"defeat_dissolve"
		&"battle_status_changed": return &"battle_status_ring"
		_: return &""

func _presentation_key_for_event(event: Dictionary) -> StringName:
	var base_key := _effect_key_for_event(event)
	if base_key in [&"hit_impact", &"damage_flash"] and _is_boss_target(event):
		return &"boss_weak_point"
	return base_key
