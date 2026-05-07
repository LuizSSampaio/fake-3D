@tool
extends VBoxContainer

const CheckerboardBackdrop := preload("res://addons/blender_sprite_sheet/checkerboard_backdrop.gd")
const SourceLoader := preload("res://addons/blender_sprite_sheet/sprite_sheet_source_loader.gd")
const ModelUtils := preload("res://addons/blender_sprite_sheet/sprite_sheet_model_utils.gd")
const MaterialApplier := preload("res://addons/blender_sprite_sheet/sprite_sheet_material_applier.gd")
const PreviewScene := preload("res://addons/blender_sprite_sheet/sprite_sheet_preview_scene.gd")
const CameraController := preload("res://addons/blender_sprite_sheet/sprite_sheet_camera_controller.gd")
const Capture := preload("res://addons/blender_sprite_sheet/sprite_sheet_capture.gd")
const Exporter := preload("res://addons/blender_sprite_sheet/sprite_sheet_exporter.gd")

const SUPPORTED_EXTENSIONS := SourceLoader.SUPPORTED_EXTENSIONS
const DEFAULT_CAMERA_POSITION := Vector3(0.0, 1.5, 4.0)
const DEFAULT_CAMERA_ROTATION := Vector3(-15.0, 0.0, 0.0)
const DEFAULT_OBJECT_POSITION := Vector3.ZERO
const DEFAULT_OBJECT_ROTATION := Vector3.ZERO
const PREVIEW_MARGIN := 1.3
const PREVIEW_TARGET_SIZE := 1.0

var _source_path_edit: LineEdit
var _material_path_edit: LineEdit
var _texture_path_edit: LineEdit
var _status_label: Label
var _source_file_dialog: EditorFileDialog
var _material_file_dialog: EditorFileDialog
var _texture_file_dialog: EditorFileDialog
var _output_file_dialog: EditorFileDialog
var _preview_stack: Control
var _checkerboard: CheckerboardBackdrop
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _scene_root: Node3D
var _object_root: Node3D
var _model_root: Node3D
var _camera: Camera3D
var _world_environment: WorldEnvironment
var _transparent_background_check: CheckBox
var _background_color_picker: ColorPickerButton
var _object_position_controls: Array[SpinBox] = []
var _object_rotation_controls: Array[SpinBox] = []
var _camera_fov_spin: SpinBox
var _camera_projection_option: OptionButton
var _camera_orthographic_size_spin: SpinBox
var _frame_width_spin: SpinBox
var _frame_height_spin: SpinBox
var _frame_count_spin: SpinBox
var _columns_spin: SpinBox
var _frame_spacing_spin: SpinBox
var _output_path_edit: LineEdit
var _export_individual_frames_check: CheckBox
var _export_button: Button
var _export_result_label: Label
var _loaded_source: Node
var _is_exporting := false


func _ready() -> void:
	name = "Fake3D"
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

	content.add_child(_create_section_label("Object"))
	content.add_child(_create_object_controls())

	content.add_child(_create_section_label("Material"))
	content.add_child(_create_material_controls())

	content.add_child(_create_section_label("Background"))
	content.add_child(_create_background_controls())

	content.add_child(_create_section_label("Export"))
	content.add_child(_create_export_controls())

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


func _create_object_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_object_position_controls = _create_vector3_row(container, "Position", DEFAULT_OBJECT_POSITION, -1000.0, 1000.0, 0.01, _on_object_control_changed)
	_object_rotation_controls = _create_vector3_row(container, "Rotation", DEFAULT_OBJECT_ROTATION, -360.0, 360.0, 0.1, _on_object_control_changed)

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
	reset_button.text = "Reset Object"
	reset_button.pressed.connect(_reset_object)
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


func _create_export_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_frame_width_spin = _create_spin_box(1.0, 8192.0, 1.0, 256.0)
	_add_labeled_control(container, "Width", _frame_width_spin)

	_frame_height_spin = _create_spin_box(1.0, 8192.0, 1.0, 256.0)
	_add_labeled_control(container, "Height", _frame_height_spin)

	_frame_count_spin = _create_spin_box(1.0, 10000.0, 1.0, 1.0)
	_add_labeled_control(container, "Frames", _frame_count_spin)

	_columns_spin = _create_spin_box(1.0, 10000.0, 1.0, 1.0)
	_add_labeled_control(container, "Columns", _columns_spin)

	_frame_spacing_spin = _create_spin_box(0.0, 1024.0, 1.0, 0.0)
	_add_labeled_control(container, "Spacing", _frame_spacing_spin)

	var output_row := HBoxContainer.new()
	output_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_row.add_child(_create_row_label("Output"))

	_output_path_edit = LineEdit.new()
	_output_path_edit.placeholder_text = "res://sprite_sheet.png"
	_output_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_path_edit.text_submitted.connect(_on_output_path_submitted)
	output_row.add_child(_output_path_edit)

	var output_browse_button := Button.new()
	output_browse_button.text = "Browse"
	output_browse_button.pressed.connect(_on_output_browse_pressed)
	output_row.add_child(output_browse_button)
	container.add_child(output_row)

	_export_individual_frames_check = CheckBox.new()
	_export_individual_frames_check.text = "Export individual frames"
	container.add_child(_export_individual_frames_check)

	_export_button = Button.new()
	_export_button.text = "Export PNG"
	_export_button.pressed.connect(_on_export_pressed)
	container.add_child(_export_button)

	_export_result_label = Label.new()
	_export_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_export_result_label.text = "Static PNG export is ready after a source is loaded."
	container.add_child(_export_result_label)

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
	if not Engine.is_editor_hint():
		return

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

	_output_file_dialog = EditorFileDialog.new()
	_output_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_output_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_output_file_dialog.title = "Export Sprite Sheet PNG"
	_output_file_dialog.add_filter("*.png ; PNG sprite sheet")
	_output_file_dialog.file_selected.connect(_on_output_file_selected)
	add_child(_output_file_dialog)


func _create_file_dialog(title: String, selected_callback: Callable) -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.title = title
	dialog.file_selected.connect(selected_callback)
	return dialog


func _build_preview_scene() -> void:
	var preview_scene := PreviewScene.build(_viewport)
	_scene_root = preview_scene.scene_root
	_object_root = preview_scene.object_root
	_model_root = preview_scene.model_root
	_camera = preview_scene.camera
	_world_environment = preview_scene.world_environment


func _on_browse_pressed() -> void:
	if _source_file_dialog:
		_source_file_dialog.popup_centered_ratio(0.75)


func _on_source_file_selected(path: String) -> void:
	_source_path_edit.text = path
	_load_source(path)


func _on_material_browse_pressed() -> void:
	if _material_file_dialog:
		_material_file_dialog.popup_centered_ratio(0.75)


func _on_texture_browse_pressed() -> void:
	if _texture_file_dialog:
		_texture_file_dialog.popup_centered_ratio(0.75)


func _on_output_browse_pressed() -> void:
	if _output_file_dialog:
		_output_file_dialog.current_path = _output_path_edit.text
		_output_file_dialog.popup_centered_ratio(0.75)


func _on_material_file_selected(path: String) -> void:
	_material_path_edit.text = path
	_apply_material_settings()


func _on_texture_file_selected(path: String) -> void:
	_texture_path_edit.text = path
	_apply_material_settings()


func _on_output_file_selected(path: String) -> void:
	_output_path_edit.text = Exporter.normalize_png_output_path(path)


func _on_source_path_submitted(path: String) -> void:
	_load_source(path)


func _on_material_path_submitted(path: String) -> void:
	_material_path_edit.text = path.strip_edges()
	_apply_material_settings()


func _on_texture_path_submitted(path: String) -> void:
	_texture_path_edit.text = path.strip_edges()
	_apply_material_settings()


func _on_output_path_submitted(path: String) -> void:
	_output_path_edit.text = Exporter.normalize_png_output_path(path)


func _clear_material_path() -> void:
	_material_path_edit.clear()
	_apply_material_settings()


func _clear_texture_path() -> void:
	_texture_path_edit.clear()
	_apply_material_settings()


func _reload_source() -> void:
	_load_source(_source_path_edit.text)


func _on_export_pressed() -> void:
	if _is_exporting:
		return

	await _export_static_sprite_sheet()


func _load_source(path: String) -> void:
	var load_result := SourceLoader.load_source(path)
	if not load_result.ok:
		_set_status(load_result.message, true)
		return

	_clear_loaded_source()
	_reset_object_transform()
	_model_root.position = Vector3.ZERO
	_model_root.scale = Vector3.ONE
	_loaded_source = load_result.instance
	_model_root.add_child(_loaded_source)

	var bounds := _calculate_model_bounds()
	if not bounds.has_value:
		_clear_loaded_source()
		_set_status("No visible mesh found in source asset: %s" % load_result.path, true)
		return

	_fit_model_to_preview(bounds.aabb)
	bounds = _calculate_model_bounds()
	_apply_material_settings(false)
	_frame_bounds(bounds.aabb)
	_set_status("Loaded %s" % (load_result.path as String).get_file(), false)


func _instantiate_resource(resource: Resource) -> Node:
	return SourceLoader.instantiate_resource(resource)


func _clear_loaded_source() -> void:
	if is_instance_valid(_loaded_source):
		_loaded_source.queue_free()
	_loaded_source = null
	_reset_object_transform()
	if _model_root:
		_model_root.position = Vector3.ZERO
		_model_root.scale = Vector3.ONE


func _is_supported_source_path(path: String) -> bool:
	return SourceLoader.is_supported_source_path(path)


func _calculate_model_bounds() -> Dictionary:
	return ModelUtils.calculate_model_bounds(_model_root)


func _fit_model_to_preview(bounds: AABB) -> void:
	ModelUtils.fit_model_to_preview(_model_root, bounds, PREVIEW_TARGET_SIZE)


func _apply_material_settings(show_status := true) -> void:
	if not is_instance_valid(_loaded_source):
		if show_status:
			_set_status("Load a source asset before applying material settings.", true)
		return

	var result := MaterialApplier.apply_to_model(_model_root, _material_path_edit.text, _texture_path_edit.text)
	if show_status:
		_set_status(result.message, not result.ok)


func _set_mesh_surface_override(material: Material) -> void:
	MaterialApplier.set_mesh_surface_override(_model_root, material)


func _has_object_property(object: Object, property_name: String) -> bool:
	return MaterialApplier.has_object_property(object, property_name)


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	return ModelUtils.find_mesh_instances(root)


func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	return ModelUtils.transform_aabb(transform, aabb)


func _frame_model() -> void:
	var bounds := _calculate_model_bounds()
	if not bounds.has_value:
		_set_status("Load a source asset with at least one visible mesh before framing.", true)
		return

	_reset_object_transform()
	bounds = _calculate_model_bounds()
	_frame_bounds(bounds.aabb)
	_set_status("Object framed in fixed camera view.", false)


func _reset_object() -> void:
	_reset_object_transform()
	_sync_camera_from_controls()
	_set_status("Object transform reset.", false)


func _reset_camera() -> void:
	_reset_object()


func _reset_object_transform() -> void:
	if _object_position_controls.is_empty() or _object_rotation_controls.is_empty():
		return

	_set_vector3_controls(_object_position_controls, DEFAULT_OBJECT_POSITION)
	_set_vector3_controls(_object_rotation_controls, DEFAULT_OBJECT_ROTATION)
	_sync_object_from_controls()


func _frame_bounds(bounds: AABB) -> void:
	CameraController.frame_bounds(
		_camera,
		_camera_fov_spin,
		_camera_orthographic_size_spin,
		_camera_projection_option,
		bounds,
		PREVIEW_MARGIN,
		DEFAULT_CAMERA_POSITION,
		DEFAULT_CAMERA_ROTATION
	)


func _set_vector3_controls(controls: Array[SpinBox], value: Vector3) -> void:
	CameraController.set_vector3_controls(controls, value)


func _on_object_control_changed(_value: float) -> void:
	_sync_object_from_controls()


func _on_camera_control_changed(_value: float) -> void:
	_sync_camera_from_controls()


func _on_projection_selected(_index: int) -> void:
	_sync_camera_from_controls()


func _sync_camera_from_controls() -> void:
	CameraController.sync_from_controls(
		_camera,
		_camera_projection_option,
		_camera_fov_spin,
		_camera_orthographic_size_spin,
		DEFAULT_CAMERA_POSITION,
		DEFAULT_CAMERA_ROTATION
	)


func _sync_object_from_controls() -> void:
	CameraController.sync_object_from_controls(
		_object_root,
		_object_position_controls,
		_object_rotation_controls
	)


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


func _collect_export_settings() -> Dictionary:
	return {
		"source_path": _source_path_edit.text.strip_edges(),
		"frame_width": int(round(_frame_width_spin.value)),
		"frame_height": int(round(_frame_height_spin.value)),
		"frame_count": int(round(_frame_count_spin.value)),
		"columns": int(round(_columns_spin.value)),
		"frame_spacing": int(round(_frame_spacing_spin.value)),
		"transparent_background": _transparent_background_check.button_pressed,
		"background_color": _background_color_picker.color,
		"output_path": _output_path_edit.text.strip_edges(),
		"output_format": "png",
		"export_individual_frames": _export_individual_frames_check.button_pressed,
	}


func _validate_export_settings() -> Dictionary:
	var validation := Exporter.validate_export_settings(_collect_export_settings(), is_instance_valid(_loaded_source))
	if not validation.ok:
		return validation

	var bounds := _calculate_model_bounds()
	if not bounds.has_value:
		return {
			"ok": false,
			"message": "No visible mesh found in source asset before export.",
		}

	return validation


func _export_static_sprite_sheet() -> void:
	var validation := _validate_export_settings()
	if not validation.ok:
		_set_export_result(validation.message, true)
		return

	var settings: Dictionary = validation.settings
	_is_exporting = true
	_export_button.disabled = true
	_set_export_result("Rendering static preview frame...", false)
	_sync_camera_from_controls()
	_update_background()

	var frame_size := Vector2i(int(settings["frame_width"]), int(settings["frame_height"]))
	var capture_result: Dictionary = await Capture.capture_scene(_scene_root, frame_size, bool(settings["transparent_background"]))
	if not capture_result.ok:
		_finish_export(capture_result.message, true)
		return

	var export_result := _write_static_export(capture_result.image, settings)
	if not export_result.ok:
		_finish_export(export_result.message, true)
		return

	var message := "%s Sheet size: %dx%d." % [
		export_result.message,
		export_result.sheet_size.x,
		export_result.sheet_size.y,
	]
	_finish_export(message, false)


func _write_static_export(captured_frame: Image, settings: Dictionary) -> Dictionary:
	if captured_frame == null or captured_frame.is_empty():
		return {
			"ok": false,
			"message": "Preview viewport capture produced an empty image.",
		}

	var frames := Exporter.build_repeated_frames(captured_frame, int(settings["frame_count"]), int(settings["frame_width"]), int(settings["frame_height"]))
	return Exporter.export_pngs(frames, settings)


func _finish_export(message: String, is_error: bool) -> void:
	_is_exporting = false
	_export_button.disabled = false
	_set_export_result(message, is_error)


func _set_export_result(message: String, is_error: bool) -> void:
	_export_result_label.text = message
	_set_status(message, is_error)


func _set_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if is_error else Color(0.7, 0.9, 0.7))
