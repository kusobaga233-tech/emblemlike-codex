class_name SaveService
extends RefCounted

const BattleSessionScript = preload("res://src/tactics/battle_session.gd")
const ChapterDefinitionScript = preload("res://src/content/chapter_definition.gd")
const GridPointScript = preload("res://src/core/grid_point.gd")
const SaveDataScript = preload("res://src/core/save_data.gd")
const ObjectiveRulesScript = preload("res://src/core/objective_rules.gd")
const ResonanceStateScript = preload("res://src/core/resonance_state.gd")
const TurnStateScript = preload("res://src/core/turn_state.gd")
const UnitDefinitionScript = preload("res://src/core/unit_definition.gd")
const UnitStateScript = preload("res://src/core/unit_state.gd")
const MAX_SAVE_BYTES := 1024 * 1024
const MAX_STRING_LENGTH := 128
const MAX_CONTAINER_ITEMS := 1024
const MAX_NESTING_DEPTH := 32
const MAX_CANONICAL_NODES := 8192
# SaveService is a main-thread, single-writer service. Reentrant saves to the
# same path are rejected instead of sharing mutable staging slots.
const CONCURRENCY_CONTRACT := &"main_thread_single_writer"
static var _active_save_paths: Dictionary = {}

static func serialize(session: Variant) -> Dictionary:
	var result := serialize_result(session)
	return result.payload if result.ok else {}

static func serialize_result(session: Variant) -> Dictionary:
	if session == null or not session is BattleSessionScript: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	if session.chapter == null or not session.chapter is ChapterDefinitionScript: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	if session.turn_state == null or not session.turn_state is TurnStateScript: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	if session.resonance_state == null or not session.resonance_state is ResonanceStateScript: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	if not session.units is Array or not session.fired_scripted_event_ids is Array: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	if not session.turn_state.round is int or not session.turn_state.phase is StringName: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	if not session.resonance_state.value is int or not session.selected_unit_id is StringName or not session.battle_status is StringName: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	if not session._base_seed is int or not session._combat_index is int: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	var units: Array = []
	for unit in session.units:
		if unit == null or not unit is UnitStateScript: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
		if unit.definition == null or not unit.definition is UnitDefinitionScript: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
		if unit.grid_position == null or not unit.grid_position is GridPointScript: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
		if not unit.instance_id is StringName or not unit.current_hp is int or not unit.acted is bool or not unit.has_moved is bool: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
		if not unit.experience is int or not unit.level is int or not unit.grid_position.x is int or not unit.grid_position.y is int: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
		if not unit.definition.id is StringName or not unit.definition.team is StringName or not unit.definition.max_hp is int: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
		units.append({"id": String(unit.instance_id), "definition_id": String(unit.definition.id), "team": String(unit.definition.team), "x": unit.grid_position.x, "y": unit.grid_position.y, "hp": unit.current_hp, "acted": unit.acted, "moved": unit.has_moved, "experience": unit.experience, "level": unit.level})
	for event_id in session.fired_scripted_event_ids:
		if not event_id is StringName: return {"ok": false, "payload": {}, "reason": &"invalid_session"}
	var payload := {"version": SaveDataScript.VERSION, "chapter_id": String(session.chapter.id), "round": session.turn_state.round, "phase": String(session.turn_state.phase), "selected_unit_id": String(session.selected_unit_id), "battle_status": String(session.battle_status), "resonance": session.resonance_state.value, "fired_event_ids": Array(session.fired_scripted_event_ids).map(func(id): return String(id)), "base_seed": session._base_seed, "combat_index": session._combat_index, "units": units}
	return {"ok": true, "payload": payload, "reason": &""}

static func restore(input: Dictionary, chapter: Variant) -> Variant:
	if not canonical_result(input).ok: return null
	var payload := input.duplicate(true)
	var migrated := not payload.has("version")
	if migrated: payload["version"] = 1
	if not _is_integer(payload.get("version")) or int(payload.get("version")) != 1 or chapter == null or payload.get("chapter_id") != String(chapter.id): return null
	for key in ["round", "phase", "selected_unit_id", "battle_status", "resonance", "fired_event_ids", "base_seed", "combat_index", "units"]:
		if not payload.has(key): return null
	if not _is_integer(payload.round) or payload.round < 1 or payload.round > 100000: return null
	if not _is_integer(payload.base_seed) or payload.base_seed < 0 or payload.base_seed > 2147483647: return null
	if not _is_integer(payload.combat_index) or payload.combat_index < 0 or payload.combat_index > 1000000: return null
	if payload.phase not in ["player", "enemy"] or payload.battle_status not in ["ongoing", "victory", "defeat"]: return null
	if not _is_integer(payload.resonance) or payload.resonance < 0 or payload.resonance > 100 or not payload.units is Array: return null
	if not payload.fired_event_ids is Array: return null
	if payload.fired_event_ids.size() > chapter.events.size(): return null
	var valid_event_ids := {}
	for event: Dictionary in chapter.events:
		var defined_id := String(event.get("id", ""))
		valid_event_ids[defined_id] = event
	var seen_events := {}
	var has_last_deterministic_key := false
	var last_deterministic_key := Vector2i(-1, -1)
	for event_id in payload.fired_event_ids:
		if not event_id is String or not valid_event_ids.has(event_id) or seen_events.has(event_id): return null
		seen_events[event_id] = true
		var definition: Dictionary = valid_event_ids[event_id]
		var deterministic_key := _deterministic_event_key(String(definition.get("trigger", "")))
		if deterministic_key.x >= 0:
			if has_last_deterministic_key and (deterministic_key.x < last_deterministic_key.x or (deterministic_key.x == last_deterministic_key.x and deterministic_key.y < last_deterministic_key.y)): return null
			last_deterministic_key = deterministic_key
			has_last_deterministic_key = true
	for event: Dictionary in chapter.events:
		var trigger := String(event.get("trigger", ""))
		var event_id := String(event.get("id", ""))
		var round_threshold := _trigger_threshold(trigger, "round-start:")
		if round_threshold < 0: round_threshold = _trigger_threshold(trigger, "round:")
		if round_threshold >= 0 and seen_events.has(event_id) != (payload.round >= round_threshold): return null
		var resonance_threshold := _trigger_threshold(trigger, "resonance:")
		if resonance_threshold >= 0 and payload.resonance >= resonance_threshold and not seen_events.has(event_id): return null
	var session = BattleSessionScript.new(chapter, payload.base_seed)
	if payload.units.size() != chapter.deployments.size() or payload.units.size() != session.units.size(): return null
	var seen := {}; var positions := {}
	for state in payload.units:
		if not state is Dictionary: return null
		var required_keys := ["id", "definition_id", "team", "x", "y", "hp", "acted", "experience", "level"]
		if not migrated: required_keys.append("moved")
		for key in required_keys:
			if not state.has(key): return null
		var id := StringName(state.id)
		if id == &"" or seen.has(id): return null
		seen[id] = true
		var unit = session._find_unit(id)
		if unit == null or String(unit.definition.id) != state.definition_id or String(unit.definition.team) != state.team: return null
		if not _is_integer(state.x) or not _is_integer(state.y) or state.x < 0 or state.y < 0 or state.x >= chapter.width or state.y >= chapter.height: return null
		var pos := Vector2i(int(state.x), int(state.y))
		if positions.has(pos): return null
		if chapter.terrain[pos.y * chapter.width + pos.x] == "water": return null
		positions[pos] = true
		if not _is_integer(state.hp) or state.hp < 0 or state.hp > unit.definition.max_hp or not state.acted is bool: return null
		if not _is_integer(state.experience) or state.experience < 0 or state.experience > 1000000: return null
		if not _is_integer(state.level) or state.level < 1 or state.level > 100: return null
		if state.has("moved") and not state.moved is bool: return null
	if not (payload.selected_unit_id is String or payload.selected_unit_id is StringName or payload.selected_unit_id == null): return null
	var selected_id := StringName(payload.selected_unit_id if payload.selected_unit_id != null else "")
	if selected_id != &"" and not seen.has(selected_id): return null
	if selected_id != &"" and (payload.battle_status != "ongoing" or payload.phase != "player"): return null
	for state in payload.units:
		var unit = session._find_unit(StringName(state.id)); unit.grid_position.x = int(state.x); unit.grid_position.y = int(state.y); unit.current_hp = int(state.hp); unit.acted = state.acted; unit.has_moved = bool(state.get("moved", false)); unit.experience = int(state.experience); unit.level = int(state.level)
	if selected_id != &"":
		var selected = session._find_unit(selected_id)
		if selected.current_hp <= 0 or selected.acted or selected.definition.team != &"player": return null
	var evaluated := ObjectiveRulesScript.evaluate(session.units, {"victory": chapter.objectives, "defeat": chapter.failure_conditions})
	if evaluated != StringName(payload.battle_status): return null
	session.turn_state.round = int(payload.round); session.turn_state.phase = StringName(payload.phase); session.selected_unit_id = selected_id; session.battle_status = StringName(payload.battle_status); session.resonance_state.value = int(payload.resonance); session.fired_scripted_event_ids.clear()
	for id in payload.fired_event_ids: session.fired_scripted_event_ids.append(StringName(id))
	session._base_seed = payload.base_seed; session._combat_index = payload.combat_index
	return session

static func save_file(session: Variant, path: String = SaveDataScript.DEFAULT_PATH, replace_strategy: Callable = Callable()) -> Dictionary:
	if _active_save_paths.has(path): return {"ok": false, "error": &"save_in_progress"}
	_active_save_paths[path] = true
	var result := _save_file_internal(session, path, replace_strategy)
	_active_save_paths.erase(path)
	return result

static func _save_file_internal(session: Variant, path: String, replace_strategy: Callable) -> Dictionary:
	var serialization := serialize_result(session)
	if not serialization.ok: return {"ok": false, "error": &"invalid_session"}
	var payload: Dictionary = serialization.payload
	var restored: Variant = restore(payload, session.chapter)
	if restored == null:
		return {"ok": false, "error": &"invalid_session"}
	var payload_result := canonical_result(payload)
	var restored_serialization := serialize_result(restored)
	if not restored_serialization.ok: return {"ok": false, "error": &"invalid_session"}
	var restored_result := canonical_result(restored_serialization.payload)
	if not payload_result.ok or not restored_result.ok or payload_result.text != restored_result.text:
		return {"ok": false, "error": &"invalid_session"}
	var reconciliation := _reconcile_slots(path, session.chapter)
	if not reconciliation.ok: return reconciliation
	var temp := path + ".tmp"
	var backup := path + ".bak"
	var previous := path + ".previous.new"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return {"ok": false, "error": "open_failed"}
	file.store_string(JSON.stringify(payload)); file.close()
	if not _load_one(session.chapter, temp).get("ok", false):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return {"ok": false, "error": &"temp_validation_failed"}
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temp := ProjectSettings.globalize_path(temp)
	var absolute_backup := ProjectSettings.globalize_path(backup)
	var absolute_previous := ProjectSettings.globalize_path(previous)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(previous):
			DirAccess.remove_absolute(absolute_temp)
			return {"ok": false, "error": &"backup_failed"}
		if _stage_error(replace_strategy, &"backup", temp, path, backup) != OK:
			DirAccess.remove_absolute(absolute_temp)
			return {"ok": false, "error": &"backup_failed"}
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_previous)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temp)
			return {"ok": false, "error": &"backup_failed"}
	if _stage_error(replace_strategy, &"promote", temp, path, backup) != OK:
		var rollback_injected := _stage_error(replace_strategy, &"rollback", temp, path, backup)
		var rollback_error := rollback_injected
		if rollback_error == OK and FileAccess.file_exists(previous): rollback_error = DirAccess.rename_absolute(absolute_previous, absolute_path)
		DirAccess.remove_absolute(absolute_temp)
		return {"ok": false, "error": &"rollback_failed" if rollback_error != OK else &"promote_failed"}
	var error := DirAccess.rename_absolute(absolute_temp, absolute_path)
	if error != OK:
		var rollback_error := _stage_error(replace_strategy, &"rollback", temp, path, backup)
		if rollback_error == OK and FileAccess.file_exists(previous): rollback_error = DirAccess.rename_absolute(absolute_previous, absolute_path)
		DirAccess.remove_absolute(absolute_temp)
		return {"ok": false, "error": &"rollback_failed" if rollback_error != OK else &"promote_failed"}
	if FileAccess.file_exists(previous):
		if _stage_error(replace_strategy, &"rotation", temp, path, backup) != OK:
			return {"ok": true, "error": &"", "warning": &"rotation_failed", "backup_retained": FileAccess.file_exists(backup)}
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(absolute_backup) != OK:
			return {"ok": true, "error": &"", "warning": &"rotation_failed", "backup_retained": true}
		if DirAccess.rename_absolute(absolute_previous, absolute_backup) != OK:
			return {"ok": true, "error": &"", "warning": &"rotation_failed", "backup_retained": FileAccess.file_exists(backup)}
	return {"ok": true, "error": &"", "backup_retained": FileAccess.file_exists(backup)}

static func load_file(chapter: Variant, path: String = SaveDataScript.DEFAULT_PATH) -> Variant:
	var result := load_file_result(chapter, path)
	return result.get("session") if result.get("ok", false) else null

static func load_file_result(chapter: Variant, path: String = SaveDataScript.DEFAULT_PATH) -> Dictionary:
	var reconciliation := _reconcile_slots(path, chapter)
	if not reconciliation.ok: return reconciliation
	var primary := _load_one(chapter, path)
	if primary.get("ok", false):
		primary["source"] = &"target"
		primary["recovered"] = reconciliation.get("recovered", false)
		return primary
	var previous := _load_one(chapter, path + ".previous.new")
	if previous.get("ok", false):
		previous["source"] = &"previous"
		previous["recovered"] = true
		previous["primary_error"] = primary.get("error")
		return previous
	var backup := _load_one(chapter, path + ".bak")
	if backup.get("ok", false):
		backup["source"] = &"backup"
		backup["recovered"] = true
		backup["primary_error"] = primary.get("error")
		return backup
	return primary

static func _reconcile_slots(path: String, chapter: Variant) -> Dictionary:
	var previous_path := path + ".previous.new"
	if not FileAccess.file_exists(previous_path): return {"ok": true, "error": &""}
	var target_valid: bool = _load_one(chapter, path).get("ok", false)
	var previous_valid: bool = _load_one(chapter, previous_path).get("ok", false)
	var backup_valid: bool = _load_one(chapter, path + ".bak").get("ok", false)
	var absolute_target := ProjectSettings.globalize_path(path)
	var absolute_previous := ProjectSettings.globalize_path(previous_path)
	var absolute_backup := ProjectSettings.globalize_path(path + ".bak")
	if previous_valid:
		if target_valid:
			if FileAccess.file_exists(path + ".bak") and DirAccess.remove_absolute(absolute_backup) != OK:
				return {"ok": false, "error": &"recovery_failed"}
			if DirAccess.rename_absolute(absolute_previous, absolute_backup) != OK:
				return {"ok": false, "error": &"recovery_failed"}
			return {"ok": true, "error": &"", "recovered": true}
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(absolute_target) != OK:
			return {"ok": false, "error": &"recovery_failed"}
		if DirAccess.rename_absolute(absolute_previous, absolute_target) != OK:
			return {"ok": false, "error": &"recovery_failed"}
		return {"ok": true, "error": &"", "recovered": true}
	if target_valid or backup_valid:
		if DirAccess.remove_absolute(absolute_previous) != OK:
			return {"ok": false, "error": &"recovery_failed"}
		return {"ok": true, "error": &"", "recovered": true}
	return {"ok": false, "error": &"recovery_failed"}

static func _load_one(chapter: Variant, path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "error": &"open_failed"}
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return {"ok": false, "error": &"file_too_large"}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"ok": false, "error": &"malformed_json"}
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return {"ok": false, "error": &"malformed_json"}
	var session: Variant = restore(parsed, chapter)
	if session == null: return {"ok": false, "error": &"invalid_schema"}
	return {"ok": true, "session": session, "recovered": false}

static func _stage_error(strategy: Callable, stage: StringName, temp: String, target: String, backup: String) -> int:
	if not strategy.is_valid(): return OK
	return int(strategy.call(stage, temp, target, backup))

static func canonical_json(value: Variant) -> Variant:
	var result := canonical_result(value)
	return result.text if result.ok else null

static func canonical_result(value: Variant) -> Dictionary:
	return _canonical_typed(value, 0, {"count": 0})

static func _canonical_typed(value: Variant, depth: int, budget: Dictionary) -> Dictionary:
	budget.count += 1
	if budget.count > MAX_CANONICAL_NODES: return {"ok": false, "text": "", "reason": &"too_many_values"}
	if depth > MAX_NESTING_DEPTH: return {"ok": false, "text": "", "reason": &"nesting_too_deep"}
	if value == null: return {"ok": true, "text": "z:null", "reason": &""}
	if value is bool: return {"ok": true, "text": "b:1" if value else "b:0", "reason": &""}
	if value is int: return {"ok": true, "text": "i:%d" % value, "reason": &""}
	if value is float:
		if not is_finite(value): return {"ok": false, "text": "", "reason": &"non_finite_float"}
		var normalized := "0.0" if value == 0.0 else String.num(value, 17)
		return {"ok": true, "text": "f:" + normalized, "reason": &""}
	if value is String:
		if value.length() > MAX_STRING_LENGTH: return {"ok": false, "text": "", "reason": &"string_too_long"}
		return {"ok": true, "text": "s:" + JSON.stringify(value), "reason": &""}
	if value is StringName:
		if String(value).length() > MAX_STRING_LENGTH: return {"ok": false, "text": "", "reason": &"string_too_long"}
		return {"ok": true, "text": "n:" + JSON.stringify(String(value)), "reason": &""}
	if value is Vector2i: return {"ok": true, "text": "v2i:%d,%d" % [value.x, value.y], "reason": &""}
	if value is Array:
		if value.size() > MAX_CONTAINER_ITEMS: return {"ok": false, "text": "", "reason": &"container_too_large"}
		var array_parts: Array[String] = []
		for item in value:
			var item_result := _canonical_typed(item, depth + 1, budget)
			if not item_result.ok: return item_result
			array_parts.append(item_result.text)
		return {"ok": true, "text": "a:%d:[%s]" % [value.size(), ",".join(array_parts)], "reason": &""}
	if value is Dictionary:
		if value.size() > MAX_CONTAINER_ITEMS: return {"ok": false, "text": "", "reason": &"container_too_large"}
		var pairs: Array[String] = []
		var seen_keys := {}
		for key in value:
			var key_result := _canonical_typed(key, depth + 1, budget)
			if not key_result.ok: return {"ok": false, "text": "", "reason": &"unsupported_dictionary_key"}
			if seen_keys.has(key_result.text): return {"ok": false, "text": "", "reason": &"duplicate_canonical_key"}
			seen_keys[key_result.text] = true
			var value_result := _canonical_typed(value[key], depth + 1, budget)
			if not value_result.ok: return value_result
			pairs.append(key_result.text + "=>" + value_result.text)
		pairs.sort()
		return {"ok": true, "text": "d:%d:{%s}" % [value.size(), ",".join(pairs)], "reason": &""}
	return {"ok": false, "text": "", "reason": &"unsupported_type"}

static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

static func _trigger_threshold(trigger: String, prefix: String) -> int:
	if not trigger.begins_with(prefix): return -1
	var suffix := trigger.trim_prefix(prefix)
	if not suffix.is_valid_int(): return -1
	var threshold := int(suffix)
	return threshold if threshold >= 0 else -1

static func _deterministic_event_key(trigger: String) -> Vector2i:
	var round_start := _trigger_threshold(trigger, "round-start:")
	if round_start >= 0: return Vector2i(round_start, 0)
	var round_event := _trigger_threshold(trigger, "round:")
	if round_event >= 0: return Vector2i(round_event, 1)
	return Vector2i(-1, -1)
