extends TestCase

const TITLE := "res://src/scenes/title/title.tscn"
const DEPLOYMENT := "res://src/scenes/deployment/deployment.tscn"
const HUD := "res://src/ui/battle_hud.tscn"
const FORECAST := "res://src/ui/combat_forecast_panel.tscn"
const RESULT := "res://src/scenes/result/result.tscn"


func run() -> void:
	for path: String in [TITLE, DEPLOYMENT, HUD, FORECAST, RESULT]:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
	if failures.size() > 0:
		return
	await _test_title_flow()
	await _test_deployment_flow()
	await _test_hud_forecast_and_result_flow()


func _test_title_flow() -> void:
	var title := (load(TITLE) as PackedScene).instantiate()
	_add(title)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(title.get_node_or_null("Layout/Title") is Label, "Title has its heading")
	assert_true(title.get_node_or_null("Layout/Start") is Button, "Title has its start button")
	var requests: Array = []
	title.start_pressed.connect(func(path: String): requests.append(path))
	Input.parse_input_event(_key_event(KEY_ENTER))
	await (Engine.get_main_loop() as SceneTree).process_frame
	Input.parse_input_event(_key_event(KEY_ENTER, false, false))
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_equal(requests, [DEPLOYMENT], "Start requests deployment exactly once")
	assert_equal(title.get_viewport().gui_get_focus_owner(), title.get_node("Layout/Start"), "Start owns default focus")
	await _remove(title)


func _test_deployment_flow() -> void:
	var chapter := ChapterOne.build()
	var deployment := (load(DEPLOYMENT) as PackedScene).instantiate()
	deployment.configure(chapter)
	_add(deployment)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_equal(deployment.get_node("Layout/UnitCards").get_child_count(), 4, "Deployment shows four player cards")
	var default_focus := deployment.get_viewport().gui_get_focus_owner()
	assert_equal(default_focus, deployment.get_node("Layout/Actions/Confirm"), "Deployment confirm owns default focus")
	Input.parse_input_event(_key_event(KEY_TAB))
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(deployment.get_viewport().gui_get_focus_owner() != default_focus, "Tab advances deployment focus")
	Input.parse_input_event(_key_event(KEY_TAB, true))
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_equal(deployment.get_viewport().gui_get_focus_owner(), default_focus, "Shift+Tab reverses deployment focus")
	var defaults: Array = deployment.get_deployment()
	assert_equal(defaults.size(), 4, "Deployment exposes four player placements")
	assert_true(deployment.swap_slots(0, 1), "Two player slots can be swapped")
	var swapped: Array = deployment.get_deployment()
	assert_equal(swapped[0]["position"], defaults[1]["position"], "Swap exchanges first position")
	assert_equal(swapped[1]["position"], defaults[0]["position"], "Swap exchanges second position")
	assert_equal(swapped[0]["instance_id"], defaults[0]["instance_id"], "Swap preserves unit identity")
	assert_true(not deployment.swap_slots(0, 99), "Illegal swaps are controlled no-ops")
	var first_card := deployment.get_node("Layout/UnitCards/Unit1") as Button
	first_card.pressed.emit()
	assert_true(first_card.button_pressed, "First deployment click has visible selection state")
	deployment.configure(chapter)
	var after_configure: Array = deployment.get_deployment()
	(deployment.get_node("Layout/UnitCards/Unit2") as Button).pressed.emit()
	assert_equal(deployment.get_deployment(), after_configure, "Configure clears a half-finished swap")
	assert_true((deployment.get_node("Layout/UnitCards/Unit2") as Button).button_pressed, "First click after configure starts a new selection")
	deployment.reset_defaults()
	assert_equal(deployment.get_deployment(), defaults, "Reset restores deterministic defaults")
	(deployment.get_node("Layout/UnitCards/Unit1") as Button).pressed.emit()
	deployment.reset_defaults()
	(deployment.get_node("Layout/UnitCards/Unit2") as Button).pressed.emit()
	assert_equal(deployment.get_deployment(), defaults, "Reset clears a half-finished swap")
	assert_true((deployment.get_node("Layout/UnitCards/Unit2") as Button).button_pressed, "First click after reset starts a new selection")
	var requests: Array = []
	deployment.deployment_confirmed.connect(func(path: String, rows: Array): requests.append([path, rows]))
	deployment.get_node("Layout/Actions/Confirm").pressed.emit()
	assert_equal(requests.size(), 1, "Confirm emits once")
	assert_equal(requests[0][0], "res://src/scenes/battle/battle_scene.tscn", "Confirm requests battle")
	assert_equal(requests[0][1], defaults, "Confirm carries deterministic deployment")
	Input.parse_input_event(_escape_event())
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_equal(deployment.last_navigation_request, TITLE, "Escape returns one layer")
	await _remove(deployment)


func _test_hud_forecast_and_result_flow() -> void:
	var session := BattleSession.new(ChapterOne.build(), 8)
	var hud := (load(HUD) as PackedScene).instantiate()
	hud.configure(session)
	hud.configure(session)
	_add(hud)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_equal(hud.get_viewport().gui_get_focus_owner(), hud.get_node("Layout/Commands/Move"), "HUD move owns default focus")
	assert_true(not hud.get_node("Layout/Objective").text.is_empty(), "HUD displays objective text")
	assert_true(hud.get_node("Layout/Turn").text.contains("1"), "HUD displays turn")
	assert_true(hud.get_node("Layout/Phase").text.contains("player"), "HUD displays phase")
	assert_true(hud.get_node("Layout/Resonance").text.contains("0"), "HUD displays resonance")
	assert_true(hud.get_node("Layout/Commands/Move") is Button, "HUD has move command")
	var commands: Array = []
	var result_requests: Array = []
	hud.command_selected.connect(func(command: StringName): commands.append(command))
	hud.result_requested.connect(func(path: String, summary: Dictionary): result_requests.append([path, summary]))
	hud.get_node("Layout/Commands/Wait").pressed.emit()
	assert_equal(commands, [&"wait"], "Command emits exactly once after repeated configure")
	Input.parse_input_event(_escape_event())
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_equal(commands, [&"wait", &"cancel"], "Escape cancels the current HUD layer")
	session.select_unit(&"fenn-1")
	assert_true(hud.get_node("Layout/SelectedUnit").text.contains("芬恩"), "Session events refresh selected unit")
	session.events_flushed.emit(_terminal_events(&"ongoing"))
	var missing_status: Array[Dictionary] = [{"type": &"battle_status_changed", "actor_id": &"", "target_id": &"", "payload": {}}]
	session.events_flushed.emit(missing_status)
	assert_equal(result_requests.size(), 0, "Invalid terminal statuses do not request or lock result")
	session.events_flushed.emit(_terminal_events(&"victory"))
	session.events_flushed.emit(_terminal_events(&"victory"))
	assert_equal(result_requests.size(), 1, "Repeated terminal events request result only once")
	assert_equal(result_requests[0][0], RESULT, "Terminal battle requests the result scene")
	var victory_summary: Dictionary = result_requests[0][1]
	assert_equal(victory_summary["outcome"], &"victory", "Result summary carries victory")
	assert_equal(victory_summary["turns_used"], session.turn_state.round, "Result summary carries turns")
	assert_equal(victory_summary["surviving_units"], 4, "Result summary carries player survivors")
	assert_true(victory_summary.has("experience_gained"), "Result summary carries experience")

	var defeat_session := BattleSession.new(ChapterOne.build(), 9)
	var defeat_hud := (load(HUD) as PackedScene).instantiate()
	defeat_hud.configure(defeat_session)
	_add(defeat_hud)
	var defeat_requests: Array = []
	defeat_hud.result_requested.connect(func(path: String, summary: Dictionary): defeat_requests.append([path, summary]))
	defeat_session.events_flushed.emit(_terminal_events(&"defeat"))
	assert_equal(defeat_requests.size(), 1, "Defeat requests result once")
	assert_equal(defeat_requests[0][1]["outcome"], &"defeat", "Result summary carries defeat")
	await _remove(defeat_hud)
	defeat_session.events_flushed.emit(_terminal_events(&"defeat"))
	assert_equal(defeat_requests.size(), 1, "Freed HUD receives no terminal callback")

	var panel := (load(FORECAST) as PackedScene).instantiate()
	_add(panel)
	var forecast := CombatForecast.new()
	forecast.damage = 9
	forecast.hit_rate = 83
	forecast.critical_rate = 12
	forecast.strike_count = 2
	forecast.can_counter = true
	forecast.defender_remaining_hp = 7
	panel.show_forecast(forecast)
	assert_equal(panel.get_node("Layout/Damage").text, "Damage: 9", "Forecast shows damage")
	assert_equal(panel.get_node("Layout/HitRate").text, "Hit: 83%", "Forecast shows hit rate")
	assert_equal(panel.get_node("Layout/CriticalRate").text, "Critical: 12%", "Forecast shows critical rate")
	assert_equal(panel.get_node("Layout/StrikeCount").text, "Strikes: 2", "Forecast shows strike count")
	assert_equal(panel.get_node("Layout/Counter").text, "Counter: Yes", "Forecast shows counter status")
	assert_equal(panel.get_node("Layout/RemainingHp").text, "Remaining HP: 7", "Forecast shows projected HP")
	panel.show_forecast(null)
	assert_true(not panel.visible, "Empty forecast safely hides the panel")
	panel.show_forecast({"damage": 99})
	assert_true(not panel.visible, "Malformed forecast safely hides the panel")
	assert_equal(panel.get_node("Layout/Damage").text, "", "Malformed forecast clears stale values")

	var result := (load(RESULT) as PackedScene).instantiate()
	result.configure({"outcome": &"victory", "turns_used": 5, "surviving_units": 3, "experience_gained": 120})
	_add(result)
	assert_equal(result.get_node("Layout/Outcome").text, "VICTORY", "Result displays victory")
	assert_true(result.get_node("Layout/Summary").text.contains("Turns: 5"), "Result displays turns")
	assert_true(result.get_node("Layout/Summary").text.contains("Survivors: 3"), "Result displays survivors")
	assert_true(result.get_node("Layout/Summary").text.contains("Experience: 120"), "Result displays experience")
	var actions: Array = []
	result.result_closed.connect(func(action: StringName, path: String): actions.append([action, path]))
	result.get_node("Layout/Actions/Retry").pressed.emit()
	result.get_node("Layout/Actions/Redeploy").pressed.emit()
	result.get_node("Layout/Actions/Title").pressed.emit()
	assert_equal(actions.size(), 3, "Result exposes all three actions once")
	assert_equal(actions[1], [&"redeploy", DEPLOYMENT], "Redeploy requests deployment")
	await _remove(result)
	await _remove(panel)
	var weak: WeakRef = weakref(hud)
	hud.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	session.events_flushed.emit([])
	assert_true(weak.get_ref() == null, "Freed HUD receives no stale callback")


func _add(node: Node) -> void:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)


func _remove(node: Node) -> void:
	node.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _escape_event() -> InputEventKey:
	return _key_event(KEY_ESCAPE)


func _key_event(keycode: Key, shift_pressed: bool = false, is_pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = is_pressed
	event.shift_pressed = shift_pressed
	return event


func _terminal_events(outcome: StringName) -> Array[Dictionary]:
	return [{"type": &"battle_status_changed", "actor_id": &"", "target_id": &"", "payload": {"from": &"ongoing", "to": outcome}}]
