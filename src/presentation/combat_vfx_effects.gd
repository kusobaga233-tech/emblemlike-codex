class_name CombatVfxEffects
extends RefCounted

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color.darkened(0.35)
	material.emission_energy_multiplier = 0.8
	return material

static func _finish(node: Node3D, parent: Node, duration: float) -> Node3D:
	parent.add_child(node)
	if duration > 0.0 and parent.is_inside_tree() and parent.get_tree() != null:
		parent.get_tree().create_timer(duration).timeout.connect(node.queue_free)
	return node

static func spawn_ring(parent: Node3D, position: Vector3, color: Color, duration: float, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "CombatVfxRing"
	root.position = position
	root.set_meta("effect_category", &"ring")
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.04
	mesh.mesh = cylinder
	mesh.material_override = _material(color)
	root.add_child(mesh)
	return _finish(root, parent, duration)

static func spawn_trail(parent: Node3D, origin: Vector3, target: Vector3, color: Color, duration: float, secondary: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "CombatVfxTrail"
	root.position = origin
	root.set_meta("effect_category", &"trail")
	root.set_meta("secondary", secondary)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var quad := QuadMesh.new()
	quad.size = Vector2(maxf(origin.distance_to(target), 0.1), 0.08 if secondary else 0.14)
	mesh.mesh = quad
	mesh.material_override = _material(color)
	root.add_child(mesh)
	var direction := target - origin
	if not direction.is_zero_approx():
		root.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return _finish(root, parent, duration)

static func spawn_burst(parent: Node3D, position: Vector3, color: Color, duration: float, critical: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "CombatVfxBurst"
	root.position = position
	root.set_meta("effect_category", &"burst")
	root.set_meta("critical", critical)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45 if critical else 0.3, 0.45 if critical else 0.3)
	mesh.mesh = quad
	mesh.material_override = _material(color)
	root.add_child(mesh)
	return _finish(root, parent, duration)

static func spawn_particles(parent: Node3D, position: Vector3, color: Color, duration: float, count: int) -> Node3D:
	var root := Node3D.new()
	root.name = "CombatVfxParticles"
	root.position = position
	root.set_meta("effect_category", &"particles")
	var particles := GPUParticles3D.new()
	particles.name = "Particles"
	particles.amount = maxi(count, 1)
	particles.one_shot = true
	particles.lifetime = maxf(duration, 0.05)
	particles.explosiveness = 1.0
	var process := ParticleProcessMaterial.new()
	process.color = color
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.7
	particles.process_material = process
	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.12, 0.12)
	draw_mesh.material = _material(color)
	particles.draw_pass_1 = draw_mesh
	root.add_child(particles)
	return _finish(root, parent, duration)
