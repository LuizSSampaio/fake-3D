@tool
extends RefCounted

const SourceLoader := preload("res://addons/blender_sprite_sheet/sprite_sheet_source_loader.gd")
const Exporter := preload("res://addons/blender_sprite_sheet/sprite_sheet_exporter.gd")


static func build(base_settings: Dictionary, source_paths: PackedStringArray, name_pattern: String) -> Dictionary:
	if source_paths.is_empty():
		return _failure("Select at least one source model before exporting.")

	var clean_pattern := name_pattern.strip_edges()
	if clean_pattern.is_empty():
		return _failure("Choose a file naming pattern before exporting.")

	var base_validation := Exporter.validate_export_directory_settings(base_settings, true)
	if not base_validation.ok:
		return base_validation

	var normalized_settings: Dictionary = base_validation.settings
	var items := []
	var output_paths := {}
	for index in range(source_paths.size()):
		var source_path := source_paths[index]
		if not SourceLoader.is_supported_source_path(source_path):
			return _failure("Unsupported source path \"%s\". Choose .tscn, .scn, .glb, .gltf, .obj, .fbx, or .blend." % source_path)

		if not ResourceLoader.exists(source_path):
			return _failure("Source asset doesn't exist: \"%s\"." % source_path)

		var item_settings := _settings_for_source(
			normalized_settings,
			source_path,
			clean_pattern,
			index,
			source_paths.size()
		)
		var item_validation := Exporter.validate_export_settings(item_settings, true)
		if not item_validation.ok:
			return item_validation

		var output_path: String = item_validation.settings.output_path
		if output_paths.has(output_path):
			return _failure("File naming pattern creates a duplicate output path: \"%s\"." % output_path)

		output_paths[output_path] = true
		items.append(item_validation.settings)

	return {
		"ok": true,
		"items": items,
		"settings": items[0],
	}


static func _settings_for_source(base_settings: Dictionary, source_path: String, name_pattern: String, index: int, count: int) -> Dictionary:
	var item_settings := base_settings.duplicate()
	item_settings["source_path"] = source_path
	item_settings["output_path"] = Exporter.get_source_output_path(
		str(base_settings["output_directory"]),
		source_path,
		name_pattern,
		index,
		count
	)
	return item_settings


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
