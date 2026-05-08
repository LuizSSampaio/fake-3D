@tool
extends RefCounted

const Paths := preload("res://addons/blender_sprite_sheet/sprite_sheet_export_paths.gd")
const Layout := preload("res://addons/blender_sprite_sheet/sprite_sheet_export_layout.gd")
const Output := preload("res://addons/blender_sprite_sheet/sprite_sheet_export_output.gd")

const DEFAULT_FRAME_DIGITS := Paths.DEFAULT_FRAME_DIGITS
const DEFAULT_OUTPUT_NAME_PATTERN := Paths.DEFAULT_OUTPUT_NAME_PATTERN
const DEFAULT_OUTPUT_FORMAT := Paths.DEFAULT_OUTPUT_FORMAT
const METADATA_FORMAT := Output.METADATA_FORMAT
const METADATA_VERSION := Output.METADATA_VERSION
const SPRITE_FRAMES_ANIMATION := Output.SPRITE_FRAMES_ANIMATION
const OUTPUT_FORMATS := Paths.OUTPUT_FORMATS


static func validate_export_settings(settings: Dictionary, has_loaded_source: bool) -> Dictionary:
	return Output.validate_export_settings(settings, has_loaded_source)


static func validate_export_directory_settings(settings: Dictionary, has_loaded_source: bool) -> Dictionary:
	return Output.validate_export_directory_settings(settings, has_loaded_source)


static func get_output_format_options() -> Array[Dictionary]:
	return Paths.get_output_format_options()


static func normalize_output_format(value: Variant) -> String:
	return Paths.normalize_output_format(value)


static func get_output_format_extension(output_format: Variant) -> String:
	return Paths.get_output_format_extension(output_format)


static func get_output_format_label(output_format: Variant) -> String:
	return Paths.get_output_format_label(output_format)


static func get_default_output_name_pattern(output_format: Variant = DEFAULT_OUTPUT_FORMAT) -> String:
	return Paths.get_default_output_name_pattern(output_format)


static func normalize_name_pattern_extension(pattern: String, output_format: Variant) -> String:
	return Paths.normalize_name_pattern_extension(pattern, output_format)


static func normalize_output_path(path: String, output_format: Variant = DEFAULT_OUTPUT_FORMAT) -> String:
	return Paths.normalize_output_path(path, output_format)


static func normalize_png_output_path(path: String) -> String:
	return Paths.normalize_png_output_path(path)


static func normalize_output_directory(path: String) -> String:
	return Paths.normalize_output_directory(path)


static func format_output_name(pattern: String, source_path: String, index: int, count: int, output_path := "") -> String:
	return Paths.format_output_name(pattern, source_path, index, count, output_path)


static func get_source_output_path(output_path: String, source_path: String, pattern: String, index: int, count: int, output_format := DEFAULT_OUTPUT_FORMAT) -> String:
	return Paths.get_source_output_path(output_path, source_path, pattern, index, count, output_format)


static func calculate_layout(frame_count: int, columns: int, frame_width: int, frame_height: int, frame_spacing: int) -> Dictionary:
	return Layout.calculate_layout(frame_count, columns, frame_width, frame_height, frame_spacing)


static func build_repeated_frames(frame: Image, frame_count: int, frame_width: int, frame_height: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Array[Image]:
	return Layout.build_repeated_frames(frame, frame_count, frame_width, frame_height, resize_filter)


static func assemble_sprite_sheet(frames: Array[Image], frame_width: int, frame_height: int, columns: int, frame_spacing: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Image:
	return Layout.assemble_sprite_sheet(frames, frame_width, frame_height, columns, frame_spacing, resize_filter)


static func export_images(frames: Array[Image], settings: Dictionary) -> Dictionary:
	return Output.export_images(frames, settings)


static func export_pngs(frames: Array[Image], settings: Dictionary) -> Dictionary:
	return Output.export_pngs(frames, settings)


static func get_individual_frame_paths(output_path: String, frame_count: int, output_format := "") -> PackedStringArray:
	return Paths.get_individual_frame_paths(output_path, frame_count, output_format)


static func get_metadata_path(output_path: String) -> String:
	return Paths.get_metadata_path(output_path)


static func get_sprite_frames_path(output_path: String) -> String:
	return Paths.get_sprite_frames_path(output_path)


static func get_export_paths(output_path: String, frame_count: int, settings: Dictionary) -> PackedStringArray:
	return Paths.get_export_paths(output_path, frame_count, settings)


static func build_metadata(frame_count: int, settings: Dictionary, layout := {}) -> Dictionary:
	return Output.build_metadata(frame_count, settings, layout)


static func write_metadata(metadata_path: String, metadata: Dictionary) -> Dictionary:
	return Output.write_metadata(metadata_path, metadata)


static func write_sprite_frames(sprite_frames_path: String, frames: Array[Image], settings: Dictionary) -> Dictionary:
	return Output.write_sprite_frames(sprite_frames_path, frames, settings)


static func format_export_file_count(count: int, output_format: Variant) -> String:
	return Paths.format_export_file_count(count, output_format)
