extends TestCase

const GRID_POINT_PATH := "res://src/core/grid_point.gd"
const GRID_RULES_PATH := "res://src/core/grid_rules.gd"
const UNIT_DEFINITION_PATH := "res://src/core/unit_definition.gd"
const UNIT_STATE_PATH := "res://src/core/unit_state.gd"

var _grid_point_script: Script
var _grid_rules_script: Script
var _unit_definition_script: Script
var _unit_state_script: Script


func run() -> void:
	_grid_point_script = load(GRID_POINT_PATH) as Script
	_grid_rules_script = load(GRID_RULES_PATH) as Script
	_unit_definition_script = load(UNIT_DEFINITION_PATH) as Script
	_unit_state_script = load(UNIT_STATE_PATH) as Script
	assert_true(_grid_point_script != null, "GridPoint class exists")
	assert_true(_grid_rules_script != null, "GridRules class exists")
	assert_true(_unit_definition_script != null, "UnitDefinition class exists")
	assert_true(_unit_state_script != null, "UnitState class exists")
	if (
		_grid_point_script == null
		or _grid_rules_script == null
		or _unit_definition_script == null
		or _unit_state_script == null
	):
		return

	_test_manhattan_distance()
	_test_reachable_respects_cost_bounds_and_blocking()
	_test_reachable_order_is_stable_row_major()
	_test_reachable_work_is_bounded_by_visited_cells()
	_test_zero_move_only_includes_unblocked_origin()
	_test_invalid_reachable_inputs_return_empty()
	_test_unit_definition_and_state_initialization()
	_test_unit_states_are_independently_mutable()


func _test_manhattan_distance() -> void:
	var start: Variant = _grid_point_script.new(1, 7)
	var destination: Variant = _grid_point_script.new(5, 5)
	assert_equal(_grid_rules_script.manhattan(start, destination), 6, "Manhattan distance")


func _test_reachable_respects_cost_bounds_and_blocking() -> void:
	var blocked := {Vector2i(2, 1): true}
	var points: Array = _grid_rules_script.reachable(
		_grid_point_script.new(1, 1),
		2,
		4,
		4,
		blocked,
	)
	var signature := _points_signature(points)
	assert_equal(
		signature,
		"0:0,1:0,2:0,0:1,1:1,0:2,1:2,2:2,1:3",
		"Reachable cells use minimum movement cost and row-major order",
	)
	assert_true(signature.contains("1:3"), "A cell exactly two moves away is reachable")
	assert_true(not signature.contains("2:1"), "Blocked cells are excluded")
	assert_true(not signature.contains("-1:"), "Negative x coordinates are excluded")
	assert_true(not signature.contains(":-1"), "Negative y coordinates are excluded")
	assert_true(not signature.contains("4:"), "Coordinates beyond board width are excluded")
	assert_true(not signature.contains(":4"), "Coordinates beyond board height are excluded")


func _test_reachable_order_is_stable_row_major() -> void:
	var origin: Variant = _grid_point_script.new(2, 2)
	var first := _points_signature(_grid_rules_script.reachable(origin, 2, 5, 5, {}))
	var second := _points_signature(_grid_rules_script.reachable(origin, 2, 5, 5, {}))
	assert_equal(second, first, "Repeated calls preserve ordering")
	assert_equal(
		first,
		"2:0,1:1,2:1,3:1,0:2,1:2,2:2,3:2,4:2,1:3,2:3,3:3,2:4",
		"Reachable output is row-major",
	)


func _test_reachable_work_is_bounded_by_visited_cells() -> void:
	var origin: Variant = _grid_point_script.new(5000, 5000)
	var started_at := Time.get_ticks_msec()
	var points: Array = _grid_rules_script.reachable(origin, 0, 10000, 10000, {})
	var elapsed_ms := Time.get_ticks_msec() - started_at
	assert_equal(_points_signature(points), "5000:5000", "Large-board zero-move result")
	assert_true(
		elapsed_ms < 1000,
		"Reachability work is bounded by visited cells; elapsed %d ms" % elapsed_ms,
	)


func _test_zero_move_only_includes_unblocked_origin() -> void:
	var origin: Variant = _grid_point_script.new(3, 2)
	assert_equal(
		_points_signature(_grid_rules_script.reachable(origin, 0, 5, 5, {})),
		"3:2",
		"Zero movement includes the origin",
	)
	assert_equal(
		_grid_rules_script.reachable(origin, 0, 5, 5, {Vector2i(3, 2): true}).size(),
		0,
		"A blocked origin is excluded",
	)


func _test_invalid_reachable_inputs_return_empty() -> void:
	var origin: Variant = _grid_point_script.new(0, 0)
	assert_equal(_grid_rules_script.reachable(origin, -1, 4, 4, {}).size(), 0, "Negative move")
	assert_equal(_grid_rules_script.reachable(origin, 1, 0, 4, {}).size(), 0, "Zero width")
	assert_equal(_grid_rules_script.reachable(origin, 1, 4, 0, {}).size(), 0, "Zero height")
	assert_equal(_grid_rules_script.reachable(origin, 1, -2, 4, {}).size(), 0, "Negative width")
	assert_equal(_grid_rules_script.reachable(origin, 1, 4, -2, {}).size(), 0, "Negative height")
	assert_equal(
		_grid_rules_script.reachable(_grid_point_script.new(4, 0), 1, 4, 4, {}).size(),
		0,
		"Out-of-bounds origin",
	)


func _test_unit_definition_and_state_initialization() -> void:
	var definition: Variant = _unit_definition_script.new(
		&"ember_knight",
		"Ember Knight",
		&"player",
		&"vanguard",
		24,
		8,
		5,
		3,
		4,
		PackedInt32Array([1, 2]),
	)
	assert_equal(definition.id, &"ember_knight", "Definition id")
	assert_equal(definition.display_name, "Ember Knight", "Definition display name")
	assert_equal(definition.team, &"player", "Definition team")
	assert_equal(definition.role, &"vanguard", "Definition role")
	assert_equal(definition.max_hp, 24, "Definition max hp")
	assert_equal(definition.attack, 8, "Definition attack")
	assert_equal(definition.defense, 5, "Definition defense")
	assert_equal(definition.resistance, 3, "Definition resistance")
	assert_equal(definition.move, 4, "Definition move")
	assert_equal(definition.ranges, PackedInt32Array([1, 2]), "Definition ranges")
	assert_equal(definition.damage_type, &"physical", "Legacy definitions default to physical damage")
	assert_equal(definition.hit, 100, "Legacy definitions default to guaranteed accuracy")
	assert_equal(definition.critical, 0, "Legacy definitions default to no critical chance")

	var state: Variant = _unit_state_script.new(
		definition,
		&"player-1",
		_grid_point_script.new(2, 3),
	)
	assert_true(state.definition == definition, "State keeps its unit definition")
	assert_equal(state.instance_id, &"player-1", "State instance id")
	assert_equal(state.grid_position.x, 2, "State grid x")
	assert_equal(state.grid_position.y, 3, "State grid y")
	assert_equal(state.current_hp, 24, "State starts at maximum hp")
	assert_equal(state.acted, false, "State starts without acting")
	assert_equal(state.experience, 0, "State starts without experience")
	assert_equal(state.level, 1, "State starts at level one")


func _test_unit_states_are_independently_mutable() -> void:
	var definition: Variant = _unit_definition_script.new(
		&"spark_scout",
		"Spark Scout",
		&"player",
		&"skirmisher",
		16,
		6,
		2,
		2,
		5,
		PackedInt32Array([1]),
	)
	var shared_origin: Variant = _grid_point_script.new(1, 1)
	var first: Variant = _unit_state_script.new(definition, &"scout-1", shared_origin)
	var second: Variant = _unit_state_script.new(definition, &"scout-2", shared_origin)

	first.grid_position.x = 3
	first.current_hp = 7
	first.acted = true
	first.experience = 40
	first.level = 2

	assert_equal(second.grid_position.x, 1, "Grid positions are not shared")
	assert_equal(second.current_hp, 16, "Hit points are not shared")
	assert_equal(second.acted, false, "Acted state is not shared")
	assert_equal(second.experience, 0, "Experience is not shared")
	assert_equal(second.level, 1, "Level is not shared")


func _points_signature(points: Array) -> String:
	var parts := PackedStringArray()
	for point in points:
		parts.append("%d:%d" % [point.x, point.y])
	return ",".join(parts)
