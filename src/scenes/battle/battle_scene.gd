class_name BattleScene
extends Node3D

const BATTLE_SESSION_SCRIPT := preload("res://src/tactics/battle_session.gd")
const CHAPTER_ONE_SCRIPT := preload("res://src/content/chapter_one.gd")
const GREYBOX_UNIT_SCRIPT := preload("res://src/presentation/greybox_unit.gd")

var chapter: Variant
var session: Variant
var _configured: bool = false


func _ready() -> void:
	if not _configured:
		setup_battle(CHAPTER_ONE_SCRIPT.build())


func setup_battle(initial_chapter: Variant, injected_session: Variant = null) -> void:
	_disconnect_session()
	chapter = initial_chapter
	session = injected_session
	if session == null:
		session = BATTLE_SESSION_SCRIPT.new(initial_chapter)
	var presentation_chapter: Variant = session.chapter if session.chapter != null else initial_chapter
	get_node("GreyboxBoard").build(presentation_chapter)
	_clear_units()
	for unit_state: Variant in session.units:
		var unit := GREYBOX_UNIT_SCRIPT.new() as Node3D
		unit.name = String(unit_state.instance_id)
		unit.configure(unit_state)
		get_node("Units").add_child(unit)
		_assign_owner_recursive(unit)
	get_node("TacticalCamera").configure_board(
		int(presentation_chapter.width),
		int(presentation_chapter.height),
	)
	var event_callable := Callable(self, "_on_events_flushed")
	if not session.events_flushed.is_connected(event_callable):
		session.events_flushed.connect(event_callable)
	_configured = true


func get_unit_node(instance_id: StringName) -> Node3D:
	return get_node_or_null("Units/%s" % String(instance_id)) as Node3D


func _on_events_flushed(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		for unit: Node in get_node("Units").get_children():
			unit.play_event(event)
		var event_type := StringName(event.get("type", &""))
		var actor_id := StringName(event.get("actor_id", &""))
		if event_type == &"unit_selected":
			var selected := get_unit_node(actor_id)
			get_node("TacticalCamera").focus_target = selected
		elif event_type == &"unit_moved":
			var moved := get_unit_node(actor_id)
			if moved != null and get_node("TacticalCamera").focus_target == moved:
				get_node("TacticalCamera").focus(moved.position)


func _disconnect_session() -> void:
	if session == null:
		return
	var event_callable := Callable(self, "_on_events_flushed")
	if session.events_flushed.is_connected(event_callable):
		session.events_flushed.disconnect(event_callable)


func _clear_units() -> void:
	for child: Node in get_node("Units").get_children():
		child.free()


func _assign_owner_recursive(node: Node) -> void:
	node.owner = self
	for child: Node in node.get_children():
		_assign_owner_recursive(child)
