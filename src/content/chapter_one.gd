class_name ChapterOne
extends RefCounted

const CHAPTER_ONE_RESOURCE_PATH := "res://src/content/chapter_one.tres"


static func build() -> ChapterDefinition:
	var canonical: Variant = ResourceLoader.load(
		CHAPTER_ONE_RESOURCE_PATH,
		"ChapterDefinition",
		ResourceLoader.CACHE_MODE_IGNORE,
	)
	if not canonical is ChapterDefinition:
		return null
	return canonical.validated_deep_duplicate()
