extends Node

func _ready() -> void:
	var coordinator := get_node_or_null("/root/FlowCoordinator")
	if coordinator != null:
		coordinator.call_deferred("start_flow")
