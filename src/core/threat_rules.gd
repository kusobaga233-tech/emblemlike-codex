class_name ThreatRules
extends RefCounted

# Presentation-only danger envelope. Never mutates units or the board.
const GridRulesScript = preload("res://src/core/grid_rules.gd")


static func compute(units: Array, board: Dictionary) -> Dictionary:
	var width := int(board.get("width", 0))
	var height := int(board.get("height", 0))
	var result := {"move": [], "attack": [], "by_enemy": {}}
	if width <= 0 or height <= 0:
		return result
	var terrain_blocked: Dictionary = board.get("blocked", {})
	var move_union := {}
	var attack_union := {}
	var by_enemy := {}
	for enemy: Variant in units:
		if not _is_living_team_unit(enemy, &"enemy"):
			continue
		var blocked := terrain_blocked.duplicate()
		for other: Variant in units:
			if other == enemy or not _has_unit_state(other) or other.current_hp <= 0:
				continue
			blocked[Vector2i(other.grid_position.x, other.grid_position.y)] = true
		blocked.erase(Vector2i(enemy.grid_position.x, enemy.grid_position.y))
		var move_set := {}
		for point: Variant in GridRulesScript.reachable(
			enemy.grid_position,
			maxi(0, int(enemy.definition.move)),
			width,
			height,
			blocked,
		):
			move_set[Vector2i(point.x, point.y)] = true
		var attack_set := {}
		for y: int in height:
			for x: int in width:
				var cell := Vector2i(x, y)
				if terrain_blocked.has(cell):
					continue
				if _is_attacked_from(cell, move_set, enemy.definition.ranges):
					attack_set[cell] = true
		for cell: Vector2i in move_set:
			move_union[cell] = true
		for cell: Vector2i in attack_set:
			attack_union[cell] = true
		by_enemy[enemy.instance_id] = {
			"move": _sorted_cells(move_set),
			"attack": _sorted_cells(attack_set),
		}
	result["move"] = _sorted_cells(move_union)
	result["attack"] = _sorted_cells(attack_union)
	result["by_enemy"] = by_enemy
	return result


static func _is_attacked_from(cell: Vector2i, move_set: Dictionary, ranges: PackedInt32Array) -> bool:
	if ranges.is_empty():
		return false
	for origin: Vector2i in move_set:
		var distance := absi(origin.x - cell.x) + absi(origin.y - cell.y)
		for attack_range: int in ranges:
			if distance == attack_range:
				return true
	return false


static func _sorted_cells(cells: Dictionary) -> Array[Vector2i]:
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in cells:
		ordered.append(cell)
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return ordered


static func _is_living_team_unit(unit: Variant, team: StringName) -> bool:
	return (
		_has_unit_state(unit)
		and unit.current_hp > 0
		and unit.definition.team == team
	)


static func _has_unit_state(unit: Variant) -> bool:
	return unit != null and unit.definition != null and unit.grid_position != null
