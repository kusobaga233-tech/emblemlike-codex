class_name EnemyInspectionPanel
extends PanelContainer

# Snapshot values only: this panel never owns or changes a rule-state object.
func show_enemy(data: Dictionary) -> void:
	$Layout/Title.text = "%s · 敌军" % String(data.get("name", ""))
	$Layout/Role.text = "兵种：" + String(data.get("role", ""))
	$Layout/Health.text = "生命：%d / %d" % [int(data.get("hp", 0)), int(data.get("max_hp", 0))]
	var type_label := "魔法" if data.get("damage_type") == &"magical" else "物理"
	$Layout/Offense.text = "攻击：%d（%s）" % [int(data.get("attack", 0)), type_label]
	$Layout/Defense.text = "防御：%d    抗性：%d" % [int(data.get("defense", 0)), int(data.get("resistance", 0))]
	var ranges := PackedStringArray()
	for distance: int in data.get("ranges", []): ranges.append(str(distance))
	$Layout/Mobility.text = "移动：%d 格    射程：%s 格" % [int(data.get("move", 0)), "、".join(ranges) if not ranges.is_empty() else "无"]
	$Layout/Accuracy.text = "基础命中：%d%%    暴击：%d%%" % [int(data.get("hit", 0)), int(data.get("critical", 0))]
	$Layout/Action.text = "本阶段已行动" if data.get("acted", false) else "本阶段尚未行动"
	visible = true


func clear() -> void:
	visible = false
	for child in $Layout.get_children():
		if child is Label and child.name != "Notice": child.text = ""
