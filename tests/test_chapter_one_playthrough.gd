extends "res://tests/test_case.gd"

const ChapterOne = preload("res://src/content/chapter_one.gd")
const BattleSession = preload("res://src/tactics/battle_session.gd")
const QaStateLoader = preload("res://src/qa/qa_state_loader.gd")
const SaveService = preload("res://src/core/save_service.gd")

func run() -> void:
	var session = BattleSession.new(ChapterOne.build(), 19)
	assert_equal(session.resonance_value(), 0, "Session owns resonance")
	assert_equal(session.fired_scripted_event_ids, [&"mist-teach"], "Opening event fires once")
	var elio = _unit(session, &"elio-1")
	var brann = _unit(session, &"brann-1")
	brann.current_hp -= 8
	assert_true(session.select_unit(&"elio-1")["ok"], "Select healer")
	var support: Dictionary = session.support_selected(&"brann-1")
	assert_true(support["ok"], "Legal support succeeds")
	assert_equal(brann.current_hp, brann.definition.max_hp, "Support heals eight")
	assert_equal(session.resonance_value(), 25, "Support gains resonance")
	assert_equal(_types(support.events), [&"support_started", &"unit_healed", &"resonance_changed", &"unit_acted"], "Support event order is stable")
	for id in ["chapter_one_opening", "chapter_one_boss", "chapter_one_resonance", "chapter_one_victory"]:
		assert_true(QaStateLoader.load_state(id) != null, "Registered QA state loads: %s" % id)
	assert_true(QaStateLoader.load_state("../chapter_one_opening") == null, "QA traversal rejects")
	var ready = QaStateLoader.load_state("chapter_one_resonance")
	var result: Dictionary = ready.use_resonance_selected(&"brann-1", &"captain-1")
	assert_true(result["ok"], "Full resonance command is legal")
	assert_equal(ready.battle_status, &"victory", "Resonance defeats captain through objective rules")
	var first = QaStateLoader.load_state("chapter_one_opening")
	var second = QaStateLoader.load_state("chapter_one_opening")
	first.units[0].current_hp = 1
	assert_equal(second.units[0].current_hp, second.units[0].definition.max_hp, "QA loads are independent")
	assert_equal(SaveService.canonical_json(SaveService.serialize(second)), SaveService.canonical_json(SaveService.serialize(QaStateLoader.load_state("chapter_one_opening"))), "Fresh QA sessions have identical canonical state")

func _unit(session, id: StringName):
	for unit in session.units:
		if unit.instance_id == id:
			return unit
	return null

func _types(events: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for event in events:
		result.append(StringName(event.type))
	return result
