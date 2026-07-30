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
	assert_true(SaveService.restore(early_resonance, chapter) == null, "Resonance event cannot precede captain event")
	_test_file_durability(session, chapter)
	_test_phase_boundary_continuation(chapter)

func _test_file_durability(session, chapter) -> void:
	var directory := "user://task9-tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory + "/isolated-save.json"
	var first: Dictionary = SaveService.save_file(session, path)
	assert_true(first.ok, "Isolated valid save writes")
	var baseline := FileAccess.get_file_as_bytes(path)
	var backup_failed: Dictionary = SaveService.save_file(session, path, func(stage, _temp, _target, _backup): return ERR_CANT_CREATE if stage == &"backup" else OK)
	assert_true(not backup_failed.ok and backup_failed.error == &"backup_failed", "Backup stage failure is explicit")
	assert_equal(FileAccess.get_file_as_bytes(path), baseline, "Backup failure preserves target")
	var failed: Dictionary = SaveService.save_file(session, path, func(stage, _temp, _target, _backup): return ERR_CANT_CREATE if stage == &"promote" else OK)
	assert_true(not failed.ok and failed.error == &"promote_failed", "Promote failure reports rollback success")
	assert_equal(FileAccess.get_file_as_bytes(path), baseline, "Replace failure preserves valid bytes")
	assert_true(not FileAccess.file_exists(path + ".tmp"), "Replace failure cleans temp")
	var rollback_failed: Dictionary = SaveService.save_file(session, path, func(stage, _temp, _target, _backup): return ERR_CANT_CREATE if stage in [&"promote", &"rollback"] else OK)
	assert_true(not rollback_failed.ok and rollback_failed.error == &"rollback_failed", "Rollback failure is explicit")
	var recovered: Dictionary = SaveService.load_file_result(chapter, path)
	assert_true(recovered.ok and recovered.recovered, "Backup remains loadable after rollback failure")
	assert_true(SaveService.save_file(session, path).ok, "Successful save restores canonical target")
	var malformed_path := directory + "/malformed.json"
	var malformed := FileAccess.open(malformed_path, FileAccess.WRITE); malformed.store_string("{"); malformed.close()
	var load_result: Dictionary = SaveService.load_file_result(chapter, malformed_path)
	assert_true(not load_result.ok and load_result.error == &"malformed_json", "Malformed JSON reports explicit error")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(malformed_path))
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
