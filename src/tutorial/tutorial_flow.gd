class_name TutorialFlow
extends RefCounted

signal step_changed(step: Dictionary)
signal finished

const STEP_MOVE := &"move"
const STEP_ATTACK := &"attack"
const STEP_HEAL := &"heal"
const STEP_RESONANCE := &"resonance"

const STEPS: Array[Dictionary] = [
	{
		"id": STEP_MOVE,
		"title": "第一步 · 移动",
		"instruction": "选择一名我方角色，点击“移动”，再点击蓝色高亮地块。",
		"hint": "右键可撤销尚未提交的移动；点击“待机”提交后不可撤销。",
	},
	{
		"id": STEP_ATTACK,
		"title": "第二步 · 攻击",
		"instruction": "选择我方角色，点击“攻击”，悬停查看预测后点击敌军锁定，再点“确认攻击”。",
		"hint": "攻击会消耗该角色本阶段行动；可以先移动再攻击。",
	},
	{
		"id": STEP_HEAL,
		"title": "第三步 · 治疗",
		"instruction": "选择艾利欧，点击“治疗”，再点击相邻且受伤的友军并确认。",
		"hint": "每次治疗使星誓共鸣 +25%。若友军满血，可先结束回合让敌军进攻。",
	},
	{
		"id": STEP_RESONANCE,
		"title": "第四步 · 星誓共鸣",
		"instruction": "共鸣达到 100% 后，选择奥蕾莉亚，点击“共鸣”，先选相邻且未行动的友军，再选射程内敌军。",
		"hint": "共鸣会同时消耗奥蕾莉亚与伙伴本阶段行动。",
	},
]

var step_index: int = 0
var skipped: bool = false
var _demonstrated: Dictionary = {}


func current_step() -> Dictionary:
	if is_finished():
		return {}
	return STEPS[step_index].duplicate(true)


func step_number() -> int:
	return mini(step_index + 1, STEPS.size())


func step_count() -> int:
	return STEPS.size()


func is_finished() -> bool:
	return step_index >= STEPS.size()


func is_active() -> bool:
	return not skipped and not is_finished()


func observe_event(event: Dictionary, session: Variant) -> void:
	if not is_active() or session == null:
		return
	var type := StringName(event.get("type", &""))
	var actor_id := StringName(event.get("actor_id", &""))
	match type:
		&"unit_moved":
			if _is_player_unit(session, actor_id):
				_mark(STEP_MOVE)
		&"unit_acted":
			if _is_player_unit(session, actor_id):
				var action := StringName(event.get("payload", {}).get("action", &""))
				if action == &"attack":
					_mark(STEP_ATTACK)
				elif action == &"support":
					_mark(STEP_HEAL)
		&"resonance_finished":
			_mark(STEP_RESONANCE)
	_advance()


func skip() -> void:
	if skipped or is_finished():
		return
	skipped = true
	step_index = STEPS.size()
	step_changed.emit({})
	finished.emit()


func reset() -> void:
	step_index = 0
	skipped = false
	_demonstrated.clear()
	step_changed.emit(current_step())


func _mark(step_id: StringName) -> void:
	_demonstrated[step_id] = true


func _advance() -> void:
	var before := step_index
	while not is_finished() and _demonstrated.has(StringName(STEPS[step_index]["id"])):
		step_index += 1
	if step_index == before:
		return
	if is_finished():
		finished.emit()
	else:
		step_changed.emit(current_step())


func _is_player_unit(session: Variant, instance_id: StringName) -> bool:
	if instance_id == &"":
		return false
	var unit: Variant = session._find_unit(instance_id)
	return unit != null and unit.definition != null and unit.definition.team == &"player"
