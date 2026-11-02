extends TestCase

const UNIT = preload("res://src/presentation/greybox_unit.gd")
const SESSION = preload("res://src/tactics/battle_session.gd")
const CHAPTER = preload("res://src/content/chapter_one.gd")

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session := SESSION.new(CHAPTER.build())
	for state: Variant in session.units:
		var unit: Variant = UNIT.new()
		tree.root.add_child(unit)
		unit.configure(state)
		var sprite := unit.get_node_or_null("ProductionVisual") as Sprite3D
		assert_true(sprite != null, "each combatant uses a static Sprite3D: %s" % state.instance_id)
		if sprite != null:
			assert_true(sprite.texture != null, "static sprite texture exists")
			assert_true(sprite.texture.resource_path.contains("units_v03"), "uses four-head cartoon sprite set")
			assert_equal(sprite.texture.get_size(), Vector2(1536, 1024), "full resolution sprite canvas retained")
			assert_true(absf(sprite.pixel_size * 850.0 - UNIT.PRODUCTION_DISPLAY_HEIGHT) < 0.001, "painted sprites preserve consistent world height")
			assert_true(sprite.has_meta("foot_anchor_pixels"), "explicit reviewed two-foot anchor is present")
			if sprite.has_meta("foot_anchor_pixels"):
				var foot: Vector2 = sprite.get_meta("foot_anchor_pixels")
				assert_equal(sprite.get_meta("head_ratio"), 4.0, "four-head proportion measurement recorded")
				var size: Vector2 = sprite.texture.get_size()
				var local_foot := Vector2(foot.x - size.x * 0.5 + sprite.offset.x, size.y * 0.5 - foot.y + sprite.offset.y)
				assert_true(local_foot.is_zero_approx(), "two-foot support center maps exactly to sprite pivot")
				assert_true(is_zero_approx(sprite.position.x) and is_zero_approx(sprite.position.z), "sprite pivot has no horizontal grid offset")
				assert_true(absf(sprite.position.y - unit.get_node("SelectionOutline").position.y) < 0.01, "feet and tile-center ring share the same ground plane")
			assert_equal(sprite.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "sprite faces orbiting camera")
			var texture_before := sprite.texture
			var transform_before := sprite.transform
			unit.play_event({"type": &"attack_started", "actor_id": state.instance_id, "payload": {"distance": 1}})
			assert_equal(sprite.texture, texture_before, "attack does not swap animation frames")
			assert_equal(sprite.transform, transform_before, "attack does not deform character")
		assert_true(unit.production_animation_player == null, "runtime does not own character AnimationPlayer")
		assert_true(unit.get_node("SelectionOutline").mesh is TorusMesh, "selection uses ground ring instead of opaque body capsule")
		assert_true(unit.get_node("SelectionOutline").position.y + unit.position.y >= 0.23, "selected ring lies above tactical tiles")
		assert_true(unit.get_node("HpBar/Fill").material_override.render_priority > unit.get_node("HpBar/Background").material_override.render_priority, "health fill draws above background")
		unit.set_selected(true)
		assert_true(unit.get_node("SelectionOutline").visible, "selected ring visible")
		unit.set_selected(false)
		assert_true(not unit.get_node("SelectionOutline").visible, "unselected ring hidden")
		if sprite != null:
			unit.play_event({"type": &"unit_acted", "actor_id": state.instance_id, "payload": {"action": &"wait"}})
			assert_true(sprite.modulate != Color.WHITE, "acted static sprite is visibly dimmed")
			unit.play_event({"type": &"phase_changed", "payload": {"to": state.definition.team}})
			assert_equal(sprite.modulate, Color.WHITE, "own next phase restores actionable sprite")
		unit.free()

	var battle: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	tree.root.add_child(battle)
	battle.handle_board_pick(&"unit", &"aurelia-1")
	battle._on_hud_command(&"move")
	battle._on_hud_command(&"cancel")
	assert_equal(battle.session.selected_unit_id, &"aurelia-1", "first cancel exits action preview but retains selection")
	battle._on_hud_command(&"cancel")
	assert_equal(battle.session.selected_unit_id, &"", "second cancel clears selected unit")
	assert_true(not battle.get_unit_node(&"aurelia-1").get_node("SelectionOutline").visible, "deselection hides selected ring")
	assert_true(battle.get_node("TacticalCamera").focus_target == null, "deselection clears orbit target")
	for state: Variant in battle.session.units:
		if state.instance_id == &"aurelia-1":
			assert_true(not state.acted and not state.has_moved, "cancel selection consumes no action or move")
	battle.free()
