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
