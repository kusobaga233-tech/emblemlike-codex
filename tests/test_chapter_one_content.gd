extends TestCase

const CHAPTER_DEFINITION_PATH := "res://src/content/chapter_definition.gd"
const CHAPTER_ONE_PATH := "res://src/content/chapter_one.gd"
const CHAPTER_ONE_RESOURCE_PATH := "res://src/content/chapter_one.tres"
const UNIT_CATALOG_PATH := "res://src/content/unit_catalog.gd"

var _chapter_one_script: Script
var _chapter_definition_script: Script
var _unit_catalog_script: Script


func run() -> void:
	_chapter_definition_script = load(CHAPTER_DEFINITION_PATH) as Script
	_chapter_one_script = load(CHAPTER_ONE_PATH) as Script
	_unit_catalog_script = load(UNIT_CATALOG_PATH) as Script
	assert_true(_chapter_definition_script != null, "ChapterDefinition class exists")
	assert_true(_chapter_one_script != null, "ChapterOne class exists")
	assert_true(_unit_catalog_script != null, "UnitCatalog class exists")
	if _chapter_definition_script == null or _chapter_one_script == null or _unit_catalog_script == null:
		return

	_test_unit_catalog_contract()
	_test_original_unit_names_roles_and_balance()
	_test_chapter_board_deployments_and_objectives()
	_test_chapter_events_and_dialogue_are_stable()
	_test_terrain_is_complete_and_explicit()
	_test_chapter_one_uses_only_the_canonical_resource()
	_test_chapter_semantic_validation()
	_test_repeated_builds_do_not_alias_mutable_content()
	_test_deep_duplicate_copies_nested_resources()
	_test_serialized_resource_matches_builder_contract()


func _test_unit_catalog_contract() -> void:
	var aurelia: Variant = _unit_catalog_script.get_definition(&"aurelia")
	assert_true(aurelia != null, "Known unit id resolves")
	if aurelia == null:
		return
	var original_attack: int = aurelia.attack
	aurelia.attack = 999

	assert_equal(_unit_catalog_script.get_definition(&"missing-unit"), null, "Unknown unit id returns null")
	var fresh_aurelia: Variant = _unit_catalog_script.get_definition(&"aurelia")
	assert_true(fresh_aurelia != null, "Catalog remains usable after an unknown lookup")
	if fresh_aurelia != null:
		assert_equal(fresh_aurelia.attack, original_attack, "Unknown lookup and caller mutation do not mutate catalog data")


func _test_original_unit_names_roles_and_balance() -> void:
	_assert_unit(&"aurelia", "奥蕾莉亚", &"先锋", &"player", 24, 11, 4, 3, 5, [1], &"physical", 90, 5)
	_assert_unit(&"brann", "布兰", &"守卫", &"player", 32, 9, 8, 3, 3, [1], &"physical", 90, 5)
	_assert_unit(&"elio", "艾利欧", &"治疗者", &"player", 24, 4, 4, 8, 4, [1], &"physical", 90, 5)
	_assert_unit(&"fenn", "芬恩", &"弓手", &"player", 24, 9, 4, 3, 4, [2, 3], &"physical", 90, 5)
	_assert_unit(&"bridge-captain", "雾桥队长", &"守桥执誓官", &"enemy", 42, 13, 6, 2, 4, [1], &"physical", 82, 3)
	_assert_unit(&"hollow-blade", "空誓剑士", &"近战", &"enemy", 18, 8, 3, 2, 3, [1], &"physical", 82, 3)
	_assert_unit(&"hollow-bow", "空誓弓手", &"远程", &"enemy", 18, 8, 3, 2, 3, [2, 3], &"physical", 82, 3)


func _test_chapter_board_deployments_and_objectives() -> void:
	var chapter: Variant = _chapter_one_script.build()
	assert_true(chapter != null, "ChapterOne.build returns a chapter")
	if chapter == null:
		return
	assert_equal(chapter.id, &"chapter-1", "Chapter id is stable")
	assert_equal(chapter.title, "雾桥初阵", "Chapter title preserves the original Chinese copy")
	assert_equal(chapter.subtitle, "晨雾中的第一道誓约", "Chapter subtitle preserves the original Chinese copy")
	assert_equal(chapter.width, 8, "Chapter board width")
	assert_equal(chapter.height, 10, "Chapter board height")
	assert_equal(chapter.turn_limit, 20, "Chapter turn limit")
	assert_equal(chapter.deployments.size(), 7, "Chapter has four heroes and three enemies")

	_assert_deployment(chapter.deployments, &"aurelia-1", &"aurelia", &"player", Vector2i(1, 7))
	_assert_deployment(chapter.deployments, &"brann-1", &"brann", &"player", Vector2i(2, 8))
	_assert_deployment(chapter.deployments, &"elio-1", &"elio", &"player", Vector2i(3, 8))
	_assert_deployment(chapter.deployments, &"fenn-1", &"fenn", &"player", Vector2i(1, 8))
	_assert_deployment(chapter.deployments, &"captain-1", &"bridge-captain", &"enemy", Vector2i(6, 3))
	_assert_deployment(chapter.deployments, &"blade-1", &"hollow-blade", &"enemy", Vector2i(5, 5))
	_assert_deployment(chapter.deployments, &"bow-1", &"hollow-bow", &"enemy", Vector2i(6, 4))

	assert_equal(chapter.objectives, [{"type": &"unit_defeated", "target_id": &"captain-1"}], "Victory targets the stable captain instance")
	assert_equal(chapter.failure_conditions, [{"type": &"unit_defeated", "target_id": &"aurelia-1"}], "Defeat occurs when Aurelia is defeated")
	assert_equal(chapter.protected_unit_ids, [&"aurelia-1"], "Aurelia is explicitly protected for AI objective pressure")


func _test_chapter_events_and_dialogue_are_stable() -> void:
	var chapter: Variant = _chapter_one_script.build()
	var expected_events := [
		{"id": &"mist-teach", "trigger": &"round-start:1", "text": "雾气遮住了桥面，先确认可移动范围。"},
		{"id": &"captain-advance", "trigger": &"round:4", "text": "守桥队长拔剑前进。"},
		{"id": &"first-resonance", "trigger": &"resonance:100", "text": "星誓共鸣已准备完成。"},
	]
	assert_equal(chapter.events, expected_events, "Chapter event ids, triggers, order, and text remain stable")
	assert_equal(chapter.dialogue, {
		"prologue": ["星核的残光穿过雾桥。", "奥蕾莉亚：我们必须在王庭援军赶到前通过。"],
		"midpoint": ["布兰：别让他们切断退路！"],
		"victory": ["桥上的雾散开了，第一枚星屑落入掌心。"],
		"defeat": ["雾重新吞没了桥面。"],
	}, "Chapter dialogue preserves the original Chinese copy")


func _test_terrain_is_complete_and_explicit() -> void:
	var chapter: Variant = _chapter_one_script.build()
	assert_equal(chapter.terrain.size(), 80, "Terrain has exactly width times height cells")
	assert_equal(chapter.terrain.size(), chapter.width * chapter.height, "Terrain dimensions are valid")
	for terrain_id: String in ["plain", "bridge", "forest", "water", "crystal"]:
		assert_true(chapter.terrain.has(terrain_id), "Terrain includes explicit id %s" % terrain_id)
	for cell: String in chapter.terrain:
		assert_true(cell in ["plain", "bridge", "forest", "water", "crystal"], "Terrain cell uses a supported explicit id")


func _test_chapter_one_uses_only_the_canonical_resource() -> void:
	var source := FileAccess.get_file_as_string(CHAPTER_ONE_PATH)
	assert_true(source.contains("CHAPTER_ONE_RESOURCE_PATH"), "ChapterOne names its canonical resource path")
	assert_true(source.contains("ResourceLoader.CACHE_MODE_IGNORE"), "ChapterOne ignores cache when loading canonical content")
	assert_true(not source.contains("雾桥初阵"), "ChapterOne does not duplicate canonical chapter copy")
	assert_true(not source.contains("_terrain"), "ChapterOne does not duplicate canonical terrain data")
	assert_true(not source.contains("_deployments"), "ChapterOne does not duplicate canonical deployment data")


func _test_chapter_semantic_validation() -> void:
	var canonical: Variant = _load_canonical()
	assert_true(canonical.has_method("validate"), "ChapterDefinition exposes semantic validation")
	assert_true(canonical.has_method("validated_deep_duplicate"), "ChapterDefinition exposes controlled validated duplication")
	if not canonical.has_method("validate") or not canonical.has_method("validated_deep_duplicate"):
		return
	assert_equal(canonical.validate(), [], "Canonical chapter validates cleanly")
	assert_true(canonical.validated_deep_duplicate() != null, "Valid chapter produces a validated duplicate")

	var invalid_dimensions: Variant = _load_canonical()
	invalid_dimensions.width = 0
	_assert_validation_error(invalid_dimensions, &"invalid_dimensions", "width")

	var wrong_terrain_length: Variant = _load_canonical()
	wrong_terrain_length.terrain.remove_at(wrong_terrain_length.terrain.size() - 1)
	_assert_validation_error(wrong_terrain_length, &"terrain_length_mismatch", "terrain")

	var unknown_terrain: Variant = _load_canonical()
	unknown_terrain.terrain[0] = "lava"
	_assert_validation_error(unknown_terrain, &"unknown_terrain_id", "terrain[0]")

	var empty_instance: Variant = _load_canonical()
	empty_instance.deployments[0]["instance_id"] = &""
	_assert_validation_error(empty_instance, &"empty_instance_id", "deployments[0].instance_id")

	var duplicate_instance: Variant = _load_canonical()
	duplicate_instance.deployments[1]["instance_id"] = &"aurelia-1"
	_assert_validation_error(duplicate_instance, &"duplicate_instance_id", "deployments[1].instance_id")

	var unknown_unit: Variant = _load_canonical()
	unknown_unit.deployments[0]["unit_id"] = &"missing-unit"
	_assert_validation_error(unknown_unit, &"unknown_unit_id", "deployments[0].unit_id")

	var wrong_team: Variant = _load_canonical()
	wrong_team.deployments[0]["team"] = &"enemy"
	_assert_validation_error(wrong_team, &"deployment_team_mismatch", "deployments[0].team")

	var overlapping: Variant = _load_canonical()
	overlapping.deployments[1]["position"] = overlapping.deployments[0]["position"]
	_assert_validation_error(overlapping, &"overlapping_position", "deployments[1].position")

	var out_of_bounds: Variant = _load_canonical()
	out_of_bounds.deployments[0]["position"] = Vector2i(out_of_bounds.width, 0)
	_assert_validation_error(out_of_bounds, &"position_out_of_bounds", "deployments[0].position")

	var unresolved_objective: Variant = _load_canonical()
	unresolved_objective.objectives[0]["target_id"] = &"missing-target"
	_assert_validation_error(unresolved_objective, &"unresolved_reference", "objectives[0].target_id")

	var unresolved_protected: Variant = _load_canonical()
	unresolved_protected.protected_unit_ids[0] = &"missing-target"
	_assert_validation_error(unresolved_protected, &"unresolved_reference", "protected_unit_ids[0]")

	var two_captains: Variant = _load_canonical()
	two_captains.deployments.append({
		"instance_id": &"captain-2",
		"unit_id": &"bridge-captain",
		"team": &"enemy",
		"position": Vector2i(7, 3),
	})
	assert_equal(two_captains.validate(), [], "Stable captain instance remains resolvable with two matching definitions")
	two_captains.objectives[0]["target_id"] = &"bridge-captain"
	_assert_validation_error(two_captains, &"ambiguous_reference", "objectives[0].target_id")
	assert_equal(two_captains.validated_deep_duplicate(), null, "Invalid chapter duplication fails in a controlled way")


func _test_repeated_builds_do_not_alias_mutable_content() -> void:
	var first: Variant = _chapter_one_script.build()
	var second: Variant = _chapter_one_script.build()
	assert_true(first != second, "Repeated builds return independent resources")

	first.terrain[0] = "water"
	first.deployments[0]["position"] = Vector2i(7, 9)
	first.objectives[0]["target_id"] = &"changed"
	first.failure_conditions[0]["target_id"] = &"changed"
	first.protected_unit_ids[0] = &"changed"
	first.events[0]["text"] = "changed"
	first.dialogue["prologue"][0] = "changed"

	assert_equal(second.terrain[0], "forest", "Terrain arrays do not alias")
	assert_equal(second.deployments[0]["position"], Vector2i(1, 7), "Deployment dictionaries do not alias")
	assert_equal(second.objectives[0]["target_id"], &"captain-1", "Objective dictionaries do not alias")
	assert_equal(second.failure_conditions[0]["target_id"], &"aurelia-1", "Failure-condition dictionaries do not alias")
	assert_equal(second.protected_unit_ids[0], &"aurelia-1", "Protected-unit arrays do not alias")
	assert_equal(second.events[0]["text"], "雾气遮住了桥面，先确认可移动范围。", "Event dictionaries do not alias")
	assert_equal(second.dialogue["prologue"][0], "星核的残光穿过雾桥。", "Dialogue arrays do not alias")


func _test_deep_duplicate_copies_nested_resources() -> void:
	var original: Variant = _load_canonical()
	assert_true(original.has_method("deep_duplicate"), "ChapterDefinition exposes deep duplication")
	if not original.has_method("deep_duplicate"):
		return
	var nested_unit: Variant = _unit_catalog_script.get_definition(&"aurelia")
	original.dialogue["nested"] = {"units": [nested_unit]}
	var copied: Variant = original.deep_duplicate()
	nested_unit.attack = 999
	original.dialogue["nested"]["units"].append(_unit_catalog_script.get_definition(&"brann"))

	assert_true(copied != original, "Deep duplicate creates a distinct chapter resource")
	assert_equal(copied.dialogue["nested"]["units"].size(), 1, "Deep duplicate copies nested arrays and dictionaries")
	assert_equal(copied.dialogue["nested"]["units"][0].attack, 11, "Deep duplicate copies nested resources")
	assert_true(copied.dialogue["nested"]["units"][0] != nested_unit, "Nested resource identity is independent")


func _test_serialized_resource_matches_builder_contract() -> void:
	var serialized: Variant = ResourceLoader.load(CHAPTER_ONE_RESOURCE_PATH, "ChapterDefinition", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(serialized != null, "chapter_one.tres loads as a ChapterDefinition resource")
	if serialized == null:
		return
	var built: Variant = _chapter_one_script.build()
	for property_name: StringName in [
		&"id", &"title", &"subtitle", &"width", &"height", &"terrain", &"deployments",
		&"objectives", &"failure_conditions", &"protected_unit_ids", &"events", &"dialogue", &"turn_limit",
	]:
		assert_equal(serialized.get(property_name), built.get(property_name), "Serialized chapter matches build field %s" % property_name)
	assert_true(serialized.has_method("validate"), "Serialized chapter exposes semantic validation")
	if serialized.has_method("validate"):
		assert_equal(serialized.validate(), [], "Serialized canonical chapter validates cleanly")


func _load_canonical() -> Variant:
	return ResourceLoader.load(CHAPTER_ONE_RESOURCE_PATH, "ChapterDefinition", ResourceLoader.CACHE_MODE_IGNORE)


func _assert_validation_error(chapter: Variant, code: StringName, path: String) -> void:
	var errors: Array = chapter.validate()
	var found := false
	for error: Variant in errors:
		if error is Dictionary and error.get("code", &"") == code and error.get("path", "") == path:
			assert_true(not String(error.get("message", "")).is_empty(), "Validation error %s has a message" % code)
			found = true
			break
	assert_true(found, "Validation reports %s at %s" % [code, path])


func _assert_unit(
	id: StringName,
	display_name: String,
	role: StringName,
	team: StringName,
	max_hp: int,
	attack: int,
	defense: int,
	resistance: int,
	move: int,
	ranges: Array,
	damage_type: StringName,
	hit: int,
	critical: int,
) -> void:
	var definition: Variant = _unit_catalog_script.get_definition(id)
	assert_true(definition != null, "Unit %s exists" % id)
	if definition == null:
		return
	assert_equal(definition.id, id, "Unit id %s" % id)
	assert_equal(definition.display_name, display_name, "Unit Chinese name %s" % id)
	assert_equal(definition.role, role, "Unit role %s" % id)
	assert_equal(definition.team, team, "Unit team %s" % id)
	assert_equal(definition.max_hp, max_hp, "Unit max HP %s" % id)
	assert_equal(definition.attack, attack, "Unit attack %s" % id)
	assert_equal(definition.defense, defense, "Unit defense %s" % id)
	assert_equal(definition.resistance, resistance, "Unit resistance %s" % id)
	assert_equal(definition.move, move, "Unit move %s" % id)
	assert_equal(definition.ranges, PackedInt32Array(ranges), "Unit ranges %s" % id)
	assert_equal(definition.damage_type, damage_type, "Unit damage type %s" % id)
	assert_equal(definition.hit, hit, "Unit hit %s" % id)
	assert_equal(definition.critical, critical, "Unit critical %s" % id)


func _assert_deployment(
	deployments: Array[Dictionary],
	instance_id: StringName,
	unit_id: StringName,
	team: StringName,
	position: Vector2i,
) -> void:
	var found: Dictionary = {}
	for deployment: Dictionary in deployments:
		if deployment.get("instance_id", &"") == instance_id:
			found = deployment
			break
	assert_true(not found.is_empty(), "Deployment %s exists" % instance_id)
	if found.is_empty():
		return
	assert_equal(found.get("unit_id"), unit_id, "Deployment unit id %s" % instance_id)
	assert_equal(found.get("team"), team, "Deployment team %s" % instance_id)
	assert_equal(found.get("position"), position, "Deployment position %s" % instance_id)
