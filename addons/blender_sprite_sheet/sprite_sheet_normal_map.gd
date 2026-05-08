@tool
extends RefCounted

const Layout := preload("res://addons/blender_sprite_sheet/sprite_sheet_export_layout.gd")
const ModelUtils := preload("res://addons/blender_sprite_sheet/sprite_sheet_model_utils.gd")

const NORMAL_MAP_SUFFIX := "_normal"
const NORMAL_MAP_EXTENSION := "png"
const NEUTRAL_NORMAL := Color(0.5, 0.5, 1.0, 0.0)
const OPAQUE_NEUTRAL_NORMAL := Color(0.5, 0.5, 1.0, 1.0)
const NORMAL_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

void fragment() {
	vec3 normal = normalize(NORMAL);
	ALBEDO = normal * 0.5 + 0.5;
}
"""


static func create_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = NORMAL_SHADER_CODE

	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func apply_to_model(root: Node) -> void:
	var material := create_material()
	for mesh_instance in ModelUtils.find_mesh_instances(root):
		if mesh_instance.mesh == null:
			continue

		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface_index, material)


static func finalize_capture(image: Image, transparent_background: bool) -> Image:
	var result := image.duplicate()
	if result.get_format() != Image.FORMAT_RGBA8:
		result.convert(Image.FORMAT_RGBA8)

	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var pixel: Color = result.get_pixel(x, y)
			result.set_pixel(x, y, _finalize_pixel(pixel, transparent_background))

	return result


static func get_output_path(output_path: String) -> String:
	return "%s%s.%s" % [output_path.strip_edges().get_basename(), NORMAL_MAP_SUFFIX, NORMAL_MAP_EXTENSION]


static func get_individual_frame_paths(output_path: String, frame_count: int) -> PackedStringArray:
	var base_path := get_output_path(output_path).get_basename()
	var paths := PackedStringArray()
	var digits := max(3, str(max(frame_count - 1, 0)).length())
	for index in range(frame_count):
		paths.append("%s_%s.%s" % [base_path, str(index).pad_zeros(digits), NORMAL_MAP_EXTENSION])
	return paths


static func get_export_paths(output_path: String, frame_count: int, settings: Dictionary) -> PackedStringArray:
	var paths := PackedStringArray()
	if not bool(settings.get("export_normal_map", false)):
		return paths

	paths.append(get_output_path(output_path))
	if bool(settings.get("export_individual_frames", false)):
		paths.append_array(get_individual_frame_paths(output_path, frame_count))

	return paths


static func export_maps(normal_frames: Array[Image], settings: Dictionary) -> Dictionary:
	var validation := validate_frames(normal_frames, int(settings.get("frame_count", normal_frames.size())))
	if not validation.ok:
		return validation

	var frame_width := int(settings["frame_width"])
	var frame_height := int(settings["frame_height"])
	var columns := int(settings["columns"])
	var frame_spacing := int(settings["frame_spacing"])
	var resize_filter := int(settings.get("resize_filter", Image.INTERPOLATE_LANCZOS))
	var output_path := get_output_path(str(settings["output_path"]))
	var exported_paths := PackedStringArray()

	var sheet := Layout.assemble_sprite_sheet(normal_frames, frame_width, frame_height, columns, frame_spacing, resize_filter)
	var sheet_error := sheet.save_png(output_path)
	if sheet_error != OK:
		return _failure("Image encoding failed for normal map sprite sheet: %s." % error_string(sheet_error))

	exported_paths.append(output_path)

	if bool(settings.get("export_individual_frames", false)):
		var frame_paths := get_individual_frame_paths(str(settings["output_path"]), normal_frames.size())
		for index in range(normal_frames.size()):
			var frame := Layout._copy_frame_at_size(normal_frames[index], frame_width, frame_height, resize_filter)
			var frame_error := frame.save_png(frame_paths[index])
			if frame_error != OK:
				_delete_exported_paths(exported_paths)
				return _failure("Image encoding failed for normal map frame %d: %s." % [index, error_string(frame_error)])
			exported_paths.append(frame_paths[index])

	return {
		"ok": true,
		"paths": exported_paths,
	}


static func validate_frames(normal_frames: Array[Image], expected_count: int) -> Dictionary:
	if normal_frames.is_empty():
		return _failure("Normal map export was enabled but no normal frames were captured.")

	if expected_count > 0 and normal_frames.size() != expected_count:
		return _failure("Normal map frame count doesn't match the color export frame count.")

	for frame in normal_frames:
		if frame == null or frame.is_empty():
			return _failure("Normal map capture produced an empty image.")

	return {"ok": true}


static func _finalize_pixel(pixel: Color, transparent_background: bool) -> Color:
	var alpha := clampf(pixel.a, 0.0, 1.0)
	if transparent_background:
		if alpha <= 0.0:
			return NEUTRAL_NORMAL
		return Color(pixel.r, pixel.g, pixel.b, alpha)

	return Color(
		lerpf(OPAQUE_NEUTRAL_NORMAL.r, pixel.r, alpha),
		lerpf(OPAQUE_NEUTRAL_NORMAL.g, pixel.g, alpha),
		lerpf(OPAQUE_NEUTRAL_NORMAL.b, pixel.b, alpha),
		1.0
	)


static func _delete_exported_paths(paths: PackedStringArray) -> void:
	for path in paths:
		if FileAccess.file_exists(_absolute_path(path)):
			DirAccess.remove_absolute(_absolute_path(path))


static func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)

	return path


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
