extends TestCase

func run() -> void:
	var path := "res://src/presentation/sprite_combat_presentation.gd"
	assert_true(ResourceLoader.exists(path), "sprite combat timeline exists")
	if not ResourceLoader.exists(path):
		return
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	tree.root.add_child(scene)
	var timeline: Variant = scene.get_node("SpriteCombatPresentation")
	timeline.set_process(false)
	var actor: Variant = scene.get_unit_node(&"aurelia-1")
	var target: Variant = scene.get_unit_node(&"blade-1")
	var sprite: Sprite3D = actor.get_node("ProductionVisual")
	var home := sprite.transform
	var logical_position: Vector3 = actor.position
	var initial_hp: int = target.visual_hp
	var old_state: String = str(scene.session.units.map(func(u: Variant) -> Array: return [u.current_hp, u.acted, u.has_moved, u.grid_position.x, u.grid_position.y]))
	var events: Array[Dictionary] = [
		{"type": &"attack_started", "actor_id": &"aurelia-1", "target_id": &"blade-1", "payload": {"distance": 1}},
		{"type": &"hit_confirmed", "actor_id": &"aurelia-1", "target_id": &"blade-1", "payload": {"critical": false}},
		{"type": &"damage_applied", "actor_id": &"aurelia-1", "target_id": &"blade-1", "payload": {"amount": 6, "remaining_hp": initial_hp - 6}},
		{"type": &"attack_finished", "actor_id": &"aurelia-1", "target_id": &"blade-1", "payload": {}},
	]
	scene.session.events_flushed.emit(events)
	assert_true(timeline.is_busy(), "resolved attack starts timed playback")
	assert_true(not scene.get_node("TacticalCamera").controls_enabled, "camera controls pause during attack so target framing stays stable")
	assert_equal(target.visual_hp, initial_hp, "damage does not appear before impact")
	timeline.advance(0.1)
	assert_true(sprite.transform != home, "whole sprite shows visible anticipation without skeleton")
	assert_equal(actor.position, logical_position, "presentation never moves logical unit root")
	assert_true(not scene.handle_board_pick(&"unit", &"brann-1"), "combat clicks blocked during playback")
	scene._on_hud_command(&"end_phase")
	assert_equal(scene.session.turn_state.phase, &"player", "HUD commands blocked during playback")
	timeline.advance(0.21)
	assert_equal(target.visual_hp, initial_hp - 6, "damage appears on melee impact cue")
	assert_true(timeline.effect_count() > 0, "slash/impact effects visible")
	timeline.advance(1.0)
	assert_true(not timeline.is_busy(), "timeline completes")
	assert_true(scene.get_node("TacticalCamera").controls_enabled, "camera controls restore after attack")
	assert_true(sprite.transform.is_equal_approx(home), "sprite returns exactly to standing anchor")
	assert_equal(str(scene.session.units.map(func(u: Variant) -> Array: return [u.current_hp, u.acted, u.has_moved, u.grid_position.x, u.grid_position.y])), old_state, "presentation never changes rule state")
	# A second strike in the same resolved batch must wait, not hit simultaneously.
	var counter: Array[Dictionary] = events.duplicate(true)
	counter.append_array([
		{"type": &"attack_started", "actor_id": &"blade-1", "target_id": &"aurelia-1", "payload": {"distance": 1}},
		{"type": &"damage_applied", "actor_id": &"blade-1", "target_id": &"aurelia-1", "payload": {"amount": 3, "remaining_hp": 21}},
		{"type": &"attack_finished", "actor_id": &"blade-1", "target_id": &"aurelia-1", "payload": {}},
	] as Array[Dictionary])
	scene.session.events_flushed.emit(counter)
	timeline.advance(0.4)
	assert_equal(actor.visual_hp, 24, "counter damage waits for second strike")
	timeline.advance(0.8)
	assert_equal(actor.visual_hp, 21, "counter damage plays after its impact")
	timeline.clear()
	assert_true(not timeline.is_busy() and timeline.effect_count() == 0, "clear releases all effects and scheduled events")
	assert_true(sprite.transform.is_equal_approx(home), "clear restores sprite anchor")
	# Bow profile has a travelling projectile and later impact.
	var bow_events: Array[Dictionary] = events.duplicate(true)
	for event in bow_events:
		event["actor_id"] = &"fenn-1"
	scene.session.events_flushed.emit(bow_events)
	timeline.advance(0.25)
	assert_equal(timeline.current_style(), &"bow", "archer uses bow profile")
	assert_true(timeline.has_projectile(), "archer launches visible travelling arrow")
	timeline.clear()
	# Heal pulses and HP appear together, without requiring bones or body parts.
	var heal_events: Array[Dictionary] = [
		{"type": &"support_started", "actor_id": &"elio-1", "target_id": &"aurelia-1", "payload": {}},
		{"type": &"unit_healed", "actor_id": &"elio-1", "target_id": &"aurelia-1", "payload": {"amount": 3, "remaining_hp": 24}},
	]
	scene.session.events_flushed.emit(heal_events)
	timeline.advance(0.2)
	assert_equal(actor.visual_hp, 21, "healing HP waits for cast cue")
	timeline.advance(0.15)
	assert_equal(actor.visual_hp, 24, "healing HP matches pulse cue")
	timeline.clear()
	assert_true(not timeline.is_busy(), "healing clears cleanly")

	# Cancelling/reconfiguring mid-attack must not leave the camera input locked.
	scene.get_node("TacticalCamera").controls_enabled = true
	scene.session.events_flushed.emit(events)
	timeline.advance(0.1)
	timeline.clear()
	assert_true(scene.get_node("TacticalCamera").controls_enabled, "cancel restores camera controls")
	scene.session.events_flushed.emit(events)
	scene.setup_battle(scene.chapter)
	assert_true(scene.get_node("TacticalCamera").controls_enabled, "battle reconfigure restores camera controls")

	# A pre-disabled camera must not be spuriously re-enabled by playback.
	scene.get_node("TacticalCamera").controls_enabled = false
	scene.session.events_flushed.emit(events)
	timeline.advance(2.0)
	assert_true(not scene.get_node("TacticalCamera").controls_enabled, "playback preserves pre-disabled camera state")
	timeline.clear()
	scene.free()
