class_name GreyboxBoard
extends Node3D

signal cell_picked(position: Vector2i)
signal cell_hovered(position: Vector2i)

const TERRAIN_COLORS := {
	&"plain": Color("59616a"),
	&"bridge": Color("7b6546"),
	&"forest": Color("365947"),
	&"water": Color("315f78"),
	&"crystal": Color("674c7e"),
}
const MOVE_COLOR := Color(0.20, 0.70, 1.0, 0.48)
const ATTACK_COLOR := Color(1.0, 0.22, 0.25, 0.48)
const ENVIRONMENT_KIT_PATH := "res://assets/production/environment/chapter_one_observatory_kit.glb"

var board_width: int = 0
var board_height: int = 0
var _environment_meshes: Dictionary = {}
var _terrain_materials: Dictionary = {}


func build(chapter: Variant) -> void:
	var terrain_root := _ensure_root("Terrain")
	var move_root := _ensure_root("MoveOverlay")
	var attack_root := _ensure_root("AttackOverlay")
	var decor_root := _ensure_root("EnvironmentDecor")
	_clear_children(terrain_root)
	_clear_children(move_root)
	_clear_children(attack_root)
	_clear_children(decor_root)
	_load_environment_meshes()
	board_width = 0 if chapter == null else maxi(0, int(chapter.width))
	board_height = 0 if chapter == null else maxi(0, int(chapter.height))
	if chapter == null:
		return
	for index: int in mini(chapter.terrain.size(), board_width * board_height):
		var position := Vector2i(index % board_width, index / board_width)
		var terrain_id := StringName(chapter.terrain[index])
		terrain_root.add_child(_make_tile(position, terrain_id))
		_assign_scene_owner(terrain_root.get_child(terrain_root.get_child_count() - 1))
	_build_environment_decor(decor_root, chapter)


func show_move_cells(cells: Array) -> void:
	_show_overlay(_ensure_root("MoveOverlay"), cells, MOVE_COLOR, "Move")


func show_attack_cells(cells: Array) -> void:
	_show_overlay(_ensure_root("AttackOverlay"), cells, ATTACK_COLOR, "Attack")


func pick_cell(position: Vector2i) -> void:
	cell_picked.emit(position)


func _make_tile(grid_position: Vector2i, terrain_id: StringName) -> MeshInstance3D:
	var tile := MeshInstance3D.new()
	tile.name = "Cell_%d_%d" % [grid_position.x, grid_position.y]
	var mesh: Mesh = _environment_meshes.get("Bridge_1x1" if terrain_id == &"bridge" else "Floor_1x1") as Mesh
	if mesh == null:
		var fallback_mesh := BoxMesh.new()
		fallback_mesh.size = Vector3(0.94, _terrain_height(terrain_id), 0.94)
		mesh = fallback_mesh
	var height := _terrain_height(terrain_id)
	tile.mesh = mesh
	tile.position = Vector3(grid_position.x, _terrain_y(terrain_id), grid_position.y)
	tile.material_override = _terrain_material(terrain_id)
	tile.set_meta("grid_position", grid_position)
	tile.set_meta("terrain_id", terrain_id)
	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = 1
	pick_area.collision_mask = 0
	pick_area.input_ray_pickable = true
	pick_area.input_event.connect(_on_cell_input_event.bind(grid_position))
	pick_area.mouse_entered.connect(_on_cell_mouse_entered.bind(grid_position))
	tile.add_child(pick_area)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.92, maxf(0.06, height), 0.92)
	collision.shape = shape
	pick_area.add_child(collision)
	return tile


func _load_environment_meshes() -> void:
	if not _environment_meshes.is_empty():
		return
	var packed := load(ENVIRONMENT_KIT_PATH) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate()
	_collect_environment_meshes(instance)
	instance.free()


func _collect_environment_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_environment_meshes[String(node.name)] = (node as MeshInstance3D).mesh
	for child: Node in node.get_children():
		_collect_environment_meshes(child)


func _build_environment_decor(root: Node3D, chapter: Variant) -> void:
	var cover_mesh := _environment_meshes.get("Cover_Low_1x1") as Mesh
	var ruin_mesh := _environment_meshes.get("Ruin_Arch_2x1") as Mesh
	if cover_mesh != null:
		for index: int in mini(chapter.terrain.size(), board_width * board_height):
			if StringName(chapter.terrain[index]) not in [&"forest", &"crystal"]:
				continue
			var grid_position := Vector2i(index % board_width, index / board_width)
			if (grid_position.x + grid_position.y) % 4 != 0:
				continue
			_add_decor_mesh(root, cover_mesh, "Cover_%d_%d" % [grid_position.x, grid_position.y], Vector3(grid_position.x, 0.12, grid_position.y))
	if ruin_mesh != null and board_width >= 2 and board_height >= 2:
		_add_decor_mesh(root, ruin_mesh, "Ruin_North", Vector3(0.1, 0.0, -0.55))
		var south_ruin := _add_decor_mesh(root, ruin_mesh, "Ruin_South", Vector3(board_width - 1.1, 0.0, board_height - 0.45))
		south_ruin.rotation.y = PI
	_build_platform_rim(root)
	_build_observatory_foundation(root)
	_build_distant_structures(root, ruin_mesh)
	_build_crystal_beacons(root)


func _build_platform_rim(root: Node3D) -> void:
	var rim := Node3D.new()
	rim.name = "PlatformRim"
	root.add_child(rim)
	_assign_scene_owner(rim)
	var rim_material := _material(Color("35445a"))
	rim_material.metallic = 0.58
	rim_material.roughness = 0.42
	for x: int in board_width:
		_add_box_decor(rim, "RimNorth_%02d" % x, Vector3(x, -0.12, -0.82), Vector3(0.92, 0.28, 0.32), rim_material)
		_add_box_decor(rim, "RimSouth_%02d" % x, Vector3(x, -0.12, board_height - 0.18), Vector3(0.92, 0.28, 0.32), rim_material)
	for z: int in board_height:
		_add_box_decor(rim, "RimWest_%02d" % z, Vector3(-0.82, -0.12, z), Vector3(0.32, 0.28, 0.92), rim_material)
		_add_box_decor(rim, "RimEast_%02d" % z, Vector3(board_width - 0.18, -0.12, z), Vector3(0.32, 0.28, 0.92), rim_material)


func _build_observatory_foundation(root: Node3D) -> void:
	var foundation := Node3D.new()
	foundation.name = "ObservatoryFoundation"
	root.add_child(foundation)
	_assign_scene_owner(foundation)
	var materials := [_material(Color("26354d")), _material(Color("1d2a40")), _material(Color("172238"))]
	for index: int in 3:
		var inset := float(index) * 0.7
		_add_box_decor(
			foundation,
			"FoundationTier_%02d" % index,
			Vector3(float(board_width - 1) * 0.5, -0.34 - float(index) * 0.22, float(board_height - 1) * 0.5 + float(index) * 0.15),
			Vector3(float(board_width) + 2.3 + inset, 0.34, float(board_height) + 2.3 + inset),
			materials[index],
		)


func _build_distant_structures(root: Node3D, ruin_mesh: Mesh) -> void:
	var distant := Node3D.new()
	distant.name = "DistantStructures"
	root.add_child(distant)
	_assign_scene_owner(distant)
	var placements := [
		Vector3(-4.2, -0.8, -3.5), Vector3(2.0, -1.1, -5.2), Vector3(8.8, -0.7, -3.2),
		Vector3(12.0, -1.3, 2.0), Vector3(11.3, -0.9, 9.0), Vector3(8.5, -1.2, 14.0),
		Vector3(1.5, -1.0, 14.5), Vector3(-4.8, -1.2, 10.8),
	]
	var silhouette_material := _material(Color("202c45"))
	silhouette_material.metallic = 0.35
	for index: int in placements.size():
		if ruin_mesh != null and index % 2 == 0:
			var arch := _add_decor_mesh(distant, ruin_mesh, "DistantArch_%02d" % index, placements[index])
			arch.scale = Vector3(1.7, 2.8, 1.7)
			arch.material_override = silhouette_material
		else:
			_add_box_decor(distant, "DistantPylon_%02d" % index, placements[index], Vector3(0.8, 5.5, 0.8), silhouette_material)


func _build_crystal_beacons(root: Node3D) -> void:
	var beacons := Node3D.new()
	beacons.name = "CrystalBeacons"
	root.add_child(beacons)
	_assign_scene_owner(beacons)
	var beacon_material := _material(Color("334a78"))
	beacon_material.emission_enabled = true
	beacon_material.emission = Color("263d72")
	beacon_material.emission_energy_multiplier = 0.16
	var placements := [Vector3(-1.2, 0.5, 1.0), Vector3(-1.2, 0.5, 4.5), Vector3(-1.2, 0.5, 8.0), Vector3(8.2, 0.5, 0.5), Vector3(8.2, 0.5, 3.8), Vector3(8.2, 0.5, 7.0)]
	for index: int in placements.size():
		var beacon := MeshInstance3D.new()
		beacon.name = "Beacon_%02d" % index
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.34, 1.35, 0.34)
		beacon.mesh = mesh
		beacon.position = placements[index]
		beacon.material_override = beacon_material
		beacon.set_meta("render_only", true)
		beacons.add_child(beacon)
		_assign_scene_owner(beacon)


func _add_box_decor(root: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	instance.set_meta("render_only", true)
	root.add_child(instance)
	_assign_scene_owner(instance)
	return instance


func _add_decor_mesh(root: Node3D, mesh: Mesh, node_name: String, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.set_meta("render_only", true)
	root.add_child(instance)
	_assign_scene_owner(instance)
	return instance


func _on_cell_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
	grid_position: Vector2i,
) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cell_picked.emit(grid_position)


func _on_cell_mouse_entered(grid_position: Vector2i) -> void:
	cell_hovered.emit(grid_position)


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
		for child: Node in node.get_children():
			_assign_scene_owner(child)


func _material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _terrain_material(terrain_id: StringName) -> StandardMaterial3D:
	if _terrain_materials.has(terrain_id):
		return _terrain_materials[terrain_id] as StandardMaterial3D
	var material := _material(TERRAIN_COLORS.get(terrain_id, TERRAIN_COLORS[&"plain"]))
	material.metallic = 0.28 if terrain_id in [&"bridge", &"crystal"] else 0.08
	material.roughness = 0.34 if terrain_id == &"water" else 0.68
	if terrain_id == &"crystal":
		material.emission_enabled = true
		material.emission = Color("2c183c")
		material.emission_energy_multiplier = 0.45
	_terrain_materials[terrain_id] = material
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
			return -0.08
		&"bridge":
			return 0.04
		&"forest":
			return 0.06
		&"crystal":
			return 0.09
	return 0.0
