class_name GridRules
extends RefCounted

const GridPointScript = preload("res://src/core/grid_point.gd")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.DOWN,
]


static func manhattan(a: GridPointScript, b: GridPointScript) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func reachable(
	origin: GridPointScript,
	movement: int,
	width: int,
	height: int,
	blocked: Dictionary,
) -> Array[GridPointScript]:
	var result: Array[GridPointScript] = []
	if movement < 0 or width <= 0 or height <= 0 or origin == null:
		return result

	var origin_position := Vector2i(origin.x, origin.y)
	if not _is_in_bounds(origin_position, width, height):
		return result
	if _is_blocked(origin_position, blocked):
		return result

	var frontier: Array[Vector2i] = [origin_position]
	var movement_costs := {origin_position: 0}
	var frontier_index := 0
	while frontier_index < frontier.size():
		var current := frontier[frontier_index]
		frontier_index += 1
		var current_cost: int = movement_costs[current]
		for direction in DIRECTIONS:
			var next := current + direction
			if not _is_in_bounds(next, width, height):
				continue
			if _is_blocked(next, blocked) or movement_costs.has(next):
				continue
			var next_cost := current_cost + 1
			if next_cost > movement:
				continue
			movement_costs[next] = next_cost
			frontier.append(next)

	for y in range(height):
		for x in range(width):
			if movement_costs.has(Vector2i(x, y)):
				result.append(GridPointScript.new(x, y))
	return result


static func _is_in_bounds(point: Vector2i, width: int, height: int) -> bool:
	return point.x >= 0 and point.x < width and point.y >= 0 and point.y < height


static func _is_blocked(point: Vector2i, blocked: Dictionary) -> bool:
	return bool(blocked.get(point, false))
