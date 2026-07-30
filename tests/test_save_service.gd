extends "res://tests/test_case.gd"

const ChapterOne = preload("res://src/content/chapter_one.gd")
const BattleSession = preload("res://src/tactics/battle_session.gd")
const SaveService = preload("res://src/core/save_service.gd")

func run() -> void:
	var chapter = ChapterOne.build()
	var session = BattleSession.new(chapter, 77)
	var payload: Dictionary = SaveService.serialize(session)
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
	_test_file_durability(session, chapter)
	_test_phase_boundary_continuation(chapter)

func _test_file_durability(session, chapter) -> void:
	var directory := "user://task9-tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory + "/isolated-save.json"
	var first: Dictionary = SaveService.save_file(session, path)
	assert_true(first.ok, "Isolated valid save writes")
	var baseline := FileAccess.get_file_as_bytes(path)
	var failed: Dictionary = SaveService.save_file(session, path, func(_temp, _target, _backup): return ERR_CANT_CREATE)
	assert_true(not failed.ok, "Injected replace failure reports error")
	assert_equal(FileAccess.get_file_as_bytes(path), baseline, "Replace failure preserves valid bytes")
	assert_true(not FileAccess.file_exists(path + ".tmp"), "Replace failure cleans temp")
	var malformed_path := directory + "/malformed.json"
	var malformed := FileAccess.open(malformed_path, FileAccess.WRITE); malformed.store_string("{"); malformed.close()
	var load_result: Dictionary = SaveService.load_file_result(chapter, malformed_path)
	assert_true(not load_result.ok and load_result.error == &"malformed_json", "Malformed JSON reports explicit error")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
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
