extends TestCase


func run() -> void:
	assert_true(FileAccess.file_exists("res://project.godot"), "Project configuration exists")
	assert_equal(
		ProjectSettings.get_setting("application/config/name", ""),
		"星烬誓约",
		"Project name",
	)
	assert_equal(
		ProjectSettings.get_setting("application/run/main_scene", ""),
		"res://src/scenes/boot.tscn",
		"Main scene",
	)
	assert_equal(
		ProjectSettings.get_setting("display/window/size/viewport_width", 0),
		1920,
		"Viewport width",
	)
	assert_equal(
		ProjectSettings.get_setting("display/window/size/viewport_height", 0),
		1080,
		"Viewport height",
	)
	var project_features: PackedStringArray = ProjectSettings.get_setting(
		"application/config/features",
		PackedStringArray(),
	)
	assert_true(project_features.has("Forward Plus"), "Forward+ renderer feature")
	assert_true(FileAccess.file_exists("res://src/scenes/boot.gd"), "Boot script exists")
	var boot_scene_exists := FileAccess.file_exists("res://src/scenes/boot.tscn")
	assert_true(boot_scene_exists, "Boot scene exists")
	var boot_scene: PackedScene = null
	if boot_scene_exists:
		boot_scene = load("res://src/scenes/boot.tscn") as PackedScene
	assert_true(boot_scene != null, "Boot scene loads")
	if boot_scene != null:
		var boot_node := boot_scene.instantiate()
		assert_true(boot_node.get_script() != null, "Boot scene has its script attached")
		boot_node.free()
