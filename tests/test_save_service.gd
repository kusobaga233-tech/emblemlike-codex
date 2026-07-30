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
