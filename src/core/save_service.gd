class_name SaveService
extends RefCounted

const BattleSessionScript = preload("res://src/tactics/battle_session.gd")
const SaveDataScript = preload("res://src/core/save_data.gd")

static func serialize(session: Variant) -> Dictionary:
	if session == null or session.chapter == null: return {}
	var units: Array = []
	for unit in session.units:
		units.append({"id": String(unit.instance_id), "definition_id": String(unit.definition.id), "team": String(unit.definition.team), "x": unit.grid_position.x, "y": unit.grid_position.y, "hp": unit.current_hp, "acted": unit.acted, "experience": unit.experience, "level": unit.level})
	return {"version": SaveDataScript.VERSION, "chapter_id": String(session.chapter.id), "round": session.turn_state.round, "phase": String(session.turn_state.phase), "selected_unit_id": String(session.selected_unit_id), "battle_status": String(session.battle_status), "resonance": session.resonance_value(), "fired_event_ids": Array(session.fired_scripted_event_ids).map(func(id): return String(id)), "base_seed": session._base_seed, "combat_index": session._combat_index, "units": units}

static func restore(input: Dictionary, chapter: Variant) -> Variant:
	var payload := input.duplicate(true)
	if not payload.has("version"): payload["version"] = 1
	if not _is_integer(payload.get("version")) or int(payload.get("version")) != 1 or chapter == null or payload.get("chapter_id") != String(chapter.id): return null
	for key in ["round", "phase", "selected_unit_id", "battle_status", "resonance", "fired_event_ids", "base_seed", "combat_index", "units"]:
		if not payload.has(key): return null
	if not _is_integer(payload.round) or payload.round < 1 or payload.round > 100000: return null
	if payload.phase not in ["player", "enemy"] or payload.battle_status not in ["ongoing", "victory", "defeat"]: return null
	if not _is_integer(payload.resonance) or payload.resonance < 0 or payload.resonance > 100 or not payload.units is Array: return null
	if not payload.fired_event_ids is Array: return null
	var valid_event_ids := {}
	for event: Dictionary in chapter.events: valid_event_ids[String(event.get("id", ""))] = true
	var seen_events := {}
	for event_id in payload.fired_event_ids:
		if not event_id is String or not valid_event_ids.has(event_id) or seen_events.has(event_id): return null
		seen_events[event_id] = true
	var session = BattleSessionScript.new(chapter, payload.base_seed)
	if payload.units.size() != session.units.size(): return null
	var seen := {}; var positions := {}
	for state in payload.units:
		if not state is Dictionary: return null
		for key in ["id", "definition_id", "team", "x", "y", "hp", "acted", "experience", "level"]:
			if not state.has(key): return null
		var id := StringName(state.id)
		if id == &"" or seen.has(id): return null
		seen[id] = true
		var unit = session._find_unit(id)
		if unit == null or String(unit.definition.id) != state.definition_id or String(unit.definition.team) != state.team: return null
		if not _is_integer(state.x) or not _is_integer(state.y) or state.x < 0 or state.y < 0 or state.x >= chapter.width or state.y >= chapter.height: return null
		var pos := Vector2i(int(state.x), int(state.y))
		if positions.has(pos): return null
		positions[pos] = true
		if not _is_integer(state.hp) or state.hp < 0 or state.hp > unit.definition.max_hp or not state.acted is bool: return null
	if payload.selected_unit_id != "" and not seen.has(StringName(payload.selected_unit_id)): return null
	for state in payload.units:
		var unit = session._find_unit(StringName(state.id)); unit.grid_position.x = int(state.x); unit.grid_position.y = int(state.y); unit.current_hp = int(state.hp); unit.acted = state.acted; unit.experience = int(state.experience); unit.level = int(state.level)
	session.turn_state.round = int(payload.round); session.turn_state.phase = StringName(payload.phase); session.selected_unit_id = StringName(payload.selected_unit_id); session.battle_status = StringName(payload.battle_status); session.resonance_state.value = int(payload.resonance); session.fired_scripted_event_ids.clear()
	for id in payload.fired_event_ids: session.fired_scripted_event_ids.append(StringName(id))
	session._base_seed = payload.base_seed; session._combat_index = payload.combat_index
	return session

static func save_file(session: Variant, path: String = SaveDataScript.DEFAULT_PATH) -> Dictionary:
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
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK: return {"ok": false, "error": backup_error}
	var error := DirAccess.rename_absolute(absolute_temp, absolute_path)
	if error != OK and FileAccess.file_exists(backup): DirAccess.rename_absolute(absolute_backup, absolute_path)
	elif error == OK and FileAccess.file_exists(backup): DirAccess.remove_absolute(absolute_backup)
	return {"ok": error == OK, "error": error}

static func load_file(chapter: Variant, path: String = SaveDataScript.DEFAULT_PATH) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return null
	return restore(parsed, chapter)

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
