@tool
extends RefCounted

const ControlFactory := preload("res://addons/blender_sprite_sheet/sprite_sheet_control_factory.gd")


static func sync_from_controls(
	camera: Camera3D,
	projection_option: OptionButton,
	fov_spin: Range,
	orthographic_size_spin: Range,
	fixed_position: Vector3,
	fixed_rotation: Vector3
) -> void:
	if not camera:
		return

	camera.position = fixed_position
	camera.rotation_degrees = fixed_rotation
	camera.projection = projection_option.get_item_id(projection_option.selected)
	camera.fov = fov_spin.value
	camera.size = orthographic_size_spin.value
	ControlFactory.set_numeric_read_only(orthographic_size_spin, camera.projection != Camera3D.PROJECTION_ORTHOGONAL)
	ControlFactory.set_numeric_read_only(fov_spin, camera.projection != Camera3D.PROJECTION_PERSPECTIVE)


static func sync_object_from_controls(
	object_root: Node3D,
	position_controls: Array[Range],
	rotation_controls: Array[Range]
) -> void:
	if not object_root:
		return

	object_root.position = Vector3(
		position_controls[0].value,
		position_controls[1].value,
		position_controls[2].value
	)
	object_root.rotation_degrees = Vector3(
		rotation_controls[0].value,
		rotation_controls[1].value,
		rotation_controls[2].value
	)


static func frame_bounds(
	camera: Camera3D,
	fov_spin: Range,
	orthographic_size_spin: Range,
	projection_option: OptionButton,
	bounds: AABB,
	preview_margin: float,
	fixed_position: Vector3,
	fixed_rotation: Vector3,
	frame_size := Vector2i.ZERO
) -> void:
	orthographic_size_spin.set_value_no_signal(calculate_orthographic_size(bounds, frame_size, preview_margin))
	sync_from_controls(camera, projection_option, fov_spin, orthographic_size_spin, fixed_position, fixed_rotation)


static func calculate_orthographic_size(bounds: AABB, frame_size: Vector2i, preview_margin: float) -> float:
	var aspect_ratio := 1.0
	if frame_size.x > 0 and frame_size.y > 0:
		aspect_ratio = float(frame_size.x) / float(frame_size.y)

	var height_requirement: float = bounds.size.y
	var width_requirement: float = bounds.size.x / max(aspect_ratio, 0.001)
	var depth_requirement: float = bounds.size.z * 0.5
	var required_size: float = max(height_requirement, max(width_requirement, depth_requirement))
	return max(required_size * preview_margin, 0.01)


static func set_vector3_controls(controls: Array[Range], value: Vector3) -> void:
	controls[0].set_value_no_signal(value.x)
	controls[1].set_value_no_signal(value.y)
	controls[2].set_value_no_signal(value.z)


static func get_vector3_from_controls(controls: Array[Range], fallback := Vector3.ZERO) -> Vector3:
	if controls.size() < 3:
		return fallback

	return Vector3(controls[0].value, controls[1].value, controls[2].value)
