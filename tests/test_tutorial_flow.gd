extends TestCase

const TutorialFlowScript = preload("res://src/tutorial/tutorial_flow.gd")
const ChapterOneScript = preload("res://src/content/chapter_one.gd")
const BattleSessionScript = preload("res://src/tactics/battle_session.gd")


func run() -> void:
	var session: Variant = BattleSessionScript.new(ChapterOneScript.build(), 7)
	_test_sequential_steps(session)
	_test_out_of_order_demonstrations(session)
	_test_skip_and_reset(session)


func _test_sequential_steps(session: Variant) -> void:
	var flow: Variant = TutorialFlowScript.new()
	var changes: Array = []
	var finished_count := [0]
	flow.step_changed.connect(func(step: Dictionary) -> void: changes.append(step))
	flow.finished.connect(func() -> void: finished_count[0] += 1)
	assert_equal(flow.current_step().id, &"move", "Tutorial starts on movement")
	assert_equal(flow.step_number(), 1, "Tutorial exposes the current step number")
	flow.observe_event(_event(&"unit_moved", &"blade-1"), session)
	assert_equal(flow.current_step().id, &"move", "Enemy movement never completes the player movement step")
	flow.observe_event(_event(&"unit_moved", &"aurelia-1"), session)
	assert_equal(flow.current_step().id, &"attack", "Player movement advances to attack")
	assert_equal(changes.size(), 1, "Advancing emits one step change")
	flow.observe_event(_event(&"unit_acted", &"blade-1", {"action": &"attack"}), session)
	assert_equal(flow.current_step().id, &"attack", "Enemy attacks never complete the player attack step")
	flow.observe_event(_event(&"unit_acted", &"aurelia-1", {"action": &"wait"}), session)
	assert_equal(flow.current_step().id, &"attack", "Waiting does not count as attacking")
	flow.observe_event(_event(&"unit_acted", &"aurelia-1", {"action": &"attack"}), session)
	assert_equal(flow.current_step().id, &"heal", "Player attack advances to healing")
	flow.observe_event(_event(&"unit_acted", &"elio-1", {"action": &"support"}), session)
	assert_equal(flow.current_step().id, &"resonance", "Support action advances to resonance")
	flow.observe_event(_event(&"resonance_finished", &"aurelia-1"), session)
	assert_true(flow.is_finished(), "Resonance finishes the tutorial")
	assert_true(not flow.is_active(), "Finished tutorial is inactive")
	assert_equal(flow.current_step(), {}, "Finished tutorial has no current step")
	assert_equal(finished_count[0], 1, "Finished signal fires exactly once")
	flow.observe_event(_event(&"unit_moved", &"aurelia-1"), session)
	assert_equal(finished_count[0], 1, "Finished tutorial ignores later events")


func _test_out_of_order_demonstrations(session: Variant) -> void:
	var flow: Variant = TutorialFlowScript.new()
	flow.observe_event(_event(&"unit_acted", &"elio-1", {"action": &"support"}), session)
	flow.observe_event(_event(&"unit_acted", &"aurelia-1", {"action": &"attack"}), session)
	assert_equal(flow.current_step().id, &"move", "Out-of-order actions do not skip the pending movement step")
	flow.observe_event(_event(&"unit_moved", &"aurelia-1"), session)
	assert_equal(flow.current_step().id, &"resonance", "Already-demonstrated steps auto-advance once movement completes")
	assert_true(flow.is_active(), "Only the resonance step remains")
	flow.observe_event(_event(&"resonance_finished", &"aurelia-1"), session)
	assert_true(flow.is_finished(), "Out-of-order flow still reaches the end")


func _test_skip_and_reset(session: Variant) -> void:
	var flow: Variant = TutorialFlowScript.new()
	var finished_count := [0]
	flow.finished.connect(func() -> void: finished_count[0] += 1)
	flow.skip()
	assert_true(flow.skipped and flow.is_finished(), "Skip finishes the tutorial")
	assert_equal(flow.current_step(), {}, "Skipped tutorial exposes no step")
	flow.observe_event(_event(&"unit_moved", &"aurelia-1"), session)
	assert_equal(finished_count[0], 1, "Skipped tutorial ignores later events")
	flow.reset()
	assert_true(not flow.skipped and flow.is_active(), "Reset re-arms the tutorial")
	assert_equal(flow.current_step().id, &"move", "Reset returns to the first step")
	assert_equal(flow.step_number(), 1, "Reset restores step numbering")


func _event(type: StringName, actor_id: StringName, payload: Dictionary = {}) -> Dictionary:
	return {"type": type, "actor_id": actor_id, "payload": payload}
