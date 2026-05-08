@tool
extends RefCounted

const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")

const DEFAULT_FRAME_DIGITS := 3
const DEFAULT_OUTPUT_NAME_PATTERN := "{model}.png"


static func validate_export_settings(settings: Dictionary, has_loaded_source: bool) -> Dictionary:
	if not has_loaded_source:
		return _failure("Load a source asset before exporting.")

	var frame_width := int(settings.get("frame_width", 0))
	var frame_height := int(settings.get("frame_height", 0))
	var frame_count := int(settings.get("frame_count", 0))
	var columns := int(settings.get("columns", 0))
	var frame_spacing := int(settings.get("frame_spacing", 0))
	var output_path := normalize_png_output_path(str(settings.get("output_path", "")))

	if frame_width <= 0 or frame_height <= 0:
		return _failure("Output frame width and height must be greater than zero.")

	if frame_count <= 0:
		return _failure("Frame count must be greater than zero.")

	if columns <= 0:
		return _failure("Columns per row must be greater than zero.")

	if frame_spacing < 0:
		return _failure("Frame spacing cannot be negative.")

	if output_path.is_empty():
		return _failure("Choose an output PNG path before exporting.")

	if output_path.get_extension().to_lower() != "png":
		return _failure("Output format must be PNG for static sprite export.")

	var base_dir := output_path.get_base_dir()
	if base_dir.is_empty() or not _directory_exists(base_dir):
		return _failure("Export directory does not exist: %s" % base_dir)

	var normalized_settings := settings.duplicate()
	normalized_settings["output_path"] = output_path
	normalized_settings["frame_width"] = frame_width
	normalized_settings["frame_height"] = frame_height
	normalized_settings["frame_count"] = frame_count
	normalized_settings["columns"] = columns
	normalized_settings["frame_spacing"] = frame_spacing
	normalized_settings = RenderOptions.normalize(normalized_settings)

	var capture_validation := RenderOptions.validate_capture_size(Vector2i(frame_width, frame_height), normalized_settings)
	if not capture_validation.ok:
		return capture_validation

	return {
		"ok": true,
		"settings": normalized_settings,
	}


static func normalize_png_output_path(path: String) -> String:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return ""

	if clean_path.get_extension().is_empty():
		return "%s.png" % clean_path

	return clean_path


static func format_output_name(pattern: String, source_path: String, index: int, count: int, output_path := "") -> String:
	var clean_pattern := pattern.strip_edges()
	if clean_pattern.is_empty():
		clean_pattern = DEFAULT_OUTPUT_NAME_PATTERN

	var source_name := source_path.get_file().get_basename()
	var base_output_name := normalize_png_output_path(output_path).get_file().get_basename()
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


static func get_source_output_path(output_path: String, source_path: String, pattern: String, index: int, count: int) -> String:
	var base_output_path := normalize_png_output_path(output_path)
	var base_dir := base_output_path.get_base_dir()
	var file_name := format_output_name(pattern, source_path, index, count, base_output_path).strip_edges()
	if file_name.get_extension().is_empty():
		file_name = "%s.png" % file_name

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


static func export_pngs(frames: Array[Image], settings: Dictionary) -> Dictionary:
	if frames.is_empty():
		return _failure("No rendered frames were available to export.")

	var frame_width := int(settings["frame_width"])
	var frame_height := int(settings["frame_height"])
	var columns := int(settings["columns"])
	var frame_spacing := int(settings["frame_spacing"])
	var resize_filter := RenderOptions.get_resize_filter(settings)
	var output_path := normalize_png_output_path(str(settings["output_path"]))
	var exported_paths: PackedStringArray = []
	var sheet := assemble_sprite_sheet(frames, frame_width, frame_height, columns, frame_spacing, resize_filter)
	var sheet_error := sheet.save_png(output_path)
	if sheet_error != OK:
		return _failure("Image encoding failed for sprite sheet: %s" % error_string(sheet_error))

	exported_paths.append(output_path)

	if bool(settings.get("export_individual_frames", false)):
		var frame_paths := get_individual_frame_paths(output_path, frames.size())
		for index in range(frames.size()):
			var frame := _copy_frame_at_size(frames[index], frame_width, frame_height, resize_filter)
			var frame_error := frame.save_png(frame_paths[index])
			if frame_error != OK:
				_delete_exported_paths(exported_paths)
				return _failure("Image encoding failed for frame %d: %s" % [index, error_string(frame_error)])
			exported_paths.append(frame_paths[index])

	var layout := calculate_layout(frames.size(), columns, frame_width, frame_height, frame_spacing)
	return {
		"ok": true,
		"message": "Exported %d PNG file(s)." % exported_paths.size(),
		"paths": exported_paths,
		"sheet_size": layout.sheet_size,
	}


static func get_individual_frame_paths(output_path: String, frame_count: int) -> PackedStringArray:
	var base_path := normalize_png_output_path(output_path).get_basename()
	var paths: PackedStringArray = []
	var digits := max(DEFAULT_FRAME_DIGITS, str(max(frame_count - 1, 0)).length())
	for index in range(frame_count):
		paths.append("%s_%s.png" % [base_path, str(index).pad_zeros(digits)])
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


static func _delete_exported_paths(paths: PackedStringArray) -> void:
	for path in paths:
		var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute_path)


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
