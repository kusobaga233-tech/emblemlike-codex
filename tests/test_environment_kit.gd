extends TestCase

const KIT_PATH := "res://assets/production/environment/chapter_one_observatory_kit.glb"
const BOARD_PATH := "res://src/presentation/greybox_board.gd"
const CHAPTER_PATH := "res://src/content/chapter_one.gd"
const REPORT_PATH := "res://assets/production/environment/environment_kit_report.json"
const SOURCE_SCRIPT_PATH := "res://tools/production_source/chapter_one_observatory/build_environment_kit.py"
const SOURCE_BLEND_PATH := "res://tools/production_source/chapter_one_observatory/chapter_one_observatory_kit.blend"


func run() -> void:
	assert_true(ResourceLoader.exists(KIT_PATH), "Observatory kit GLB exists")
	assert_true(FileAccess.file_exists(SOURCE_SCRIPT_PATH), "Versioned Blender generator exists in the Godot repository")
	assert_true(FileAccess.file_exists(SOURCE_BLEND_PATH), "Versioned Blender source file exists in the Godot repository")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
	assert_true(report.has("module_triangles"), "Environment report includes per-module triangle counts")
	for module_name: String in ["Floor_1x1", "Bridge_1x1", "Cover_Low_1x1", "Ruin_Arch_2x1"]:
		var triangles := int(report.get("module_triangles", {}).get(module_name, 0))
		assert_true(triangles >= 2000 and triangles <= 12000, "%s stays inside the 2k-12k production range; found=%d" % [module_name, triangles])
	if not ResourceLoader.exists(KIT_PATH):
		return
	var packed := load(KIT_PATH) as PackedScene
	assert_true(packed != null, "Observatory kit imports as PackedScene")
	if packed == null:
		return
	var kit := packed.instantiate()
	for module_name: String in ["Floor_1x1", "Bridge_1x1", "Cover_Low_1x1", "Ruin_Arch_2x1"]:
		var module := _find_named_mesh(kit, module_name)
		assert_true(module != null, "Kit contains %s" % module_name)
		if module != null:
			assert_true(module.mesh.get_surface_count() > 0, "%s has render surfaces" % module_name)
			assert_true(module.mesh.surface_get_material(0) != null, "%s has an imported production material" % module_name)
			var imported_triangles := _mesh_triangle_count(module.mesh)
			assert_true(imported_triangles >= 2000 and imported_triangles <= 12000, "%s imported mesh has 2k-12k production density; found=%d" % [module_name, imported_triangles])
	var floor := _find_named_mesh(kit, "Floor_1x1")
	if floor != null:
		var size := floor.mesh.get_aabb().size
		assert_true(size.x <= 1.0 and size.z <= 1.0, "Floor module stays within one grid cell")
		assert_true(size.x >= 0.90 and size.z >= 0.90, "Floor module visibly fills its grid cell")
	var bridge := _find_named_mesh(kit, "Bridge_1x1")
	if bridge != null:
		var size := bridge.mesh.get_aabb().size
		assert_true(size.x <= 1.0 and size.z <= 1.0, "Bridge module stays within one grid cell")
	kit.free()

	var board_script := load(BOARD_PATH) as Script
	var chapter_script := load(CHAPTER_PATH) as Script
	var board: Node3D = board_script.new()
	board.build(chapter_script.build())
	var terrain := board.get_node_or_null("Terrain")
	assert_true(terrain != null and terrain.get_child_count() == 80, "Environment board preserves eighty deterministic grid cells")
	if terrain != null:
		var terrain_colors: Dictionary = {}
		for child: Node in terrain.get_children():
			assert_true(child is MeshInstance3D and not ((child as MeshInstance3D).mesh is BoxMesh), "Grid cells use imported environment meshes")
			assert_true(child.get_node_or_null("PickArea/CollisionShape3D") is CollisionShape3D, "Every imported cell keeps explicit pick collision")
			var terrain_material := (child as MeshInstance3D).material_override as StandardMaterial3D
			assert_true(terrain_material != null, "%s terrain owns an explicit readability material" % child.get_meta("terrain_id"))
			if terrain_material != null:
				terrain_colors[child.get_meta("terrain_id")] = terrain_material.albedo_color
		assert_equal(terrain_colors.size(), 5, "All five terrain IDs retain explicit visual signals")
		var unique_colors: Dictionary = {}
		for color: Color in terrain_colors.values():
			unique_colors[color.to_html()] = true
		assert_equal(unique_colors.size(), 5, "Plain, bridge, forest, water, and crystal are visibly distinct")
	var decor := board.get_node_or_null("EnvironmentDecor")
	assert_true(decor != null and decor.get_child_count() > 0, "Board creates modular observatory decor")
	if decor != null:
		assert_equal(_count_type(decor, CollisionObject3D), 0, "Decor is collision-free and cannot alter deterministic movement")
	board.free()


func _find_named_mesh(root: Node, target: String) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == target:
		return root
	for child: Node in root.get_children():
		var found := _find_named_mesh(child, target)
		if found != null:
			return found
	return null


func _count_type(root: Node, expected_type: Variant) -> int:
	var result := 1 if is_instance_of(root, expected_type) else 0
	for child: Node in root.get_children():
		result += _count_type(child, expected_type)
	return result


func _mesh_triangle_count(mesh: Mesh) -> int:
	var triangles := 0
	for surface_index: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += vertices.size() / 3
		else:
			triangles += indices.size() / 3
	return triangles
