@tool
extends RefCounted

const DEFAULT_MSAA_3D := Viewport.MSAA_4X
const DEFAULT_SCREEN_SPACE_AA := Viewport.SCREEN_SPACE_AA_SMAA
const DEFAULT_USE_TAA := false
const DEFAULT_SUPERSAMPLE_SCALE := 1
const DEFAULT_RESIZE_FILTER := Image.INTERPOLATE_LANCZOS
const DEFAULT_ANISOTROPIC_FILTERING := Viewport.ANISOTROPY_4X
const MAX_CAPTURE_DIMENSION := 16384


static func get_msaa_options() -> Array[Dictionary]:
	return [
		{"label": "Off", "key": "off", "value": Viewport.MSAA_DISABLED},
		{"label": "2x", "key": "2x", "value": Viewport.MSAA_2X},
		{"label": "4x", "key": "4x", "value": Viewport.MSAA_4X},
		{"label": "8x", "key": "8x", "value": Viewport.MSAA_8X},
	]


static func get_screen_space_aa_options() -> Array[Dictionary]:
	return [
		{"label": "Off", "key": "off", "value": Viewport.SCREEN_SPACE_AA_DISABLED},
		{"label": "FXAA", "key": "fxaa", "value": Viewport.SCREEN_SPACE_AA_FXAA},
		{"label": "SMAA", "key": "smaa", "value": Viewport.SCREEN_SPACE_AA_SMAA},
	]


static func get_supersample_options() -> Array[Dictionary]:
	return [
		{"label": "1x", "key": "1x", "value": 1},
		{"label": "2x", "key": "2x", "value": 2},
		{"label": "4x", "key": "4x", "value": 4},
	]


static func get_resize_filter_options() -> Array[Dictionary]:
	return [
		{"label": "Nearest", "key": "nearest", "value": Image.INTERPOLATE_NEAREST},
		{"label": "Bilinear", "key": "bilinear", "value": Image.INTERPOLATE_BILINEAR},
		{"label": "Cubic", "key": "cubic", "value": Image.INTERPOLATE_CUBIC},
		{"label": "Trilinear", "key": "trilinear", "value": Image.INTERPOLATE_TRILINEAR},
		{"label": "Lanczos", "key": "lanczos", "value": Image.INTERPOLATE_LANCZOS},
	]


static func get_anisotropic_filtering_options() -> Array[Dictionary]:
	return [
		{"label": "Off", "key": "off", "value": Viewport.ANISOTROPY_DISABLED},
		{"label": "2x", "key": "2x", "value": Viewport.ANISOTROPY_2X},
		{"label": "4x", "key": "4x", "value": Viewport.ANISOTROPY_4X},
		{"label": "8x", "key": "8x", "value": Viewport.ANISOTROPY_8X},
		{"label": "16x", "key": "16x", "value": Viewport.ANISOTROPY_16X},
	]


static func normalize(settings: Dictionary) -> Dictionary:
	var normalized := settings.duplicate()
	normalized["msaa_3d"] = _option_value(settings.get("msaa_3d", DEFAULT_MSAA_3D), get_msaa_options(), DEFAULT_MSAA_3D)
	normalized["screen_space_aa"] = _option_value(settings.get("screen_space_aa", DEFAULT_SCREEN_SPACE_AA), get_screen_space_aa_options(), DEFAULT_SCREEN_SPACE_AA)
	normalized["use_taa"] = bool(settings.get("use_taa", DEFAULT_USE_TAA))
	normalized["supersample_scale"] = _option_value(settings.get("supersample_scale", DEFAULT_SUPERSAMPLE_SCALE), get_supersample_options(), DEFAULT_SUPERSAMPLE_SCALE)
	normalized["resize_filter"] = _option_value(settings.get("resize_filter", DEFAULT_RESIZE_FILTER), get_resize_filter_options(), DEFAULT_RESIZE_FILTER)
	normalized["anisotropic_filtering"] = _option_value(settings.get("anisotropic_filtering", DEFAULT_ANISOTROPIC_FILTERING), get_anisotropic_filtering_options(), DEFAULT_ANISOTROPIC_FILTERING)
	return normalized


static func apply_to_viewport(viewport: Viewport, settings: Dictionary) -> void:
	if viewport == null:
		return

	var normalized := normalize(settings)
	viewport.msaa_3d = int(normalized["msaa_3d"])
	viewport.screen_space_aa = int(normalized["screen_space_aa"])
	viewport.use_taa = bool(normalized["use_taa"])
	viewport.anisotropic_filtering_level = int(normalized["anisotropic_filtering"])


static func get_capture_size(frame_size: Vector2i, settings: Dictionary) -> Vector2i:
	var scale := int(normalize(settings)["supersample_scale"])
	return Vector2i(frame_size.x * scale, frame_size.y * scale)


static func get_resize_filter(settings: Dictionary) -> int:
	return int(normalize(settings)["resize_filter"])


static func get_capture_frame_count(settings: Dictionary) -> int:
	return 8 if bool(normalize(settings)["use_taa"]) else 2


static func validate_capture_size(frame_size: Vector2i, settings: Dictionary) -> Dictionary:
	var capture_size := get_capture_size(frame_size, settings)
	if capture_size.x > MAX_CAPTURE_DIMENSION or capture_size.y > MAX_CAPTURE_DIMENSION:
		return _failure("Supersampling would render at %dx%d, above the %d pixel limit." % [
			capture_size.x,
			capture_size.y,
			MAX_CAPTURE_DIMENSION,
		])

	return {
		"ok": true,
		"capture_size": capture_size,
	}


static func _option_value(value: Variant, options: Array[Dictionary], fallback: int) -> int:
	if value is int or value is float:
		var numeric_value := int(value)
		if _has_option_value(options, numeric_value):
			return numeric_value

	var text_value := str(value).strip_edges().to_lower()
	for option in options:
		if text_value == str(option["value"]) or text_value == str(option["key"]).to_lower() or text_value == str(option["label"]).to_lower():
			return int(option["value"])

	return fallback


static func _has_option_value(options: Array[Dictionary], value: int) -> bool:
	for option in options:
		if int(option["value"]) == value:
			return true

	return false


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
