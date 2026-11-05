extends TestCase

const BattleScenePath := "res://src/scenes/battle/battle_scene.tscn"
const ThreatRulesScript = preload("res://src/core/threat_rules.gd")


func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	var scene: Variant = load(BattleScenePath).instantiate()
	viewport.add_child(scene)
	await tree.process_frame
	var presenter: Variant = scene.get_node("SpriteCombatPresentation")
	presenter.set_process(false)
	var hud: Variant = scene.get_node("BattleHud")
	var panel: Variant = scene.get_node("TutorialPanel")
	var session: Variant = scene.session
	var tutorial: Variant = scene.tutorial

	# Objective, turn and failure HUD.
	assert_true(hud.get_node("Layout/Objective").text.contains("胜利条件：击败雾桥队长（0/1）"), "HUD shows objective progress")
	assert_true(hud.get_node("Layout/Objective").text.contains("失败条件：奥蕾莉亚阵亡"), "HUD shows the failure condition")
	assert_equal(hud.get_node("Layout/Turn").text, "回合：1 / 20", "HUD shows the turn limit")
	assert_equal(hud.get_node("Layout/Phase").text, "阶段：我方行动", "HUD shows the localized phase")

	# Tutorial starts on movement with a gold ring on the suggested unit.
	assert_true(panel.visible, "Tutorial panel is visible at battle start")
	assert_equal(panel.get_node("Card/Layout/Header/Step").text, "教学 1 / 4", "Tutorial exposes step numbering")
	assert_equal(panel.get_node("Card/Layout/Header/Title").text, "第一步 · 移动", "Tutorial starts on movement")
	assert_true(scene.get_unit_node(&"aurelia-1").get_node("TutorialRing").visible, "Movement step highlights the suggested unit")
	assert_true(scene.get_unit_node(&"aurelia-1").get_node("TutorialMarker").visible, "Tutorial also shows a floating marker above the unit")
	assert_true(not scene.get_unit_node(&"blade-1").get_node("TutorialRing").visible, "Only the current step target is highlighted")
	assert_true(not panel.get_node("Card").get_global_rect().intersects(hud.get_node("Backdrop").get_global_rect()), "Tutorial card avoids the left HUD")
	assert_true(panel.get_node("Card/Layout/Header/Skip").visible, "Tutorial offers an explicit skip")

	# Threat toggle mirrors the pure envelope and clears again.
	var threat_button: CheckButton = hud.get_node("Layout/Threat")
	assert_true(threat_button != null, "HUD exposes the threat toggle")
	await _click(viewport, threat_button)
	var expected: Dictionary = ThreatRulesScript.compute(session.units, session.board_snapshot())
	assert_true(threat_button.button_pressed, "Actual pointer click turns the threat toggle on")
	assert_equal(threat_button.text, "威胁范围：开", "Threat toggle spells out its state")
	assert_equal(scene.get_node("GreyboxBoard/ThreatOverlay/Move").get_child_count(), expected.move.size(), "Threat movement overlay matches rules")
	assert_equal(scene.get_node("GreyboxBoard/ThreatOverlay/Attack").get_child_count(), expected.attack.size(), "Threat attack overlay matches rules")
	await _click(viewport, threat_button)
	assert_true(not threat_button.button_pressed, "Second pointer click turns the threat toggle off")
	assert_equal(threat_button.text, "威胁范围：关", "Threat toggle spells out the disabled state")
	assert_equal(scene.get_node("GreyboxBoard/ThreatOverlay/Move").get_child_count(), 0, "Threat overlay clears when toggled off")

	# Step 1: move Aurelia through the HUD command path.
	session.select_unit(&"aurelia-1")
	scene._on_hud_command(&"move")
	assert_true(scene.handle_board_pick(&"cell", Vector2i(2, 7)), "Move command commits a legal destination")
	presenter.advance(5.0)
	assert_equal(panel.get_node("Card/Layout/Header/Title").text, "第二步 · 攻击", "Committed movement advances the tutorial")
	assert_true(scene.get_unit_node(&"blade-1").get_node("TutorialRing").visible, "Attack step highlights an enemy")
	assert_true(not scene.get_unit_node(&"aurelia-1").get_node("TutorialRing").visible, "Previous step highlight is cleared")

	# Step 2: Fenn attacks a repositioned blade from range three.
	var blade: Variant = session._find_unit(&"blade-1")
	blade.grid_position.x = 1
	blade.grid_position.y = 5
	session.select_unit(&"fenn-1")
	scene._on_hud_command(&"attack")
	assert_true(scene.handle_board_pick(&"unit", &"blade-1"), "Attack locks a legal target")
	assert_true(scene.get_node("CombatForecastPanel").visible, "Attack confirmation is shown")
	scene._confirm_attack()
	presenter.advance(5.0)
	assert_equal(panel.get_node("Card/Layout/Header/Title").text, "第三步 · 治疗", "Confirmed attack advances the tutorial")
	assert_true(session._find_unit(&"fenn-1").acted, "Attack spends Fenn's action")

	# Step 3: Elio heals the injured Aurelia from an adjacent tile.
	var aurelia: Variant = session._find_unit(&"aurelia-1")
	aurelia.current_hp -= 5
	var elio: Variant = session._find_unit(&"elio-1")
	elio.grid_position.x = 2
	elio.grid_position.y = 6
	session.select_unit(&"elio-1")
	scene._on_hud_command(&"support")
	assert_true(scene.handle_board_pick(&"unit", &"aurelia-1"), "Healer locks an injured adjacent ally")
	scene._confirm_support()
	presenter.advance(5.0)
	presenter.advance(5.0)
	scene._on_hud_command(&"support")
	assert_true(scene.handle_board_pick(&"unit", &"aurelia-1"), "Healer locks an injured adjacent ally")
	scene._confirm_support()
	presenter.advance(5.0)
	assert_equal(panel.get_node("Card/Layout/Header/Title").text, "第四步 · 星誓共鸣", "Confirmed heal advances the tutorial")
	assert_true(panel.get_node("Card/Layout/Extra").text.contains("25%"), "Tutorial shows live resonance progress")
	assert_equal(session.resonance_value(), 25, "Heal grants one resonance step")

	# Before full charge the button is visible but disabled and explains why.
	session.select_unit(&"aurelia-1")
	hud._refresh()
	var resonance_button: Button = hud.get_node("Layout/Commands/Resonance")
	assert_true(resonance_button.visible, "Resonance button follows the leader selection")
	assert_true(resonance_button.disabled, "Resonance is disabled below full charge")
	scene._on_hud_command(&"resonance")
	assert_true(hud.get_node("Layout/Feedback").text.contains("100%"), "Insufficient resonance explains the requirement")

	# Prepare a legal target and full gauge.
	blade.grid_position.x = 1
	blade.grid_position.y = 7
	session.resonance_state.value = 100
	hud._refresh()
	assert_true(not resonance_button.disabled, "Resonance button enables at full charge")

	# Cancel once to prove preview cleanup, then run the real command.
	await _click(viewport, resonance_button)
	assert_equal(scene.interaction_mode, &"resonance_partner", "Resonance first asks for a partner")
	assert_equal(scene.get_node("GreyboxBoard/ResonanceOverlay").get_child_count(), 1, "Only the ready adjacent partner is highlighted")
	scene.cancel_interaction()
	assert_equal(scene.get_node("GreyboxBoard/ResonanceOverlay").get_child_count(), 0, "Cancel clears resonance highlights")
	assert_equal(session.resonance_value(), 100, "Cancel does not spend resonance")
	await _click(viewport, resonance_button)
	assert_true(scene.handle_board_pick(&"unit", &"brann-1"), "Adjacent ready partner is accepted")
	assert_equal(scene.interaction_mode, &"resonance_target", "Partner selection moves to target selection")
	assert_true(scene.handle_board_pick(&"unit", &"blade-1"), "In-range enemy is accepted")
	var forecast: Variant = scene.get_node("CombatForecastPanel")
	assert_true(forecast.visible, "Resonance confirmation panel is shown")
	assert_equal(forecast.get_node("Layout/Title").text, "星誓共鸣 · 空誓剑士", "Resonance panel names the target")
	assert_true(forecast.get_node("Layout/Damage").text.contains("17"), "Resonance panel previews rule damage")
	assert_equal(forecast.get_node("Layout/Actions/Confirm").text, "确认共鸣", "Resonance uses an explicit confirm button")
	await tree.process_frame
	await _click(viewport, forecast.get_node("Layout/Actions/Confirm"))
	presenter.advance(5.0)
	assert_equal(session.resonance_value(), 0, "Confirm spends the full resonance gauge")
	assert_true(blade.current_hp <= 1, "Resonance applies the previewed damage")
	assert_true(session._find_unit(&"aurelia-1").acted and session._find_unit(&"brann-1").acted, "Resonance spends both actors")
	assert_true(tutorial.is_finished(), "Resonance finishes the tutorial flow")
	assert_true(not panel.visible, "Tutorial panel hides after completion")
	assert_equal(scene.get_node("GreyboxBoard/ResonanceOverlay").get_child_count(), 0, "Confirmed resonance clears its overlay")
	assert_true(not scene.get_unit_node(&"aurelia-1").get_node("TutorialRing").visible, "Completion clears the tutorial ring")
	assert_true(not scene.get_unit_node(&"aurelia-1").get_node("TutorialMarker").visible, "Completion clears the floating tutorial marker")

	# Skipping a restarted tutorial hides it and clears the ring without touching rules.
	scene.tutorial.reset()
	await tree.process_frame
	assert_true(panel.visible and panel.get_node("Card/Layout/Header/Title").text == "第一步 · 移动", "Restarted tutorial shows the first step")
	await _click(viewport, panel.get_node("Card/Layout/Header/Skip"))
	assert_true(scene.tutorial.is_finished() and not panel.visible, "Skip hides the tutorial")
	assert_true(not scene.get_unit_node(&"aurelia-1").get_node("TutorialRing").visible, "Skip clears the tutorial ring")

	# Defeating the objective target updates progress and the threat envelope.
	scene.session._find_unit(&"captain-1").current_hp = 0
	hud._refresh()
	assert_true(hud.get_node("Layout/Objective").text.contains("击败雾桥队长（1/1）"), "Objective progress follows the rules state")
	threat_button.button_pressed = true
	var after_defeat: Dictionary = ThreatRulesScript.compute(session.units, session.board_snapshot())
	assert_equal(scene.get_node("GreyboxBoard/ThreatOverlay/Move").get_child_count(), after_defeat.move.size(), "Threat refresh excludes defeated enemies")
	assert_true(not after_defeat.by_enemy.has(&"captain-1"), "Defeated captain no longer contributes threat")
	threat_button.button_pressed = false

	viewport.free()


func _click(viewport: SubViewport, control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	viewport.push_input(event, true)
	await (Engine.get_main_loop() as SceneTree).process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await (Engine.get_main_loop() as SceneTree).process_frame
