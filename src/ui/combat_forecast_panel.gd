class_name CombatForecastPanel
extends PanelContainer

signal attack_confirmed
signal support_confirmed
signal resonance_confirmed
signal preview_cancelled

var _confirm_kind: StringName = &""

func _ready() -> void:
	$Layout/Actions/Confirm.pressed.connect(_on_confirm)
	$Layout/Actions/Cancel.pressed.connect(func(): preview_cancelled.emit())
	$Layout/Actions.hide()

func show_support(forecast: Dictionary) -> void:
	_clear()
	_confirm_kind = &"support"
	$Layout/Actions/Confirm.text = "确认治疗"
	for child in $Layout.get_children():
		if child is Label: child.visible = child.name in ["Title", "Damage", "RemainingHp"]
	visible = true
	$Layout/Title.text = "治疗确认 · " + String(forecast.get("target_name", ""))
	$Layout/Damage.text = "恢复生命：+%d" % int(forecast.get("amount", 0))
	$Layout/RemainingHp.text = "生命：%d → %d / %d" % [int(forecast.get("current_hp", 0)), int(forecast.get("remaining_hp", 0)), int(forecast.get("max_hp", 0))]
	$Layout/Actions.show()
	$Layout/Actions/Confirm.disabled = false


func show_resonance(forecast: Dictionary) -> void:
	_clear()
	_confirm_kind = &"resonance"
	for child in $Layout.get_children():
		if child is Label:
			child.visible = child.name in ["Title", "Damage", "HitRate", "StrikeCount", "Counter", "RemainingHp", "Notice"]
	visible = true
	$Layout/Title.text = "星誓共鸣 · " + String(forecast.get("target_name", ""))
	$Layout/Damage.text = "共鸣伤害：%d" % int(forecast.get("damage", 0))
	$Layout/HitRate.text = "命中：必中"
	$Layout/StrikeCount.text = "消耗：共鸣 100%"
	$Layout/Counter.text = "伙伴：%s" % String(forecast.get("partner_name", ""))
	$Layout/RemainingHp.text = "敌方生命：%d → %d / %d" % [
		int(forecast.get("target_hp", 0)),
		int(forecast.get("remaining_hp", 0)),
		int(forecast.get("max_hp", 0)),
	]
	$Layout/Notice.text = "奥蕾莉亚与伙伴本阶段行动将被消耗"
	$Layout/Actions/Confirm.text = "确认共鸣"
	$Layout/Actions/Confirm.disabled = false
	$Layout/Actions.show()




func show_forecast(forecast: Variant) -> void:
	_confirm_kind = &""
	$Layout/Actions.hide()
	if not forecast is CombatForecast:
		_clear()
		visible = false
		return
	visible = true
	for child in $Layout.get_children():
		if child is Label: child.show()
	$Layout/Title.text = "战斗预测"
	$Layout/Damage.text = "预计伤害：%d" % forecast.damage
	$Layout/HitRate.text = "命中率：%d%%" % forecast.hit_rate
	$Layout/CriticalRate.text = "暴击率：%d%%" % forecast.critical_rate
	$Layout/StrikeCount.text = "攻击次数：%d" % forecast.strike_count
	$Layout/Counter.text = "敌方反击：%s" % ("可以" if forecast.can_counter else "无法")
	$Layout/RemainingHp.text = "敌方剩余生命：%d" % forecast.defender_remaining_hp
	$Layout/Notice.text = "普通命中预估；实际结果受命中与暴击影响"


func show_attack(forecast: CombatForecast, target_name: String) -> void:
	show_forecast(forecast)
	if not visible: return
	_confirm_kind = &"attack"
	$Layout/Title.text = "攻击确认 · " + target_name
	$Layout/Actions/Confirm.text = "确认攻击"
	$Layout/Actions/Confirm.disabled = false
	$Layout/Actions.show()


func _on_confirm() -> void:
	if not visible or not $Layout/Actions.visible or $Layout/Actions/Confirm.disabled: return
	match _confirm_kind:
		&"attack": attack_confirmed.emit()
		&"support": support_confirmed.emit()
		&"resonance": resonance_confirmed.emit()


func _clear() -> void:
	_confirm_kind = &""
	for child: Node in $Layout.get_children():
		if child is Label:
			(child as Label).text = ""
