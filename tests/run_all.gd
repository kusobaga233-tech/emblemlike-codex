extends SceneTree

const TESTS_DIRECTORY := "res://tests"
const WORKER_FLAG := "--test-runner-worker"


func _init() -> void:
	var user_arguments := OS.get_cmdline_user_args()
	if user_arguments.size() >= 2 and user_arguments[0] == WORKER_FLAG:
		call_deferred("_run_single_test", user_arguments[1])
	else:
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
		if not _is_eligible_test_file(file_name):
			continue

		tests_run += 1
		var test_path := "%s/%s" % [TESTS_DIRECTORY, file_name]
		if not _run_test_process(test_path, file_name):
			tests_failed += 1

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


func _is_eligible_test_file(file_name: String) -> bool:
	return (
		file_name.begins_with("test_")
		and file_name.ends_with(".gd")
		and file_name != "test_case.gd"
	)


func _run_test_process(test_path: String, file_name: String) -> bool:
	var worker_output: Array = []
	var worker_exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			get_script().resource_path,
			"--quit-after",
			"2",
			"--",
			WORKER_FLAG,
			test_path,
		]),
		worker_output,
		true,
	)
	var combined_output := "\n".join(PackedStringArray(worker_output))
	var has_script_error := _has_script_error_diagnostic(combined_output)
	_emit_worker_output(combined_output, has_script_error)
	if has_script_error:
		print("FAIL %s" % file_name)
		print("  Test suite emitted SCRIPT ERROR while running this file; treating run as failed.")
		return false
	return worker_exit_code == 0


func _has_script_error_diagnostic(worker_output: String) -> bool:
	for line in worker_output.split("\n"):
		var line_without_ending := line.trim_suffix("\r")
		if line_without_ending.begins_with("SCRIPT ERROR:"):
			return true
	return false


func _emit_worker_output(worker_output: String, suppress_success: bool) -> void:
	for line in worker_output.split("\n"):
		var cleaned_line := line.strip_edges()
		if cleaned_line.begins_with("Godot Engine v"):
			continue
		if suppress_success and cleaned_line.begins_with("PASS "):
			continue
		if not cleaned_line.is_empty():
			print(cleaned_line)


func _run_single_test(test_path: String) -> void:
	var file_name := test_path.get_file()
	var test_script := load(test_path) as Script
	if test_script == null:
		print("FAIL %s" % file_name)
		print("  Could not load test script.")
		quit(1)
		return

	if not _inherits_test_case(test_script):
		print("FAIL %s" % file_name)
		print("  Malformed test: expected TestCase inheritance.")
		quit(1)
		return

	var test_case: Variant = test_script.new()
	if not test_case.has_method("run"):
		print("FAIL %s" % file_name)
		print("  Test script does not define run().")
		quit(1)
		return

	test_case.run()
	var failures: Array = test_case.failures
	if failures.is_empty():
		print("PASS %s" % file_name)
		quit(0)
		return

	print("FAIL %s" % file_name)
	for failure in failures:
		print("  %s" % failure)
	quit(1)


func _inherits_test_case(test_script: Script) -> bool:
	var base_script := test_script.get_base_script()
	while base_script != null:
		if base_script.resource_path == "res://tests/test_case.gd":
			return true
		base_script = base_script.get_base_script()
	return false
