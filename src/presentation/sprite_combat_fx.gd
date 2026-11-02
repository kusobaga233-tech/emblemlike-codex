class_name SpriteCombatFx
extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 0.7
	return m

static func make_mesh(parent: Node3D, kind: StringName, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = String(kind)
	node.set_meta("sprite_fx", kind)
	node.mesh = ImmediateMesh.new()
	node.material_override = material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)

static func ribbon(mesh: ImmediateMesh, a: Vector3, b: Vector3, width: Vector3) -> void:
	triangle(mesh, a - width, b - width, b + width)
	triangle(mesh, a - width, b + width, a + width)

static func draw_arrow(node: MeshInstance3D, origin: Vector3, target: Vector3, progress: float, camera: Camera3D) -> void:
	var mesh := node.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var forward := origin.direction_to(target)
	var at := origin.lerp(target, clampf(progress, 0.0, 1.0))
	var view := camera.global_basis.z if camera != null else Vector3.FORWARD
	var side := forward.cross(view).normalized()
	if side.is_zero_approx(): side = Vector3.UP
	ribbon(mesh, at - forward * 0.48, at - forward * 0.07, side * 0.018)
	triangle(mesh, at + forward * 0.1, at - forward * 0.13 + side * 0.085, at - forward * 0.13 - side * 0.085)
	triangle(mesh, at - forward * 0.36, at - forward * 0.5 + side * 0.065, at - forward * 0.5 - side * 0.065)
	mesh.surface_end()

static func draw_slash(node: MeshInstance3D, center: Vector3, progress: float, camera: Camera3D, thrust: bool = false, screen_direction: Vector2 = Vector2.RIGHT) -> void:
	var mesh := node.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	var up := camera.global_basis.y if camera != null else Vector3.UP
	var attack_screen := screen_direction.normalized()
	if attack_screen.is_zero_approx(): attack_screen = Vector2.RIGHT
	var attack_axis := (right * attack_screen.x + up * attack_screen.y).normalized()
	var cut_axis := (right * -attack_screen.y + up * attack_screen.x).normalized()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if thrust:
		ribbon(mesh, center - attack_axis * 0.22, center + attack_axis * 0.58, cut_axis * 0.035)
		triangle(mesh, center + attack_axis * 0.72, center + attack_axis * 0.4 + cut_axis * 0.12, center + attack_axis * 0.4 - cut_axis * 0.12)
	else:
		# A camera-facing crescent bulges toward the victim. Taper both ends
		# rather than drawing a flat strip across the incoming direction.
		var sweep := clampf(progress / 0.45, 0.0, 1.0)
		var travel := lerpf(-0.16, 0.1, clampf(progress, 0.0, 1.0))
		var stroke_center := center + attack_axis * travel
		for i in 24:
			var u := float(i) / 24.0
			var v := float(i + 1) / 24.0
			var angle_a := lerpf(-1.35, -1.35 + 2.7 * sweep, u)
			var angle_b := lerpf(-1.35, -1.35 + 2.7 * sweep, v)
			var width_a := 0.005 + 0.11 * sin(u * PI)
			var width_b := 0.005 + 0.11 * sin(v * PI)
			var outer_a := stroke_center + attack_axis * cos(angle_a) * 0.46 + cut_axis * sin(angle_a) * 0.63
			var outer_b := stroke_center + attack_axis * cos(angle_b) * 0.46 + cut_axis * sin(angle_b) * 0.63
			var inner_a := outer_a - attack_axis * width_a
			var inner_b := outer_b - attack_axis * width_b
			triangle(mesh, outer_a, outer_b, inner_b)
			triangle(mesh, outer_a, inner_b, inner_a)
	mesh.surface_end()


static func draw_ring(node: MeshInstance3D, center: Vector3, radius: float, thickness: float) -> void:
	var mesh := node.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a := float(i) / 40 * TAU
		var b := float(i + 1) / 40 * TAU
		var da := Vector3(cos(a), 0.0, sin(a))
		var db := Vector3(cos(b), 0.0, sin(b))
		triangle(mesh, center + da * radius, center + db * radius, center + db * (radius - thickness))
		triangle(mesh, center + da * radius, center + db * (radius - thickness), center + da * (radius - thickness))
	mesh.surface_end()

static func draw_sparks(node: MeshInstance3D, center: Vector3, progress: float, camera: Camera3D) -> void:
	var mesh := node.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	var up := camera.global_basis.y if camera != null else Vector3.UP
	for i in 8:
		var angle := float(i) / 8 * TAU + 0.2
		var dir := right * cos(angle) + up * sin(angle)
		var side := right * -sin(angle) + up * cos(angle)
		var near_point := center + dir * (0.08 + progress * 0.28)
		var far_point := center + dir * (0.3 + progress * 0.42)
		triangle(mesh, far_point, near_point + side * 0.045 * (1.0 - progress), near_point - side * 0.045 * (1.0 - progress))
	mesh.surface_end()
