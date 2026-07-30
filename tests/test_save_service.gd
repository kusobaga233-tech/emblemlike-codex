extends "res://tests/test_case.gd"

const ChapterOne = preload("res://src/content/chapter_one.gd")
const BattleSession = preload("res://src/tactics/battle_session.gd")
const SaveService = preload("res://src/core/save_service.gd")

func run() -> void:
	var chapter = ChapterOne.build()
	var session = BattleSession.new(chapter, 77)
	var payload: Dictionary = SaveService.serialize(session)
	assert_true(payload.units[0].has("moved"), "Save schema records movement budget")
	assert_equal(payload.get("version"), 1, "Save schema is versioned")
	var restored = SaveService.restore(payload, chapter)
	assert_true(restored != null, "Valid payload restores")
	if restored != null:
		assert_equal(SaveService.serialize(restored), payload, "Version 1 round trips exactly")
		assert_true(restored.units[0] != session.units[0], "Restore owns independent unit state")
	assert_true(SaveService.restore({"version": 2}, chapter) == null, "Future versions reject")
	assert_true(SaveService.restore({"version": 1, "chapter_id": "chapter-1"}, chapter) == null, "Incomplete payload rejects")
	var duplicate := payload.duplicate(true)
	duplicate.units[1].id = duplicate.units[0].id
	assert_true(SaveService.restore(duplicate, chapter) == null, "Duplicate unit ids reject")
	var overlap := payload.duplicate(true)
	overlap.units[1].x = overlap.units[0].x; overlap.units[1].y = overlap.units[0].y
	assert_true(SaveService.restore(overlap, chapter) == null, "Ambiguous positions reject")
	var migrated := payload.duplicate(true); migrated.erase("version")
	assert_true(SaveService.restore(migrated, chapter) != null, "Unversioned payload migrates")
	assert_equal(SaveService.canonical_json(payload), SaveService.canonical_json(payload.duplicate(true)), "Canonical JSON is stable")
	var canonical_string: Dictionary = SaveService.canonical_result("id")
	var canonical_name: Dictionary = SaveService.canonical_result(&"id")
	assert_true(canonical_string.ok and canonical_name.ok and canonical_string.text != canonical_name.text, "Canonical encoding distinguishes String and StringName")
	assert_equal(SaveService.canonical_result(-0.0).text, SaveService.canonical_result(0.0).text, "Negative zero is canonicalized")
	assert_true(not SaveService.canonical_result(NAN).ok, "Canonical encoding rejects NaN")
	assert_true(not SaveService.canonical_result(INF).ok, "Canonical encoding rejects infinity")
	assert_true(not SaveService.canonical_result(func(): pass).ok, "Canonical encoding rejects Callable")
	var typed_dictionary := {&"name": 1, "value": Vector2i(2, 3), 4: true}
	assert_true(SaveService.canonical_result(typed_dictionary).ok, "Canonical encoding supports typed dictionary keys")
	var invalid_numbers := payload.duplicate(true); invalid_numbers.round = NAN
	assert_true(SaveService.restore(invalid_numbers, chapter) == null, "NaN rejects")
	invalid_numbers.round = INF
	assert_true(SaveService.restore(invalid_numbers, chapter) == null, "Infinity rejects")
	var unknown_event := payload.duplicate(true); unknown_event.fired_event_ids = ["unknown"]
	assert_true(SaveService.restore(unknown_event, chapter) == null, "Unknown event id rejects")
	var duplicate_event := payload.duplicate(true); duplicate_event.fired_event_ids = ["mist-teach", "mist-teach"]
	assert_true(SaveService.restore(duplicate_event, chapter) == null, "Duplicate event id rejects")
	var missing_moved := payload.duplicate(true); missing_moved.units[0].erase("moved")
	assert_true(SaveService.restore(missing_moved, chapter) == null, "Version 1 requires moved")
	var moved_payload := payload.duplicate(true); moved_payload.units[0].moved = true
	var moved_restore = SaveService.restore(moved_payload, chapter)
	assert_true(moved_restore != null and moved_restore.units[0].has_moved, "Moved round trips")
	for field in ["base_seed", "combat_index"]:
		var wrong := payload.duplicate(true); wrong[field] = "1"
		assert_true(SaveService.restore(wrong, chapter) == null, "%s rejects wrong type" % field)
	var wrong_exp := payload.duplicate(true); wrong_exp.units[0].experience = -1
	assert_true(SaveService.restore(wrong_exp, chapter) == null, "Negative experience rejects")
	var wrong_level := payload.duplicate(true); wrong_level.units[0].level = 101
	assert_true(SaveService.restore(wrong_level, chapter) == null, "Excessive level rejects")
	var blocked := payload.duplicate(true); blocked.units[0].x = 2; blocked.units[0].y = 1
	assert_true(SaveService.restore(blocked, chapter) == null, "Water position rejects")
	var false_victory := payload.duplicate(true); false_victory.battle_status = "victory"
	assert_true(SaveService.restore(false_victory, chapter) == null, "Contradictory objective status rejects")
	var enemy_selected := payload.duplicate(true); enemy_selected.phase = "enemy"; enemy_selected.selected_unit_id = "aurelia-1"
	assert_true(SaveService.restore(enemy_selected, chapter) == null, "Enemy phase selected unit rejects")
	var terminal_selected := payload.duplicate(true); terminal_selected.units[4].hp = 0; terminal_selected.battle_status = "victory"; terminal_selected.selected_unit_id = "aurelia-1"
	assert_true(SaveService.restore(terminal_selected, chapter) == null, "Terminal selected unit rejects")
	var early_captain := payload.duplicate(true); early_captain.fired_event_ids = ["mist-teach", "captain-advance"]
	assert_true(SaveService.restore(early_captain, chapter) == null, "Round one captain event rejects")
	var reversed_events := payload.duplicate(true); reversed_events.fired_event_ids = ["captain-advance", "mist-teach"]
	assert_true(SaveService.restore(reversed_events, chapter) == null, "Reversed event timeline rejects")
	var skipped_mist := payload.duplicate(true); skipped_mist.round = 4; skipped_mist.fired_event_ids = ["captain-advance"]
	assert_true(SaveService.restore(skipped_mist, chapter) == null, "Event timeline cannot skip mist")
	var early_resonance := payload.duplicate(true); early_resonance.fired_event_ids = ["mist-teach", "first-resonance"]
	assert_true(SaveService.restore(early_resonance, chapter) != null, "Historical resonance may precede captain event")
	var resonance_then_captain := payload.duplicate(true); resonance_then_captain.round = 4; resonance_then_captain.fired_event_ids = ["mist-teach", "first-resonance", "captain-advance"]
	assert_true(SaveService.restore(resonance_then_captain, chapter) != null, "Resonance then captain causal order restores")
	var captain_then_resonance := payload.duplicate(true); captain_then_resonance.round = 4; captain_then_resonance.fired_event_ids = ["mist-teach", "captain-advance", "first-resonance"]
	assert_true(SaveService.restore(captain_then_resonance, chapter) != null, "Captain then resonance causal order restores")
	_test_file_durability(session, chapter)
	_test_save_preflight(session, chapter)
	_test_resource_limits(payload, chapter)
	_test_phase_boundary_continuation(chapter)

func _test_file_durability(session, chapter) -> void:
	var directory := "user://task9-tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var old_target = BattleSession.new(chapter, 101)
	var old_backup = BattleSession.new(chapter, 202)
	var old_target_text := JSON.stringify(SaveService.serialize(old_target))
	var old_backup_text := JSON.stringify(SaveService.serialize(old_backup))
	for failure_stage in [&"backup", &"promote", &"rollback", &"rotation"]:
		var path := directory + "/%s.json" % failure_stage
		_write_text(path, old_target_text)
		_write_text(path + ".bak", old_backup_text)
		var result: Dictionary = SaveService.save_file(session, path, func(stage, _temp, _target, _backup):
			if stage == failure_stage or (failure_stage == &"rollback" and stage == &"promote"): return ERR_CANT_CREATE
			return OK
		)
		if failure_stage == &"backup":
			assert_true(not result.ok and result.error == &"backup_failed", "Backup-stage failure is explicit")
			assert_equal(FileAccess.get_file_as_string(path), old_target_text, "Backup-stage failure preserves target")
			assert_equal(FileAccess.get_file_as_string(path + ".bak"), old_backup_text, "Backup-stage failure preserves old backup")
		elif failure_stage == &"promote":
			assert_true(not result.ok and result.error == &"promote_failed", "Promote failure reports rollback success")
			assert_equal(FileAccess.get_file_as_string(path), old_target_text, "Promote failure restores target")
			assert_equal(FileAccess.get_file_as_string(path + ".bak"), old_backup_text, "Promote failure preserves old backup")
		elif failure_stage == &"rollback":
			assert_true(not result.ok and result.error == &"rollback_failed", "Rollback failure is explicit")
			assert_true(FileAccess.file_exists(path + ".previous.new"), "Rollback failure preserves staged previous target")
			assert_equal(FileAccess.get_file_as_string(path + ".bak"), old_backup_text, "Rollback failure preserves old backup")
			var rollback_recovered: Dictionary = SaveService.load_file_result(chapter, path)
			assert_true(rollback_recovered.get("ok", false) and rollback_recovered.get("recovered", false) and rollback_recovered.get("source") == &"target", "Rollback failure self-heals previous stage into target")
		else:
			assert_true(result.get("ok", false) and result.get("warning") == &"rotation_failed", "Rotation failure keeps new target with explicit warning")
			assert_equal(FileAccess.get_file_as_string(path + ".bak"), old_backup_text, "Rotation failure preserves old backup")
			assert_true(FileAccess.file_exists(path + ".previous.new"), "Rotation failure preserves previous target")
		assert_true(not FileAccess.file_exists(path + ".tmp"), "Failure path cleans temp")
	var success_path := directory + "/success.json"
	_write_text(success_path, old_target_text)
	_write_text(success_path + ".bak", old_backup_text)
	assert_true(SaveService.save_file(session, success_path).ok, "Successful save promotes canonical target")
	assert_equal(FileAccess.get_file_as_string(success_path + ".bak"), old_target_text, "Successful rotation replaces backup with previous target")
	assert_true(not FileAccess.file_exists(success_path + ".previous.new"), "Successful rotation consumes previous stage")
	var heal_path := directory + "/self-heal.json"
	_write_text(heal_path, old_target_text)
	_write_text(heal_path + ".bak", old_backup_text)
	var interrupted: Dictionary = SaveService.save_file(session, heal_path, func(stage, _temp, _target, _backup): return ERR_CANT_CREATE if stage == &"rotation" else OK)
	assert_true(interrupted.get("ok", false) and interrupted.get("warning") == &"rotation_failed", "Interrupted rotation leaves a recoverable warning state")
	var second_text := FileAccess.get_file_as_string(heal_path)
	var third_session = BattleSession.new(chapter, 303)
	assert_true(SaveService.save_file(third_session, heal_path).ok, "Next save reconciles interrupted rotation before staging")
	assert_equal(FileAccess.get_file_as_string(heal_path), JSON.stringify(SaveService.serialize(third_session)), "Self-healed target contains third payload")
	assert_equal(FileAccess.get_file_as_string(heal_path + ".bak"), second_text, "Self-healed backup contains second payload")
	assert_true(not FileAccess.file_exists(heal_path + ".previous.new"), "Self-healed save clears previous stage")
	var restart_path := directory + "/restart-load.json"
	_write_text(restart_path, "{")
	_write_text(restart_path + ".previous.new", old_target_text)
	_write_text(restart_path + ".bak", old_backup_text)
	var restart_loaded: Dictionary = SaveService.load_file_result(chapter, restart_path)
	assert_true(restart_loaded.get("ok", false), "Restart load recovers a valid previous target")
	assert_equal(FileAccess.get_file_as_string(restart_path), old_target_text, "Restart load restores previous bytes to target")
	assert_equal(FileAccess.get_file_as_string(restart_path + ".bak"), old_backup_text, "Restart recovery preserves older backup")
	assert_true(not FileAccess.file_exists(restart_path + ".previous.new"), "Restart recovery consumes previous stage")
	var stale_path := directory + "/stale-previous.json"
	_write_text(stale_path, old_target_text)
	_write_text(stale_path + ".previous.new", "{")
	_write_text(stale_path + ".bak", old_backup_text)
	assert_true(SaveService.load_file_result(chapter, stale_path).get("ok", false), "Valid target survives invalid previous stage")
	assert_true(not FileAccess.file_exists(stale_path + ".previous.new"), "Invalid previous stage is cleared when another valid slot exists")
	var unrecoverable_path := directory + "/unrecoverable.json"
	_write_text(unrecoverable_path, "{")
	_write_text(unrecoverable_path + ".previous.new", "{")
	var unrecoverable: Dictionary = SaveService.load_file_result(chapter, unrecoverable_path)
	assert_true(not unrecoverable.get("ok", false) and unrecoverable.get("error") == &"recovery_failed", "Invalid target and previous stage report recovery failure")
	var recovery_path := directory + "/recovery.json"
	_write_text(recovery_path, "{")
	_write_text(recovery_path + ".previous.new", old_target_text)
	_write_text(recovery_path + ".bak", old_backup_text)
	var recovered: Dictionary = SaveService.load_file_result(chapter, recovery_path)
	assert_true(recovered.get("ok", false) and recovered.get("recovered", false) and recovered.get("source") == &"target", "Load self-heals previous stage before backup")
	_write_text(recovery_path, "{")
	_write_text(recovery_path + ".previous.new", "{")
	recovered = SaveService.load_file_result(chapter, recovery_path)
	assert_true(recovered.get("ok", false) and recovered.get("recovered", false) and recovered.get("source") == &"backup", "Load falls back to backup after invalid previous stage")
	var malformed_path := directory + "/malformed.json"
	_write_text(malformed_path, "{")
	var load_result: Dictionary = SaveService.load_file_result(chapter, malformed_path)
	assert_true(not load_result.ok and load_result.error == &"malformed_json", "Malformed JSON reports explicit error")
	for file_name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory + "/" + file_name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _test_resource_limits(payload: Dictionary, chapter) -> void:
	var directory := "user://task9-resource-limits"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var oversized_path := directory + "/oversized.json"
	var oversized_file := FileAccess.open(oversized_path, FileAccess.WRITE)
	var oversized_bytes := PackedByteArray()
	oversized_bytes.resize(1024 * 1024 + 1)
	oversized_file.store_buffer(oversized_bytes)
	oversized_file.close()
	var oversized_result: Dictionary = SaveService.load_file_result(chapter, oversized_path)
	assert_true(not oversized_result.ok and oversized_result.error == &"file_too_large", "Save larger than one MiB rejects before parsing")
	var long_id := payload.duplicate(true)
	long_id.units[0].id = "x".repeat(129)
	assert_true(SaveService.restore(long_id, chapter) == null, "Identifiers longer than 128 characters reject")
	assert_true(not SaveService.canonical_result("x".repeat(129)).ok, "Canonical strings longer than 128 characters reject")
	var too_many := []
	too_many.resize(1025)
	assert_true(not SaveService.canonical_result(too_many).ok, "Oversized arrays reject")
	var too_wide := {}
	for index in 1025: too_wide[index] = null
	assert_true(not SaveService.canonical_result(too_wide).ok, "Oversized dictionaries reject")
	var too_deep: Variant = null
	for _index in 33: too_deep = [too_deep]
	assert_true(not SaveService.canonical_result(too_deep).ok, "Excessively nested values reject")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(oversized_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

func _test_phase_boundary_continuation(chapter) -> void:
	var baseline = BattleSession.new(chapter, 91)
	var player_payload = JSON.parse_string(JSON.stringify(SaveService.serialize(baseline)))
	var player_restored = SaveService.restore(player_payload, chapter)
	assert_equal(SaveService.canonical_json(SaveService.serialize(player_restored)), SaveService.canonical_json(SaveService.serialize(baseline)), "Player phase JSON continuation restores exactly")
	for id in [&"aurelia-1", &"brann-1", &"elio-1", &"fenn-1"]:
		assert_true(baseline.select_unit(id).ok and baseline.wait_selected().ok, "Baseline wait is legal")
		assert_true(player_restored.select_unit(id).ok and player_restored.wait_selected().ok, "Restored wait is legal")
	assert_true(baseline.end_player_phase().ok and player_restored.end_player_phase().ok, "Both reach enemy boundary")
	var enemy_payload = JSON.parse_string(JSON.stringify(SaveService.serialize(baseline)))
	var enemy_restored = SaveService.restore(enemy_payload, chapter)
	var baseline_events: Dictionary = baseline.advance_enemy_phase()
	var restored_events: Dictionary = enemy_restored.advance_enemy_phase()
	assert_equal(SaveService.canonical_json(baseline_events.events), SaveService.canonical_json(restored_events.events), "Enemy boundary continuation event digest matches")
	assert_equal(SaveService.canonical_json(SaveService.serialize(baseline)), SaveService.canonical_json(SaveService.serialize(enemy_restored)), "Enemy boundary continuation final state matches")

func _test_save_preflight(session, chapter) -> void:
	var directory := "user://task9-preflight"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory + "/save.json"
	assert_true(SaveService.save_file(session, path).ok, "Preflight baseline writes")
	var target_bytes := FileAccess.get_file_as_bytes(path)
	var backup_bytes := FileAccess.get_file_as_bytes(path + ".bak") if FileAccess.file_exists(path + ".bak") else PackedByteArray()
	for invalid in [null, RefCounted.new()]:
		var result: Dictionary = SaveService.save_file(invalid, path)
		assert_true(not result.ok and result.error == &"invalid_session", "Invalid object fails preflight")
		assert_equal(FileAccess.get_file_as_bytes(path), target_bytes, "Invalid object preserves target")
		assert_equal(FileAccess.get_file_as_bytes(path + ".bak") if FileAccess.file_exists(path + ".bak") else PackedByteArray(), backup_bytes, "Invalid object preserves backup")
	var contradictory = BattleSession.new(chapter, 12); contradictory.battle_status = &"victory"
	assert_true(SaveService.save_file(contradictory, path).error == &"invalid_session", "Contradictory session fails preflight")
	var blocked = BattleSession.new(chapter, 12); blocked.units[0].grid_position.x = 2; blocked.units[0].grid_position.y = 1
	assert_true(SaveService.save_file(blocked, path).error == &"invalid_session", "Blocked session fails preflight")
	assert_true(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".previous.new"), "Preflight creates no stage files")
	for suffix in ["", ".bak", ".tmp", ".previous.new"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
