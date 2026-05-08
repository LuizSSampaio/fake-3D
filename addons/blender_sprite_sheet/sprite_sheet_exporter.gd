@tool
extends RefCounted

const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")

const DEFAULT_FRAME_DIGITS := 3
const DEFAULT_OUTPUT_NAME_PATTERN := "{model}.png"
const DEFAULT_OUTPUT_FORMAT := "png"
const OUTPUT_FORMATS := [
	{"label": "PNG", "key": "png", "extension": "png"},
	{"label": "WebP", "key": "webp", "extension": "webp"},
	{"label": "JPEG", "key": "jpg", "extension": "jpg", "aliases": ["jpeg"]},
]


static func validate_export_settings(settings: Dictionary, has_loaded_source: bool) -> Dictionary:
	var base_validation := _validate_common_settings(settings, has_loaded_source)
	if not base_validation.ok:
		return base_validation

	var normalized_settings: Dictionary = base_validation.settings
	var output_format := str(normalized_settings["output_format"])
	var output_path := normalize_output_path(str(settings.get("output_path", "")), output_format)

	if output_path.is_empty():
		return _failure("Choose an output path before exporting.")

	var base_dir := output_path.get_base_dir()
	if base_dir.is_empty() or not _directory_exists(base_dir):
		return _failure("Export directory doesn't exist: \"%s\"." % base_dir)

	normalized_settings["output_path"] = output_path
	return {
		"ok": true,
		"settings": normalized_settings,
	}


static func validate_export_directory_settings(settings: Dictionary, has_loaded_source: bool) -> Dictionary:
	var base_validation := _validate_common_settings(settings, has_loaded_source)
	if not base_validation.ok:
		return base_validation

	var normalized_settings: Dictionary = base_validation.settings
	var output_directory := normalize_output_directory(str(settings.get("output_directory", settings.get("output_path", ""))))

	if output_directory.is_empty():
		return _failure("Choose an output folder before exporting.")

	if not _directory_exists(output_directory):
		return _failure("Export folder doesn't exist: \"%s\"." % output_directory)

	normalized_settings["output_directory"] = output_directory
	normalized_settings.erase("output_path")
	return {
		"ok": true,
		"settings": normalized_settings,
	}


static func _validate_common_settings(settings: Dictionary, has_loaded_source: bool) -> Dictionary:
	if not has_loaded_source:
		return _failure("Load a source asset before exporting.")

	var frame_width := int(settings.get("frame_width", 0))
	var frame_height := int(settings.get("frame_height", 0))
	var frame_count := int(settings.get("frame_count", 0))
	var columns := int(settings.get("columns", 0))
	var frame_spacing := int(settings.get("frame_spacing", 0))

	if frame_width <= 0 or frame_height <= 0:
		return _failure("Output frame width and height must be greater than zero.")

	if frame_count <= 0:
		return _failure("Frame count must be greater than zero.")

	if columns <= 0:
		return _failure("Columns per row must be greater than zero.")

	if frame_spacing < 0:
		return _failure("Frame spacing can't be negative.")

	var output_format := normalize_output_format(settings.get("output_format", DEFAULT_OUTPUT_FORMAT))
	if output_format.is_empty():
		return _failure("Unsupported export format: \"%s\"." % str(settings.get("output_format", "")).strip_edges())

	var normalized_settings := settings.duplicate()
	normalized_settings["frame_width"] = frame_width
	normalized_settings["frame_height"] = frame_height
	normalized_settings["frame_count"] = frame_count
	normalized_settings["columns"] = columns
	normalized_settings["frame_spacing"] = frame_spacing
	normalized_settings["output_format"] = output_format
	normalized_settings = RenderOptions.normalize(normalized_settings)

	var capture_validation := RenderOptions.validate_capture_size(Vector2i(frame_width, frame_height), normalized_settings)
	if not capture_validation.ok:
		return capture_validation

	return {
		"ok": true,
		"settings": normalized_settings,
	}


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
	var base_output_name := _get_output_token_value(output_path)
	if base_output_name.is_empty():
		base_output_name = "sprite_sheet"

	var digits := max(DEFAULT_FRAME_DIGITS, str(max(count, 1)).length())
	var output_name := clean_pattern
	output_name = output_name.replace("{model}", source_name)
	output_name = output_name.replace("{source}", source_name)
	output_name = output_name.replace("{index}", str(index + 1).pad_zeros(digits))
	output_name = output_name.replace("{index0}", str(index).pad_zeros(digits))
	output_name = output_name.replace("{count}", str(count))
	output_name = output_name.replace("{output}", base_output_name)
	return output_name


static func get_source_output_path(output_path: String, source_path: String, pattern: String, index: int, count: int, output_format := DEFAULT_OUTPUT_FORMAT) -> String:
	var base_output_path := output_path.strip_edges()
	var base_dir := normalize_output_directory(base_output_path)
	var file_name := format_output_name(pattern, source_path, index, count, base_output_path).strip_edges()
	file_name = normalize_output_path(file_name, output_format)

	if base_dir.is_empty():
		return file_name

	return base_dir.path_join(file_name)


static func calculate_layout(frame_count: int, columns: int, frame_width: int, frame_height: int, frame_spacing: int) -> Dictionary:
	var safe_frame_count := int(max(frame_count, 0))
	var safe_columns := int(max(columns, 1))
	var safe_spacing := int(max(frame_spacing, 0))
	var rows := int(ceil(float(safe_frame_count) / float(safe_columns))) if safe_frame_count > 0 else 0
	var sheet_width: int = safe_columns * int(max(frame_width, 0)) + int(max(safe_columns - 1, 0)) * safe_spacing
	var sheet_height: int = rows * int(max(frame_height, 0)) + int(max(rows - 1, 0)) * safe_spacing

	return {
		"columns": safe_columns,
		"rows": rows,
		"sheet_size": Vector2i(sheet_width, sheet_height),
	}


static func build_repeated_frames(frame: Image, frame_count: int, frame_width: int, frame_height: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Array[Image]:
	var frames: Array[Image] = []
	for _index in range(frame_count):
		frames.append(_copy_frame_at_size(frame, frame_width, frame_height, resize_filter))
	return frames


static func assemble_sprite_sheet(frames: Array[Image], frame_width: int, frame_height: int, columns: int, frame_spacing: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Image:
	var layout := calculate_layout(frames.size(), columns, frame_width, frame_height, frame_spacing)
	var sheet_size: Vector2i = layout["sheet_size"]
	var sheet := Image.create(sheet_size.x, sheet_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))

	for frame_index in range(frames.size()):
		var column: int = frame_index % int(layout["columns"])
		var row := int(frame_index / int(layout["columns"]))
		var destination := Vector2i(
			column * (frame_width + max(frame_spacing, 0)),
			row * (frame_height + max(frame_spacing, 0))
		)
		var frame := _copy_frame_at_size(frames[frame_index], frame_width, frame_height, resize_filter)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, Vector2i(frame_width, frame_height)), destination)

	return sheet


static func export_images(frames: Array[Image], settings: Dictionary) -> Dictionary:
	if frames.is_empty():
		return _failure("No rendered frames were available to export.")

	var frame_width := int(settings["frame_width"])
	var frame_height := int(settings["frame_height"])
	var columns := int(settings["columns"])
	var frame_spacing := int(settings["frame_spacing"])
	var resize_filter := RenderOptions.get_resize_filter(settings)
	var output_format := normalize_output_format(settings.get("output_format", DEFAULT_OUTPUT_FORMAT))
	if output_format.is_empty():
		return _failure("Unsupported export format: \"%s\"." % str(settings.get("output_format", "")).strip_edges())

	var output_path := normalize_output_path(str(settings["output_path"]), output_format)
	var exported_paths: PackedStringArray = []
	var sheet := assemble_sprite_sheet(frames, frame_width, frame_height, columns, frame_spacing, resize_filter)
	var sheet_error := _save_image(sheet, output_path, output_format)
	if sheet_error != OK:
		return _failure("Image encoding failed for sprite sheet: %s." % error_string(sheet_error))

	exported_paths.append(output_path)

	if bool(settings.get("export_individual_frames", false)):
		var frame_paths := get_individual_frame_paths(output_path, frames.size(), output_format)
		for index in range(frames.size()):
			var frame := _copy_frame_at_size(frames[index], frame_width, frame_height, resize_filter)
			var frame_error := _save_image(frame, frame_paths[index], output_format)
			if frame_error != OK:
				_delete_exported_paths(exported_paths)
				return _failure("Image encoding failed for frame %d: %s." % [index, error_string(frame_error)])
			exported_paths.append(frame_paths[index])

	var layout := calculate_layout(frames.size(), columns, frame_width, frame_height, frame_spacing)
	return {
		"ok": true,
		"message": "Exported %s." % format_export_file_count(exported_paths.size(), output_format),
		"paths": exported_paths,
		"sheet_size": layout.sheet_size,
	}


static func export_pngs(frames: Array[Image], settings: Dictionary) -> Dictionary:
	var png_settings := settings.duplicate()
	png_settings["output_format"] = "png"
	return export_images(frames, png_settings)


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


static func _copy_frame_at_size(frame: Image, frame_width: int, frame_height: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Image:
	var copy := frame.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)

	if copy.get_width() != frame_width or copy.get_height() != frame_height:
		copy.resize(frame_width, frame_height, resize_filter)

	return copy


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
		var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


static func _is_supported_output_extension(extension: String) -> bool:
	return not normalize_output_format(extension).is_empty()


static func format_export_file_count(count: int, output_format: Variant) -> String:
	return "%d %s %s" % [count, get_output_format_label(output_format), "file" if count == 1 else "files"]


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


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
