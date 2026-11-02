extends TestCase

const SCENE_PATH := "res://src/qa/cutout_character_2d.tscn"
const REQUIRED_BONES := [&"root", &"body", &"head", &"weapon"]
const REQUIRED_ANIMATIONS := [&"idle", &"locomotion", &"attack_primary", &"hit"]


func run() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "isolated cutout character scene exists")
	var packed := load(SCENE_PATH) as PackedScene
	assert_true(packed != null, "isolated cutout character scene loads")
	if packed == null:
		return

	var character := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(character)
	await tree.process_frame

	var skeleton := character.get_node_or_null("Skeleton2D") as Skeleton2D
	assert_true(skeleton != null, "cutout character contains Skeleton2D")
	if skeleton != null:
		for bone_name in REQUIRED_BONES:
			assert_true(_find_named_bone(skeleton, bone_name) != null, "cutout character contains %s Bone2D" % bone_name)

	var body_art := character.get_node_or_null("Skeleton2D/root/body/BodyArt") as Sprite2D
	var head_art := character.get_node_or_null("Skeleton2D/root/body/head/HeadArt") as Sprite2D
	var weapon_art := character.get_node_or_null("Skeleton2D/root/body/weapon/WeaponArt") as Sprite2D
	assert_true(body_art != null and body_art.texture != null, "formal Aurelia full art is assigned")
	assert_true(head_art != null and head_art.texture != null, "formal Aurelia head layer is assigned")
	assert_true(weapon_art != null and weapon_art.texture != null, "separate oathblade art is assigned")
	if body_art != null and body_art.texture != null:
		assert_equal(body_art.texture.resource_path, "res://assets/test/cutout/aurelia_v01/body_no_sword_no_head.png", "body uses approved formal artwork")
	if head_art != null and head_art.texture != null:
		assert_equal(head_art.texture.resource_path, "res://assets/test/cutout/aurelia_v01/clean_head.png", "head uses approved formal artwork")
	if weapon_art != null and weapon_art.texture != null:
		assert_equal(weapon_art.texture.resource_path, "res://assets/test/cutout/aurelia_v01/clean_weapon_hand.png", "weapon and gripping hand use approved formal artwork")
	assert_equal(_find_sprites(character).size(), 3, "cutout exposes exactly three visible art layers")
	if head_art != null:
		var head_position := head_art.global_position
		character.get_node("Skeleton2D/root/body/head").rotation = 0.2
		await tree.process_frame
		assert_true(not is_equal_approx(head_art.global_position.x, head_position.x), "head bone transforms head layer")
	if weapon_art != null:
		var weapon_position := weapon_art.global_position
		character.get_node("Skeleton2D/root/body/weapon").rotation = 0.2
		await tree.process_frame
		assert_true(not is_equal_approx(weapon_art.global_position.x, weapon_position.x), "weapon bone transforms weapon layer")

	var player := character.get_node_or_null("AnimationPlayer") as AnimationPlayer
	assert_true(player != null, "cutout character contains AnimationPlayer")
	if player != null:
		for animation_name in REQUIRED_ANIMATIONS:
			assert_true(player.has_animation(animation_name), "cutout character contains %s animation" % animation_name)

	var emitted_events: Array[StringName] = []
	character.presentation_event.connect(func(event_name: StringName, _payload: Dictionary) -> void: emitted_events.append(event_name))
	assert_true(character.play_animation(&"attack_primary"), "attack animation can be played through character API")
	await tree.create_timer(0.8).timeout
	assert_equal(emitted_events, [&"weapon_trail_on", &"impact", &"weapon_trail_off"], "attack emits ordered presentation events")

	character.free()


func _find_named_bone(node: Node, bone_name: StringName) -> Bone2D:
	if node is Bone2D and node.name == bone_name:
		return node
	for child in node.get_children():
		var found := _find_named_bone(child, bone_name)
		if found != null:
			return found
	return null


func _find_sprites(node: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	if node is Sprite2D and node.texture != null:
		sprites.append(node)
	for child in node.get_children():
		sprites.append_array(_find_sprites(child))
	return sprites
