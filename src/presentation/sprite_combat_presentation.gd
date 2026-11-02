class_name SpriteCombatPresentation
extends Node

signal event_due(event: Dictionary)
signal playback_finished

const FX = preload("res://src/presentation/sprite_combat_fx.gd")
const DURATION := 0.7
const RELEASE := 0.18
var resolve_unit: Callable
var _clock := 0.0
var _tail := 0.0
var _scheduled: Array[Dictionary] = []
var _actions: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _host: Node3D
var _serial := 0
var _home_transforms: Dictionary = {}

func _ready() -> void:
	_host = Node3D.new()
	_host.name = "SpriteCombatEffects"
	add_child(_host)
	_host.owner = get_parent() if get_parent() != null else owner

func is_busy() -> bool:
	return not _scheduled.is_empty() or not _actions.is_empty()

func effect_count() -> int:
	return _host.get_child_count() if is_instance_valid(_host) else 0

func current_style() -> StringName:
	return _actions[0]["style"] if not _actions.is_empty() else &""


func screen_attack_direction(camera: Camera3D, origin: Vector3, target: Vector3) -> Vector2:
	var world_direction := target - origin
	world_direction.y = 0.0
	if world_direction.is_zero_approx():
		return Vector2.RIGHT
	world_direction = world_direction.normalized()
	if camera == null:
		return Vector2(world_direction.x, -world_direction.z).normalized()
	var direction := Vector2(world_direction.dot(camera.global_basis.x), world_direction.dot(camera.global_basis.y))
	return direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT

func has_projectile() -> bool:
	return _effects.any(func(e: Dictionary) -> bool: return e["kind"] == &"arrow" and e["node"].visible)

func accepts(events: Array[Dictionary]) -> bool:
	var start := false
	var finish := false
	for event in events:
		start = start or StringName(event.get("type", &"")) in [&"attack_started", &"support_started"]
		finish = finish or StringName(event.get("type", &"")) in [&"attack_finished", &"unit_healed"]
	return is_busy() or (start and finish)

func _unit(id: StringName) -> Node3D:
	return resolve_unit.call(id) if resolve_unit.is_valid() else null

func _style(actor: Node3D, heal: bool) -> StringName:
	if heal: return &"heal"
	var id := StringName(actor.get_meta("definition_id", &"")) if is_instance_valid(actor) else &""
	if id in [&"fenn", &"hollow-bow"]: return &"bow"
	if id == &"brann": return &"thrust"
	if id == &"elio": return &"magic"
	return &"melee"

func enqueue(events: Array[Dictionary]) -> void:
	var cursor := maxf(_tail, _clock)
	var start := cursor
	var impact := cursor
	for source in events:
		var event: Dictionary = source.duplicate(true)
		event["sprite_sequence"] = true
		var type := StringName(event.get("type", &""))
		var at := cursor
		if type in [&"attack_started", &"support_started"]:
			start = cursor
			var style := _style(_unit(StringName(event.get("actor_id", &""))), type == &"support_started")
			impact = start + (0.42 if style == &"bow" else (0.34 if style in [&"magic", &"heal"] else 0.3))
			event["sprite_style"] = style
		elif type in [&"hit_confirmed", &"damage_applied", &"attack_missed", &"unit_defeated", &"unit_healed"]:
			at = impact
			if type == &"unit_healed": cursor = maxf(cursor, start + DURATION + 0.08)
		elif type == &"attack_finished":
			at = start + DURATION
			cursor = at + 0.08
		_serial += 1
		_scheduled.append({"at": at, "order": _serial, "event": event})
	_tail = maxf(cursor, impact + 0.4)
	_scheduled.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"] if a["at"] != b["at"] else a["order"] < b["order"])
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	var was_busy := is_busy()
	_clock += maxf(delta, 0.0)
	while not _scheduled.is_empty() and float(_scheduled[0]["at"]) <= _clock + 0.000001:
		var job: Dictionary = _scheduled.pop_front()
		var event: Dictionary = job["event"]
		if StringName(event.get("type", &"")) in [&"attack_started", &"support_started"]:
			_begin_action(event, float(job["at"]))
		if StringName(event.get("type", &"")) in [&"hit_confirmed", &"damage_applied"]:
			for action in _actions:
				if action["actor"] == _unit(StringName(event.get("actor_id", &""))) and action["target"] == _unit(StringName(event.get("target_id", &""))):
					action["confirmed"] = true
		if StringName(event.get("type", &"")) in [&"damage_applied", &"unit_healed", &"attack_missed"]:
			_number(event, float(job["at"]))
		event_due.emit(event)
	for action in _actions.duplicate():
		_sample_action(action)
		if _clock >= float(action["start"]) + DURATION:
			_restore(action)
			_actions.erase(action)
	_sample_effects()
	if was_busy and not is_busy():
		playback_finished.emit()

func _begin_action(event: Dictionary, start: float) -> void:
	var actor := _unit(StringName(event.get("actor_id", &"")))
	var target := _unit(StringName(event.get("target_id", &"")))
	if not is_instance_valid(actor) or not is_instance_valid(target): return
	var sprite := actor.get_node_or_null("ProductionVisual") as Sprite3D
	var victim := target.get_node_or_null("ProductionVisual") as Sprite3D
	if sprite == null: return
	var style := StringName(event.get("sprite_style", &"melee"))
	var direction := actor.global_position.direction_to(target.global_position)
	direction.y = 0.0
	direction = direction.normalized()
	if not _home_transforms.has(sprite): _home_transforms[sprite] = sprite.transform
	var action := {"actor": actor, "target": target, "sprite": sprite, "victim": victim, "home": sprite.transform, "victim_home": victim.transform if victim != null else Transform3D.IDENTITY, "victim_tint": victim.modulate if victim != null else Color.WHITE, "start": start, "style": style, "direction": direction, "impact": start + (0.42 if style == &"bow" else (0.34 if style in [&"magic", &"heal"] else 0.3))}
	_actions.append(action)
	var kind: StringName = &"arrow" if style == &"bow" else (&"spell" if style == &"magic" else (&"heal" if style == &"heal" else &"slash"))
	var color := Color("a6ecff") if style in [&"magic", &"heal"] else (Color("fff6d6") if style in [&"melee", &"thrust"] else Color("ffe59a"))
	var camera := get_viewport().get_camera_3d()
	var screen_direction := screen_attack_direction(camera, actor.global_position, target.global_position)
	var mesh := FX.make_mesh(_host, kind, color)
	var attack_origin := actor.global_position + Vector3(0.0, 0.45, 0.0)
	var attack_target := target.global_position + Vector3(0.0, 0.45, 0.0)
	var effect_anchor := (attack_origin + attack_target) * 0.5 if kind == &"slash" else attack_origin
	mesh.global_position = effect_anchor
	_effects.append({"node": mesh, "kind": kind, "start": start + RELEASE, "end": start + DURATION, "origin": attack_origin, "target": attack_target, "anchor": effect_anchor, "impact": float(action["impact"]), "style": style, "screen_direction": screen_direction})

func _sample_action(action: Dictionary) -> void:
	var sprite: Sprite3D = action["sprite"]
	if not is_instance_valid(sprite): return
	var t := clampf(_clock - float(action["start"]), 0.0, DURATION)
	var style: StringName = action["style"]
	var strength := 0.3 if style in [&"melee", &"thrust"] else 0.065
	var displacement: float
	if t < RELEASE:
		displacement = -0.1 * sin(t / RELEASE * PI * 0.5)
	elif t < 0.3:
		displacement = lerpf(-0.1, strength, (t - RELEASE) / 0.12)
	else:
		displacement = strength * (1.0 - smoothstep(0.36, DURATION, t))
	sprite.transform = action["home"]
	sprite.position += (action["direction"] as Vector3) * displacement
	if style in [&"magic", &"heal"]:
		sprite.position.y += sin(t / DURATION * PI) * 0.09
	var victim: Sprite3D = action["victim"]
	var hit_time := float(action["impact"])
	if is_instance_valid(victim) and style != &"heal" and action.get("confirmed", false):
		var hit_elapsed := _clock - hit_time
		victim.transform = action["victim_home"]
		if hit_elapsed >= 0.0 and hit_elapsed < 0.16:
			victim.position += (action["direction"] as Vector3) * sin(hit_elapsed / 0.16 * PI) * 0.07
			victim.modulate = Color(1.8, 1.8, 1.8, 1.0)
		else:
			victim.modulate = action["victim_tint"]

func _restore(action: Dictionary) -> void:
	if is_instance_valid(action["sprite"]): action["sprite"].transform = action["home"]
	if is_instance_valid(action["victim"]):
		action["victim"].transform = action["victim_home"]
		action["victim"].modulate = action["victim_tint"]

func _number(event: Dictionary, at: float) -> void:
	var target := _unit(StringName(event.get("target_id", &"")))
	if target == null: return
	var payload: Dictionary = event.get("payload", {})
	var heal := StringName(event.get("type", &"")) == &"unit_healed"
	var miss := StringName(event.get("type", &"")) == &"attack_missed"
	var label := Label3D.new()
	label.text = "MISS" if miss else ("+" if heal else "-") + str(payload.get("amount", 0))
	label.font_size = 64
	label.pixel_size = 0.005
	label.outline_size = 12
	label.modulate = Color("7fffb1") if heal else Color("ffe49c")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = target.global_position + Vector3(0, 1.05, 0)
	_host.add_child(label)
	_effects.append({"node": label, "kind": &"number", "start": at, "end": at + 0.65, "origin": label.position})
	if not miss:
		var burst := FX.make_mesh(_host, &"impact", Color("7fffb1") if heal else Color("fff1b3"))
		_effects.append({"node": burst, "kind": &"impact", "start": at, "end": at + 0.25, "target": target.global_position + Vector3(0, 0.35, 0)})

func _sample_effects() -> void:
	var camera := get_viewport().get_camera_3d()
	for effect in _effects.duplicate():
		var node: Node3D = effect["node"]
		if not is_instance_valid(node):
			_effects.erase(effect)
			continue
		if _clock >= float(effect["end"]):
			_dispose_effect_node(node)
			_effects.erase(effect)
			continue
		node.visible = _clock >= float(effect["start"])
		if not node.visible: continue
		var elapsed := _clock - float(effect["start"])
		var life := float(effect["end"]) - float(effect["start"])
		var p := clampf(elapsed / life, 0.0, 1.0)
		var kind: StringName = effect["kind"]
		if kind == &"number":
			node.position = effect["origin"] + Vector3(0, p * 0.45, 0)
			node.modulate.a = 1.0 - smoothstep(0.6, 1.0, p)
		elif kind == &"arrow":
			node.visible = _clock < float(effect["impact"])
			# Anchor once in world space; mesh vertices are local offsets.
			node.global_position = effect["origin"]
			FX.draw_arrow(node, Vector3.ZERO, effect["target"] - effect["origin"], elapsed / maxf(0.01, float(effect["impact"]) - float(effect["start"])), camera)
		elif kind == &"slash":
			node.visible = elapsed < 0.24
			(node.material_override as StandardMaterial3D).albedo_color.a = 1.0 - smoothstep(0.13, 0.24, elapsed)
			var screen_direction := screen_attack_direction(camera, effect["origin"], effect["target"])
			effect["screen_direction"] = screen_direction
			node.global_position = effect["anchor"]
			FX.draw_slash(node, Vector3.ZERO, elapsed / 0.24, camera, effect["style"] == &"thrust", screen_direction)
		elif kind in [&"spell", &"heal"]:
			var pos: Vector3 = effect["origin"]
			if kind == &"spell": pos = pos.lerp(effect["target"], clampf(elapsed / 0.16, 0.0, 1.0))
			pos.y = 0.3 if kind == &"heal" else pos.y
			node.global_position = pos if _clock < float(effect["impact"]) else Vector3(effect["target"].x, 0.3, effect["target"].z)
			FX.draw_ring(node, Vector3.ZERO, 0.2 + p * 0.45, 0.04)
		elif kind == &"impact":
			node.global_position = effect["target"]
			FX.draw_sparks(node, Vector3.ZERO, p, camera)

func _dispose_effect_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh is ImmediateMesh:
			(mesh_node.mesh as ImmediateMesh).clear_surfaces()
		mesh_node.mesh = null
		mesh_node.material_override = null
	if node is Label3D:
		var label := node as Label3D
		label.text = ""
		label.font = null
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func clear() -> void:
	var was_busy := is_busy()
	for action in _actions: _restore(action)
	for sprite: Sprite3D in _home_transforms.keys():
		if is_instance_valid(sprite): sprite.transform = _home_transforms[sprite]
	_home_transforms.clear()
	_actions.clear()
	_scheduled.clear()
	_effects.clear()
	if is_instance_valid(_host):
		for child in _host.get_children():
			_dispose_effect_node(child)
	_effects.clear()
	_clock = 0.0
	_tail = 0.0
	if was_busy:
		playback_finished.emit()

func _exit_tree() -> void:
	clear()
	resolve_unit = Callable()
	if is_instance_valid(_host):
		_host.free()
	_host = null
