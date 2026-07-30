class_name ChapterOne
extends RefCounted

const CHAPTER_DEFINITION_SCRIPT := preload("res://src/content/chapter_definition.gd")


static func build() -> ChapterDefinition:
	var chapter: ChapterDefinition = CHAPTER_DEFINITION_SCRIPT.new()
	chapter.id = &"chapter-1"
	chapter.title = "雾桥初阵"
	chapter.subtitle = "晨雾中的第一道誓约"
	chapter.width = 8
	chapter.height = 10
	chapter.terrain = _terrain()
	chapter.deployments = _deployments()
	chapter.objectives = [{"type": &"unit_defeated", "target_id": &"bridge-captain"}]
	chapter.failure_conditions = [{"type": &"unit_defeated", "target_id": &"aurelia-1"}]
	chapter.protected_unit_ids = [&"aurelia-1"]
	chapter.events = _events()
	chapter.dialogue = _dialogue()
	chapter.turn_limit = 20
	return chapter


static func _terrain() -> PackedStringArray:
	return PackedStringArray([
		&"forest", &"plain", &"plain", &"plain", &"crystal", &"plain", &"plain", &"forest",
		&"plain", &"plain", &"water", &"water", &"plain", &"plain", &"plain", &"plain",
		&"plain", &"forest", &"water", &"plain", &"plain", &"crystal", &"plain", &"plain",
		&"plain", &"plain", &"water", &"plain", &"forest", &"plain", &"plain", &"plain",
		&"water", &"bridge", &"bridge", &"bridge", &"bridge", &"bridge", &"bridge", &"water",
		&"plain", &"water", &"plain", &"forest", &"plain", &"plain", &"plain", &"water",
		&"crystal", &"water", &"plain", &"plain", &"forest", &"plain", &"water", &"plain",
		&"plain", &"plain", &"plain", &"water", &"plain", &"forest", &"water", &"plain",
		&"plain", &"plain", &"plain", &"water", &"crystal", &"plain", &"water", &"forest",
		&"forest", &"plain", &"plain", &"water", &"plain", &"plain", &"water", &"crystal",
	])


static func _deployments() -> Array[Dictionary]:
	return [
		{"instance_id": &"aurelia-1", "unit_id": &"aurelia", "team": &"player", "position": Vector2i(1, 7)},
		{"instance_id": &"brann-1", "unit_id": &"brann", "team": &"player", "position": Vector2i(2, 8)},
		{"instance_id": &"elio-1", "unit_id": &"elio", "team": &"player", "position": Vector2i(3, 8)},
		{"instance_id": &"fenn-1", "unit_id": &"fenn", "team": &"player", "position": Vector2i(1, 8)},
		{"instance_id": &"captain-1", "unit_id": &"bridge-captain", "team": &"enemy", "position": Vector2i(6, 3)},
		{"instance_id": &"blade-1", "unit_id": &"hollow-blade", "team": &"enemy", "position": Vector2i(5, 5)},
		{"instance_id": &"bow-1", "unit_id": &"hollow-bow", "team": &"enemy", "position": Vector2i(6, 4)},
	]


static func _events() -> Array[Dictionary]:
	return [
		{"id": &"mist-teach", "trigger": &"round-start:1", "text": "雾气遮住了桥面，先确认可移动范围。"},
		{"id": &"captain-advance", "trigger": &"round:4", "text": "守桥队长拔剑前进。"},
		{"id": &"first-resonance", "trigger": &"resonance:100", "text": "星誓共鸣已准备完成。"},
	]


static func _dialogue() -> Dictionary:
	return {
		"prologue": ["星核的残光穿过雾桥。", "奥蕾莉亚：我们必须在王庭援军赶到前通过。"],
		"midpoint": ["布兰：别让他们切断退路！"],
		"victory": ["桥上的雾散开了，第一枚星屑落入掌心。"],
		"defeat": ["雾重新吞没了桥面。"],
	}
