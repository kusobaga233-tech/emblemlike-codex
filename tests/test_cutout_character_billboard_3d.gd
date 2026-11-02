extends TestCase

const SCENE_PATH := "res://src/qa/cutout_character_billboard_3d.tscn"


func run() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "isolated cutout billboard scene exists")
	var packed := load(SCENE_PATH) as PackedScene
	assert_true(packed != null, "isolated cutout billboard scene loads")
	if packed == null:
		return

	var billboard := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(billboard)
	await tree.process_frame

	var viewport := billboard.get_node_or_null("CharacterViewport") as SubViewport
	assert_true(viewport != null, "billboard owns a SubViewport")
	if viewport != null:
		assert_true(viewport.transparent_bg, "SubViewport renders with a transparent background")
		assert_true(viewport.size.x >= 512 and viewport.size.y >= 720, "SubViewport has enough resolution for formal art")

	var character := billboard.get_node_or_null("CharacterViewport/CutoutCharacter2D")
	assert_true(character != null, "formal cutout character is embedded in the SubViewport")
	if character != null and viewport != null:
		assert_true(is_equal_approx(character.position.x, viewport.size.x * 0.5), "character is centered horizontally")
		assert_true(is_equal_approx(character.position.y, viewport.size.y - billboard.foot_margin_px), "character foot anchor is pinned to viewport bottom")
		var weapon_art := character.get_node_or_null("Skeleton2D/root/body/weapon/WeaponArt") as Sprite2D
		var body_art := character.get_node_or_null("Skeleton2D/root/body/BodyArt") as Sprite2D
		assert_true(body_art != null and body_art.texture.resource_path.ends_with("body_no_sword_no_head.png"), "billboard embeds the updated clean body layer")
		assert_true(weapon_art != null and weapon_art.texture.resource_path.ends_with("clean_weapon_hand.png"), "billboard embeds the updated clean weapon-and-hand layer")

	var quad := billboard.get_node_or_null("CharacterQuad") as MeshInstance3D
	assert_true(quad != null and quad.mesh is QuadMesh, "billboard renders on a QuadMesh")
	var character_material: StandardMaterial3D = null
	if quad != null:
		var quad_mesh := quad.mesh as QuadMesh
		assert_true(quad_mesh.size.y >= 3.2, "character quad preserves full-height review framing")
		assert_true(absf(quad.position.y - quad_mesh.size.y * 0.5) <= 0.05, "character quad is framed from the ground baseline")
		character_material = quad.material_override as StandardMaterial3D
		assert_true(character_material != null and character_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "quad material uses alpha transparency")
		assert_true(character_material != null and character_material.albedo_texture is ViewportTexture, "quad material samples the SubViewport texture")

	var shadow := billboard.get_node_or_null("GroundShadow") as MeshInstance3D
	assert_true(shadow != null and shadow.mesh is QuadMesh, "billboard includes a textured elliptical ground shadow")
	var shadow_material: StandardMaterial3D = null
	if shadow != null:
		var shadow_mesh := shadow.mesh as QuadMesh
		assert_true(shadow_mesh.size.x > shadow_mesh.size.y, "ground shadow is wider than it is deep")
		shadow_material = shadow.material_override as StandardMaterial3D
		assert_true(shadow_material != null and shadow_material.albedo_texture is GradientTexture2D, "ground shadow uses a soft radial alpha texture")
		assert_true(shadow_material != null and shadow_material.albedo_color.a >= 0.34 and shadow_material.albedo_color.a <= 0.42, "ground shadow stays visibly translucent")
		assert_true(shadow.position.y <= 0.025, "ground shadow stays attached to the feet")

	var ground := billboard.get_node_or_null("EnvironmentGround") as MeshInstance3D
	assert_true(ground != null and ground.mesh is PlaneMesh, "QA billboard scene includes real 3D ground geometry")
	var ground_material: StandardMaterial3D = null
	if ground != null:
		ground_material = ground.material_override as StandardMaterial3D
		assert_true(ground_material != null and ground_material.roughness >= 0.8, "3D ground uses a matte presentation material")
		assert_true(ground_material != null and ground_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "3D ground stays in the opaque pass")
	if character_material != null and shadow_material != null and ground_material != null:
		assert_true(shadow_material.render_priority > ground_material.render_priority, "shadow sorts above opaque ground")
		assert_true(character_material.render_priority > shadow_material.render_priority, "character transparency sorts above its shadow")

	var camera := Camera3D.new()
	camera.position = Vector3(4.0, 2.0, 4.0)
	tree.root.add_child(camera)
	billboard.face_camera(camera)
	var forward: Vector3 = -billboard.global_basis.z
	var expected: Vector3 = billboard.global_position.direction_to(Vector3(camera.global_position.x, billboard.global_position.y, camera.global_position.z))
	assert_true(forward.dot(expected) > 0.999, "billboard faces the camera around the vertical axis")

	var forwarded_events: Array[StringName] = []
	billboard.presentation_event.connect(func(event_name: StringName, _payload: Dictionary) -> void: forwarded_events.append(event_name))
	assert_true(billboard.play_animation(&"attack_primary"), "billboard forwards animation playback to the cutout")
	await tree.create_timer(0.8).timeout
	assert_equal(forwarded_events, [&"weapon_trail_on", &"impact", &"weapon_trail_off"], "billboard forwards ordered presentation events")

	camera.free()
	billboard.free()
