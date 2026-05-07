@tool
extends VBoxContainer

const SUPPORTED_EXTENSIONS := ["tscn", "scn", "glb", "gltf", "obj", "fbx", "blend"]
const DEFAULT_CAMERA_POSITION := Vector3(0.0, 1.5, 4.0)
const DEFAULT_CAMERA_ROTATION := Vector3(-15.0, 0.0, 0.0)
const CHECKER_LIGHT := Color(0.48, 0.48, 0.48)
const CHECKER_DARK := Color(0.36, 0.36, 0.36)
const PREVIEW_MARGIN := 1.3
const PREVIEW_TARGET_SIZE := 1.0

var _source_path_edit: LineEdit
var _material_path_edit: LineEdit
var _texture_path_edit: LineEdit
var _status_label: Label
var _source_file_dialog: EditorFileDialog
var _material_file_dialog: EditorFileDialog
var _texture_file_dialog: EditorFileDialog
var _preview_stack: Control
var _checkerboard: CheckerboardBackdrop
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _scene_root: Node3D
var _model_root: Node3D
var _camera: Camera3D
var _world_environment: WorldEnvironment
var _transparent_background_check: CheckBox
var _background_color_picker: ColorPickerButton
var _camera_position_controls: Array[SpinBox] = []
var _camera_rotation_controls: Array[SpinBox] = []
var _camera_fov_spin: SpinBox
var _camera_projection_option: OptionButton
var _camera_orthographic_size_spin: SpinBox
var _loaded_source: Node


class CheckerboardBackdrop:
	extends Control

	var tile_size := 16

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect_size := get_size()
		for y in range(0, int(rect_size.y) + tile_size, tile_size):
			for x in range(0, int(rect_size.x) + tile_size, tile_size):
				var checker_index := int(x / tile_size) + int(y / tile_size)
				var color := CHECKER_LIGHT if checker_index % 2 == 0 else CHECKER_DARK
				draw_rect(Rect2(Vector2(x, y), Vector2(tile_size, tile_size)), color)


func _ready() -> void:
	name = "Sprite Sheet Renderer"
	custom_minimum_size = Vector2(360, 520)
	_build_ui()
	_build_preview_scene()
	_sync_camera_from_controls()
	_update_background()


func _exit_tree() -> void:
	_clear_loaded_source()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	content.add_child(_create_section_label("Source"))
	content.add_child(_create_source_controls())

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Select a supported 3D asset to preview."
	content.add_child(_status_label)

	content.add_child(_create_section_label("Preview"))
	content.add_child(_create_preview_controls())

	content.add_child(_create_section_label("Camera"))
	content.add_child(_create_camera_controls())

	content.add_child(_create_section_label("Material"))
	content.add_child(_create_material_controls())

	content.add_child(_create_section_label("Background"))
	content.add_child(_create_background_controls())

	_create_file_dialogs()


func _create_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _create_source_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var picker_row := HBoxContainer.new()
	picker_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(picker_row)

	_source_path_edit = LineEdit.new()
	_source_path_edit.placeholder_text = "res://path/to/model.glb"
	_source_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_path_edit.text_submitted.connect(_on_source_path_submitted)
	picker_row.add_child(_source_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_on_browse_pressed)
	picker_row.add_child(browse_button)

	var reload_button := Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(_reload_source)
	container.add_child(reload_button)

	return container


func _create_material_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(_create_resource_picker_row("Material", "res://path/to/material.tres", _on_material_browse_pressed, _on_material_path_submitted, _clear_material_path))
	container.add_child(_create_resource_picker_row("Texture", "res://path/to/texture.png", _on_texture_browse_pressed, _on_texture_path_submitted, _clear_texture_path))

	var apply_button := Button.new()
	apply_button.text = "Apply Material"
	apply_button.pressed.connect(_apply_material_settings)
	container.add_child(apply_button)

	return container


func _create_resource_picker_row(label_text: String, placeholder: String, browse_callback: Callable, submit_callback: Callable, clear_callback: Callable) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_create_row_label(label_text))

	var path_edit := LineEdit.new()
	path_edit.placeholder_text = placeholder
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.text_submitted.connect(submit_callback)
	row.add_child(path_edit)

	if label_text == "Material":
		_material_path_edit = path_edit
	else:
		_texture_path_edit = path_edit

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(browse_callback)
	row.add_child(browse_button)

	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(clear_callback)
	row.add_child(clear_button)

	return row


func _create_preview_controls() -> Control:
	_preview_stack = Control.new()
	_preview_stack.custom_minimum_size = Vector2(320, 240)
	_preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_checkerboard = CheckerboardBackdrop.new()
	_checkerboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_stack.add_child(_checkerboard)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_stack.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 480)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport_container.add_child(_viewport)

	return _preview_stack


func _create_camera_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_camera_position_controls = _create_vector3_row(container, "Position", DEFAULT_CAMERA_POSITION, -1000.0, 1000.0, 0.01, _on_camera_control_changed)
	_camera_rotation_controls = _create_vector3_row(container, "Rotation", DEFAULT_CAMERA_ROTATION, -360.0, 360.0, 0.1, _on_camera_control_changed)

	var projection_row := HBoxContainer.new()
	projection_row.add_child(_create_row_label("Projection"))
	_camera_projection_option = OptionButton.new()
	_camera_projection_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_projection_option.add_item("Perspective", Camera3D.PROJECTION_PERSPECTIVE)
	_camera_projection_option.add_item("Orthographic", Camera3D.PROJECTION_ORTHOGONAL)
	_camera_projection_option.item_selected.connect(_on_projection_selected)
	projection_row.add_child(_camera_projection_option)
	container.add_child(projection_row)

	_camera_fov_spin = _create_spin_box(1.0, 179.0, 0.1, 70.0)
	_add_labeled_control(container, "FOV", _camera_fov_spin)
	_camera_fov_spin.value_changed.connect(_on_camera_control_changed)

	_camera_orthographic_size_spin = _create_spin_box(0.001, 1000.0, 0.01, 4.0)
	_add_labeled_control(container, "Ortho Size", _camera_orthographic_size_spin)
	_camera_orthographic_size_spin.value_changed.connect(_on_camera_control_changed)

	var frame_button := Button.new()
	frame_button.text = "Frame Model"
	frame_button.pressed.connect(_frame_model)
	container.add_child(frame_button)

	var reset_button := Button.new()
	reset_button.text = "Reset Camera"
	reset_button.pressed.connect(_reset_camera)
	container.add_child(reset_button)

	return container


func _create_background_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_transparent_background_check = CheckBox.new()
	_transparent_background_check.text = "Transparent preview background"
	_transparent_background_check.button_pressed = true
	_transparent_background_check.toggled.connect(_on_transparent_background_toggled)
	container.add_child(_transparent_background_check)

	_background_color_picker = ColorPickerButton.new()
	_background_color_picker.color = Color(0.12, 0.12, 0.12)
	_background_color_picker.color_changed.connect(_on_background_color_changed)
	_add_labeled_control(container, "Color", _background_color_picker)

	return container


func _create_vector3_row(parent: BoxContainer, label_text: String, initial_value: Vector3, min_value: float, max_value: float, step: float, callback: Callable) -> Array[SpinBox]:
	var row := HBoxContainer.new()
	row.add_child(_create_row_label(label_text))

	var controls: Array[SpinBox] = []
	var values := [initial_value.x, initial_value.y, initial_value.z]
	for axis in ["X", "Y", "Z"]:
		var spin := _create_spin_box(min_value, max_value, step, values[controls.size()])
		spin.tooltip_text = "%s %s" % [label_text, axis]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(callback)
		row.add_child(spin)
		controls.append(spin)

	parent.add_child(row)
	return controls


func _add_labeled_control(parent: BoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_child(_create_row_label(label_text))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


func _create_row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 86.0
	return label


func _create_spin_box(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.allow_greater = true
	spin.allow_lesser = true
	return spin


func _create_file_dialogs() -> void:
	_source_file_dialog = _create_file_dialog("Select 3D Asset", _on_source_file_selected)
	_source_file_dialog.add_filter("*.tscn, *.scn, *.glb, *.gltf, *.obj, *.fbx, *.blend ; Supported 3D assets")
	_source_file_dialog.add_filter("*.tscn, *.scn ; Godot scenes")
	_source_file_dialog.add_filter("*.glb, *.gltf, *.obj, *.fbx, *.blend ; Imported 3D assets")
	add_child(_source_file_dialog)

	_material_file_dialog = _create_file_dialog("Select Material", _on_material_file_selected)
	_material_file_dialog.add_filter("*.tres, *.res, *.material ; Godot material resources")
	add_child(_material_file_dialog)

	_texture_file_dialog = _create_file_dialog("Select Texture", _on_texture_file_selected)
	_texture_file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.tga, *.bmp, *.svg, *.exr, *.hdr ; Texture resources")
	add_child(_texture_file_dialog)


func _create_file_dialog(title: String, selected_callback: Callable) -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.title = title
	dialog.file_selected.connect(selected_callback)
	return dialog


func _build_preview_scene() -> void:
	_scene_root = Node3D.new()
	_scene_root.name = "PreviewScene"
	_viewport.add_child(_scene_root)

	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	_scene_root.add_child(_model_root)

	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.current = true
	_camera.near = 0.001
	_camera.far = 10000.0
	_scene_root.add_child(_camera)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 2.0
	key_light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	_scene_root.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_energy = 0.7
	fill_light.rotation_degrees = Vector3(-20.0, 120.0, 0.0)
	_scene_root.add_child(fill_light)

	_world_environment = WorldEnvironment.new()
	_world_environment.environment = Environment.new()
	_world_environment.environment.background_mode = Environment.BG_COLOR
	_world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world_environment.environment.ambient_light_color = Color.WHITE
	_world_environment.environment.ambient_light_energy = 0.35
	_scene_root.add_child(_world_environment)


func _on_browse_pressed() -> void:
	_source_file_dialog.popup_centered_ratio(0.75)


func _on_source_file_selected(path: String) -> void:
	_source_path_edit.text = path
	_load_source(path)


func _on_material_browse_pressed() -> void:
	_material_file_dialog.popup_centered_ratio(0.75)


func _on_texture_browse_pressed() -> void:
	_texture_file_dialog.popup_centered_ratio(0.75)


func _on_material_file_selected(path: String) -> void:
	_material_path_edit.text = path
	_apply_material_settings()


func _on_texture_file_selected(path: String) -> void:
	_texture_path_edit.text = path
	_apply_material_settings()


func _on_source_path_submitted(path: String) -> void:
	_load_source(path)


func _on_material_path_submitted(path: String) -> void:
	_material_path_edit.text = path.strip_edges()
	_apply_material_settings()


func _on_texture_path_submitted(path: String) -> void:
	_texture_path_edit.text = path.strip_edges()
	_apply_material_settings()


func _clear_material_path() -> void:
	_material_path_edit.clear()
	_apply_material_settings()


func _clear_texture_path() -> void:
	_texture_path_edit.clear()
	_apply_material_settings()


func _reload_source() -> void:
	_load_source(_source_path_edit.text)


func _load_source(path: String) -> void:
	path = path.strip_edges()
	if path.is_empty():
		_set_status("Choose a source asset before reloading.", true)
		return

	if not _is_supported_source_path(path):
		_set_status("Unsupported source type. Choose .tscn, .scn, .glb, .gltf, .obj, .fbx, or .blend.", true)
		return

	if not ResourceLoader.exists(path):
		_set_status("Source asset does not exist: %s" % path, true)
		return

	var resource := ResourceLoader.load(path)
	if resource == null:
		_set_status("Godot could not load the source asset: %s" % path, true)
		return

	var instance := _instantiate_resource(resource)
	if instance == null:
		_set_status("Source asset cannot be instantiated as 3D content: %s" % path, true)
		return

	_clear_loaded_source()
	_model_root.position = Vector3.ZERO
	_model_root.scale = Vector3.ONE
	_loaded_source = instance
	_model_root.add_child(_loaded_source)

	var bounds := _calculate_model_bounds()
	if not bounds.has_value:
		_clear_loaded_source()
		_set_status("No visible mesh found in source asset: %s" % path, true)
		return

	_fit_model_to_preview(bounds.aabb)
	bounds = _calculate_model_bounds()
	_apply_material_settings(false)
	_frame_bounds(bounds.aabb)
	_set_status("Loaded %s" % path.get_file(), false)


func _instantiate_resource(resource: Resource) -> Node:
	if resource is PackedScene:
		return (resource as PackedScene).instantiate()

	if resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource
		mesh_instance.name = resource.resource_path.get_file().get_basename()
		return mesh_instance

	return null


func _clear_loaded_source() -> void:
	if is_instance_valid(_loaded_source):
		_loaded_source.queue_free()
	_loaded_source = null
	if _model_root:
		_model_root.position = Vector3.ZERO
		_model_root.scale = Vector3.ONE


func _is_supported_source_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return SUPPORTED_EXTENSIONS.has(extension)


func _calculate_model_bounds() -> Dictionary:
	var mesh_instances := _find_mesh_instances(_model_root)
	var has_value := false
	var bounds := AABB()

	for mesh_instance in mesh_instances:
		var local_aabb := mesh_instance.get_aabb()
		if local_aabb.size == Vector3.ZERO:
			continue

		var global_aabb := _transform_aabb(mesh_instance.global_transform, local_aabb)
		if has_value:
			bounds = bounds.merge(global_aabb)
		else:
			bounds = global_aabb
			has_value = true

	return {
		"has_value": has_value,
		"aabb": bounds,
	}


func _fit_model_to_preview(bounds: AABB) -> void:
	var largest_axis := max(bounds.size.x, max(bounds.size.y, bounds.size.z))
	var preview_scale := 1.0
	if largest_axis > 0.0:
		preview_scale = PREVIEW_TARGET_SIZE / largest_axis

	_model_root.scale = Vector3.ONE * preview_scale
	_model_root.position = -bounds.get_center() * preview_scale


func _apply_material_settings(show_status := true) -> void:
	if not is_instance_valid(_loaded_source):
		if show_status:
			_set_status("Load a source asset before applying material settings.", true)
		return

	var material_path := _material_path_edit.text.strip_edges()
	var texture_path := _texture_path_edit.text.strip_edges()
	if material_path.is_empty() and texture_path.is_empty():
		_set_mesh_surface_override(null)
		if show_status:
			_set_status("Cleared preview material override.", false)
		return

	var material: Material = null
	if not material_path.is_empty():
		if not ResourceLoader.exists(material_path):
			if show_status:
				_set_status("Material resource does not exist: %s" % material_path, true)
			return

		var material_resource := ResourceLoader.load(material_path)
		if not (material_resource is Material):
			if show_status:
				_set_status("Selected resource is not a Material: %s" % material_path, true)
			return
		material = (material_resource as Material).duplicate(true)

	var texture: Texture2D = null
	if not texture_path.is_empty():
		if not ResourceLoader.exists(texture_path):
			if show_status:
				_set_status("Texture resource does not exist: %s" % texture_path, true)
			return

		var texture_resource := ResourceLoader.load(texture_path)
		if not (texture_resource is Texture2D):
			if show_status:
				_set_status("Selected resource is not a Texture2D: %s" % texture_path, true)
			return
		texture = texture_resource as Texture2D

	if material == null:
		material = StandardMaterial3D.new()

	if texture != null:
		if _has_object_property(material, "albedo_texture"):
			material.set("albedo_texture", texture)
		elif show_status:
			_set_status("Selected material does not support an albedo texture property.", true)
			return

	_set_mesh_surface_override(material)
	if show_status:
		_set_status("Applied preview material to loaded model.", false)


func _set_mesh_surface_override(material: Material) -> void:
	for mesh_instance in _find_mesh_instances(_model_root):
		if mesh_instance.mesh == null:
			continue

		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface_index, material)


func _has_object_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if property_info["name"] == property_name:
			return true
	return false


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and child.visible:
			result.append(child)
		result.append_array(_find_mesh_instances(child))
	return result


func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var points := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
	]

	var transformed := AABB(transform * points[0], Vector3.ZERO)
	for index in range(1, points.size()):
		transformed = transformed.expand(transform * points[index])
	return transformed


func _frame_model() -> void:
	var bounds := _calculate_model_bounds()
	if not bounds.has_value:
		_set_status("Load a source asset with at least one visible mesh before framing.", true)
		return

	_frame_bounds(bounds.aabb)
	_set_status("Camera framed to loaded model.", false)


func _reset_camera() -> void:
	var bounds := _calculate_model_bounds()
	if bounds.has_value:
		_frame_bounds(bounds.aabb)
	else:
		_set_vector3_controls(_camera_position_controls, DEFAULT_CAMERA_POSITION)
		_set_vector3_controls(_camera_rotation_controls, DEFAULT_CAMERA_ROTATION)
		_camera_fov_spin.set_value_no_signal(70.0)
		_camera_orthographic_size_spin.set_value_no_signal(4.0)
		_sync_camera_from_controls()


func _frame_bounds(bounds: AABB) -> void:
	var center := bounds.get_center()
	var radius := max(bounds.size.length() * 0.5, 0.01)
	var fov_radians := deg_to_rad(max(_camera_fov_spin.value, 1.0))
	var distance: float = radius / tan(fov_radians * 0.5)
	distance = max(max(distance * PREVIEW_MARGIN, radius * 2.0), 1.0)

	var camera_position := center + Vector3(0.0, radius * 0.2, distance)
	_set_vector3_controls(_camera_position_controls, camera_position)
	var largest_axis := max(bounds.size.x, max(bounds.size.y, bounds.size.z))
	_camera_orthographic_size_spin.set_value_no_signal(max(largest_axis * PREVIEW_MARGIN, 0.01))
	_sync_camera_from_controls()
	_camera.look_at(center, Vector3.UP)
	_set_vector3_controls(_camera_rotation_controls, _camera.rotation_degrees)


func _set_vector3_controls(controls: Array[SpinBox], value: Vector3) -> void:
	controls[0].set_value_no_signal(value.x)
	controls[1].set_value_no_signal(value.y)
	controls[2].set_value_no_signal(value.z)


func _on_camera_control_changed(_value: float) -> void:
	_sync_camera_from_controls()


func _on_projection_selected(_index: int) -> void:
	_sync_camera_from_controls()


func _sync_camera_from_controls() -> void:
	if not _camera:
		return

	_camera.position = Vector3(
		_camera_position_controls[0].value,
		_camera_position_controls[1].value,
		_camera_position_controls[2].value
	)
	_camera.rotation_degrees = Vector3(
		_camera_rotation_controls[0].value,
		_camera_rotation_controls[1].value,
		_camera_rotation_controls[2].value
	)
	_camera.projection = _camera_projection_option.get_item_id(_camera_projection_option.selected)
	_camera.fov = _camera_fov_spin.value
	_camera.size = _camera_orthographic_size_spin.value
	_camera_orthographic_size_spin.editable = _camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	_camera_fov_spin.editable = _camera.projection == Camera3D.PROJECTION_PERSPECTIVE


func _on_transparent_background_toggled(_button_pressed: bool) -> void:
	_update_background()


func _on_background_color_changed(_color: Color) -> void:
	_update_background()


func _update_background() -> void:
	var transparent := _transparent_background_check.button_pressed
	_viewport.transparent_bg = transparent
	_checkerboard.visible = transparent
	_background_color_picker.disabled = transparent

	if _world_environment and _world_environment.environment:
		_world_environment.environment.background_color = _background_color_picker.color


func _set_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if is_error else Color(0.7, 0.9, 0.7))
