@tool
extends RefCounted

const Paths := preload("res://addons/blender_sprite_sheet/sprite_sheet_export_paths.gd")
const Layout := preload("res://addons/blender_sprite_sheet/sprite_sheet_export_layout.gd")
const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")

const METADATA_FORMAT := "blender_sprite_sheet.metadata"
const METADATA_VERSION := 1
const SPRITE_FRAMES_ANIMATION := "default"


static func validate_export_settings(settings: Dictionary, has_loaded_source: bool) -> Dictionary:
	var base_validation := _validate_common_settings(settings, has_loaded_source)
	if not base_validation.ok:
		return base_validation

	var normalized_settings: Dictionary = base_validation.settings
	var output_format := str(normalized_settings["output_format"])
	var output_path := Paths.normalize_output_path(str(settings.get("output_path", "")), output_format)

	if output_path.is_empty():
		return _failure("Choose an output path before exporting.")

	var base_dir := output_path.get_base_dir()
	if base_dir.is_empty() or not Paths._directory_exists(base_dir):
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
	var output_directory := Paths.normalize_output_directory(str(settings.get("output_directory", settings.get("output_path", ""))))

	if output_directory.is_empty():
		return _failure("Choose an output folder before exporting.")

	if not Paths._directory_exists(output_directory):
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
	var turntable_degrees := float(settings.get("turntable_degrees", 360.0))

	if frame_width <= 0 or frame_height <= 0:
		return _failure("Output frame width and height must be greater than zero.")

	if frame_count <= 0:
		return _failure("Frame count must be greater than zero.")

	if columns <= 0:
		return _failure("Columns per row must be greater than zero.")

	if frame_spacing < 0:
		return _failure("Frame spacing can't be negative.")

	if not is_finite(turntable_degrees):
		return _failure("Turntable degrees must be a finite number.")

	var output_format := Paths.normalize_output_format(settings.get("output_format", Paths.DEFAULT_OUTPUT_FORMAT))
	if output_format.is_empty():
		return _failure("Unsupported export format: \"%s\"." % str(settings.get("output_format", "")).strip_edges())

	var normalized_settings := settings.duplicate()
	normalized_settings["frame_width"] = frame_width
	normalized_settings["frame_height"] = frame_height
	normalized_settings["frame_count"] = frame_count
	normalized_settings["columns"] = columns
	normalized_settings["frame_spacing"] = frame_spacing
	normalized_settings["turntable_enabled"] = bool(settings.get("turntable_enabled", false))
	normalized_settings["turntable_degrees"] = turntable_degrees
	normalized_settings["output_format"] = output_format
	normalized_settings = RenderOptions.normalize(normalized_settings)

	var capture_validation := RenderOptions.validate_capture_size(Vector2i(frame_width, frame_height), normalized_settings)
	if not capture_validation.ok:
		return capture_validation

	return {
		"ok": true,
		"settings": normalized_settings,
	}


static func export_images(frames: Array[Image], settings: Dictionary) -> Dictionary:
	if frames.is_empty():
		return _failure("No rendered frames were available to export.")

	var frame_width := int(settings["frame_width"])
	var frame_height := int(settings["frame_height"])
	var columns := int(settings["columns"])
	var frame_spacing := int(settings["frame_spacing"])
	var resize_filter := RenderOptions.get_resize_filter(settings)
	var output_format := Paths.normalize_output_format(settings.get("output_format", Paths.DEFAULT_OUTPUT_FORMAT))
	if output_format.is_empty():
		return _failure("Unsupported export format: \"%s\"." % str(settings.get("output_format", "")).strip_edges())

	var output_path := Paths.normalize_output_path(str(settings["output_path"]), output_format)
	var planned_paths := Paths.get_export_paths(output_path, frames.size(), settings)
	if not bool(settings.get("overwrite_existing", true)):
		var conflict_path := Paths._first_existing_path(planned_paths)
		if not conflict_path.is_empty():
			return _failure("Export path already exists: \"%s\"." % conflict_path)

	var exported_paths: PackedStringArray = []
	var sheet := Layout.assemble_sprite_sheet(frames, frame_width, frame_height, columns, frame_spacing, resize_filter)
	var sheet_error := Paths._save_image(sheet, output_path, output_format)
	if sheet_error != OK:
		return _failure("Image encoding failed for sprite sheet: %s." % error_string(sheet_error))

	exported_paths.append(output_path)

	if bool(settings.get("export_individual_frames", false)):
		var frame_paths := Paths.get_individual_frame_paths(output_path, frames.size(), output_format)
		for index in range(frames.size()):
			var frame := Layout._copy_frame_at_size(frames[index], frame_width, frame_height, resize_filter)
			var frame_error := Paths._save_image(frame, frame_paths[index], output_format)
			if frame_error != OK:
				Paths._delete_exported_paths(exported_paths)
				return _failure("Image encoding failed for frame %d: %s." % [index, error_string(frame_error)])
			exported_paths.append(frame_paths[index])

	var layout := Layout.calculate_layout(frames.size(), columns, frame_width, frame_height, frame_spacing)
	if bool(settings.get("export_metadata", false)):
		var metadata_path := Paths.get_metadata_path(output_path)
		var metadata_result := write_metadata(metadata_path, build_metadata(frames.size(), settings, layout))
		if not metadata_result.ok:
			Paths._delete_exported_paths(exported_paths)
			return metadata_result
		exported_paths.append(metadata_path)

	if bool(settings.get("export_sprite_frames", false)):
		var sprite_frames_path := Paths.get_sprite_frames_path(output_path)
		var sprite_frames_result := write_sprite_frames(sprite_frames_path, frames, settings)
		if not sprite_frames_result.ok:
			Paths._delete_exported_paths(exported_paths)
			return sprite_frames_result
		exported_paths.append(sprite_frames_path)

	return {
		"ok": true,
		"message": "Exported %s." % Paths._format_exported_paths(exported_paths, output_format),
		"paths": exported_paths,
		"sheet_size": layout.sheet_size,
	}


static func export_pngs(frames: Array[Image], settings: Dictionary) -> Dictionary:
	var png_settings := settings.duplicate()
	png_settings["output_format"] = "png"
	return export_images(frames, png_settings)


static func build_metadata(frame_count: int, settings: Dictionary, layout := {}) -> Dictionary:
	var frame_width := int(settings.get("frame_width", 0))
	var frame_height := int(settings.get("frame_height", 0))
	var columns := int(settings.get("columns", 1))
	var frame_spacing := int(settings.get("frame_spacing", 0))
	var resolved_layout: Dictionary = layout if layout is Dictionary and not layout.is_empty() else Layout.calculate_layout(frame_count, columns, frame_width, frame_height, frame_spacing)

	var frames := []
	for index in range(frame_count):
		var column: int = index % int(resolved_layout["columns"])
		var row := int(index / int(resolved_layout["columns"]))
		frames.append({
			"index": index,
			"x": column * (frame_width + frame_spacing),
			"y": row * (frame_height + frame_spacing),
			"width": frame_width,
			"height": frame_height,
		})

	return {
		"format": METADATA_FORMAT,
		"version": METADATA_VERSION,
		"source_path": str(settings.get("source_path", "")),
		"animation_name": str(settings.get("animation_name", "")),
		"output_path": Paths.normalize_output_path(str(settings.get("output_path", "")), settings.get("output_format", Paths.DEFAULT_OUTPUT_FORMAT)),
		"output_format": Paths.normalize_output_format(settings.get("output_format", Paths.DEFAULT_OUTPUT_FORMAT)),
		"frame_count": frame_count,
		"frame_width": frame_width,
		"frame_height": frame_height,
		"columns": int(resolved_layout["columns"]),
		"rows": int(resolved_layout["rows"]),
		"frame_spacing": frame_spacing,
		"sheet_width": Vector2i(resolved_layout["sheet_size"]).x,
		"sheet_height": Vector2i(resolved_layout["sheet_size"]).y,
		"transparent_background": bool(settings.get("transparent_background", true)),
		"lighting_preset": str(settings.get("lighting_preset", "")),
		"turntable_enabled": bool(settings.get("turntable_enabled", false)),
		"turntable_degrees": float(settings.get("turntable_degrees", 360.0)),
		"frames": frames,
	}


static func write_metadata(metadata_path: String, metadata: Dictionary) -> Dictionary:
	var file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if file == null:
		return _failure("Metadata JSON write failed: %s." % error_string(FileAccess.get_open_error()))

	file.store_string(JSON.stringify(metadata, "\t"))
	file.flush()
	file.close()
	return {
		"ok": true,
		"path": metadata_path,
	}


static func write_sprite_frames(sprite_frames_path: String, frames: Array[Image], settings: Dictionary) -> Dictionary:
	if frames.is_empty():
		return _failure("No rendered frames were available for SpriteFrames export.")

	var sprite_frames := SpriteFrames.new()
	if not sprite_frames.has_animation(SPRITE_FRAMES_ANIMATION):
		sprite_frames.add_animation(SPRITE_FRAMES_ANIMATION)
	sprite_frames.clear(SPRITE_FRAMES_ANIMATION)
	sprite_frames.set_animation_loop(SPRITE_FRAMES_ANIMATION, true)
	sprite_frames.set_animation_speed(SPRITE_FRAMES_ANIMATION, max(1.0, float(settings.get("sprite_frames_fps", settings.get("frame_count", frames.size())))))

	var frame_width := int(settings.get("frame_width", frames[0].get_width()))
	var frame_height := int(settings.get("frame_height", frames[0].get_height()))
	var resize_filter := RenderOptions.get_resize_filter(settings)
	for frame in frames:
		var frame_image := Layout._copy_frame_at_size(frame, frame_width, frame_height, resize_filter)
		var texture := ImageTexture.create_from_image(frame_image)
		sprite_frames.add_frame(SPRITE_FRAMES_ANIMATION, texture)

	var save_error := ResourceSaver.save(sprite_frames, sprite_frames_path)
	if save_error != OK:
		return _failure("SpriteFrames resource write failed: %s." % error_string(save_error))

	return {
		"ok": true,
		"path": sprite_frames_path,
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
