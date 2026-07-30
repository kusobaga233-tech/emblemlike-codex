class_name TurnState
extends RefCounted

var round: int = 1
var phase: StringName = &"player"
var units: Array = []


func _init(initial_units: Array = []) -> void:
	units = initial_units.duplicate()


func begin_player_phase() -> void:
	phase = &"player"
	_reset_acted_for_team(&"player")


func end_player_phase() -> void:
	begin_enemy_phase()


func begin_enemy_phase() -> void:
	phase = &"enemy"
	_reset_acted_for_team(&"enemy")


func finish_round() -> void:
	round += 1
	begin_player_phase()


func _reset_acted_for_team(team: StringName) -> void:
	for unit: Variant in units:
		if unit == null or unit.definition == null:
			continue
		if unit.definition.team == team:
			unit.acted = false
