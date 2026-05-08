@tool
extends RefCounted

const FORMAT := "blender_sprite_sheet.profile"
const VERSION := 1

const POSITION_KEYS := ["position", "Position", "pos", "Pos"]
const ROTATION_KEYS := ["rotation_degrees", "rotation", "Rotation", "rot", "Rot"]


static func normalize_path(path: String) -> String:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return ""

	if clean_path.get_extension().is_empty():
		return "%s.json" % clean_path

	return clean_path


static func save_profile(path: String, profile: Dictionary) -> Dictionary:
	var normalized_path := normalize_path(path)
	if normalized_path.is_empty():
		return _failure("Choose a profile JSON path before saving.")

	if normalized_path.get_extension().to_lower() != "json":
		return _failure("Profile path must use a .json extension.")

	var file := FileAccess.open(normalized_path, FileAccess.WRITE)
	if file == null:
		return _failure("Couldn't save profile: %s." % error_string(FileAccess.get_open_error()))

	file.store_string(JSON.stringify(profile, "\t"))
	file.flush()
	file.close()
	return {
		"ok": true,
		"message": "Saved profile \"%s\"." % normalized_path.get_file(),
		"path": normalized_path,
		"profile": profile.duplicate(true),
	}


static func load_profile(path: String) -> Dictionary:
	var normalized_path := normalize_path(path)
	if normalized_path.is_empty():
		return _failure("Choose a profile JSON path before loading.")

	if normalized_path.get_extension().to_lower() != "json":
		return _failure("Profile path must use a .json extension.")

	var file := FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return _failure("Couldn't load profile: %s." % error_string(FileAccess.get_open_error()))

	var profile_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(profile_text)
	if error != OK:
		return _failure("Profile JSON is invalid at line %d: %s." % [json.get_error_line(), json.get_error_message()])

	if not (json.data is Dictionary):
		return _failure("Profile JSON root must be an object.")

	var profile: Dictionary = json.data
	return {
		"ok": true,
		"message": "Loaded profile \"%s\"." % normalized_path.get_file(),
		"path": normalized_path,
		"profile": profile,
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


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
