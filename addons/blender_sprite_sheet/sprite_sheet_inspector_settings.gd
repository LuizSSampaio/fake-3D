@tool
extends Resource

const DEFAULT_OBJECT_POSITION := Vector3.ZERO
const DEFAULT_OBJECT_ROTATION := Vector3.ZERO
const DEFAULT_BACKGROUND_COLOR := Color(0.12, 0.12, 0.12, 1.0)
const PROJECTION_PERSPECTIVE := 0
const PROJECTION_ORTHOGRAPHIC := 1

@export_group("Object")
@export var object_position := DEFAULT_OBJECT_POSITION
@export var object_rotation := DEFAULT_OBJECT_ROTATION

@export_group("Camera")
@export_enum("Perspective", "Orthographic")
var camera_projection: int = PROJECTION_PERSPECTIVE
@export_range(1.0, 179.0, 0.1, "or_less,or_greater")
var camera_fov: float = 70.0
@export_range(0.001, 1000.0, 0.01, "or_less,or_greater")
var camera_orthographic_size: float = 4.0

@export_group("Background")
@export var transparent_background := true
@export var background_color := DEFAULT_BACKGROUND_COLOR


func apply_to_controls(
	object_position_controls: Array[SpinBox],
	object_rotation_controls: Array[SpinBox],
	camera_projection_option: OptionButton,
	camera_fov_spin: SpinBox,
	camera_orthographic_size_spin: SpinBox,
	transparent_background_check: CheckBox,
	background_color_picker: ColorPickerButton
) -> void:
	if object_position_controls.size() == 3:
		object_position_controls[0].set_value_no_signal(object_position.x)
		object_position_controls[1].set_value_no_signal(object_position.y)
		object_position_controls[2].set_value_no_signal(object_position.z)

	if object_rotation_controls.size() == 3:
		object_rotation_controls[0].set_value_no_signal(object_rotation.x)
		object_rotation_controls[1].set_value_no_signal(object_rotation.y)
		object_rotation_controls[2].set_value_no_signal(object_rotation.z)

	if camera_projection_option != null:
		var projection_id := Camera3D.PROJECTION_ORTHOGONAL if camera_projection == PROJECTION_ORTHOGRAPHIC else Camera3D.PROJECTION_PERSPECTIVE
		for index in range(camera_projection_option.item_count):
			if camera_projection_option.get_item_id(index) == projection_id:
				camera_projection_option.select(index)
				break

	if camera_fov_spin != null:
		camera_fov_spin.set_value_no_signal(camera_fov)

	if camera_orthographic_size_spin != null:
		camera_orthographic_size_spin.set_value_no_signal(camera_orthographic_size)

	if transparent_background_check != null:
		transparent_background_check.button_pressed = transparent_background

	if background_color_picker != null:
		background_color_picker.color = background_color


func sync_from_controls(
	object_position_controls: Array[SpinBox],
	object_rotation_controls: Array[SpinBox],
	camera_projection_option: OptionButton,
	camera_fov_spin: SpinBox,
	camera_orthographic_size_spin: SpinBox,
	transparent_background_check: CheckBox,
	background_color_picker: ColorPickerButton
) -> void:
	if object_position_controls.size() == 3:
		object_position = Vector3(
			object_position_controls[0].value,
			object_position_controls[1].value,
			object_position_controls[2].value
		)

	if object_rotation_controls.size() == 3:
		object_rotation = Vector3(
			object_rotation_controls[0].value,
			object_rotation_controls[1].value,
			object_rotation_controls[2].value
		)

	if camera_projection_option != null and camera_projection_option.selected >= 0:
		var projection_id := camera_projection_option.get_item_id(camera_projection_option.selected)
		camera_projection = PROJECTION_ORTHOGRAPHIC if projection_id == Camera3D.PROJECTION_ORTHOGONAL else PROJECTION_PERSPECTIVE

	if camera_fov_spin != null:
		camera_fov = camera_fov_spin.value

	if camera_orthographic_size_spin != null:
		camera_orthographic_size = camera_orthographic_size_spin.value

	if transparent_background_check != null:
		transparent_background = transparent_background_check.button_pressed

	if background_color_picker != null:
		background_color = background_color_picker.color
