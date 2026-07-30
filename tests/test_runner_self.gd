extends TestCase

const RUNNER_SOURCE_PATH := "res://tests/run_all.gd"
const TEST_CASE_SOURCE_PATH := "res://tests/test_case.gd"


func run() -> void:
	_test_missing_tests_directory_fails()
	_test_zero_eligible_tests_fails()
	_test_malformed_test_fails_without_crashing_summary()
	_test_runtime_script_error_fails_without_false_pass()
	_test_plain_text_script_error_phrase_still_passes()


func _test_missing_tests_directory_fails() -> void:
	var result := _run_fixture("missing_tests", {})
	assert_equal(result.exit_code, 1, "Missing tests directory exits with failure")
	assert_true(
		result.output.contains("Test directory is missing or unreadable"),
		"Missing tests directory reports a clear error",
	)


func _test_zero_eligible_tests_fails() -> void:
	var result := _run_fixture("zero_tests", {
		"tests/helper.gd": "extends RefCounted\n",
		"tests/test_case.gd": FileAccess.get_file_as_string(TEST_CASE_SOURCE_PATH),
	})
	assert_equal(result.exit_code, 1, "Zero eligible tests exits with failure")
	assert_true(
		result.output.contains("No eligible tests found"),
		"Zero eligible tests reports a clear error",
	)


func _test_malformed_test_fails_without_crashing_summary() -> void:
	var result := _run_fixture("malformed_test", {
		"tests/test_case.gd": FileAccess.get_file_as_string(TEST_CASE_SOURCE_PATH),
		"tests/test_malformed.gd": "extends RefCounted\n\nfunc run() -> void:\n\tpass\n",
	})
	assert_equal(result.exit_code, 1, "Malformed test exits with failure")
	assert_true(
		result.output.contains("Malformed test: expected TestCase inheritance"),
		"Malformed test reports its contract violation",
	)
	assert_true(
		result.output.contains("Ran 1 test file(s): 0 passed, 1 failed."),
		"Malformed test is included in the final summary",
	)


func _test_runtime_script_error_fails_without_false_pass() -> void:
	var result := _run_fixture("runtime_script_error", {
		"tests/test_case.gd": FileAccess.get_file_as_string(TEST_CASE_SOURCE_PATH),
		"tests/test_runtime_error.gd": (
			"extends \"res://tests/test_case.gd\"\n\n"
			+ "func run() -> void:\n"
			+ "\t_trigger_runtime_error()\n\n"
			+ "func _trigger_runtime_error() -> void:\n"
			+ "\tvar value: Variant = null\n"
			+ "\tvalue.call(\"definitely_missing_method\")\n"
		),
	})
	assert_equal(result.exit_code, 1, "Runtime SCRIPT ERROR exits with failure")
	assert_true(
		result.output.contains("SCRIPT ERROR:"),
		"Runtime SCRIPT ERROR remains visible for diagnosis",
	)
	assert_true(
		result.output.contains("Test suite emitted SCRIPT ERROR"),
		"Runner reports a controlled script-error failure",
	)
	assert_true(
		not result.output.contains("PASS test_runtime_error.gd"),
		"Runtime SCRIPT ERROR is not reported as a passing test",
	)


func _test_plain_text_script_error_phrase_still_passes() -> void:
	var result := _run_fixture("plain_text_script_error", {
		"tests/test_case.gd": FileAccess.get_file_as_string(TEST_CASE_SOURCE_PATH),
		"tests/test_plain_text.gd": (
			"extends \"res://tests/test_case.gd\"\n\n"
			+ "func run() -> void:\n"
			+ "\tprint(\"ordinary message mentions SCRIPT ERROR: without being a diagnostic\")\n"
		),
	})
	assert_equal(result.exit_code, 0, "Plain text SCRIPT ERROR phrase exits successfully")
	assert_true(
		result.output.contains("PASS test_plain_text.gd"),
		"Plain text SCRIPT ERROR phrase remains a passing test",
	)
	assert_true(
		not result.output.contains("Test suite emitted SCRIPT ERROR"),
		"Plain text phrase does not trigger controlled script-error failure",
	)


func _run_fixture(fixture_name: String, fixture_files: Dictionary) -> Dictionary:
	var fixture_root := "%s/%s-%d" % [
		ProjectSettings.globalize_path("res://.godot/runner-self-tests"),
		fixture_name,
		Time.get_ticks_usec(),
	]
	var directory_error := DirAccess.make_dir_recursive_absolute(fixture_root)
	assert_equal(directory_error, OK, "Fixture directory can be created")

	_write_utf8(
		fixture_root.path_join("project.godot"),
		"config_version=5\n",
	)
	_write_utf8(
		fixture_root.path_join("run_all.gd"),
		FileAccess.get_file_as_string(RUNNER_SOURCE_PATH),
	)
	for relative_path: String in fixture_files:
		_write_utf8(fixture_root.path_join(relative_path), fixture_files[relative_path])

	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless",
			"--path",
			fixture_root,
			"--script",
			"res://run_all.gd",
			"--quit-after",
			"2",
		]),
		output,
		true,
	)
	return {
		"exit_code": exit_code,
		"output": "\n".join(PackedStringArray(output)),
	}


func _write_utf8(path: String, content: String) -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert_equal(directory_error, OK, "Fixture parent directory can be created")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "Fixture file can be opened: %s" % path)
	if file != null:
		file.store_string(content)
