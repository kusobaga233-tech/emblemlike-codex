extends SceneTree

const TESTS_DIRECTORY := "res://tests"


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var test_files := DirAccess.get_files_at(TESTS_DIRECTORY)
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

		test_case.run()
		var failures: Array = test_case.failures
		if failures.is_empty():
			print("PASS %s" % file_name)
			continue

		tests_failed += 1
		print("FAIL %s" % file_name)
		for failure in failures:
			print("  %s" % failure)

	print("Ran %d test file(s): %d passed, %d failed." % [
		tests_run,
		tests_run - tests_failed,
		tests_failed,
	])
	quit(1 if tests_failed > 0 else 0)
