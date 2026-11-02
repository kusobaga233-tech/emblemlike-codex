extends TestCase

func run() -> void:
	var session: Variant = load("res://src/tactics/battle_session.gd").new(load("res://src/content/chapter_one.gd").build(), 41)
	assert_true(session.has_method("forecast_support"), "support has read-only rule forecast")
	if not session.has_method("forecast_support"): return
	session.select_unit(&"elio-1")
	var actor: Variant = session._find_unit(&"elio-1")
	var target: Variant = session._find_unit(&"aurelia-1")
	target.grid_position.x = 3
	target.grid_position.y = 7
	target.current_hp = target.definition.max_hp - 3
	var signals: Array = []
	session.events_flushed.connect(func(events: Array[Dictionary]): signals.append(events))
	var prediction: Dictionary = session.forecast_support(&"aurelia-1")
	assert_true(prediction.get("ok", false), "adjacent injured friend is forecastable")
	assert_equal(prediction.forecast.amount, 3, "heal forecast caps at missing HP")
	assert_equal(prediction.forecast.remaining_hp, target.definition.max_hp, "forecast shows target final HP")
	assert_equal(signals.size(), 0, "forecast emits no mutation events")
	assert_true(not actor.acted and target.current_hp == target.definition.max_hp - 3 and session.resonance_value() == 0, "forecast never mutates action HP or resonance")
	target.current_hp = target.definition.max_hp
	assert_equal(session.forecast_support(&"aurelia-1").get("reason"), &"full_hp", "full HP forecast refused")
	assert_equal(session.support_selected(&"aurelia-1").get("reason"), &"full_hp", "confirmation rechecks changed target")
	target.current_hp -= 9
	assert_equal(session.forecast_support(&"aurelia-1").forecast.amount, 8, "normal forecast uses existing eight HP heal")
	target.grid_position.y = 6
	assert_equal(session.forecast_support(&"aurelia-1").get("reason"), &"out_of_range", "distant friend refused")
	target.grid_position.y = 7
	session.select_unit(&"fenn-1")
	assert_equal(session.forecast_support(&"aurelia-1").get("reason"), &"not_healer", "non healer has no support forecast")
	session.select_unit(&"elio-1")
	session.wait_selected()
	assert_equal(session.forecast_support(&"aurelia-1").get("reason"), &"unit_acted", "acted healer cannot preview")
	await _test_scene()


func _test_scene() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(scene)
	var hud: Variant = scene.get_node("BattleHud")
	var support: Button = hud.get_node_or_null("Layout/Commands/Support")
	assert_true(support != null, "HUD exposes healer support button")
	if support == null:
		viewport.free()
		return
	var presenter: Variant = scene.get_node("SpriteCombatPresentation")
	presenter.set_process(false)
	assert_true(hud.get_node("Layout/Commands/Move").disabled, "move unavailable without selection")
	assert_true(hud.get_node("Layout/Commands/Wait").disabled, "wait unavailable without selection")
	assert_true(not hud.get_node("Layout/Commands/EndPhase").disabled, "end phase needs no unit selection")
	scene.session.select_unit(&"elio-1")
	assert_true(support.visible and not support.disabled, "healer exposes ready support")
	var target: Variant = scene.session._find_unit(&"aurelia-1")
	target.grid_position.x = 3
	target.grid_position.y = 7
	target.current_hp -= 3
	var old_hp: int = target.current_hp
	scene._present_event({"type": &"damage_applied", "actor_id": &"blade-1", "target_id": &"aurelia-1", "payload": {"amount": 3, "remaining_hp": old_hp}})
	support.pressed.emit()
	assert_equal(scene.interaction_mode, &"support", "support button enters ally target mode")
	assert_true(scene.handle_board_pick(&"unit", &"aurelia-1"), "click selects healing target")
	var panel: Variant = scene.get_node("CombatForecastPanel")
	assert_true(panel.visible and panel.get_node("Layout/Actions/Confirm").visible, "selected target opens confirmation")
	assert_true(panel.get_node("Layout/Damage").text.contains("3"), "preview shows capped amount")
	assert_true(not panel.get_node("Layout/HitRate").visible, "support preview hides irrelevant combat rows")
	await tree.process_frame
	assert_true(panel.position.x >= hud.get_node("Backdrop").size.x + 10, "confirmation panel does not overlap HUD")
	assert_equal(target.current_hp, old_hp, "target click only previews")
	assert_true(not scene.session._find_unit(&"elio-1").acted, "target click does not spend action")
	assert_equal(scene.session.forecast_support(&"blade-1").get("reason"), &"invalid_target", "enemy cannot be healed")
	assert_equal(scene.session.forecast_support(&"elio-1").get("reason"), &"invalid_target", "healer cannot target self")
	# Moving pointer away must not clear a selected support preview.
	scene._on_cell_hovered(Vector2i(4, 4))
	assert_true(panel.visible and scene.pending_target_id == &"aurelia-1", "support preview stays while pointer enters confirm UI")
	panel.get_node("Layout/Actions/Cancel").pressed.emit()
	assert_true(not panel.visible, "cancel hides preview without healing")
	assert_equal(target.current_hp, old_hp, "cancel preserves HP")
	assert_equal(scene.session.selected_unit_id, &"elio-1", "cancel keeps healer selected")
	# Revalidation on stale selected target must be a visible no-op.
	support.pressed.emit()
	scene.handle_board_pick(&"unit", &"aurelia-1")
	target.current_hp = target.definition.max_hp
	panel.get_node("Layout/Actions/Confirm").pressed.emit()
	assert_true(not scene.session._find_unit(&"elio-1").acted and not panel.visible, "stale full-HP confirm cannot spend action")
	assert_true(hud.get_node("Layout/Feedback").text.contains("已满"), "stale confirm explains refusal")
	target.current_hp = old_hp
	scene.handle_board_pick(&"unit", &"aurelia-1")
	await tree.process_frame
	await _click(viewport, panel.get_node("Layout/Actions/Confirm"))
	assert_equal(target.current_hp, target.definition.max_hp, "explicit confirm commits support rule")
	assert_true(scene.combat_presentation_busy(), "heal displays through timeline")
	assert_true(hud.get_node("Layout/Commands/EndPhase").disabled and support.disabled, "presentation locks actual buttons")
	assert_equal(scene.get_unit_node(&"aurelia-1").visual_hp, old_hp, "visible heal HP waits until cue despite committed logical HP")
	presenter.advance(0.2)
	assert_equal(scene.get_unit_node(&"aurelia-1").visual_hp, old_hp, "windup still shows original HP")
	presenter.advance(0.8)
	assert_equal(scene.get_unit_node(&"aurelia-1").visual_hp, target.definition.max_hp, "healing HP displayed after cue")
	assert_true(not hud.get_node("Layout/Commands/EndPhase").disabled and support.disabled, "timeline restores phase button but not spent unit")
	assert_true(not scene.handle_board_right_click(&"unit"), "right click cannot undo spent support")
	# Full HP refusal is visible and does not spend a fresh healer action.
	scene.session._find_unit(&"elio-1").acted = false
	scene.session.select_unit(&"elio-1")
	support.pressed.emit()
	assert_true(not scene.handle_board_pick(&"unit", &"aurelia-1"), "full HP ally rejected in scene")
	assert_true(hud.get_node("Layout/Feedback").text.contains("已满"), "invalid target has actionable localized reason")
	assert_true(not scene.session._find_unit(&"elio-1").acted, "rejected target leaves action available")
	# Right-click keeps the prior committed-input contract during support preview.
	scene.cancel_interaction()
	scene.session.move_selected(Vector2i(4, 8))
	var healer: Variant = scene.get_unit_node(&"elio-1")
	healer.position_animation.custom_step(1.0)
	assert_true(hud.get_node("Layout/Commands/Move").disabled, "moved unit cannot move again without undo")
	support.pressed.emit()
	assert_true(scene.handle_board_right_click(&"unit"), "support mode preserves right-click undo priority")
	healer.position_animation.custom_step(1.0)
	assert_true(not hud.get_node("Layout/Commands/Move").disabled, "undo restores Move button availability")
	viewport.free()


func _click(viewport: SubViewport, button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	viewport.push_input(event, true)
	await (Engine.get_main_loop() as SceneTree).process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await (Engine.get_main_loop() as SceneTree).process_frame
