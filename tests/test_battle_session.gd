extends TestCase

const BATTLE_COMMAND_PATH := "res://src/tactics/battle_command.gd"
const BATTLE_SESSION_PATH := "res://src/tactics/battle_session.gd"
const CHAPTER_ONE_PATH := "res://src/content/chapter_one.gd"

var _battle_command_script: Script
var _battle_session_script: Script
var _chapter_one_script: Script


func run() -> void:
	_battle_command_script = load(BATTLE_COMMAND_PATH) as Script
	_battle_session_script = load(BATTLE_SESSION_PATH) as Script
	_chapter_one_script = load(CHAPTER_ONE_PATH) as Script
	assert_true(_battle_command_script != null, "BattleCommand class exists")
	assert_true(_battle_session_script != null, "BattleSession class exists")
	assert_true(_chapter_one_script != null, "ChapterOne class exists")
	if (
		_battle_command_script == null
		or _battle_session_script == null
		or _chapter_one_script == null
	):
		return

	_test_battle_command_is_typed_data()
	_test_chapter_one_player_flow_enemy_phase_and_round_reset()
	_test_mutations_flush_matching_ordered_events()
	_test_rejected_commands_are_exact_no_ops()
	_test_unit_acted_is_an_exact_no_op()
	_test_wait_selected_marks_only_a_valid_selected_player()
	_test_reachable_cells_match_move_legality_and_block_water()
	_test_occupancy_and_blocking_are_enforced()
	_test_enemy_ai_targets_only_opponents()
	_test_objective_victory_and_defeat_propagate()
	_test_terminal_battle_rejects_every_command_without_mutation()
	_test_fresh_sessions_repeat_ai_and_event_digest()
	_test_phase_change_events_precede_acted_resets()
	_test_phase_methods_cannot_double_advance()


func _test_battle_command_is_typed_data() -> void:
	var move_command: Variant = _battle_command_script.move_selected(Vector2i(3, 6))
	assert_equal(move_command.type, &"move_selected", "Move command type is stable")
	assert_equal(move_command.destination, Vector2i(3, 6), "Move command keeps its destination")
	assert_equal(move_command.unit_id, &"", "Move command does not invent a unit id")
	assert_equal(move_command.target_id, &"", "Move command does not invent a target id")

	var attack_command: Variant = _battle_command_script.confirm_attack(&"blade-1")
	assert_equal(attack_command.type, &"confirm_attack", "Attack command type is stable")
	assert_equal(attack_command.target_id, &"blade-1", "Attack command keeps its target")


func _test_chapter_one_player_flow_enemy_phase_and_round_reset() -> void:
	var session: Variant = _new_session(701)
	var flushed: Array = []
	session.events_flushed.connect(func(events: Array[Dictionary]) -> void:
		flushed.append(events.duplicate(true))
	)

	assert_true(session.select_unit(&"aurelia-1")["ok"], "Aurelia can be selected to open Fenn's route")
	assert_true(session.move_selected(Vector2i(3, 6))["ok"], "Aurelia can move out of Fenn's route")
	assert_true(session.select_unit(&"fenn-1")["ok"], "Fenn can be selected")
	var move_result: Dictionary = session.move_selected(Vector2i(2, 5))
	assert_true(move_result["ok"], "Fenn can make the legal four-cell move")
	assert_equal(_unit(session, &"fenn-1").grid_position.x, 2, "Fenn move commits x")
	assert_equal(_unit(session, &"fenn-1").grid_position.y, 5, "Fenn move commits y")
	assert_equal(_event_types(move_result["events"]), PackedStringArray(["unit_moved"]), "Move emits one matching event")

	var forecast_result: Dictionary = session.forecast_attack(&"blade-1")
	assert_true(forecast_result["ok"], "Fenn can forecast the nearby blade")
	assert_true(forecast_result["forecast"].legal, "Accepted forecast is legal")
	assert_equal(forecast_result["events"], [], "Forecast does not mutate or emit events")
	var attack_result: Dictionary = session.confirm_attack(&"blade-1")
	assert_true(attack_result["ok"], "Fenn can confirm the forecast attack")
	assert_equal(_event_types(attack_result["events"])[0], "attack_started", "Attack events begin with attack_started")
	assert_equal(_event_types(attack_result["events"])[-1], "unit_acted", "Attack marks Fenn acted after combat")
	assert_true(_unit(session, &"fenn-1").acted, "Confirmed attack marks Fenn acted")

	var end_result: Dictionary = session.end_player_phase()
	assert_true(end_result["ok"], "Player phase can end once")
	assert_equal(session.turn_state.phase, &"enemy", "Ending player phase begins enemy phase")
	var enemy_result: Dictionary = session.advance_enemy_phase()
	assert_true(enemy_result["ok"], "Enemy actions can advance once")
	assert_equal(session.turn_state.phase, &"player", "Enemy actions return control to player")
	assert_equal(session.turn_state.round, 2, "Enemy actions finish round one")
	assert_equal(_unit(session, &"fenn-1").acted, false, "Round two resets Fenn's acted flag")
	assert_true(_event_types(enemy_result["events"]).has("phase_changed"), "Enemy advancement emits its phase change")
	assert_equal(flushed[-1], enemy_result["events"], "Signal flush matches the accepted command result")


func _test_mutations_flush_matching_ordered_events() -> void:
	var session: Variant = _new_session(11)
	var flushed: Array = []
	session.events_flushed.connect(func(events: Array[Dictionary]) -> void:
		flushed.append(events.duplicate(true))
	)

	var select_result: Dictionary = session.select_unit(&"fenn-1")
	assert_equal(_event_types(select_result["events"]), PackedStringArray(["unit_selected"]), "Selection emits its mutation")
	assert_equal(flushed.size(), 1, "Mutating selection flushes once")
	assert_equal(flushed[0], select_result["events"], "Selection return and signal events match")
	assert_equal(session.event_queue, [], "Accepted command leaves the event queue flushed")

	for event_value: Variant in select_result["events"]:
		var event: Dictionary = event_value
		assert_equal(event.keys().size(), 4, "Session event has exactly the BattleEvent schema fields")
		assert_true(event.has("type"), "Session event has type")
		assert_true(event.has("actor_id"), "Session event has actor id")
		assert_true(event.has("target_id"), "Session event has target id")
		assert_true(event.has("payload"), "Session event has payload")
		assert_equal(typeof(event["type"]), TYPE_STRING_NAME, "Session event type is StringName")
		assert_equal(typeof(event["actor_id"]), TYPE_STRING_NAME, "Session actor id is StringName")
		assert_equal(typeof(event["target_id"]), TYPE_STRING_NAME, "Session target id is StringName")
		assert_equal(typeof(event["payload"]), TYPE_DICTIONARY, "Session payload is Dictionary")


func _test_rejected_commands_are_exact_no_ops() -> void:
	var session: Variant = _new_session(19)
	var flush_count := [0]
	session.events_flushed.connect(func(_events: Array[Dictionary]) -> void:
		flush_count[0] += 1
	)
	_assert_rejected_no_op(session, func() -> Dictionary: return session.move_selected(Vector2i(0, 0)), &"no_selection", flush_count, "Move without selection")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.forecast_attack(&"blade-1"), &"no_selection", flush_count, "Forecast without selection")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.confirm_attack(&"blade-1"), &"no_selection", flush_count, "Attack without selection")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.select_unit(&"missing"), &"invalid_target", flush_count, "Unknown selection")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.select_unit(&"blade-1"), &"not_friendly", flush_count, "Enemy selection")

	assert_true(session.select_unit(&"fenn-1")["ok"], "Fenn selection establishes later rejection cases")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.move_selected(Vector2i(2, 8)), &"occupied", flush_count, "Occupied destination")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.move_selected(Vector2i(7, 0)), &"out_of_range", flush_count, "Unreachable destination")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.forecast_attack(&"aurelia-1"), &"not_enemy", flush_count, "Friendly forecast target")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.confirm_attack(&"missing"), &"invalid_target", flush_count, "Unknown attack target")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.confirm_attack(&"captain-1"), &"out_of_range", flush_count, "Attack outside range")
	assert_true(session.move_selected(Vector2i(0, 8))["ok"], "First move is legal")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.move_selected(Vector2i(0, 7)), &"already_moved", flush_count, "Second move in one turn")

	assert_true(session.end_player_phase()["ok"], "Player phase ends for wrong-phase validation")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.select_unit(&"fenn-1"), &"wrong_phase", flush_count, "Selection during enemy phase")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.end_player_phase(), &"wrong_phase", flush_count, "Double player phase end")


func _test_wait_selected_marks_only_a_valid_selected_player() -> void:
	var session: Variant = _new_session(705)
	var before: Dictionary = _snapshot(session)
	var rejected: Dictionary = session.wait_selected()
	assert_true(not rejected["ok"], "Wait rejects without a selected unit")
	assert_equal(_snapshot(session), before, "Rejected wait is an exact no-op")
	session.select_unit(&"fenn-1")
	var flushed: Array = []
	session.events_flushed.connect(func(events: Array[Dictionary]) -> void: flushed.append(events))
	var accepted: Dictionary = session.wait_selected()
	assert_true(accepted["ok"], "Selected living player can wait")
	assert_true(_unit(session, &"fenn-1").acted, "Wait marks selected unit acted")
	assert_equal(accepted["events"][0]["type"], &"unit_acted", "Wait emits stable acted event")
	assert_equal(flushed.size(), 1, "Wait flushes exactly once")
	var after: Dictionary = _snapshot(session)
	var repeated: Dictionary = session.wait_selected()
	assert_true(not repeated["ok"], "Acted unit cannot wait twice")
	assert_equal(_snapshot(session), after, "Repeated wait is an exact no-op")


func _test_reachable_cells_match_move_legality_and_block_water() -> void:
	var chapter: Variant = _chapter_one_script.build()
	for row: Dictionary in chapter.deployments:
		if row["instance_id"] == &"fenn-1":
			row["position"] = Vector2i(1, 7)
		elif row["instance_id"] == &"aurelia-1":
			row["position"] = Vector2i(1, 8)
	var session: Variant = _battle_session_script.new(chapter, 706)
	session.select_unit(&"fenn-1")
	var reachable: Array = session.reachable_cells_for_selected()
	assert_true(Vector2i(1, 6) not in reachable, "Reachable cells exclude chapter water")
	for destination: Vector2i in reachable:
		var probe: Variant = _battle_session_script.new(chapter, 706)
		probe.select_unit(&"fenn-1")
		assert_true(probe.move_selected(destination)["ok"], "Every advertised cell is legal on the same snapshot: %s" % destination)


func _test_occupancy_and_blocking_are_enforced() -> void:
	var session: Variant = _new_session(23)
	assert_true(session.select_unit(&"fenn-1")["ok"], "Fenn can be selected for blocking checks")
	var occupied_snapshot: Dictionary = _snapshot(session)
	assert_equal(session.move_selected(Vector2i(2, 8)), {"ok": false, "reason": &"occupied"}, "Living ally occupies Brann's cell")
	assert_equal(_snapshot(session), occupied_snapshot, "Occupied rejection preserves session state")

	var blocked_snapshot: Dictionary = _snapshot(session)
	assert_equal(session.move_selected(Vector2i(3, 7)), {"ok": false, "reason": &"out_of_range"}, "Adjacent units block every short route to the open cell")
	assert_equal(_snapshot(session), blocked_snapshot, "Blocking rejection preserves session state")


func _test_unit_acted_is_an_exact_no_op() -> void:
	var chapter: Variant = _chapter_one_script.build()
	_set_deployment_position(chapter, &"captain-1", Vector2i(2, 6))
	var session: Variant = _battle_session_script.new(chapter, 29)
	var flushed := [0]
	session.events_flushed.connect(func(_events: Array[Dictionary]) -> void:
		flushed[0] += 1
	)
	var fenn: Variant = _unit(session, &"fenn-1")
	fenn.definition.hit = 100
	fenn.definition.critical = 0
	assert_true(session.select_unit(&"fenn-1")["ok"], "Acted fixture selects Fenn")
	assert_true(session.confirm_attack(&"captain-1")["ok"], "Acted fixture spends Fenn's action")
	_assert_rejected_no_op(
		session,
		func() -> Dictionary: return session.select_unit(&"fenn-1"),
		&"unit_acted",
		flushed,
		"Selecting an acted unit",
	)
	_assert_rejected_no_op(
		session,
		func() -> Dictionary: return session.move_selected(Vector2i(0, 8)),
		&"unit_acted",
		flushed,
		"Moving an acted selection",
	)


func _test_enemy_ai_targets_only_opponents() -> void:
	var chapter: Variant = _chapter_one_script.build()
	_set_deployment_position(chapter, &"blade-1", Vector2i(2, 7))
	var session: Variant = _battle_session_script.new(chapter, 101)
	assert_true(session.end_player_phase()["ok"], "Close-range AI fixture enters enemy phase")
	var result: Dictionary = session.advance_enemy_phase()
	assert_true(result["ok"], "Close-range AI fixture advances")

	var enemy_ids := [&"captain-1", &"blade-1", &"bow-1"]
	var player_ids := [&"aurelia-1", &"brann-1", &"elio-1", &"fenn-1"]
	var attacks := 0
	for event_value: Variant in result["events"]:
		var event: Dictionary = event_value
		if event["type"] != &"attack_started":
			continue
		attacks += 1
		assert_true(enemy_ids.has(event["actor_id"]), "AI attack actor is an enemy")
		assert_true(player_ids.has(event["target_id"]), "AI attack target is a player, never an ally")
	assert_true(attacks > 0, "Close-range fixture produces at least one AI attack")


func _test_objective_victory_and_defeat_propagate() -> void:
	var victory_chapter: Variant = _chapter_one_script.build()
	_set_deployment_position(victory_chapter, &"captain-1", Vector2i(2, 6))
	var victory_session: Variant = _battle_session_script.new(victory_chapter, 31)
	var captain: Variant = _unit(victory_session, &"captain-1")
	var fenn: Variant = _unit(victory_session, &"fenn-1")
	captain.current_hp = 1
	fenn.definition.hit = 100
	fenn.definition.critical = 0
	assert_true(victory_session.select_unit(&"fenn-1")["ok"], "Victory fixture selects Fenn")
	var victory_result: Dictionary = victory_session.confirm_attack(&"captain-1")
	assert_true(victory_result["ok"], "Victory fixture confirms lethal attack")
	assert_equal(victory_session.battle_status, &"victory", "Captain defeat propagates victory")
	assert_equal(_event_types(victory_result["events"])[-1], "battle_status_changed", "Victory propagation is the final mutation event")

	var defeat_chapter: Variant = _chapter_one_script.build()
	_set_deployment_position(defeat_chapter, &"blade-1", Vector2i(2, 7))
	var defeat_session: Variant = _battle_session_script.new(defeat_chapter, 37)
	var aurelia: Variant = _unit(defeat_session, &"aurelia-1")
	var blade: Variant = _unit(defeat_session, &"blade-1")
	aurelia.current_hp = 1
	blade.definition.hit = 100
	blade.definition.critical = 0
	assert_true(defeat_session.end_player_phase()["ok"], "Defeat fixture enters enemy phase")
	var defeat_result: Dictionary = defeat_session.advance_enemy_phase()
	assert_true(defeat_result["ok"], "Defeat fixture advances enemy actions")
	assert_equal(defeat_session.battle_status, &"defeat", "Aurelia defeat propagates defeat")
	assert_equal(_event_types(defeat_result["events"])[-1], "battle_status_changed", "Enemy lethal defeat ends with status propagation")
	assert_equal(_event_types(defeat_result["events"]).has("phase_changed"), false, "Enemy lethal defeat does not begin another phase")
	assert_equal(_event_types(defeat_result["events"]).has("unit_ready"), false, "Enemy lethal defeat does not reset acted units")
	assert_equal(defeat_session.turn_state.phase, &"enemy", "Enemy lethal defeat remains in enemy phase")
	assert_equal(defeat_session.turn_state.round, 1, "Enemy lethal defeat remains in the current round")


func _test_terminal_battle_rejects_every_command_without_mutation() -> void:
	var chapter: Variant = _chapter_one_script.build()
	_set_deployment_position(chapter, &"captain-1", Vector2i(2, 6))
	var session: Variant = _battle_session_script.new(chapter, 53)
	var flush_count := [0]
	session.events_flushed.connect(func(_events: Array[Dictionary]) -> void:
		flush_count[0] += 1
	)
	var captain: Variant = _unit(session, &"captain-1")
	var fenn: Variant = _unit(session, &"fenn-1")
	captain.current_hp = 1
	fenn.definition.hit = 100
	fenn.definition.critical = 0
	assert_true(session.select_unit(&"fenn-1")["ok"], "Terminal fixture selects Fenn")
	assert_true(session.confirm_attack(&"captain-1")["ok"], "Terminal fixture reaches victory")
	assert_equal(session.battle_status, &"victory", "Terminal fixture is victorious")

	_assert_rejected_no_op(session, func() -> Dictionary: return session.select_unit(&"aurelia-1"), &"battle_over", flush_count, "Selection after victory")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.move_selected(Vector2i(0, 8)), &"battle_over", flush_count, "Move after victory")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.forecast_attack(&"blade-1"), &"battle_over", flush_count, "Forecast after victory")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.confirm_attack(&"blade-1"), &"battle_over", flush_count, "Attack after victory")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.end_player_phase(), &"battle_over", flush_count, "Player phase end after victory")
	_assert_rejected_no_op(session, func() -> Dictionary: return session.advance_enemy_phase(), &"battle_over", flush_count, "Enemy phase advance after victory")
	assert_equal(session.battle_status, &"victory", "Rejected terminal commands cannot reverse victory")


func _test_fresh_sessions_repeat_ai_and_event_digest() -> void:
	var first: Dictionary = _run_deterministic_round(99017)
	var second: Dictionary = _run_deterministic_round(99017)
	assert_equal(second, first, "Fresh sessions with the same seed repeat AI, events, and final state")


func _test_phase_change_events_precede_acted_resets() -> void:
	var session: Variant = _new_session(47)
	_unit(session, &"blade-1").acted = true
	_unit(session, &"bow-1").acted = true
	var end_result: Dictionary = session.end_player_phase()
	assert_equal(
		_event_types(end_result["events"]),
		PackedStringArray(["phase_changed", "unit_ready", "unit_ready"]),
		"Enemy phase change is emitted before enemy acted resets",
	)
	assert_equal(end_result["events"][1]["actor_id"], &"blade-1", "First enemy ready event keeps deployment order")
	assert_equal(end_result["events"][2]["actor_id"], &"bow-1", "Second enemy ready event keeps deployment order")

	_unit(session, &"aurelia-1").acted = true
	_unit(session, &"fenn-1").acted = true
	var advance_result: Dictionary = session.advance_enemy_phase()
	assert_equal(
		_last_event_types(advance_result["events"], 3),
		PackedStringArray(["phase_changed", "unit_ready", "unit_ready"]),
		"Player phase change is emitted before player acted resets",
	)
	assert_equal(advance_result["events"][-2]["actor_id"], &"aurelia-1", "First player ready event keeps deployment order")
	assert_equal(advance_result["events"][-1]["actor_id"], &"fenn-1", "Second player ready event keeps deployment order")


func _test_phase_methods_cannot_double_advance() -> void:
	var session: Variant = _new_session(43)
	assert_true(session.end_player_phase()["ok"], "First player phase end is accepted")
	var after_end: Dictionary = _snapshot(session)
	assert_equal(session.end_player_phase(), {"ok": false, "reason": &"wrong_phase"}, "Second player phase end is rejected")
	assert_equal(_snapshot(session), after_end, "Double player phase end is a no-op")

	assert_true(session.advance_enemy_phase()["ok"], "First enemy phase advance is accepted")
	var after_advance: Dictionary = _snapshot(session)
	assert_equal(session.advance_enemy_phase(), {"ok": false, "reason": &"wrong_phase"}, "Second enemy phase advance is rejected")
	assert_equal(_snapshot(session), after_advance, "Double enemy phase advance is a no-op")


func _run_deterministic_round(seed: int) -> Dictionary:
	var chapter: Variant = _chapter_one_script.build()
	_set_deployment_position(chapter, &"blade-1", Vector2i(2, 7))
	var session: Variant = _battle_session_script.new(chapter, seed)
	var event_batches: Array = []
	session.events_flushed.connect(func(events: Array[Dictionary]) -> void:
		event_batches.append(events.duplicate(true))
	)
	var end_result: Dictionary = session.end_player_phase()
	var enemy_result: Dictionary = session.advance_enemy_phase()
	return {
		"end_events": end_result["events"],
		"enemy_events": enemy_result["events"],
		"signal_batches": event_batches,
		"state": _snapshot(session),
	}


func _assert_rejected_no_op(
	session: Variant,
	command: Callable,
	reason: StringName,
	flush_count: Array,
	message: String,
) -> void:
	var before_snapshot: Dictionary = _snapshot(session)
	var before_flush_count: int = flush_count[0]
	var result: Dictionary = command.call()
	assert_equal(result, {"ok": false, "reason": reason}, "%s exact rejection" % message)
	assert_equal(session.event_queue, [], "%s leaves event queue unchanged" % message)
	assert_equal(_snapshot(session), before_snapshot, "%s leaves state unchanged" % message)
	assert_equal(flush_count[0], before_flush_count, "%s emits no signal" % message)


func _new_session(seed: int) -> Variant:
	return _battle_session_script.new(_chapter_one_script.build(), seed)


func _unit(session: Variant, instance_id: StringName) -> Variant:
	for unit_value: Variant in session.units:
		if unit_value.instance_id == instance_id:
			return unit_value
	return null


func _set_deployment_position(chapter: Variant, instance_id: StringName, position: Vector2i) -> void:
	for index: int in chapter.deployments.size():
		if chapter.deployments[index].get("instance_id", &"") != instance_id:
			continue
		chapter.deployments[index]["position"] = position
		return


func _snapshot(session: Variant) -> Dictionary:
	var unit_rows: Array = []
	for unit_value: Variant in session.units:
		unit_rows.append({
			"id": unit_value.instance_id,
			"x": unit_value.grid_position.x,
			"y": unit_value.grid_position.y,
			"hp": unit_value.current_hp,
			"acted": unit_value.acted,
		})
	return {
		"units": unit_rows,
		"selected": session.selected_unit_id,
		"phase": session.turn_state.phase,
		"round": session.turn_state.round,
		"status": session.battle_status,
		"event_queue": session.event_queue.duplicate(true),
	}


func _event_types(events: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for event_value: Variant in events:
		result.append(String(event_value["type"]))
	return result


func _last_event_types(events: Array, count: int) -> PackedStringArray:
	var result := PackedStringArray()
	for index: int in range(maxi(0, events.size() - count), events.size()):
		result.append(String(events[index]["type"]))
	return result
