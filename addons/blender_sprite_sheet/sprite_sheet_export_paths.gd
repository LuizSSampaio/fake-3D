@tool
extends RefCounted

const DEFAULT_FRAME_DIGITS := 3
const DEFAULT_OUTPUT_NAME_PATTERN := "{model}.png"
const DEFAULT_OUTPUT_FORMAT := "png"
const OUTPUT_FORMATS := [
	{"label": "PNG", "key": "png", "extension": "png"},
	{"label": "WebP", "key": "webp", "extension": "webp"},
	{"label": "JPEG", "key": "jpg", "extension": "jpg", "aliases": ["jpeg"]},
]


static func get_output_format_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for option in OUTPUT_FORMATS:
		options.append(option.duplicate(true))
	return options


static func normalize_output_format(value: Variant) -> String:
	var text_value := str(value).strip_edges().to_lower()
	if text_value.is_empty():
		text_value = DEFAULT_OUTPUT_FORMAT

	for option in OUTPUT_FORMATS:
		if text_value == str(option["key"]) or text_value == str(option["extension"]) or text_value == str(option["label"]).to_lower():
			return str(option["key"])

		var aliases: Array = option.get("aliases", [])
		for alias in aliases:
			if text_value == str(alias).to_lower():
				return str(option["key"])

	return ""


static func get_output_format_extension(output_format: Variant) -> String:
	var normalized_format := normalize_output_format(output_format)
	if normalized_format.is_empty():
		normalized_format = DEFAULT_OUTPUT_FORMAT

	for option in OUTPUT_FORMATS:
		if normalized_format == str(option["key"]):
			return str(option["extension"])

	return DEFAULT_OUTPUT_FORMAT


static func get_output_format_label(output_format: Variant) -> String:
	var normalized_format := normalize_output_format(output_format)
	if normalized_format.is_empty():
		normalized_format = DEFAULT_OUTPUT_FORMAT

	for option in OUTPUT_FORMATS:
		if normalized_format == str(option["key"]):
			return str(option["label"])

	return DEFAULT_OUTPUT_FORMAT.to_upper()


static func get_default_output_name_pattern(output_format: Variant = DEFAULT_OUTPUT_FORMAT) -> String:
	return "{model}.%s" % get_output_format_extension(output_format)


static func normalize_name_pattern_extension(pattern: String, output_format: Variant) -> String:
	var clean_pattern := pattern.strip_edges()
	if clean_pattern.is_empty():
		clean_pattern = DEFAULT_OUTPUT_NAME_PATTERN

	var extension := get_output_format_extension(output_format)
	var current_extension := clean_pattern.get_extension().to_lower()
	if current_extension.is_empty():
		return "%s.%s" % [clean_pattern, extension]

	if _is_supported_output_extension(current_extension):
		return "%s.%s" % [clean_pattern.get_basename(), extension]

	return clean_pattern


static func normalize_output_path(path: String, output_format: Variant = DEFAULT_OUTPUT_FORMAT) -> String:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return ""

	var extension := get_output_format_extension(output_format)
	if clean_path.get_extension().is_empty():
		return "%s.%s" % [clean_path, extension]

	if clean_path.get_extension().to_lower() != extension:
		return "%s.%s" % [clean_path.get_basename(), extension]

	return clean_path


static func normalize_png_output_path(path: String) -> String:
	return normalize_output_path(path, "png")


static func normalize_output_directory(path: String) -> String:
	var clean_path := _strip_trailing_slashes(path.strip_edges())
	if clean_path.is_empty():
		return ""

	if _directory_exists(clean_path):
		return clean_path

	if not clean_path.get_extension().is_empty():
		return clean_path.get_base_dir()

	return clean_path


static func format_output_name(pattern: String, source_path: String, index: int, count: int, output_path := "") -> String:
	var clean_pattern := pattern.strip_edges()
	if clean_pattern.is_empty():
		clean_pattern = DEFAULT_OUTPUT_NAME_PATTERN

	var source_name := source_path.get_file().get_basename()
	var output_token := _get_output_token_value(output_path)
	var index_width := max(DEFAULT_FRAME_DIGITS, str(max(count, 1)).length())
	var replacements := {
		"{model}": source_name,
		"{source}": source_name,
		"{index}": str(index + 1).pad_zeros(index_width),
		"{index0}": str(index).pad_zeros(max(DEFAULT_FRAME_DIGITS, str(max(count - 1, 0)).length())),
		"{count}": str(count),
		"{output}": output_token,
	}

	var formatted := clean_pattern
	for token in replacements.keys():
		formatted = formatted.replace(token, str(replacements[token]))

	return formatted


static func get_source_output_path(output_path: String, source_path: String, pattern: String, index: int, count: int, output_format := DEFAULT_OUTPUT_FORMAT) -> String:
	var normalized_format := normalize_output_format(output_format)
	if normalized_format.is_empty():
		normalized_format = DEFAULT_OUTPUT_FORMAT

	var normalized_output_path := normalize_output_directory(output_path)
	if normalized_output_path.is_empty():
		normalized_output_path = output_path.strip_edges()

	var file_name := format_output_name(pattern, source_path, index, count, normalized_output_path)
	var extension := get_output_format_extension(normalized_format)
	if file_name.get_extension().to_lower() != extension:
		file_name = "%s.%s" % [file_name.get_basename(), extension]

	return normalized_output_path.path_join(file_name)


static func get_individual_frame_paths(output_path: String, frame_count: int, output_format := "") -> PackedStringArray:
	var normalized_format := normalize_output_format(output_format)
	if normalized_format.is_empty():
		normalized_format = normalize_output_format(output_path.get_extension())
	if normalized_format.is_empty():
		normalized_format = DEFAULT_OUTPUT_FORMAT

	var base_path := normalize_output_path(output_path, normalized_format).get_basename()
	var extension := get_output_format_extension(normalized_format)
	var paths: PackedStringArray = []
	var digits := max(DEFAULT_FRAME_DIGITS, str(max(frame_count - 1, 0)).length())
	for index in range(frame_count):
		paths.append("%s_%s.%s" % [base_path, str(index).pad_zeros(digits), extension])
	return paths


static func get_metadata_path(output_path: String) -> String:
	return "%s.json" % output_path.strip_edges().get_basename()


static func get_sprite_frames_path(output_path: String) -> String:
	return "%s_sprite_frames.tres" % output_path.strip_edges().get_basename()


static func get_export_paths(output_path: String, frame_count: int, settings: Dictionary) -> PackedStringArray:
	var output_format := normalize_output_format(settings.get("output_format", output_path.get_extension()))
	if output_format.is_empty():
		output_format = DEFAULT_OUTPUT_FORMAT

	var normalized_output_path := normalize_output_path(output_path, output_format)
	var paths := PackedStringArray()
	paths.append(normalized_output_path)

	if bool(settings.get("export_individual_frames", false)):
		paths.append_array(get_individual_frame_paths(normalized_output_path, frame_count, output_format))

	if bool(settings.get("export_metadata", false)):
		paths.append(get_metadata_path(normalized_output_path))

	if bool(settings.get("export_sprite_frames", false)):
		paths.append(get_sprite_frames_path(normalized_output_path))

	return paths


static func format_export_file_count(count: int, output_format: Variant) -> String:
	return "%d %s %s" % [count, get_output_format_label(output_format), "file" if count == 1 else "files"]


static func _directory_exists(path: String) -> bool:
	if path.begins_with("res://") or path.begins_with("user://"):
		return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))

	return DirAccess.dir_exists_absolute(path)


static func _get_output_token_value(output_path: String) -> String:
	var clean_path := _strip_trailing_slashes(output_path.strip_edges())
	if clean_path.is_empty():
		return ""

	if _directory_exists(clean_path):
		return clean_path.get_file()

	if not clean_path.get_extension().is_empty():
		return clean_path.get_file().get_basename()

	return clean_path.get_file()


static func _strip_trailing_slashes(path: String) -> String:
	var clean_path := path
	while clean_path.ends_with("/") and not clean_path.ends_with("://"):
		clean_path = clean_path.trim_suffix("/")

	return clean_path


static func _delete_exported_paths(paths: PackedStringArray) -> void:
	for path in paths:
		if _file_exists(path):
			DirAccess.remove_absolute(_absolute_path(path))


static func _first_existing_path(paths: PackedStringArray) -> String:
	for path in paths:
		if _file_exists(path):
			return path

	return ""


static func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(_absolute_path(path))


static func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)

	return path


static func _is_supported_output_extension(extension: String) -> bool:
	return not normalize_output_format(extension).is_empty()


static func _format_exported_paths(paths: PackedStringArray, output_format: Variant) -> String:
	var image_extension := get_output_format_extension(output_format).to_lower()
	var image_only := true
	for path in paths:
		if path.get_extension().to_lower() != image_extension:
			image_only = false
			break

	if image_only:
		return format_export_file_count(paths.size(), output_format)

	return "%d %s" % [paths.size(), "file" if paths.size() == 1 else "files"]


static func _save_image(image: Image, output_path: String, output_format: String) -> Error:
	match output_format:
		"png":
			return image.save_png(output_path)
		"webp":
			return image.save_webp(output_path)
		"jpg":
			var opaque_image := image.duplicate()
			if opaque_image.get_format() != Image.FORMAT_RGB8:
				opaque_image.convert(Image.FORMAT_RGB8)
			return opaque_image.save_jpg(output_path)

	return ERR_INVALID_PARAMETER
