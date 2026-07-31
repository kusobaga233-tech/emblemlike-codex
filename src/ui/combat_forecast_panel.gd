class_name CombatForecastPanel
extends PanelContainer


func show_forecast(forecast: Variant) -> void:
	if not forecast is CombatForecast:
		_clear()
		visible = false
		return
	visible = true
	$Layout/Title.text = "战斗预测"
	$Layout/Damage.text = "预计伤害：%d" % forecast.damage
	$Layout/HitRate.text = "命中率：%d%%" % forecast.hit_rate
	$Layout/CriticalRate.text = "暴击率：%d%%" % forecast.critical_rate
	$Layout/StrikeCount.text = "攻击次数：%d" % forecast.strike_count
	$Layout/Counter.text = "敌方反击：%s" % ("可以" if forecast.can_counter else "无法")
	$Layout/RemainingHp.text = "敌方剩余生命：%d" % forecast.defender_remaining_hp


func _clear() -> void:
	for child: Node in $Layout.get_children():
		if child is Label:
			(child as Label).text = ""
