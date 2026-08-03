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
	node.set_meta("vfx_duration", duration)
	node.set_meta("vfx_elapsed", 0.0)
	return node

static func reset(node: Node3D) -> void:
	node.position = Vector3.ZERO
	node.basis = Basis.IDENTITY
	node.visible = false
	node.set_meta("vfx_elapsed", 0.0)

static func activate(node: Node3D, position: Vector3) -> void:
	node.position = position
	node.visible = true
	node.set_meta("vfx_elapsed", 0.0)

static func _root(existing: Node3D, name_value: String, category: StringName) -> Node3D:
	var root := existing if is_instance_valid(existing) else Node3D.new()
	root.name = name_value
	root.set_meta("effect_category", category)
	root.visible = true
	return root

static func _mesh_instance(root: Node3D) -> MeshInstance3D:
	var mesh := root.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "Mesh"
		root.add_child(mesh)
	return mesh

static func spawn_ring(parent: Node3D, position: Vector3, color: Color, duration: float, radius: float, existing: Node3D = null) -> Node3D:
	var root := _root(existing, "CombatVfxRing", &"ring")
	root.position = position
	root.basis = Basis.IDENTITY
	var mesh := _mesh_instance(root)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.04
	mesh.mesh = cylinder
	mesh.material_override = _material(color)
	return _finish(root, parent, duration) if existing == null else activate_configured(root, duration)

static func spawn_trail(parent: Node3D, origin: Vector3, target: Vector3, color: Color, duration: float, secondary: bool, existing: Node3D = null) -> Node3D:
	var root := _root(existing, "CombatVfxTrail", &"trail")
	root.position = origin
	root.set_meta("secondary", secondary)
	root.basis = Basis.IDENTITY
	var mesh := _mesh_instance(root)
	var quad := QuadMesh.new()
	quad.size = Vector2(maxf(origin.distance_to(target), 0.1), 0.08 if secondary else 0.14)
	mesh.mesh = quad
	mesh.material_override = _material(color)
	var direction := target - origin
	if not direction.is_zero_approx():
		root.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	return _finish(root, parent, duration) if existing == null else activate_configured(root, duration)

static func spawn_burst(parent: Node3D, position: Vector3, color: Color, duration: float, critical: bool, existing: Node3D = null) -> Node3D:
	var root := _root(existing, "CombatVfxBurst", &"burst")
	root.position = position
	root.basis = Basis.IDENTITY
	root.set_meta("critical", critical)
	var mesh := _mesh_instance(root)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45 if critical else 0.3, 0.45 if critical else 0.3)
	mesh.mesh = quad
	mesh.material_override = _material(color)
	return _finish(root, parent, duration) if existing == null else activate_configured(root, duration)

static func spawn_particles(parent: Node3D, position: Vector3, color: Color, duration: float, count: int, existing: Node3D = null) -> Node3D:
	var root := _root(existing, "CombatVfxParticles", &"particles")
	root.position = position
	root.basis = Basis.IDENTITY
	var particles := root.get_node_or_null("Particles") as GPUParticles3D
	if particles == null:
		particles = GPUParticles3D.new()
		particles.name = "Particles"
		root.add_child(particles)
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
	particles.emitting = false
	particles.restart()
	particles.emitting = true
	return _finish(root, parent, duration) if existing == null else activate_configured(root, duration)

static func activate_configured(node: Node3D, duration: float) -> Node3D:
	node.visible = true
	node.set_meta("vfx_duration", duration)
	node.set_meta("vfx_elapsed", 0.0)
	return node
