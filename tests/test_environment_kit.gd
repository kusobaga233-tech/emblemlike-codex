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
	var parsed_report: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
	assert_true(parsed_report is Dictionary, "Environment report parses as a JSON object")
	var report: Dictionary = parsed_report if parsed_report is Dictionary else {}
	assert_true(report.has("module_triangles"), "Environment report includes per-module triangle counts")
	assert_true(report.get("module_triangles") is Dictionary, "Per-module triangle counts are a JSON object")
	assert_true(report.get("modules") is Dictionary, "Per-module bounds are a JSON object")
	var reported_triangles: Dictionary = report.get("module_triangles", {}) if report.get("module_triangles") is Dictionary else {}
	var reported_modules: Dictionary = report.get("modules", {}) if report.get("modules") is Dictionary else {}
	for module_name: String in ["Floor_1x1", "Bridge_1x1", "Cover_Low_1x1", "Ruin_Arch_2x1"]:
		var triangles := int(reported_triangles.get(module_name, 0))
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
			assert_equal(imported_triangles, int(reported_triangles.get(module_name, -1)), "%s report triangle count matches the imported GLB" % module_name)
			var module_report: Variant = reported_modules.get(module_name)
			assert_true(module_report is Dictionary, "%s bounds report is an object" % module_name)
			if module_report is Dictionary:
				var blender_bounds: Variant = module_report.get("bounds_blender_xyz")
				assert_true(blender_bounds is Array and blender_bounds.size() == 3, "%s has three Blender bounds axes" % module_name)
				if blender_bounds is Array and blender_bounds.size() == 3:
					var expected_godot := Vector3(float(blender_bounds[0]), float(blender_bounds[2]), float(blender_bounds[1]))
					_assert_vector3_near(module.mesh.get_aabb().size, expected_godot, 0.002, "%s report bounds match imported GLB with axis mapping" % module_name)
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
		var first_plain_material: Material
		for child: Node in terrain.get_children():
			if child.get_meta("terrain_id") != &"plain":
				continue
			if first_plain_material == null:
				first_plain_material = (child as MeshInstance3D).material_override
			else:
				assert_true(is_same(first_plain_material, (child as MeshInstance3D).material_override), "Terrain cells share cached immutable materials")
				break
	var decor := board.get_node_or_null("EnvironmentDecor")
	assert_true(decor != null and decor.get_child_count() > 0, "Board creates modular observatory decor")
	if decor != null:
		assert_equal(_count_type(decor, CollisionObject3D), 0, "Decor is collision-free and cannot alter deterministic movement")
		var rim := decor.get_node_or_null("PlatformRim")
		var distant := decor.get_node_or_null("DistantStructures")
		var beacons := decor.get_node_or_null("CrystalBeacons")
		var foundation := decor.get_node_or_null("ObservatoryFoundation")
		assert_true(rim != null and rim.get_child_count() >= 18, "Observatory platform has a substantial perimeter rim")
		assert_true(distant != null and distant.get_child_count() >= 8, "Observatory has distant pylons and arch silhouettes")
		assert_true(beacons != null and beacons.get_child_count() >= 6, "Observatory has perimeter crystal beacons")
		assert_true(foundation != null and foundation.get_child_count() >= 3, "Observatory has layered foundation terraces beneath the grid")
		for group: Node in [rim, distant, beacons]:
			if group == null:
				continue
			for item: Node3D in group.get_children():
				var inside_grid := item.position.x >= -0.5 and item.position.x <= 7.5 and item.position.z >= -0.5 and item.position.z <= 9.5
				assert_true(not inside_grid, "%s stays outside playable tactical cells" % item.name)
	board.set("_environment_meshes", {})
	var fallback := board.call("_make_tile", Vector2i(2, 3), &"water") as MeshInstance3D
	assert_true(fallback.mesh is BoxMesh, "Missing imported mesh uses deterministic BoxMesh fallback")
	if fallback.mesh is BoxMesh:
		_assert_vector3_near((fallback.mesh as BoxMesh).size, Vector3(0.94, 0.06, 0.94), 0.0001, "Fallback water mesh restores grid-safe dimensions")
	assert_true(absf(fallback.position.y + 0.08) < 0.001, "Fallback water mesh preserves terrain elevation")
	fallback.free()
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


func _assert_vector3_near(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> void:
	assert_true(
		absf(actual.x - expected.x) <= tolerance
		and absf(actual.y - expected.y) <= tolerance
		and absf(actual.z - expected.z) <= tolerance,
		"%s: expected=%s actual=%s" % [message, expected, actual],
	)
