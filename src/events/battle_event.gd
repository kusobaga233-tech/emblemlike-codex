class_name BattleEvent
extends RefCounted


static func attack_started(
	actor_id: StringName,
	target_id: StringName,
	distance: int,
) -> Dictionary:
	return _make(&"attack_started", actor_id, target_id, {"distance": distance})


static func hit_confirmed(
	actor_id: StringName,
	target_id: StringName,
	hit_rate: int,
	critical: bool,
	critical_rate: int,
) -> Dictionary:
	return _make(
		&"hit_confirmed",
		actor_id,
		target_id,
		{
			"hit_rate": hit_rate,
			"critical": critical,
			"critical_rate": critical_rate,
		},
	)


static func attack_missed(
	actor_id: StringName,
	target_id: StringName,
	hit_rate: int,
) -> Dictionary:
	return _make(&"attack_missed", actor_id, target_id, {"hit_rate": hit_rate})


static func damage_applied(
	actor_id: StringName,
	target_id: StringName,
	amount: int,
	remaining_hp: int,
) -> Dictionary:
	return _make(
		&"damage_applied",
		actor_id,
		target_id,
		{"amount": amount, "remaining_hp": remaining_hp},
	)


static func unit_defeated(
	actor_id: StringName,
	target_id: StringName,
	remaining_hp: int,
) -> Dictionary:
	return _make(&"unit_defeated", actor_id, target_id, {"remaining_hp": remaining_hp})


static func attack_finished(
	actor_id: StringName,
	target_id: StringName,
	defender_remaining_hp: int,
) -> Dictionary:
	return _make(
		&"attack_finished",
		actor_id,
		target_id,
		{"defender_remaining_hp": defender_remaining_hp},
	)


static func _make(
	event_type: StringName,
	actor_id: StringName,
	target_id: StringName,
	payload: Dictionary,
) -> Dictionary:
	return {
		"type": event_type,
		"actor_id": actor_id,
		"target_id": target_id,
		"payload": payload.duplicate(true),
	}
