class_name UnitCatalog
extends RefCounted

const UNIT_DEFINITION_SCRIPT := preload("res://src/core/unit_definition.gd")


static func get_definition(id: StringName) -> UnitDefinition:
	match id:
		&"aurelia":
			return _make(id, "奥蕾莉亚", &"player", &"先锋", 24, 11, 4, 3, 5, [1], &"physical", 90, 5)
		&"brann":
			return _make(id, "布兰", &"player", &"守卫", 32, 9, 8, 3, 3, [1], &"physical", 90, 5)
		&"elio":
			return _make(id, "艾利欧", &"player", &"治疗者", 24, 4, 4, 8, 4, [1], &"physical", 90, 5)
		&"fenn":
			return _make(id, "芬恩", &"player", &"弓手", 24, 9, 4, 3, 4, [2, 3], &"physical", 90, 5)
		&"bridge-captain":
			return _make(id, "雾桥队长", &"enemy", &"守桥执誓官", 42, 13, 6, 2, 4, [1], &"physical", 82, 3)
		&"hollow-blade":
			return _make(id, "空誓剑士", &"enemy", &"近战", 18, 8, 3, 2, 3, [1], &"physical", 82, 3)
		&"hollow-bow":
			return _make(id, "空誓弓手", &"enemy", &"远程", 18, 8, 3, 2, 3, [2, 3], &"physical", 82, 3)
		_:
			return null


static func _make(
	id: StringName,
	display_name: String,
	team: StringName,
	role: StringName,
	max_hp: int,
	attack: int,
	defense: int,
	resistance: int,
	move: int,
	ranges: Array,
	damage_type: StringName,
	hit: int,
	critical: int,
) -> UnitDefinition:
	return UNIT_DEFINITION_SCRIPT.new(
		id,
		display_name,
		team,
		role,
		max_hp,
		attack,
		defense,
		resistance,
		move,
		PackedInt32Array(ranges),
		damage_type,
		hit,
		critical,
	)
