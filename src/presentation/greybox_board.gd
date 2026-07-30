class_name GreyboxBoard
extends Node3D

signal cell_picked(position: Vector2i)

const TERRAIN_COLORS := {
	&"plain": Color("8b8f86"),
	&"bridge": Color("586579"),
	&"forest": Color("377a4a"),
	&"water": Color("286aa6"),
	&"crystal": Color("7952b3"),
}
const MOVE_COLOR := Color(0.20, 0.70, 1.0, 0.48)
const ATTACK_COLOR := Color(1.0, 0.22, 0.25, 0.48)

var board_width: int = 0
var board_height: int = 0


func build(chapter: Variant) -> void:
	var terrain_root := _ensure_root("Terrain")
	var move_root := _ensure_root("MoveOverlay")
	var attack_root := _ensure_root("AttackOverlay")
	_clear_children(terrain_root)
	_clear_children(move_root)
	_clear_children(attack_root)
	board_width = 0 if chapter == null else maxi(0, int(chapter.width))
	board_height = 0 if chapter == null else maxi(0, int(chapter.height))
	if chapter == null:
		return
	for index: int in mini(chapter.terrain.size(), board_width * board_height):
		var position := Vector2i(index % board_width, index / board_width)
		var terrain_id := StringName(chapter.terrain[index])
		terrain_root.add_child(_make_tile(position, terrain_id))
		_assign_scene_owner(terrain_root.get_child(terrain_root.get_child_count() - 1))


func show_move_cells(cells: Array) -> void:
	_show_overlay(_ensure_root("MoveOverlay"), cells, MOVE_COLOR, "Move")


func show_attack_cells(cells: Array) -> void:
	_show_overlay(_ensure_root("AttackOverlay"), cells, ATTACK_COLOR, "Attack")


func pick_cell(position: Vector2i) -> void:
	cell_picked.emit(position)


func _make_tile(grid_position: Vector2i, terrain_id: StringName) -> MeshInstance3D:
	var tile := MeshInstance3D.new()
	tile.name = "Cell_%d_%d" % [grid_position.x, grid_position.y]
	var mesh := BoxMesh.new()
	var height := _terrain_height(terrain_id)
	mesh.size = Vector3(0.94, height, 0.94)
	tile.mesh = mesh
	tile.position = Vector3(grid_position.x, _terrain_y(terrain_id), grid_position.y)
	tile.material_override = _material(TERRAIN_COLORS.get(terrain_id, TERRAIN_COLORS[&"plain"]))
	tile.set_meta("grid_position", grid_position)
	tile.set_meta("terrain_id", terrain_id)
	return tile


func _show_overlay(root: Node3D, cells: Array, color: Color, prefix: String) -> void:
	_clear_children(root)
	for index: int in cells.size():
		var cell: Vector2i = cells[index]
		var marker := MeshInstance3D.new()
		marker.name = "%s_%d_%d" % [prefix, cell.x, cell.y]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.82, 0.035, 0.82)
		marker.mesh = mesh
		marker.position = Vector3(cell.x, 0.23 + float(index % 2) * 0.002, cell.y)
		marker.material_override = _material(color, true)
		marker.set_meta("grid_position", cell)
		root.add_child(marker)
		_assign_scene_owner(marker)


func _ensure_root(node_name: String) -> Node3D:
	var existing := get_node_or_null(node_name) as Node3D
	if existing != null:
		return existing
	var root := Node3D.new()
	root.name = node_name
	add_child(root)
	_assign_scene_owner(root)
	return root


func _clear_children(root: Node) -> void:
	for child: Node in root.get_children():
		child.free()


func _assign_scene_owner(node: Node) -> void:
	if owner != null:
		node.owner = owner


func _material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _terrain_height(terrain_id: StringName) -> float:
	match terrain_id:
		&"water":
			return 0.06
		&"bridge":
			return 0.24
		&"forest":
			return 0.28
		&"crystal":
			return 0.34
	return 0.16


func _terrain_y(terrain_id: StringName) -> float:
	match terrain_id:
		&"water":
			return -0.07
		&"bridge":
			return 0.04
		&"forest":
			return 0.06
		&"crystal":
			return 0.09
	return 0.0
