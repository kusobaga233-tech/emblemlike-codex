class_name SaveService
extends RefCounted

const BattleSessionScript = preload("res://src/tactics/battle_session.gd")
const SaveDataScript = preload("res://src/core/save_data.gd")
const ObjectiveRulesScript = preload("res://src/core/objective_rules.gd")

static func serialize(session: Variant) -> Dictionary:
	if session == null or session.chapter == null: return {}
	var units: Array = []
	for unit in session.units:
		units.append({"id": String(unit.instance_id), "definition_id": String(unit.definition.id), "team": String(unit.definition.team), "x": unit.grid_position.x, "y": unit.grid_position.y, "hp": unit.current_hp, "acted": unit.acted, "moved": unit.has_moved, "experience": unit.experience, "level": unit.level})
	return {"version": SaveDataScript.VERSION, "chapter_id": String(session.chapter.id), "round": session.turn_state.round, "phase": String(session.turn_state.phase), "selected_unit_id": String(session.selected_unit_id), "battle_status": String(session.battle_status), "resonance": session.resonance_value(), "fired_event_ids": Array(session.fired_scripted_event_ids).map(func(id): return String(id)), "base_seed": session._base_seed, "combat_index": session._combat_index, "units": units}

static func restore(input: Dictionary, chapter: Variant) -> Variant:
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
	var valid_event_ids := {}
	var defined_event_ids: Array[String] = []
	for event: Dictionary in chapter.events:
		var defined_id := String(event.get("id", ""))
		valid_event_ids[defined_id] = true
		defined_event_ids.append(defined_id)
	var seen_events := {}
	for event_id in payload.fired_event_ids:
		if not event_id is String or not valid_event_ids.has(event_id) or seen_events.has(event_id): return null
		seen_events[event_id] = true
	for index in payload.fired_event_ids.size():
		if index >= defined_event_ids.size() or payload.fired_event_ids[index] != defined_event_ids[index]: return null
	for event: Dictionary in chapter.events:
		var trigger := String(event.get("trigger", ""))
		if trigger.begins_with("round:") and seen_events.has(String(event.get("id", ""))) and payload.round < int(trigger.get_slice(":", 1)): return null
		var required: bool = trigger == "round-start:1" or (trigger.begins_with("round:") and payload.round >= int(trigger.get_slice(":", 1))) or (trigger == "resonance:100" and payload.resonance == 100)
		if required and not seen_events.has(String(event.get("id", ""))): return null
	var session = BattleSessionScript.new(chapter, payload.base_seed)
	if payload.units.size() != session.units.size(): return null
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
	var temp := path + ".tmp"
	var backup := path + ".bak"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return {"ok": false, "error": "open_failed"}
	file.store_string(JSON.stringify(serialize(session))); file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temp := ProjectSettings.globalize_path(temp)
	var absolute_backup := ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path):
		if _stage_error(replace_strategy, &"backup", temp, path, backup) != OK:
			DirAccess.remove_absolute(absolute_temp)
			return {"ok": false, "error": &"backup_failed"}
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temp)
			return {"ok": false, "error": &"backup_failed"}
	if _stage_error(replace_strategy, &"promote", temp, path, backup) != OK:
		var rollback_injected := _stage_error(replace_strategy, &"rollback", temp, path, backup)
		var rollback_error := rollback_injected
		if rollback_error == OK and FileAccess.file_exists(backup): rollback_error = DirAccess.rename_absolute(absolute_backup, absolute_path)
		DirAccess.remove_absolute(absolute_temp)
		return {"ok": false, "error": &"rollback_failed" if rollback_error != OK else &"promote_failed"}
	var error := DirAccess.rename_absolute(absolute_temp, absolute_path)
	if error != OK:
		var rollback_error := _stage_error(replace_strategy, &"rollback", temp, path, backup)
		if rollback_error == OK and FileAccess.file_exists(backup): rollback_error = DirAccess.rename_absolute(absolute_backup, absolute_path)
		DirAccess.remove_absolute(absolute_temp)
		return {"ok": false, "error": &"rollback_failed" if rollback_error != OK else &"promote_failed"}
	return {"ok": true, "error": &"", "backup_retained": FileAccess.file_exists(backup)}

static func load_file(chapter: Variant, path: String = SaveDataScript.DEFAULT_PATH) -> Variant:
	var result := load_file_result(chapter, path)
	return result.get("session") if result.get("ok", false) else null

static func load_file_result(chapter: Variant, path: String = SaveDataScript.DEFAULT_PATH) -> Dictionary:
	var primary := _load_one(chapter, path)
	if primary.get("ok", false): return primary
	var backup := _load_one(chapter, path + ".bak")
	if backup.get("ok", false):
		backup["recovered"] = true
		backup["primary_error"] = primary.get("error")
		return backup
	return primary

static func _load_one(chapter: Variant, path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "error": &"open_failed"}
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

static func canonical_json(value: Variant) -> String:
	return _canonical(value)

static func _canonical(value: Variant) -> String:
	if value == null: return "null"
	if value is bool: return "true" if value else "false"
	if value is int: return str(value)
	if value is float:
		if not is_finite(value): return ""
		return str(value)
	if value is String or value is StringName: return JSON.stringify(String(value))
	if value is Vector2i: return "{\"x\":%d,\"y\":%d}" % [value.x, value.y]
	if value is Array:
		var parts: Array[String] = []
		for item in value: parts.append(_canonical(item))
		return "[" + ",".join(parts) + "]"
	if value is Dictionary:
		var keys: Array[String] = []
		for key in value: keys.append(String(key))
		keys.sort()
		var parts: Array[String] = []
		for key in keys: parts.append(JSON.stringify(key) + ":" + _canonical(value[key]))
		return "{" + ",".join(parts) + "}"
	return ""

static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))
