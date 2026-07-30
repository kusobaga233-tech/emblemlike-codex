class_name TestCase
extends RefCounted

var failures: Array[String] = []


func assert_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		return

	var detail := "Expected %s, got %s." % [str(expected), str(actual)]
	failures.append(_format_failure(message, detail))


func assert_true(value: Variant, message: String = "") -> void:
	if value:
		return

	failures.append(_format_failure(message, "Expected a truthy value."))


func _format_failure(message: String, detail: String) -> String:
	if message.is_empty():
		return detail
	return "%s: %s" % [message, detail]
