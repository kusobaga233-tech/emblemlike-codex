class_name ChapterOne
extends RefCounted

const CHAPTER_ONE_RESOURCE_PATH := "res://src/content/chapter_one.tres"
const CHAPTER_DEFINITION_SCRIPT := preload("res://src/content/chapter_definition.gd")


static func build() -> ChapterDefinition:
	# Force the custom Resource script into the export dependency graph before
	# the converted .res file is loaded in a packaged build.
	if CHAPTER_DEFINITION_SCRIPT == null:
		return null
	var canonical: Variant = ResourceLoader.load(
		CHAPTER_ONE_RESOURCE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE,
	)
	if not canonical is ChapterDefinition:
		return null
	return canonical.validated_deep_duplicate()
