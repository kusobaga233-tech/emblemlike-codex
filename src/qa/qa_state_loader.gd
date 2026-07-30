class_name QaStateLoader
extends RefCounted

const ChapterOne = preload("res://src/content/chapter_one.gd")
const SaveService = preload("res://src/core/save_service.gd")
const STATES := {"chapter_one_opening": "res://src/qa/states/chapter_one_opening.json", "chapter_one_boss": "res://src/qa/states/chapter_one_boss.json", "chapter_one_resonance": "res://src/qa/states/chapter_one_resonance.json", "chapter_one_victory": "res://src/qa/states/chapter_one_victory.json"}

static func load_state(id: String) -> Variant:
	if not STATES.has(id): return null
	var file := FileAccess.open(STATES[id], FileAccess.READ)
	if file == null: return null
	var payload = JSON.parse_string(file.get_as_text())
	if not payload is Dictionary: return null
	return SaveService.restore(payload, ChapterOne.build())
