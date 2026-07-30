extends TestCase

const CHAPTER_DEFINITION_PATH := "res://src/content/chapter_definition.gd"
const CHAPTER_ONE_PATH := "res://src/content/chapter_one.gd"
const CHAPTER_ONE_RESOURCE_PATH := "res://src/content/chapter_one.tres"
const UNIT_CATALOG_PATH := "res://src/content/unit_catalog.gd"

var _chapter_one_script: Script
var _unit_catalog_script: Script


func run() -> void:
	var chapter_definition_script := load(CHAPTER_DEFINITION_PATH) as Script
	_chapter_one_script = load(CHAPTER_ONE_PATH) as Script
	_unit_catalog_script = load(UNIT_CATALOG_PATH) as Script
	assert_true(chapter_definition_script != null, "ChapterDefinition class exists")
	assert_true(_chapter_one_script != null, "ChapterOne class exists")
	assert_true(_unit_catalog_script != null, "UnitCatalog class exists")
	if chapter_definition_script == null or _chapter_one_script == null or _unit_catalog_script == null:
		return

	_test_unit_catalog_contract()
	_test_original_unit_names_roles_and_balance()
	_test_chapter_board_deployments_and_objectives()
	_test_chapter_events_and_dialogue_are_stable()
	_test_terrain_is_complete_and_explicit()
	_test_repeated_builds_do_not_alias_mutable_content()
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

	assert_equal(chapter.objectives, [{"type": &"unit_defeated", "target_id": &"bridge-captain"}], "Victory requires defeating the bridge captain")
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
	assert_equal(second.objectives[0]["target_id"], &"bridge-captain", "Objective dictionaries do not alias")
	assert_equal(second.failure_conditions[0]["target_id"], &"aurelia-1", "Failure-condition dictionaries do not alias")
	assert_equal(second.protected_unit_ids[0], &"aurelia-1", "Protected-unit arrays do not alias")
	assert_equal(second.events[0]["text"], "雾气遮住了桥面，先确认可移动范围。", "Event dictionaries do not alias")
	assert_equal(second.dialogue["prologue"][0], "星核的残光穿过雾桥。", "Dialogue arrays do not alias")


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
