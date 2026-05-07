@tool
extends RefCounted


static func sync_from_controls(
	camera: Camera3D,
	position_controls: Array[SpinBox],
	rotation_controls: Array[SpinBox],
	projection_option: OptionButton,
	fov_spin: SpinBox,
	orthographic_size_spin: SpinBox
) -> void:
	if not camera:
		return

	camera.position = Vector3(
		position_controls[0].value,
		position_controls[1].value,
		position_controls[2].value
	)
	camera.rotation_degrees = Vector3(
		rotation_controls[0].value,
		rotation_controls[1].value,
		rotation_controls[2].value
	)
	camera.projection = projection_option.get_item_id(projection_option.selected)
	camera.fov = fov_spin.value
	camera.size = orthographic_size_spin.value
	orthographic_size_spin.editable = camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	fov_spin.editable = camera.projection == Camera3D.PROJECTION_PERSPECTIVE


static func frame_bounds(
	camera: Camera3D,
	position_controls: Array[SpinBox],
	rotation_controls: Array[SpinBox],
	fov_spin: SpinBox,
	orthographic_size_spin: SpinBox,
	projection_option: OptionButton,
	bounds: AABB,
	preview_margin: float
) -> void:
	var center := bounds.get_center()
	var radius := max(bounds.size.length() * 0.5, 0.01)
	var fov_radians := deg_to_rad(max(fov_spin.value, 1.0))
	var distance: float = radius / tan(fov_radians * 0.5)
	distance = max(max(distance * preview_margin, radius * 2.0), 1.0)

	var camera_position := center + Vector3(0.0, radius * 0.2, distance)
	set_vector3_controls(position_controls, camera_position)
	var largest_axis := max(bounds.size.x, max(bounds.size.y, bounds.size.z))
	orthographic_size_spin.set_value_no_signal(max(largest_axis * preview_margin, 0.01))
	sync_from_controls(camera, position_controls, rotation_controls, projection_option, fov_spin, orthographic_size_spin)
	camera.look_at(center, Vector3.UP)
	set_vector3_controls(rotation_controls, camera.rotation_degrees)


static func set_vector3_controls(controls: Array[SpinBox], value: Vector3) -> void:
	controls[0].set_value_no_signal(value.x)
	controls[1].set_value_no_signal(value.y)
	controls[2].set_value_no_signal(value.z)
