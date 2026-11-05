extends TestCase

const ThreatRulesScript = preload("res://src/core/threat_rules.gd")
const UnitCatalogScript = preload("res://src/content/unit_catalog.gd")
const UnitStateScript = preload("res://src/core/unit_state.gd")
const GridPointScript = preload("res://src/core/grid_point.gd")
const ChapterOneScript = preload("res://src/content/chapter_one.gd")
const BattleSessionScript = preload("res://src/tactics/battle_session.gd")


func run() -> void:
	_test_melee_envelope_and_occupancy()
	_test_water_and_wall_block_movement()
	_test_ranged_discrete_envelope()
	_test_dead_and_friendly_units_are_ignored()
	_test_multi_enemy_union_and_chapter_one_snapshot()


func _test_melee_envelope_and_occupancy() -> void:
	var blade: Variant = _unit(&"hollow-blade", &"blade-1", 2, 2)
	var ally: Variant = _unit(&"brann", &"brann-1", 2, 4)
	var result: Dictionary = ThreatRulesScript.compute([blade, ally], _board(5, 5))
	var move: Array = result.move
	var attack: Array = result.attack
	assert_equal(move.size(), 20, "Melee move covers the radius-three diamond minus the occupied cell")
	assert_equal(attack.size(), 25, "Melee attack covers every tile adjacent to the reachable set")
	assert_true(Vector2i(2, 2) in move, "Enemy origin is part of its movement envelope")
	assert_true(not Vector2i(2, 4) in move, "Occupied ally tile is not a movement destination")
	assert_true(Vector2i(2, 4) in attack, "Occupied ally tile is still attackable")
	assert_equal(result.by_enemy[&"blade-1"].move.size(), 20, "Per-enemy movement envelope is exposed")
	assert_equal(result.by_enemy[&"blade-1"].attack.size(), 25, "Per-enemy attack envelope is exposed")


func _test_water_and_wall_block_movement() -> void:
	var blocked := {Vector2i(0, 2): true}
	var result: Dictionary = ThreatRulesScript.compute(
		[_unit(&"hollow-blade", &"blade-1", 2, 2)],
		_board(5, 5, blocked),
	)
	assert_true(not Vector2i(0, 2) in result.move, "Water never enters the movement envelope")
	assert_true(not Vector2i(0, 2) in result.attack, "Unstandable water never enters the attack envelope")

	var wall := {}
	for y: int in 5:
		wall[Vector2i(2, y)] = true
	var walled: Dictionary = ThreatRulesScript.compute(
		[_unit(&"hollow-blade", &"blade-1", 0, 2)],
		_board(5, 5, wall),
	)
	for cell: Vector2i in walled.move:
		assert_true(cell.x <= 1, "A full water wall blocks movement past it")
	for cell: Vector2i in walled.attack:
		assert_true(cell.x <= 1, "A full water wall blocks the melee attack envelope too")


func _test_ranged_discrete_envelope() -> void:
	var bow: Variant = _unit(&"hollow-bow", &"bow-1", 4, 4)
	var result: Dictionary = ThreatRulesScript.compute([bow], _board(9, 9))
	assert_true(Vector2i(4, 0) in result.attack, "Move three plus range three reaches six tiles away")
	assert_true(Vector2i(0, 0) not in result.attack, "Discrete range does not become an invented continuous radius")
	assert_true(Vector2i(4, 1) in result.attack, "A distance-two shot from a reachable tile is covered")
	assert_true(Vector2i(4, 2) in result.move, "Ranged unit still moves normally")
	assert_true(Vector2i(4, 7) in result.attack, "Envelope is symmetric on the south side")
	assert_true(Vector2i(0, 8) not in result.attack, "Distance three plus move three does not overreach the far corner")


func _test_dead_and_friendly_units_are_ignored() -> void:
	var dead_blade: Variant = _unit(&"hollow-blade", &"blade-1", 2, 2)
	dead_blade.current_hp = 0
	var ally: Variant = _unit(&"brann", &"brann-1", 2, 4)
	var result: Dictionary = ThreatRulesScript.compute([dead_blade, ally], _board(5, 5))
	assert_true(result.move.is_empty() and result.attack.is_empty(), "Defeated enemies contribute no threat")
	assert_true(result.by_enemy.is_empty(), "Defeated enemies are absent from the per-enemy map")


func _test_multi_enemy_union_and_chapter_one_snapshot() -> void:
	var first: Variant = _unit(&"hollow-blade", &"blade-1", 1, 1)
	var second: Variant = _unit(&"hollow-bow", &"bow-1", 4, 4)
	var combined: Dictionary = ThreatRulesScript.compute([first, second], _board(6, 6))
	var move_union := {}
	var attack_union := {}
	for enemy_id: StringName in [&"blade-1", &"bow-1"]:
		for cell: Vector2i in combined.by_enemy[enemy_id].move:
			move_union[cell] = true
		for cell: Vector2i in combined.by_enemy[enemy_id].attack:
			attack_union[cell] = true
	assert_equal(combined.move.size(), move_union.size(), "Move envelopes are a set union")
	assert_equal(combined.attack.size(), attack_union.size(), "Attack envelopes are a set union")

	var session: Variant = BattleSessionScript.new(ChapterOneScript.build(), 3)
	var chapter_result: Dictionary = ThreatRulesScript.compute(session.units, session.board_snapshot())
	assert_true(chapter_result.by_enemy.has(&"blade-1"), "Chapter one blade contributes threat")
	assert_true(chapter_result.by_enemy.has(&"bow-1"), "Chapter one bow contributes threat")
	assert_true(chapter_result.by_enemy.has(&"captain-1"), "Chapter one captain contributes threat")
	for cell: Vector2i in chapter_result.move:
		assert_true(cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 10, "Threat stays inside the chapter board")
		assert_true(session._board.blocked.get(cell, false) == false, "Threat movement never targets water")
	for cell: Vector2i in chapter_result.attack:
		assert_true(cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 10, "Attack threat stays inside the chapter board")
		assert_true(session._board.blocked.get(cell, false) == false, "Attack threat never targets water")


func _unit(definition_id: StringName, instance_id: StringName, x: int, y: int) -> Variant:
	return UnitStateScript.new(
		UnitCatalogScript.get_definition(definition_id),
		instance_id,
		GridPointScript.new(x, y),
	)


func _board(width: int, height: int, blocked: Dictionary = {}) -> Dictionary:
	return {"width": width, "height": height, "blocked": blocked}
