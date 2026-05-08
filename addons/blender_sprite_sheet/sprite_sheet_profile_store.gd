@tool
extends RefCounted

const FORMAT := "blender_sprite_sheet.config"
const VERSION := 1

const SourceLoader := preload("res://addons/blender_sprite_sheet/sprite_sheet_source_loader.gd")

const POSITION_KEYS := ["position", "Position", "pos", "Pos"]
const ROTATION_KEYS := ["rotation_degrees", "rotation", "Rotation", "rot", "Rot"]
const MODEL_PATH_KEYS := ["path", "source_path", "source"]
const MODEL_MATERIAL_KEYS := ["material_path", "material"]
const MODEL_TEXTURE_KEYS := ["texture_path", "texture"]


static func normalize_path(path: String) -> String:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return ""

	if clean_path.get_extension().is_empty():
		return "%s.json" % clean_path

	return clean_path


static func save_profile(path: String, profile: Dictionary) -> Dictionary:
	return save_config(path, profile)


static func load_profile(path: String) -> Dictionary:
	return load_config(path)


static func is_runnable_config_path(path: String) -> bool:
	var normalized_path := normalize_path(path)
	if normalized_path.is_empty() or normalized_path.get_extension().to_lower() != "json":
		return false

	var result := load_config(normalized_path)
	return result.ok and is_runnable_config(result.config)


static func is_runnable_config(config: Dictionary) -> bool:
	if str(config.get("format", "")).strip_edges() == FORMAT:
		return true

	for key in ["models", "object", "settings", "export", "source_path", "source_paths"]:
		if config.has(key):
			return true

	return false


static func save_config(path: String, config: Dictionary) -> Dictionary:
	var normalized_path := normalize_path(path)
	if normalized_path.is_empty():
		return _failure("Choose a config JSON path before saving.")

	if normalized_path.get_extension().to_lower() != "json":
		return _failure("Config path must use a .json extension.")

	var file := FileAccess.open(normalized_path, FileAccess.WRITE)
	if file == null:
		return _failure("Couldn't save config: %s." % error_string(FileAccess.get_open_error()))

	file.store_string(JSON.stringify(config, "\t"))
	file.flush()
	file.close()
	return {
		"ok": true,
		"message": "Saved config \"%s\"." % normalized_path.get_file(),
		"path": normalized_path,
		"config": config.duplicate(true),
		"profile": config.duplicate(true),
	}


static func load_config(path: String) -> Dictionary:
	var normalized_path := normalize_path(path)
	if normalized_path.is_empty():
		return _failure("Choose a config JSON path before loading.")

	if normalized_path.get_extension().to_lower() != "json":
		return _failure("Config path must use a .json extension.")

	var file := FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return _failure("Couldn't load config: %s." % error_string(FileAccess.get_open_error()))

	var config_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(config_text)
	if error != OK:
		return _failure("Config JSON is invalid at line %d: %s." % [json.get_error_line(), json.get_error_message()])

	if not (json.data is Dictionary):
		return _failure("Config JSON root must be an object.")

	var config: Dictionary = json.data
	return {
		"ok": true,
		"message": "Loaded config \"%s\"." % normalized_path.get_file(),
		"path": normalized_path,
		"config": config,
		"profile": config,
	}


static func dictionary_value(dictionary: Dictionary, key: String) -> Dictionary:
	var value: Variant = dictionary.get(key, {})
	if value is Dictionary:
		return value

	return {}


static func vector3_any(dictionary: Dictionary, keys: Array, fallback: Vector3) -> Vector3:
	for key in keys:
		if dictionary.has(key):
			return vector3_value(dictionary, key, fallback)

	return fallback


static func vector3_value(dictionary: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var value: Variant = dictionary.get(key, [])
	if not (value is Array):
		return fallback

	var values: Array = value
	if values.size() < 3:
		return fallback

	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func color_value(dictionary: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = dictionary.get(key, [])
	if not (value is Array):
		return fallback

	var values: Array = value
	if values.size() < 4:
		return fallback

	return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func has_any_key(dictionary: Dictionary, keys: Array) -> bool:
	for key in keys:
		if dictionary.has(key):
			return true

	return false


static func vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func color_to_array(value: Color) -> Array:
	return [value.r, value.g, value.b, value.a]


static func get_model_entries(config: Dictionary) -> Array[Dictionary]:
	var settings := dictionary_value(config, "settings")
	var defaults := dictionary_value(settings, "material")
	if defaults.is_empty():
		defaults = dictionary_value(config, "material")

	var default_material_path := _string_from_keys(defaults, MODEL_MATERIAL_KEYS, "")
	var default_texture_path := _string_from_keys(defaults, MODEL_TEXTURE_KEYS, "")
	var models := dictionary_value(config, "models")

	var entries: Array[Dictionary] = []
	var folder_path := str(models.get("folder", models.get("directory", models.get("source_folder", "")))).strip_edges()
	var recursive := bool(models.get("recursive", false))
	if not folder_path.is_empty():
		entries.append_array(_entries_from_folder(folder_path, recursive, default_material_path, default_texture_path))

	entries.append_array(_entries_from_any(models.get("items", []), default_material_path, default_texture_path))
	entries.append_array(_entries_from_any(models.get("paths", []), default_material_path, default_texture_path))
	entries.append_array(_entries_from_any(config.get("source_paths", []), default_material_path, default_texture_path))

	var source_path := str(config.get("source_path", "")).strip_edges()
	if not source_path.is_empty():
		entries.append(_model_entry_from_any({
			"path": source_path,
			"material_path": default_material_path,
			"texture_path": default_texture_path,
		}, default_material_path, default_texture_path))

	return _merge_model_entries(entries)


static func get_model_folder(config: Dictionary) -> String:
	var models := dictionary_value(config, "models")
	return str(models.get("folder", models.get("directory", models.get("source_folder", "")))).strip_edges()


static func get_model_recursive(config: Dictionary) -> bool:
	var models := dictionary_value(config, "models")
	return bool(models.get("recursive", false))


static func directory_exists(path: String) -> bool:
	return _directory_exists(path.strip_edges())


static func _entries_from_folder(folder_path: String, recursive: bool, default_material_path: String, default_texture_path: String) -> Array[Dictionary]:
	var paths := collect_source_paths_from_folder(folder_path, recursive)
	var entries: Array[Dictionary] = []
	for path in paths:
		entries.append({
			"path": path,
			"material_path": default_material_path,
			"texture_path": default_texture_path,
		})

	return entries


static func collect_source_paths_from_folder(folder_path: String, recursive: bool) -> PackedStringArray:
	var clean_folder_path := folder_path.strip_edges()
	if clean_folder_path.is_empty() or not _directory_exists(clean_folder_path):
		return PackedStringArray()

	var paths: Array[String] = []
	_collect_source_paths_from_folder(clean_folder_path, recursive, paths)
	paths.sort()

	var normalized := PackedStringArray()
	for path in paths:
		if ResourceLoader.exists(path):
			normalized.append(path)

	return normalized


static func _collect_source_paths_from_folder(folder_path: String, recursive: bool, paths: Array[String]) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null and (folder_path.begins_with("res://") or folder_path.begins_with("user://")):
		dir = DirAccess.open(ProjectSettings.globalize_path(folder_path))
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue

		var entry_path := folder_path.path_join(entry_name)
		if dir.current_is_dir():
			if recursive:
				_collect_source_paths_from_folder(entry_path, recursive, paths)
			continue

		if SourceLoader.is_supported_source_path(entry_path):
			paths.append(entry_path)
	dir.list_dir_end()


static func _entries_from_any(value: Variant, default_material_path: String, default_texture_path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if value is Array:
		for item in value:
			var entry := _model_entry_from_any(item, default_material_path, default_texture_path)
			if not entry.is_empty():
				entries.append(entry)
		return entries

	var single_entry := _model_entry_from_any(value, default_material_path, default_texture_path)
	if not single_entry.is_empty():
		entries.append(single_entry)

	return entries


static func _model_entry_from_any(value: Variant, default_material_path: String, default_texture_path: String) -> Dictionary:
	if value is String:
		return _normalize_model_entry({
			"path": str(value),
			"material_path": default_material_path,
			"texture_path": default_texture_path,
		}, default_material_path, default_texture_path)

	if value is Dictionary:
		return _normalize_model_entry(value, default_material_path, default_texture_path)

	return {}


static func _normalize_model_entry(entry: Dictionary, default_material_path: String, default_texture_path: String) -> Dictionary:
	var path := _string_from_keys(entry, MODEL_PATH_KEYS, "")
	if path.is_empty():
		return {}

	var material_path := _string_from_keys(entry, MODEL_MATERIAL_KEYS, default_material_path)
	var texture_path := _string_from_keys(entry, MODEL_TEXTURE_KEYS, default_texture_path)
	return {
		"path": path,
		"material_path": material_path,
		"texture_path": texture_path,
	}


static func _merge_model_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var ordered_paths: Array[String] = []
	var entries_by_path := {}

	for entry in entries:
		var path := str(entry.get("path", "")).strip_edges()
		if path.is_empty():
			continue

		if not entries_by_path.has(path):
			ordered_paths.append(path)
		entries_by_path[path] = entry

	var merged: Array[Dictionary] = []
	for path in ordered_paths:
		merged.append(entries_by_path[path])

	return merged


static func _string_from_keys(dictionary: Dictionary, keys: Array, fallback: String) -> String:
	for key in keys:
		if dictionary.has(key):
			return str(dictionary.get(key, fallback)).strip_edges()

	return fallback


static func _directory_exists(path: String) -> bool:
	if path.begins_with("res://") or path.begins_with("user://"):
		return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))

	return DirAccess.dir_exists_absolute(path)


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
