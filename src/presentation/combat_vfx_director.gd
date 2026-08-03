class_name CombatVfxDirector
extends Node

signal presentation_started(event: Dictionary, presentation_id: StringName)
signal presentation_finished(presentation_id: StringName)

const MAX_ACTIVE_PRESENTATIONS := 64
var quality_tier: StringName = &"default"
var _active: Array[Dictionary] = []
var _diagnostics: Dictionary = {}
var _sequence: int = 0

func play_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		var effect_key := _effect_key_for_event(event)
		if effect_key == &"":
			var event_type := StringName(event.get("type", &""))
			_diagnostics[event_type] = int(_diagnostics.get(event_type, 0)) + 1
			continue
		_sequence += 1
		var presentation_id := StringName("%s_%d" % [effect_key, _sequence])
		if _active.size() >= MAX_ACTIVE_PRESENTATIONS:
			var evicted: Dictionary = _active.pop_front()
			presentation_finished.emit(StringName(evicted.get("id", &"")))
		_active.append({"id": presentation_id, "event": event, "effect_key": effect_key})
		presentation_started.emit(event, presentation_id)

func set_quality_tier(tier: StringName) -> void:
	quality_tier = tier if tier in [&"default", &"low"] else &"default"

func clear_active_presentations() -> void:
	for record: Dictionary in _active:
		presentation_finished.emit(StringName(record.get("id", &"")))
	_active.clear()

func active_presentation_count() -> int:
	return _active.size()

func diagnostic_count(event_type: StringName) -> int:
	return int(_diagnostics.get(event_type, 0))

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
