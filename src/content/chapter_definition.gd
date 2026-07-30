class_name ChapterDefinition
extends Resource

const UNIT_CATALOG_SCRIPT := preload("res://src/content/unit_catalog.gd")
const VALID_TERRAIN_IDS := ["plain", "bridge", "forest", "water", "crystal"]

@export var id: StringName = &""
@export var title: String = ""
@export var subtitle: String = ""
@export var width: int = 0
@export var height: int = 0
@export var terrain: PackedStringArray = PackedStringArray()
@export var deployments: Array[Dictionary] = []
@export var objectives: Array[Dictionary] = []
@export var failure_conditions: Array[Dictionary] = []
@export var protected_unit_ids: Array[StringName] = []
@export var events: Array[Dictionary] = []
@export var dialogue: Dictionary = {}
@export var turn_limit: int = 0


func validate() -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	_validate_dimensions(errors)
	_validate_terrain(errors)
	var reference_index := _validate_deployments(errors)
	_validate_condition_references(errors, objectives, "objectives", reference_index)
	_validate_condition_references(errors, failure_conditions, "failure_conditions", reference_index)
	_validate_protected_references(errors, reference_index)
	return errors


func validated_deep_duplicate() -> ChapterDefinition:
	if not validate().is_empty():
		return null
	return deep_duplicate()


func deep_duplicate() -> ChapterDefinition:
	return _deep_copy_resource(self) as ChapterDefinition


func _validate_dimensions(errors: Array[Dictionary]) -> void:
	if width <= 0:
		_add_error(errors, &"invalid_dimensions", "width", "Board width must be greater than zero.")
	if height <= 0:
		_add_error(errors, &"invalid_dimensions", "height", "Board height must be greater than zero.")


func _validate_terrain(errors: Array[Dictionary]) -> void:
	if width > 0 and height > 0 and terrain.size() != width * height:
		_add_error(
			errors,
			&"terrain_length_mismatch",
			"terrain",
			"Terrain cell count must equal width multiplied by height.",
		)
	for index: int in terrain.size():
		if terrain[index] not in VALID_TERRAIN_IDS:
			_add_error(
				errors,
				&"unknown_terrain_id",
				"terrain[%d]" % index,
				"Terrain id '%s' is not supported." % terrain[index],
			)


func _validate_deployments(errors: Array[Dictionary]) -> Dictionary:
	var instance_counts: Dictionary = {}
	var definition_counts: Dictionary = {}
	var occupied_positions: Dictionary = {}

	for index: int in deployments.size():
		var deployment: Dictionary = deployments[index]
		var instance_id := StringName(deployment.get("instance_id", &""))
		var unit_id := StringName(deployment.get("unit_id", &""))
		var team := StringName(deployment.get("team", &""))
		var instance_path := "deployments[%d].instance_id" % index

		if instance_id == &"":
			_add_error(errors, &"empty_instance_id", instance_path, "Deployment instance id cannot be empty.")
		else:
			instance_counts[instance_id] = int(instance_counts.get(instance_id, 0)) + 1
			if instance_counts[instance_id] > 1:
				_add_error(errors, &"duplicate_instance_id", instance_path, "Deployment instance id must be unique.")

		if unit_id != &"":
			definition_counts[unit_id] = int(definition_counts.get(unit_id, 0)) + 1
		var definition: UnitDefinition = UNIT_CATALOG_SCRIPT.get_definition(unit_id)
		if definition == null:
			_add_error(
				errors,
				&"unknown_unit_id",
				"deployments[%d].unit_id" % index,
				"Deployment unit id '%s' is not in UnitCatalog." % unit_id,
			)
		elif team != definition.team:
			_add_error(
				errors,
				&"deployment_team_mismatch",
				"deployments[%d].team" % index,
				"Deployment team must match the catalog definition team.",
			)

		var position_value: Variant = deployment.get("position")
		if not position_value is Vector2i:
			_add_error(
				errors,
				&"invalid_position",
				"deployments[%d].position" % index,
				"Deployment position must be a Vector2i.",
			)
			continue
		var position: Vector2i = position_value
		if width > 0 and height > 0 and (
			position.x < 0 or position.y < 0 or position.x >= width or position.y >= height
		):
			_add_error(
				errors,
				&"position_out_of_bounds",
				"deployments[%d].position" % index,
				"Deployment position must be inside the board.",
			)
		elif terrain.size() == width * height and terrain[position.y * width + position.x] == "water":
			_add_error(
				errors,
				&"deployment_on_blocked_terrain",
				"deployments[%d].position" % index,
				"Deployment position cannot use blocked water terrain.",
			)
		if occupied_positions.has(position):
			_add_error(
				errors,
				&"overlapping_position",
				"deployments[%d].position" % index,
				"Living deployments cannot share a starting position.",
			)
		else:
			occupied_positions[position] = index

	return {
		"instance_counts": instance_counts,
		"definition_counts": definition_counts,
	}


func _validate_condition_references(
	errors: Array[Dictionary],
	conditions: Array[Dictionary],
	property_name: String,
	reference_index: Dictionary,
) -> void:
	for index: int in conditions.size():
		var target_id := StringName(conditions[index].get("target_id", &""))
		_validate_reference(
			errors,
			target_id,
			"%s[%d].target_id" % [property_name, index],
			reference_index,
		)


func _validate_protected_references(errors: Array[Dictionary], reference_index: Dictionary) -> void:
	for index: int in protected_unit_ids.size():
		_validate_reference(
			errors,
			protected_unit_ids[index],
			"protected_unit_ids[%d]" % index,
			reference_index,
		)


func _validate_reference(
	errors: Array[Dictionary],
	target_id: StringName,
	path: String,
	reference_index: Dictionary,
) -> void:
	var instance_count := int(reference_index["instance_counts"].get(target_id, 0))
	if instance_count == 1:
		return
	if instance_count > 1:
		_add_error(errors, &"ambiguous_reference", path, "Reference matches multiple deployment instances.")
		return

	var definition_count := int(reference_index["definition_counts"].get(target_id, 0))
	if definition_count == 1:
		return
	if definition_count > 1:
		_add_error(errors, &"ambiguous_reference", path, "Reference matches multiple unit definitions.")
		return
	_add_error(errors, &"unresolved_reference", path, "Reference does not resolve to a deployment.")


func _add_error(
	errors: Array[Dictionary],
	code: StringName,
	path: String,
	message: String,
) -> void:
	errors.append({"code": code, "path": path, "message": message})


static func _deep_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary_copy: Dictionary = value.duplicate(false)
			dictionary_copy.clear()
			for key: Variant in value:
				dictionary_copy[_deep_copy(key)] = _deep_copy(value[key])
			return dictionary_copy
		TYPE_ARRAY:
			var array_copy: Array = value.duplicate(false)
			for index: int in value.size():
				array_copy[index] = _deep_copy(value[index])
			return array_copy
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return value.duplicate()
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return value.duplicate()
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return value.duplicate()
		TYPE_PACKED_VECTOR4_ARRAY:
			return value.duplicate()
		TYPE_OBJECT:
			if value is Resource:
				return _deep_copy_resource(value)
	return value


static func _deep_copy_resource(source: Resource) -> Resource:
	var resource_copy: Resource = source.duplicate(true)
	for property: Dictionary in source.get_property_list():
		var usage := int(property.get("usage", 0))
		var property_name := StringName(property.get("name", &""))
		var copyable_usage := PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE
		if property_name == &"script" or (usage & copyable_usage) == 0:
			continue
		resource_copy.set(property_name, _deep_copy(source.get(property_name)))
	return resource_copy
