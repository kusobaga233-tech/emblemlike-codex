extends SceneTree

const TESTS_DIRECTORY := "res://tests"


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var tests_directory := DirAccess.open(TESTS_DIRECTORY)
	if tests_directory == null:
		print("ERROR Test directory is missing or unreadable: %s" % TESTS_DIRECTORY)
		quit(1)
		return

	var test_files := tests_directory.get_files()
	test_files.sort()

	var tests_run := 0
	var tests_failed := 0

	for file_name in test_files:
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		if file_name == "test_case.gd":
			continue

		tests_run += 1
		var test_path := "%s/%s" % [TESTS_DIRECTORY, file_name]
		var test_script := load(test_path) as Script
		if test_script == null:
			tests_failed += 1
			print("FAIL %s" % file_name)
			print("  Could not load test script.")
			continue

		var test_case: Variant = test_script.new()
		if not test_case.has_method("run"):
			tests_failed += 1
			print("FAIL %s" % file_name)
			print("  Test script does not define run().")
			continue
		if not _inherits_test_case(test_script):
			tests_failed += 1
			print("FAIL %s" % file_name)
			print("  Malformed test: expected TestCase inheritance.")
			continue

		test_case.run()
		var failures: Array = test_case.failures
		if failures.is_empty():
			print("PASS %s" % file_name)
			continue

		tests_failed += 1
		print("FAIL %s" % file_name)
		for failure in failures:
			print("  %s" % failure)

	if tests_run == 0:
		print("ERROR No eligible tests found in %s." % TESTS_DIRECTORY)
		quit(1)
		return

	print("Ran %d test file(s): %d passed, %d failed." % [
		tests_run,
		tests_run - tests_failed,
		tests_failed,
	])
	quit(1 if tests_failed > 0 else 0)


func _inherits_test_case(test_script: Script) -> bool:
	var base_script := test_script.get_base_script()
	while base_script != null:
		if base_script.resource_path == "res://tests/test_case.gd":
			return true
		base_script = base_script.get_base_script()
	return false
