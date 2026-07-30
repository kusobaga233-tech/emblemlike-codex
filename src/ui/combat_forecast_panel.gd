class_name CombatForecastPanel
extends PanelContainer


func show_forecast(forecast: Variant) -> void:
	if not forecast is CombatForecast:
		_clear()
		visible = false
		return
	visible = true
	$Layout/Damage.text = "Damage: %d" % forecast.damage
	$Layout/HitRate.text = "Hit: %d%%" % forecast.hit_rate
	$Layout/CriticalRate.text = "Critical: %d%%" % forecast.critical_rate
	$Layout/StrikeCount.text = "Strikes: %d" % forecast.strike_count
	$Layout/Counter.text = "Counter: %s" % ("Yes" if forecast.can_counter else "No")
	$Layout/RemainingHp.text = "Remaining HP: %d" % forecast.defender_remaining_hp


func _clear() -> void:
	for child: Node in $Layout.get_children():
		if child is Label:
			(child as Label).text = ""
