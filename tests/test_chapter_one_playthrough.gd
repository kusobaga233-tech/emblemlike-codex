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
	var run_a := _replay_frozen_playthrough()
	var run_b := _replay_frozen_playthrough()
	assert_equal(run_a.illegal_count, 0, "Frozen playthrough has no illegal commands")
	assert_equal(run_a.support_count, 6, "Frozen playthrough support count is fixed")
	assert_true(run_a.used_resonance, "Frozen playthrough uses resonance")
	assert_equal(run_a.fired_ids, [&"mist-teach", &"captain-advance", &"first-resonance"], "All chapter scripted events fire in order")
	assert_equal(run_a.status, &"victory", "Frozen playthrough reaches victory")
	assert_true(not run_a.player_defeat, "Frozen playthrough never reaches player defeat")
	assert_equal(run_a.last_event, &"battle_status_changed", "Victory status is the terminal event")
	assert_equal(run_a.digest, run_b.digest, "Two fresh runs have identical canonical event digest")
	assert_equal(run_a.final_state, run_b.final_state, "Two fresh runs have identical canonical final state")

func _replay_frozen_playthrough() -> Dictionary:
	var battle = BattleSession.new(ChapterOne.build(), 12)
	var digest: Array = []
	var support_count := 0
	var used_resonance := false
	var illegal_count := 0
	var player_defeat := false
	var commands := [
		["select", "elio-1"], ["wait"], ["select", "aurelia-1"], ["wait"], ["select", "brann-1"], ["move", 2, 5], ["wait"], ["select", "fenn-1"], ["move", 3, 6], ["attack", "blade-1"], ["end"], ["advance"],
		["select", "elio-1"], ["move", 2, 6], ["support", "fenn-1"], ["select", "aurelia-1"], ["wait"], ["select", "brann-1"], ["attack", "blade-1"], ["select", "fenn-1"], ["attack", "bow-1"], ["end"], ["advance"],
		["select", "elio-1"], ["move", 2, 7], ["support", "aurelia-1"], ["select", "aurelia-1"], ["wait"], ["select", "brann-1"], ["attack", "blade-1"], ["select", "fenn-1"], ["move", 2, 4], ["wait"], ["end"], ["advance"],
		["select", "elio-1"], ["move", 0, 7], ["support", "aurelia-1"], ["select", "brann-1"], ["move", 4, 5], ["wait"], ["select", "fenn-1"], ["move", 2, 8], ["wait"], ["select", "aurelia-1"], ["move", 2, 7], ["wait"], ["end"], ["advance"],
		["select", "elio-1"], ["move", 1, 7], ["support", "aurelia-1"], ["select", "aurelia-1"], ["resonance", "fenn-1", "captain-1"], ["select", "brann-1"], ["move", 3, 6], ["attack", "captain-1"], ["end"], ["advance"],
		["select", "elio-1"], ["support", "aurelia-1"], ["select", "aurelia-1"], ["attack", "captain-1"], ["select", "brann-1"], ["attack", "captain-1"], ["select", "fenn-1"], ["attack", "captain-1"], ["end"], ["advance"],
		["select", "elio-1"], ["support", "aurelia-1"], ["select", "aurelia-1"], ["attack", "captain-1"], ["select", "brann-1"], ["attack", "captain-1"], ["select", "fenn-1"], ["attack", "captain-1"],
	]
	for command in commands:
		var result: Dictionary
		match command[0]:
			"select": result = battle.select_unit(StringName(command[1]))
			"move": result = battle.move_selected(Vector2i(command[1], command[2]))
			"wait": result = battle.wait_selected()
			"support": result = battle.support_selected(StringName(command[1])); support_count += 1
			"attack":
				var forecast: Dictionary = battle.forecast_attack(StringName(command[1]))
				if not forecast.get("ok", false): illegal_count += 1
				result = battle.confirm_attack(StringName(command[1]))
			"resonance": result = battle.use_resonance_selected(StringName(command[1]), StringName(command[2])); used_resonance = result.get("ok", false)
			"end": result = battle.end_player_phase()
			"advance": result = battle.advance_enemy_phase()
			_: result = {"ok": false, "reason": &"unknown_test_command"}
		if not result.get("ok", false): illegal_count += 1
		else: digest.append_array(result.get("events", []))
		if battle.battle_status == &"defeat": player_defeat = true
	var event_types := _types(digest)
	var digest_result: Dictionary = SaveService.canonical_result(digest)
	var state_result: Dictionary = SaveService.canonical_result(SaveService.serialize(battle))
	assert_true(digest_result.ok and state_result.ok, "Playthrough digest values are canonically encodable")
	return {"illegal_count": illegal_count, "support_count": support_count, "used_resonance": used_resonance, "fired_ids": battle.fired_scripted_event_ids.duplicate(), "status": battle.battle_status, "player_defeat": player_defeat, "last_event": event_types[-1] if not event_types.is_empty() else &"", "digest": digest_result.text, "final_state": state_result.text}

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
