class_name CombatVfxDirector
extends Node

const CombatVfxEffects := preload("res://src/presentation/combat_vfx_effects.gd")

signal presentation_started(event: Dictionary, presentation_id: StringName)
signal presentation_finished(presentation_id: StringName)

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
		var effect_key := _effect_key_for_event(event)
		if effect_key == &"":
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

func set_quality_tier(tier: StringName) -> void:
	quality_tier = tier if tier in [&"default", &"low"] else &"default"

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
	var position := Vector3.ZERO
	var color := Color(0.92, 0.32, 0.12)
	match effect_key:
		&"attack_trail", &"resonance_arc":
			effects.append(_acquire(&"trail", func() -> Node3D: return CombatVfxEffects.spawn_trail(host, position, Vector3(0.8, 0.0, 0.0), color, 0.35, false), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"trail", func() -> Node3D: return CombatVfxEffects.spawn_trail(host, position, Vector3(0.7, 0.12, 0.0), color.darkened(0.2), 0.3, true), position))
		&"hit_impact", &"attack_miss", &"damage_flash":
			effects.append(_acquire(&"burst", func() -> Node3D: return CombatVfxEffects.spawn_burst(host, position, color, 0.3, bool(event.get("critical", false))), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"particles", func() -> Node3D: return CombatVfxEffects.spawn_particles(host, position, color, 0.3, 10), position))
		&"heal_ring":
			effects.append(_acquire(&"ring", func() -> Node3D: return CombatVfxEffects.spawn_ring(host, position, Color(0.2, 0.85, 0.55), 0.45, 0.7), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"particles", func() -> Node3D: return CombatVfxEffects.spawn_particles(host, position, Color(0.2, 0.85, 0.55), 0.4, 8), position))
		&"defeat_dissolve":
			effects.append(_acquire(&"burst", func() -> Node3D: return CombatVfxEffects.spawn_burst(host, position, Color(0.5, 0.18, 0.62), 0.5, true), position))
			if quality_tier == &"default":
				effects.append(_acquire(&"particles", func() -> Node3D: return CombatVfxEffects.spawn_particles(host, position, Color(0.5, 0.18, 0.62), 0.5, 16), position))
		_:
			effects.append(_acquire(&"ring", func() -> Node3D: return CombatVfxEffects.spawn_ring(host, position, color, 0.35, 0.55), position))
	return effects

func _acquire(kind: StringName, factory: Callable, position: Vector3) -> Node3D:
	var bucket: Array = _effect_pool.get(kind, [])
	if not bucket.is_empty():
		var node: Node3D = bucket.pop_back()
		_effect_pool[kind] = bucket
		_pooled_effect_count -= 1
		CombatVfxEffects.activate(node, position)
		return node
	while _ensure_effect_host().get_child_count() >= MAX_POOLED_EFFECTS and _pooled_effect_count > 0:
		_evict_one_pooled_effect()
	return factory.call()

func _trim_pool_to_cap() -> void:
	while _ensure_effect_host().get_child_count() > MAX_POOLED_EFFECTS:
		_evict_one_pooled_effect()

func _evict_one_pooled_effect() -> void:
	for kind: StringName in _effect_pool.keys():
		var bucket: Array = _effect_pool[kind]
		if bucket.is_empty():
			continue
		var node: Node3D = bucket.pop_back()
		node.queue_free()
		_effect_pool[kind] = bucket
		_pooled_effect_count = maxi(_pooled_effect_count - 1, 0)
		return

func _release_effects(record: Dictionary) -> void:
	for effect: Node3D in record.get("effects", []):
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			var kind := StringName(effect.get_meta("effect_category", &"ring"))
			if _pooled_effect_count < MAX_POOLED_EFFECTS:
				CombatVfxEffects.reset(effect)
				var bucket: Array = _effect_pool.get(kind, [])
				bucket.append(effect)
				_effect_pool[kind] = bucket
				_pooled_effect_count += 1
			else:
				effect.queue_free()

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
