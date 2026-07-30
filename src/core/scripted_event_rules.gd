class_name ScriptedEventRules
extends RefCounted

static func trigger_threshold(trigger: String, prefix: String) -> int:
	if not trigger.begins_with(prefix): return -1
	var suffix := trigger.trim_prefix(prefix)
	if not suffix.is_valid_int(): return -1
	var threshold := int(suffix)
	return threshold if threshold >= 0 else -1

static func deterministic_key(trigger: String) -> Vector2i:
	var round_start := trigger_threshold(trigger, "round-start:")
	if round_start >= 0: return Vector2i(round_start, 0)
	var round_event := trigger_threshold(trigger, "round:")
	if round_event >= 0: return Vector2i(round_event, 1)
	return Vector2i(-1, -1)
