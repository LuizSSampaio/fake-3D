@tool
extends RefCounted


static func sync_from_controls(
	camera: Camera3D,
	projection_option: OptionButton,
	fov_spin: SpinBox,
	orthographic_size_spin: SpinBox,
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
	orthographic_size_spin.editable = camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	fov_spin.editable = camera.projection == Camera3D.PROJECTION_PERSPECTIVE


static func sync_object_from_controls(
	object_root: Node3D,
	position_controls: Array[SpinBox],
	rotation_controls: Array[SpinBox]
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
	fov_spin: SpinBox,
	orthographic_size_spin: SpinBox,
	projection_option: OptionButton,
	bounds: AABB,
	preview_margin: float,
	fixed_position: Vector3,
	fixed_rotation: Vector3
) -> void:
	var largest_axis := max(bounds.size.x, max(bounds.size.y, bounds.size.z))
	orthographic_size_spin.set_value_no_signal(max(largest_axis * preview_margin, 0.01))
	sync_from_controls(camera, projection_option, fov_spin, orthographic_size_spin, fixed_position, fixed_rotation)


static func set_vector3_controls(controls: Array[SpinBox], value: Vector3) -> void:
	controls[0].set_value_no_signal(value.x)
	controls[1].set_value_no_signal(value.y)
	controls[2].set_value_no_signal(value.z)


static func get_vector3_from_controls(controls: Array[SpinBox], fallback := Vector3.ZERO) -> Vector3:
	if controls.size() < 3:
		return fallback

	return Vector3(controls[0].value, controls[1].value, controls[2].value)
