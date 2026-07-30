extends TestCase

const BATTLE_EVENT_PATH := "res://src/events/battle_event.gd"
const COMBAT_FORECAST_PATH := "res://src/core/combat_forecast.gd"
const COMBAT_RULES_PATH := "res://src/core/combat_rules.gd"
const GRID_POINT_PATH := "res://src/core/grid_point.gd"
const UNIT_DEFINITION_PATH := "res://src/core/unit_definition.gd"
const UNIT_STATE_PATH := "res://src/core/unit_state.gd"

var _battle_event_script: Script
var _combat_forecast_script: Script
var _combat_rules_script: Script
var _grid_point_script: Script
var _unit_definition_script: Script
var _unit_state_script: Script


func run() -> void:
	_battle_event_script = load(BATTLE_EVENT_PATH) as Script
	_combat_forecast_script = load(COMBAT_FORECAST_PATH) as Script
	_combat_rules_script = load(COMBAT_RULES_PATH) as Script
	_grid_point_script = load(GRID_POINT_PATH) as Script
	_unit_definition_script = load(UNIT_DEFINITION_PATH) as Script
	_unit_state_script = load(UNIT_STATE_PATH) as Script
	assert_true(_battle_event_script != null, "BattleEvent class exists")
	assert_true(_combat_forecast_script != null, "CombatForecast class exists")
	assert_true(_combat_rules_script != null, "CombatRules class exists")
	assert_true(_grid_point_script != null, "GridPoint class exists")
	assert_true(_unit_definition_script != null, "UnitDefinition class exists")
	assert_true(_unit_state_script != null, "UnitState class exists")
	if (
		_battle_event_script == null
		or _combat_forecast_script == null
		or _combat_rules_script == null
		or _grid_point_script == null
		or _unit_definition_script == null
		or _unit_state_script == null
	):
		return

	_test_fenn_forecast_and_resolution()
	_test_seeded_resolution_is_repeatable()
	_test_illegal_range_is_a_no_op()
	_test_defeat_emits_unit_defeated()
	_test_damage_type_uses_the_matching_defense_stat()
	_test_hit_and_critical_rates_are_clamped()
	_test_counter_requires_range_and_survival()
	_test_event_schema_and_payload_types_are_stable()


func _test_fenn_forecast_and_resolution() -> void:
	var fenn: Variant = _make_unit(
		&"fenn",
		&"fenn-1",
		18,
		9,
		2,
		2,
		PackedInt32Array([2]),
		_grid_point_script.new(0, 0),
	)
	var enemy: Variant = _make_unit(
		&"enemy",
		&"enemy-1",
		18,
		5,
		3,
		3,
		PackedInt32Array([1]),
		_grid_point_script.new(2, 0),
	)

	var forecast: Variant = _combat_rules_script.forecast(fenn, enemy)
	assert_true(forecast.legal, "Fenn can attack at range two")
	assert_equal(forecast.damage, 6, "Physical forecast subtracts defense")
	assert_equal(forecast.strike_count, 1, "Legal attacks forecast one strike")
	assert_equal(forecast.defender_remaining_hp, 12, "Forecast reports remaining HP")

	var events: Array = _combat_rules_script.resolve(fenn, enemy, 41)
	assert_equal(enemy.current_hp, 12, "Resolution applies six damage to 18 HP")
	assert_equal(
		_event_types(events),
		PackedStringArray(["attack_started", "hit_confirmed", "damage_applied", "attack_finished"]),
		"Successful attack event order",
	)


func _test_seeded_resolution_is_repeatable() -> void:
	var first_attacker: Variant = _make_unit(
		&"fenn", &"fenn-1", 18, 9, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
		&"physical", 63, 37,
	)
	var first_defender: Variant = _make_unit(
		&"guard", &"guard-1", 18, 5, 3, 3, PackedInt32Array([2]), _grid_point_script.new(2, 0),
	)
	var second_attacker: Variant = _make_unit(
		&"fenn", &"fenn-1", 18, 9, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
		&"physical", 63, 37,
	)
	var second_defender: Variant = _make_unit(
		&"guard", &"guard-1", 18, 5, 3, 3, PackedInt32Array([2]), _grid_point_script.new(2, 0),
	)

	var first_events: Array = _combat_rules_script.resolve(first_attacker, first_defender, 99017)
	var second_events: Array = _combat_rules_script.resolve(second_attacker, second_defender, 99017)
	assert_equal(second_events, first_events, "Equal seeds produce identical event arrays")
	assert_equal(second_defender.current_hp, first_defender.current_hp, "Equal seeds produce equal HP")
	assert_equal(second_attacker.current_hp, first_attacker.current_hp, "Attacker state outcome is repeatable")


func _test_illegal_range_is_a_no_op() -> void:
	var attacker: Variant = _make_unit(
		&"archer", &"archer-1", 16, 8, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
	)
	var defender: Variant = _make_unit(
		&"guard", &"guard-1", 20, 6, 4, 4, PackedInt32Array([1]), _grid_point_script.new(3, 0),
	)
	var attacker_hp: int = attacker.current_hp
	var defender_hp: int = defender.current_hp

	var forecast: Variant = _combat_rules_script.forecast(attacker, defender)
	var events: Array = _combat_rules_script.resolve(attacker, defender, 7)
	assert_equal(forecast.legal, false, "Distance outside the attacker's ranges is illegal")
	assert_equal(events, [], "Illegal resolution returns no events")
	assert_equal(attacker.current_hp, attacker_hp, "Illegal resolution does not mutate attacker HP")
	assert_equal(defender.current_hp, defender_hp, "Illegal resolution does not mutate defender HP")


func _test_defeat_emits_unit_defeated() -> void:
	var attacker: Variant = _make_unit(
		&"fenn", &"fenn-1", 18, 9, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
	)
	var defender: Variant = _make_unit(
		&"wisp", &"wisp-1", 5, 4, 1, 1, PackedInt32Array([2]), _grid_point_script.new(2, 0),
	)

	var events: Array = _combat_rules_script.resolve(attacker, defender, 11)
	assert_equal(defender.current_hp, 0, "Lethal damage floors HP at zero")
	assert_equal(
		_event_types(events),
		PackedStringArray([
			"attack_started",
			"hit_confirmed",
			"damage_applied",
			"unit_defeated",
			"attack_finished",
		]),
		"Defeat event appears before attack finished",
	)


func _test_damage_type_uses_the_matching_defense_stat() -> void:
	var defender: Variant = _make_unit(
		&"sentinel", &"sentinel-1", 20, 4, 3, 7, PackedInt32Array([1]), _grid_point_script.new(2, 0),
	)
	var physical_attacker: Variant = _make_unit(
		&"blade", &"blade-1", 18, 9, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
		&"physical",
	)
	var magical_attacker: Variant = _make_unit(
		&"mage", &"mage-1", 18, 9, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
		&"magical",
	)

	assert_equal(_combat_rules_script.forecast(physical_attacker, defender).damage, 6, "Physical damage uses defense")
	assert_equal(_combat_rules_script.forecast(magical_attacker, defender).damage, 2, "Magical damage uses resistance")


func _test_hit_and_critical_rates_are_clamped() -> void:
	var attacker: Variant = _make_unit(
		&"volatile", &"volatile-1", 18, 9, 2, 2, PackedInt32Array([1]), _grid_point_script.new(0, 0),
		&"physical", 145, -25,
	)
	var defender: Variant = _make_unit(
		&"target", &"target-1", 18, 5, 3, 3, PackedInt32Array([1]), _grid_point_script.new(1, 0),
	)

	var forecast: Variant = _combat_rules_script.forecast(attacker, defender)
	assert_equal(forecast.hit_rate, 100, "Hit rate clamps to 100")
	assert_equal(forecast.critical_rate, 0, "Critical rate clamps to zero")
	assert_equal(typeof(forecast.hit_rate), TYPE_INT, "Hit rate remains an integer")
	assert_equal(typeof(forecast.critical_rate), TYPE_INT, "Critical rate remains an integer")


func _test_counter_requires_range_and_survival() -> void:
	var attacker: Variant = _make_unit(
		&"fenn", &"fenn-1", 18, 9, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
	)
	var defender: Variant = _make_unit(
		&"guard", &"guard-1", 12, 5, 3, 3, PackedInt32Array([2]), _grid_point_script.new(2, 0),
	)
	assert_true(_combat_rules_script.forecast(attacker, defender).can_counter, "Surviving defender in range can counter")

	defender.definition.ranges = PackedInt32Array([1])
	assert_equal(_combat_rules_script.forecast(attacker, defender).can_counter, false, "Defender cannot counter outside its range")

	defender.definition.ranges = PackedInt32Array([2])
	defender.current_hp = 6
	assert_equal(_combat_rules_script.forecast(attacker, defender).can_counter, false, "Defeated defender cannot counter")


func _test_event_schema_and_payload_types_are_stable() -> void:
	var attacker: Variant = _make_unit(
		&"fenn", &"fenn-1", 18, 9, 2, 2, PackedInt32Array([2]), _grid_point_script.new(0, 0),
	)
	var defender: Variant = _make_unit(
		&"guard", &"guard-1", 18, 5, 3, 3, PackedInt32Array([2]), _grid_point_script.new(2, 0),
	)
	var events: Array = _combat_rules_script.resolve(attacker, defender, 5)

	for event: Dictionary in events:
		assert_true(event.has("type"), "Every event has a type")
		assert_true(event.has("actor_id"), "Every event has an actor id")
		assert_true(event.has("target_id"), "Every event has a target id")
		assert_true(event.has("payload"), "Every event has a payload")
		assert_equal(typeof(event["type"]), TYPE_STRING_NAME, "Event type uses StringName")
		assert_equal(typeof(event["actor_id"]), TYPE_STRING_NAME, "Actor id uses StringName")
		assert_equal(typeof(event["target_id"]), TYPE_STRING_NAME, "Target id uses StringName")
		assert_equal(typeof(event["payload"]), TYPE_DICTIONARY, "Event payload uses Dictionary")
		assert_equal(event["actor_id"], &"fenn-1", "Event actor id is stable")
		assert_equal(event["target_id"], &"guard-1", "Event target id is stable")

	assert_equal(typeof(events[0]["payload"]["distance"]), TYPE_INT, "Started distance payload is integer")
	assert_equal(typeof(events[1]["payload"]["critical"]), TYPE_BOOL, "Hit critical payload is boolean")
	assert_equal(typeof(events[2]["payload"]["amount"]), TYPE_INT, "Damage amount payload is integer")
	assert_equal(typeof(events[-1]["payload"]["defender_remaining_hp"]), TYPE_INT, "Finished HP payload is integer")


func _make_unit(
	definition_id: StringName,
	instance_id: StringName,
	max_hp: int,
	attack: int,
	defense: int,
	resistance: int,
	ranges: PackedInt32Array,
	position: Variant,
	damage_type: StringName = &"physical",
	hit: int = 100,
	critical: int = 0,
) -> Variant:
	var definition: Variant = _unit_definition_script.new(
		definition_id,
		String(definition_id),
		&"test",
		&"test_role",
		max_hp,
		attack,
		defense,
		resistance,
		4,
		ranges,
		damage_type,
		hit,
		critical,
	)
	return _unit_state_script.new(definition, instance_id, position)


func _event_types(events: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for event: Dictionary in events:
		result.append(String(event["type"]))
	return result
