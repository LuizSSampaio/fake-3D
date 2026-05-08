@tool
extends VBoxContainer

const CheckerboardBackdrop := preload("res://addons/blender_sprite_sheet/checkerboard_backdrop.gd")
const SourceLoader := preload("res://addons/blender_sprite_sheet/sprite_sheet_source_loader.gd")
const ModelUtils := preload("res://addons/blender_sprite_sheet/sprite_sheet_model_utils.gd")
const MaterialApplier := preload("res://addons/blender_sprite_sheet/sprite_sheet_material_applier.gd")
const PreviewScene := preload("res://addons/blender_sprite_sheet/sprite_sheet_preview_scene.gd")
const ExportFrameOverlay := preload("res://addons/blender_sprite_sheet/export_frame_overlay.gd")
const CameraController := preload("res://addons/blender_sprite_sheet/sprite_sheet_camera_controller.gd")
const Capture := preload("res://addons/blender_sprite_sheet/sprite_sheet_capture.gd")
const Exporter := preload("res://addons/blender_sprite_sheet/sprite_sheet_exporter.gd")
const ProfileStore := preload("res://addons/blender_sprite_sheet/sprite_sheet_profile_store.gd")
const SourceSelection := preload("res://addons/blender_sprite_sheet/sprite_sheet_source_selection.gd")
const ExportPlan := preload("res://addons/blender_sprite_sheet/sprite_sheet_export_plan.gd")
const ControlFactory := preload("res://addons/blender_sprite_sheet/sprite_sheet_control_factory.gd")
const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")

const SUPPORTED_EXTENSIONS := SourceLoader.SUPPORTED_EXTENSIONS
const DEFAULT_CAMERA_POSITION := Vector3(0.0, 1.5, 4.0)
const DEFAULT_CAMERA_ROTATION := Vector3(-15.0, 0.0, 0.0)
const DEFAULT_OBJECT_POSITION := Vector3.ZERO
const DEFAULT_OBJECT_ROTATION := Vector3.ZERO
const PREVIEW_MARGIN := 1.3
const PREVIEW_TARGET_SIZE := 1.0
const PROFILE_FORMAT := ProfileStore.FORMAT
const PROFILE_VERSION := ProfileStore.VERSION

var _source_path_edit: LineEdit
var _profile_path_edit: LineEdit
var _material_path_edit: LineEdit
var _texture_path_edit: LineEdit
var _source_list: ItemList
var _source_add_button: Button
var _source_reload_button: Button
var _source_remove_button: Button
var _source_clear_button: Button
var _name_pattern_edit: LineEdit
var _status_label: Label
var _source_file_dialog: EditorFileDialog
var _profile_open_dialog: EditorFileDialog
var _profile_save_dialog: EditorFileDialog
var _material_file_dialog: EditorFileDialog
var _texture_file_dialog: EditorFileDialog
var _output_file_dialog: EditorFileDialog
var _preview_stack: Control
var _checkerboard: CheckerboardBackdrop
var _viewport_container: SubViewportContainer
var _export_frame_overlay: ExportFrameOverlay
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
var _msaa_option: OptionButton
var _screen_space_aa_option: OptionButton
var _taa_check: CheckBox
var _supersample_option: OptionButton
var _resize_filter_option: OptionButton
var _anisotropic_filtering_option: OptionButton
var _output_path_edit: LineEdit
var _export_individual_frames_check: CheckBox
var _export_button: Button
var _export_result_label: Label
var _loaded_source: Node
var _active_profile: Dictionary = {}
var _source_paths := PackedStringArray()
var _is_exporting := false


func _ready() -> void:
	name = "Fake3D"
	custom_minimum_size = Vector2(360, 520)
	_build_ui()
	_update_render_options()
	_build_preview_scene()
	_sync_camera_from_controls()
	_update_background()
	_update_export_frame_overlay()


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

	content.add_child(ControlFactory.create_section_label("Models"))
	content.add_child(_create_source_controls())

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Select a supported 3D asset to preview."
	content.add_child(_status_label)

	content.add_child(ControlFactory.create_section_label("Preview"))
	content.add_child(_create_preview_controls())

	content.add_child(ControlFactory.create_section_label("Object"))
	content.add_child(_create_object_controls())

	content.add_child(ControlFactory.create_section_label("Profile"))
	content.add_child(_create_profile_controls())

	content.add_child(ControlFactory.create_section_label("Material"))
	content.add_child(_create_material_controls())

	content.add_child(ControlFactory.create_section_label("Background"))
	content.add_child(_create_background_controls())

	content.add_child(ControlFactory.create_section_label("Export"))
	content.add_child(_create_export_controls())

	_create_file_dialogs()


func _create_source_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_source_list = ItemList.new()
	_source_list.custom_minimum_size = Vector2(0.0, 112.0)
	_source_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_list.select_mode = ItemList.SELECT_SINGLE
	_source_list.item_selected.connect(_on_source_list_item_selected)
	container.add_child(_source_list)

	var add_row := HBoxContainer.new()
	add_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(add_row)

	_source_path_edit = LineEdit.new()
	_source_path_edit.placeholder_text = "Add model path..."
	_source_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_path_edit.text_submitted.connect(_on_source_path_submitted)
	add_row.add_child(_source_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.tooltip_text = "Choose one or more models to add."
	browse_button.pressed.connect(_on_browse_pressed)
	add_row.add_child(browse_button)

	_source_add_button = Button.new()
	_source_add_button.text = "Add"
	_source_add_button.tooltip_text = "Add the typed model path to the list."
	_source_add_button.pressed.connect(_add_source_from_entry)
	add_row.add_child(_source_add_button)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_source_reload_button = Button.new()
	_source_reload_button.text = "Reload Selected"
	_source_reload_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_reload_button.pressed.connect(_reload_source)
	action_row.add_child(_source_reload_button)

	_source_remove_button = Button.new()
	_source_remove_button.text = "Remove Selected"
	_source_remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_remove_button.pressed.connect(_remove_selected_source)
	action_row.add_child(_source_remove_button)

	_source_clear_button = Button.new()
	_source_clear_button.text = "Clear All"
	_source_clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_clear_button.pressed.connect(_clear_sources)
	action_row.add_child(_source_clear_button)
	container.add_child(action_row)

	_update_source_actions()

	return container


func _create_profile_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var path_row := HBoxContainer.new()
	path_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(ControlFactory.create_row_label("Config"))

	_profile_path_edit = LineEdit.new()
	_profile_path_edit.placeholder_text = "res://sprite_sheet_profile.json"
	_profile_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_path_edit.text_submitted.connect(_on_profile_path_submitted)
	path_row.add_child(_profile_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_on_profile_browse_pressed)
	path_row.add_child(browse_button)
	container.add_child(path_row)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var load_button := Button.new()
	load_button.text = "Load Profile"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(_on_load_profile_pressed)
	action_row.add_child(load_button)

	var save_button := Button.new()
	save_button.text = "Save Profile"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_profile_pressed)
	action_row.add_child(save_button)
	container.add_child(action_row)

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
	row.add_child(ControlFactory.create_row_label(label_text))

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
	_preview_stack.clip_contents = true

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

	_export_frame_overlay = ExportFrameOverlay.new()
	_export_frame_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_stack.add_child(_export_frame_overlay)

	return _preview_stack


func _create_object_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_object_position_controls = ControlFactory.create_vector3_row(container, "Position", DEFAULT_OBJECT_POSITION, -1000.0, 1000.0, 0.01, _on_object_control_changed)
	_object_rotation_controls = ControlFactory.create_vector3_row(container, "Rotation", DEFAULT_OBJECT_ROTATION, -360.0, 360.0, 0.1, _on_object_control_changed)

	var projection_row := HBoxContainer.new()
	projection_row.add_child(ControlFactory.create_row_label("Projection"))
	_camera_projection_option = OptionButton.new()
	_camera_projection_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_projection_option.add_item("Perspective", Camera3D.PROJECTION_PERSPECTIVE)
	_camera_projection_option.add_item("Orthographic", Camera3D.PROJECTION_ORTHOGONAL)
	_camera_projection_option.item_selected.connect(_on_projection_selected)
	projection_row.add_child(_camera_projection_option)
	container.add_child(projection_row)

	_camera_fov_spin = ControlFactory.create_spin_box(1.0, 179.0, 0.1, 70.0)
	ControlFactory.add_labeled_control(container, "FOV", _camera_fov_spin)
	_camera_fov_spin.value_changed.connect(_on_camera_control_changed)

	_camera_orthographic_size_spin = ControlFactory.create_spin_box(0.001, 1000.0, 0.01, 4.0)
	ControlFactory.add_labeled_control(container, "Ortho Size", _camera_orthographic_size_spin)
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
	ControlFactory.add_labeled_control(container, "Color", _background_color_picker)

	return container


func _create_export_controls() -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_frame_width_spin = ControlFactory.create_spin_box(1.0, 8192.0, 1.0, 256.0)
	ControlFactory.add_labeled_control(container, "Width", _frame_width_spin)
	_frame_width_spin.value_changed.connect(_on_export_dimensions_changed)

	_frame_height_spin = ControlFactory.create_spin_box(1.0, 8192.0, 1.0, 256.0)
	ControlFactory.add_labeled_control(container, "Height", _frame_height_spin)
	_frame_height_spin.value_changed.connect(_on_export_dimensions_changed)

	_frame_count_spin = ControlFactory.create_spin_box(1.0, 10000.0, 1.0, 1.0)
	ControlFactory.add_labeled_control(container, "Frames", _frame_count_spin)

	_columns_spin = ControlFactory.create_spin_box(1.0, 10000.0, 1.0, 1.0)
	ControlFactory.add_labeled_control(container, "Columns", _columns_spin)

	_frame_spacing_spin = ControlFactory.create_spin_box(0.0, 1024.0, 1.0, 0.0)
	ControlFactory.add_labeled_control(container, "Spacing", _frame_spacing_spin)

	_msaa_option = ControlFactory.create_option_button(RenderOptions.get_msaa_options(), RenderOptions.DEFAULT_MSAA_3D)
	ControlFactory.add_labeled_control(container, "MSAA", _msaa_option)
	_msaa_option.item_selected.connect(_on_render_option_selected)

	_screen_space_aa_option = ControlFactory.create_option_button(RenderOptions.get_screen_space_aa_options(), RenderOptions.DEFAULT_SCREEN_SPACE_AA)
	ControlFactory.add_labeled_control(container, "Edge AA", _screen_space_aa_option)
	_screen_space_aa_option.item_selected.connect(_on_render_option_selected)

	_taa_check = CheckBox.new()
	_taa_check.text = "Temporal anti-aliasing"
	_taa_check.button_pressed = RenderOptions.DEFAULT_USE_TAA
	_taa_check.toggled.connect(_on_taa_toggled)
	container.add_child(_taa_check)

	_supersample_option = ControlFactory.create_option_button(RenderOptions.get_supersample_options(), RenderOptions.DEFAULT_SUPERSAMPLE_SCALE)
	ControlFactory.add_labeled_control(container, "Supersample", _supersample_option)
	_supersample_option.item_selected.connect(_on_render_option_selected)

	_resize_filter_option = ControlFactory.create_option_button(RenderOptions.get_resize_filter_options(), RenderOptions.DEFAULT_RESIZE_FILTER)
	ControlFactory.add_labeled_control(container, "Resize Filter", _resize_filter_option)
	_resize_filter_option.item_selected.connect(_on_render_option_selected)

	_anisotropic_filtering_option = ControlFactory.create_option_button(RenderOptions.get_anisotropic_filtering_options(), RenderOptions.DEFAULT_ANISOTROPIC_FILTERING)
	ControlFactory.add_labeled_control(container, "Texture Filter", _anisotropic_filtering_option)
	_anisotropic_filtering_option.item_selected.connect(_on_render_option_selected)

	var output_row := HBoxContainer.new()
	output_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_row.add_child(ControlFactory.create_row_label("Output"))

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

	_name_pattern_edit = LineEdit.new()
	_name_pattern_edit.text = Exporter.DEFAULT_OUTPUT_NAME_PATTERN
	_name_pattern_edit.placeholder_text = Exporter.DEFAULT_OUTPUT_NAME_PATTERN
	_name_pattern_edit.tooltip_text = "Tokens: {model}, {source}, {index}, {index0}, {count}, {output}"
	ControlFactory.add_labeled_control(container, "Name Pattern", _name_pattern_edit)

	_export_individual_frames_check = CheckBox.new()
	_export_individual_frames_check.text = "Export individual frames"
	container.add_child(_export_individual_frames_check)

	_export_button = Button.new()
	_export_button.text = "Export PNG"
	_export_button.pressed.connect(_on_export_pressed)
	container.add_child(_export_button)

	_export_result_label = Label.new()
	_export_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_export_result_label.text = "PNG export is ready after source models are loaded."
	container.add_child(_export_result_label)

	return container


func _create_file_dialogs() -> void:
	if not Engine.is_editor_hint():
		return

	_source_file_dialog = EditorFileDialog.new()
	_source_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	_source_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_source_file_dialog.title = "Select 3D Assets"
	_source_file_dialog.add_filter("*.tscn, *.scn, *.glb, *.gltf, *.obj, *.fbx, *.blend ; Supported 3D assets")
	_source_file_dialog.add_filter("*.tscn, *.scn ; Godot scenes")
	_source_file_dialog.add_filter("*.glb, *.gltf, *.obj, *.fbx, *.blend ; Imported 3D assets")
	_source_file_dialog.files_selected.connect(_on_source_files_selected)
	add_child(_source_file_dialog)

	_profile_open_dialog = _create_file_dialog("Load Sprite Sheet Profile", _on_profile_file_selected)
	_profile_open_dialog.add_filter("*.json ; Sprite sheet profile")
	add_child(_profile_open_dialog)

	_profile_save_dialog = EditorFileDialog.new()
	_profile_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_profile_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_profile_save_dialog.title = "Save Sprite Sheet Profile"
	_profile_save_dialog.add_filter("*.json ; Sprite sheet profile")
	_profile_save_dialog.file_selected.connect(_on_profile_save_file_selected)
	add_child(_profile_save_dialog)

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


func _on_source_files_selected(paths: PackedStringArray) -> void:
	_add_source_paths(paths)


func _on_material_browse_pressed() -> void:
	if _material_file_dialog:
		_material_file_dialog.popup_centered_ratio(0.75)


func _on_profile_browse_pressed() -> void:
	if _profile_open_dialog:
		_profile_open_dialog.current_path = _profile_path_edit.text
		_profile_open_dialog.popup_centered_ratio(0.75)


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


func _on_profile_file_selected(path: String) -> void:
	_profile_path_edit.text = _normalize_profile_path(path)
	_load_profile(path)


func _on_profile_save_file_selected(path: String) -> void:
	_profile_path_edit.text = _normalize_profile_path(path)
	_save_profile(path)


func _on_texture_file_selected(path: String) -> void:
	_texture_path_edit.text = path
	_apply_material_settings()


func _on_output_file_selected(path: String) -> void:
	_output_path_edit.text = Exporter.normalize_png_output_path(path)


func _on_source_path_submitted(path: String) -> void:
	_add_source_path(path)


func _on_material_path_submitted(path: String) -> void:
	_material_path_edit.text = path.strip_edges()
	_apply_material_settings()


func _on_profile_path_submitted(path: String) -> void:
	_profile_path_edit.text = _normalize_profile_path(path)


func _on_texture_path_submitted(path: String) -> void:
	_texture_path_edit.text = path.strip_edges()
	_apply_material_settings()


func _on_output_path_submitted(path: String) -> void:
	_output_path_edit.text = Exporter.normalize_png_output_path(path)


func _on_source_list_item_selected(index: int) -> void:
	if index < 0 or index >= _source_paths.size():
		return

	_update_source_actions()
	_preview_source(_source_paths[index])


func _clear_material_path() -> void:
	_material_path_edit.clear()
	_apply_material_settings()


func _clear_texture_path() -> void:
	_texture_path_edit.clear()
	_apply_material_settings()


func _reload_source() -> void:
	var source_path := _get_selected_source_path()
	if source_path.is_empty():
		source_path = _source_path_edit.text.strip_edges()

	if source_path.is_empty():
		_set_status("Select a supported 3D asset to preview.", true)
		return

	var source_index := _source_paths.find(source_path)
	if source_index != -1:
		_select_source_index(source_index)
		_preview_source(source_path)
	else:
		_load_source(source_path)


func _on_load_profile_pressed() -> void:
	_load_profile(_profile_path_edit.text)


func _on_save_profile_pressed() -> void:
	var path := _normalize_profile_path(_profile_path_edit.text)
	if path.is_empty() and _profile_save_dialog:
		_profile_save_dialog.popup_centered_ratio(0.75)
		return

	_save_profile(path)


func _on_export_pressed() -> void:
	if _is_exporting:
		return

	await _export_sprite_sheets()


func _load_source(path: String) -> Dictionary:
	var paths := PackedStringArray()
	paths.append(path)
	return _set_source_paths(paths)


func _preview_source(path: String) -> Dictionary:
	var load_result := SourceLoader.load_source(path)
	if not load_result.ok:
		_set_status(load_result.message, true)
		return load_result

	_clear_loaded_source()
	_reset_object_transform()
	_model_root.position = Vector3.ZERO
	_model_root.scale = Vector3.ONE
	_loaded_source = load_result.instance
	_model_root.add_child(_loaded_source)

	var bounds := _calculate_model_bounds()
	if not bounds.has_value:
		_clear_loaded_source()
		var message := "No visible mesh found in source asset: %s" % load_result.path
		_set_status(message, true)
		return {
			"ok": false,
			"message": message,
		}

	_fit_model_to_preview(bounds.aabb)
	bounds = _calculate_model_bounds()
	_apply_material_settings(false)
	_frame_bounds(bounds.aabb)
	if not _active_profile.is_empty():
		_apply_profile_settings(_active_profile)
	var message := "Loaded %s" % (load_result.path as String).get_file()
	_source_path_edit.text = load_result.path
	_set_status(message, false)
	return {
		"ok": true,
		"message": message,
		"path": load_result.path,
	}


func _set_source_paths(paths: PackedStringArray, preview_first := true) -> Dictionary:
	_source_paths = SourceSelection.normalize_paths(paths)
	_update_source_list(0 if preview_first else -1)

	if _source_paths.is_empty():
		_clear_loaded_source()
		_source_path_edit.clear()
		_update_source_actions()
		var message := "Select a supported 3D asset to preview."
		_set_status(message, false)
		return {
			"ok": false,
			"message": message,
		}

	var load_result := {
		"ok": true,
		"message": "",
	}
	if preview_first:
		load_result = _preview_source(_source_paths[0])
		if not load_result.ok:
			return load_result

	if _source_paths.size() > 1:
		_set_status("Selected %d source model(s)." % _source_paths.size(), false)

	return load_result


func _clear_sources() -> void:
	_set_source_paths(PackedStringArray(), false)


func _add_source_from_entry() -> Dictionary:
	return _add_source_path(_source_path_edit.text)


func _add_source_path(path: String) -> Dictionary:
	var paths := PackedStringArray()
	paths.append(path)
	return _add_source_paths(paths)


func _add_source_paths(paths: PackedStringArray) -> Dictionary:
	var normalized_paths := SourceSelection.normalize_paths(paths)
	if normalized_paths.is_empty():
		var message := "Enter a supported 3D asset path to add."
		_set_status(message, true)
		return {
			"ok": false,
			"message": message,
		}

	var merged_paths := PackedStringArray()
	for source_path in _source_paths:
		merged_paths.append(source_path)

	var selected_index := -1
	for source_path in normalized_paths:
		var existing_index := merged_paths.find(source_path)
		if existing_index == -1:
			merged_paths.append(source_path)
			if selected_index == -1:
				selected_index = merged_paths.size() - 1
		elif selected_index == -1:
			selected_index = existing_index

	_source_paths = SourceSelection.normalize_paths(merged_paths)
	if selected_index == -1 and not _source_paths.is_empty():
		selected_index = 0

	_update_source_list(selected_index)
	var load_result := _preview_source(_source_paths[selected_index])
	if not load_result.ok:
		return load_result

	if _source_paths.size() > 1:
		_set_status("Selected %d source model(s)." % _source_paths.size(), false)

	return load_result


func _remove_selected_source() -> void:
	var selected_index := _get_selected_source_index()
	if selected_index == -1:
		_set_status("Select a model to remove.", true)
		return

	var removed_path := _source_paths[selected_index]
	var remaining_paths := PackedStringArray()
	for index in range(_source_paths.size()):
		if index != selected_index:
			remaining_paths.append(_source_paths[index])

	if remaining_paths.is_empty():
		_set_source_paths(remaining_paths, false)
		_set_status("Removed %s. Add a model to preview." % removed_path.get_file(), false)
		return

	_source_paths = remaining_paths
	var next_index := mini(selected_index, _source_paths.size() - 1)
	_update_source_list(next_index)
	var load_result := _preview_source(_source_paths[next_index])
	if load_result.ok:
		_set_status("Removed %s. Selected %d source model(s)." % [removed_path.get_file(), _source_paths.size()], false)


func _update_source_list(selected_index := -1) -> void:
	SourceSelection.populate_item_list(_source_list, _source_paths)
	_select_source_index(selected_index)


func _select_source_index(index: int) -> void:
	if _source_list == null:
		return

	_source_list.deselect_all()
	if index >= 0 and index < _source_paths.size():
		_source_list.select(index)

	_update_source_actions()


func _get_selected_source_index() -> int:
	if _source_list == null:
		return -1

	var selected_items := _source_list.get_selected_items()
	if selected_items.is_empty():
		return -1

	var selected_index := selected_items[0]
	if selected_index < 0 or selected_index >= _source_paths.size():
		return -1

	return selected_index


func _get_selected_source_path() -> String:
	var selected_index := _get_selected_source_index()
	if selected_index == -1:
		return ""

	return _source_paths[selected_index]


func _update_source_actions() -> void:
	var has_sources := not _source_paths.is_empty()
	var has_selection := _get_selected_source_index() != -1

	if _source_reload_button:
		_source_reload_button.disabled = not has_selection
	if _source_remove_button:
		_source_remove_button.disabled = not has_selection
	if _source_clear_button:
		_source_clear_button.disabled = not has_sources


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


func _save_profile(path: String) -> Dictionary:
	var result := ProfileStore.save_profile(path, _collect_profile_settings())
	if not result.ok:
		return _profile_failure(result.message, true)

	_profile_path_edit.text = result.path
	_active_profile = result.profile.duplicate(true)
	return _profile_success(result.message)


func _load_profile(path: String) -> Dictionary:
	var result := ProfileStore.load_profile(path)
	if not result.ok:
		return _profile_failure(result.message, true)

	var profile: Dictionary = result.profile
	_apply_profile_settings(profile)
	_profile_path_edit.text = result.path
	_active_profile = profile.duplicate(true)
	return _profile_success(result.message)


func _collect_profile_settings() -> Dictionary:
	return {
		"format": PROFILE_FORMAT,
		"version": PROFILE_VERSION,
		"object": {
			"position": ProfileStore.vector3_to_array(CameraController.get_vector3_from_controls(_object_position_controls)),
			"rotation_degrees": ProfileStore.vector3_to_array(CameraController.get_vector3_from_controls(_object_rotation_controls)),
		},
		"camera": {
			"projection": _get_selected_projection_name(),
			"fov": _camera_fov_spin.value,
			"orthographic_size": _camera_orthographic_size_spin.value,
		},
		"material": {
			"material_path": _material_path_edit.text.strip_edges(),
			"texture_path": _texture_path_edit.text.strip_edges(),
		},
		"background": {
			"transparent": _transparent_background_check.button_pressed,
			"color": ProfileStore.color_to_array(_background_color_picker.color),
		},
		"export": {
			"frame_width": int(round(_frame_width_spin.value)),
			"frame_height": int(round(_frame_height_spin.value)),
			"frame_count": int(round(_frame_count_spin.value)),
			"columns": int(round(_columns_spin.value)),
			"frame_spacing": int(round(_frame_spacing_spin.value)),
			"msaa_3d": _get_option_id(_msaa_option, RenderOptions.DEFAULT_MSAA_3D),
			"screen_space_aa": _get_option_id(_screen_space_aa_option, RenderOptions.DEFAULT_SCREEN_SPACE_AA),
			"use_taa": _taa_check.button_pressed,
			"supersample_scale": _get_option_id(_supersample_option, RenderOptions.DEFAULT_SUPERSAMPLE_SCALE),
			"resize_filter": _get_option_id(_resize_filter_option, RenderOptions.DEFAULT_RESIZE_FILTER),
			"anisotropic_filtering": _get_option_id(_anisotropic_filtering_option, RenderOptions.DEFAULT_ANISOTROPIC_FILTERING),
			"export_individual_frames": _export_individual_frames_check.button_pressed,
			"name_pattern": _name_pattern_edit.text.strip_edges(),
		},
	}


func _apply_profile_settings(profile: Dictionary) -> void:
	var object_settings := ProfileStore.dictionary_value(profile, "object")
	if object_settings.is_empty():
		object_settings = profile

	if ProfileStore.has_any_key(object_settings, ProfileStore.POSITION_KEYS) or ProfileStore.has_any_key(object_settings, ProfileStore.ROTATION_KEYS):
		var position := ProfileStore.vector3_any(object_settings, ProfileStore.POSITION_KEYS, CameraController.get_vector3_from_controls(_object_position_controls))
		var rotation := ProfileStore.vector3_any(object_settings, ProfileStore.ROTATION_KEYS, CameraController.get_vector3_from_controls(_object_rotation_controls))
		_set_vector3_controls(_object_position_controls, position)
		_set_vector3_controls(_object_rotation_controls, rotation)

	var camera_settings := ProfileStore.dictionary_value(profile, "camera")
	if not camera_settings.is_empty():
		var projection_id := _projection_id_from_value(camera_settings.get("projection", _get_selected_projection_name()))
		_select_projection_id(projection_id)
		_camera_fov_spin.set_value_no_signal(float(camera_settings.get("fov", _camera_fov_spin.value)))
		_camera_orthographic_size_spin.set_value_no_signal(float(camera_settings.get("orthographic_size", _camera_orthographic_size_spin.value)))

	var material_settings := ProfileStore.dictionary_value(profile, "material")
	if not material_settings.is_empty():
		_material_path_edit.text = str(material_settings.get("material_path", _material_path_edit.text)).strip_edges()
		_texture_path_edit.text = str(material_settings.get("texture_path", _texture_path_edit.text)).strip_edges()

	var background_settings := ProfileStore.dictionary_value(profile, "background")
	if not background_settings.is_empty():
		_transparent_background_check.button_pressed = bool(background_settings.get("transparent", _transparent_background_check.button_pressed))
		_background_color_picker.color = ProfileStore.color_value(background_settings, "color", _background_color_picker.color)

	var export_settings := ProfileStore.dictionary_value(profile, "export")
	if not export_settings.is_empty():
		_frame_width_spin.set_value_no_signal(float(export_settings.get("frame_width", _frame_width_spin.value)))
		_frame_height_spin.set_value_no_signal(float(export_settings.get("frame_height", _frame_height_spin.value)))
		_frame_count_spin.set_value_no_signal(float(export_settings.get("frame_count", _frame_count_spin.value)))
		_columns_spin.set_value_no_signal(float(export_settings.get("columns", _columns_spin.value)))
		_frame_spacing_spin.set_value_no_signal(float(export_settings.get("frame_spacing", _frame_spacing_spin.value)))
		var render_settings := RenderOptions.normalize(export_settings)
		ControlFactory.select_option_by_id(_msaa_option, int(render_settings["msaa_3d"]))
		ControlFactory.select_option_by_id(_screen_space_aa_option, int(render_settings["screen_space_aa"]))
		_taa_check.button_pressed = bool(render_settings["use_taa"])
		ControlFactory.select_option_by_id(_supersample_option, int(render_settings["supersample_scale"]))
		ControlFactory.select_option_by_id(_resize_filter_option, int(render_settings["resize_filter"]))
		ControlFactory.select_option_by_id(_anisotropic_filtering_option, int(render_settings["anisotropic_filtering"]))
		_export_individual_frames_check.button_pressed = bool(export_settings.get("export_individual_frames", _export_individual_frames_check.button_pressed))
		_name_pattern_edit.text = str(export_settings.get("name_pattern", _name_pattern_edit.text)).strip_edges()
		if _name_pattern_edit.text.is_empty():
			_name_pattern_edit.text = Exporter.DEFAULT_OUTPUT_NAME_PATTERN

	_sync_object_from_controls()
	_sync_camera_from_controls()
	_update_background()
	_update_render_options()
	_update_export_frame_overlay()
	_apply_material_settings(false)


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


func _on_export_dimensions_changed(_value: float) -> void:
	_update_export_frame_overlay()


func _on_render_option_selected(_index: int) -> void:
	_update_render_options()


func _on_taa_toggled(_button_pressed: bool) -> void:
	_update_render_options()


func _update_background() -> void:
	var transparent := _transparent_background_check.button_pressed
	_viewport.transparent_bg = transparent
	_checkerboard.visible = transparent
	_background_color_picker.disabled = transparent

	if _world_environment and _world_environment.environment:
		_world_environment.environment.background_color = _background_color_picker.color


func _update_export_frame_overlay() -> void:
	if _export_frame_overlay == null or _frame_width_spin == null or _frame_height_spin == null:
		return

	_export_frame_overlay.set_frame_size(Vector2i(
		int(round(_frame_width_spin.value)),
		int(round(_frame_height_spin.value))
	))


func _collect_export_settings() -> Dictionary:
	return {
		"frame_width": int(round(_frame_width_spin.value)),
		"frame_height": int(round(_frame_height_spin.value)),
		"frame_count": int(round(_frame_count_spin.value)),
		"columns": int(round(_columns_spin.value)),
		"frame_spacing": int(round(_frame_spacing_spin.value)),
		"msaa_3d": _get_option_id(_msaa_option, RenderOptions.DEFAULT_MSAA_3D),
		"screen_space_aa": _get_option_id(_screen_space_aa_option, RenderOptions.DEFAULT_SCREEN_SPACE_AA),
		"use_taa": _taa_check.button_pressed,
		"supersample_scale": _get_option_id(_supersample_option, RenderOptions.DEFAULT_SUPERSAMPLE_SCALE),
		"resize_filter": _get_option_id(_resize_filter_option, RenderOptions.DEFAULT_RESIZE_FILTER),
		"anisotropic_filtering": _get_option_id(_anisotropic_filtering_option, RenderOptions.DEFAULT_ANISOTROPIC_FILTERING),
		"transparent_background": _transparent_background_check.button_pressed,
		"background_color": _background_color_picker.color,
		"output_path": _output_path_edit.text.strip_edges(),
		"output_format": "png",
		"export_individual_frames": _export_individual_frames_check.button_pressed,
		"name_pattern": _name_pattern_edit.text.strip_edges(),
	}


func _update_render_options() -> void:
	if _viewport == null:
		return

	RenderOptions.apply_to_viewport(_viewport, _collect_render_settings())


func _collect_render_settings() -> Dictionary:
	return {
		"msaa_3d": _get_option_id(_msaa_option, RenderOptions.DEFAULT_MSAA_3D),
		"screen_space_aa": _get_option_id(_screen_space_aa_option, RenderOptions.DEFAULT_SCREEN_SPACE_AA),
		"use_taa": _taa_check.button_pressed if _taa_check != null else RenderOptions.DEFAULT_USE_TAA,
		"supersample_scale": _get_option_id(_supersample_option, RenderOptions.DEFAULT_SUPERSAMPLE_SCALE),
		"resize_filter": _get_option_id(_resize_filter_option, RenderOptions.DEFAULT_RESIZE_FILTER),
		"anisotropic_filtering": _get_option_id(_anisotropic_filtering_option, RenderOptions.DEFAULT_ANISOTROPIC_FILTERING),
	}


func _get_option_id(option_button: OptionButton, fallback: int) -> int:
	return ControlFactory.get_selected_option_id(option_button, fallback)


func _normalize_profile_path(path: String) -> String:
	return ProfileStore.normalize_path(path)


func _get_selected_projection_name() -> String:
	var projection_id := _camera_projection_option.get_item_id(_camera_projection_option.selected)
	if projection_id == Camera3D.PROJECTION_ORTHOGONAL:
		return "orthographic"

	return "perspective"


func _projection_id_from_value(value: Variant) -> int:
	if value is int or value is float:
		return int(value)

	var projection_name := str(value).to_lower()
	if projection_name == "orthographic" or projection_name == "orthogonal":
		return Camera3D.PROJECTION_ORTHOGONAL

	return Camera3D.PROJECTION_PERSPECTIVE


func _select_projection_id(projection_id: int) -> void:
	for index in range(_camera_projection_option.get_item_count()):
		if _camera_projection_option.get_item_id(index) == projection_id:
			_camera_projection_option.select(index)
			return

	_camera_projection_option.select(0)


func _validate_export_settings() -> Dictionary:
	return ExportPlan.build(_collect_export_settings(), _source_paths, _name_pattern_edit.text)


func _validate_export_settings_for(settings: Dictionary, has_loaded_source: bool, require_visible_mesh := true) -> Dictionary:
	var validation := Exporter.validate_export_settings(settings, has_loaded_source)
	if not validation.ok:
		return validation

	if require_visible_mesh and not _calculate_model_bounds().has_value:
		return {
			"ok": false,
			"message": "No visible mesh found in source asset before export.",
		}

	return validation


func _export_sprite_sheets() -> void:
	var validation := _validate_export_settings()
	if not validation.ok:
		_set_export_result(validation.message, true)
		return

	var export_items: Array = validation.items
	_is_exporting = true
	_export_button.disabled = true
	var exported_file_count := 0
	var output_dir := str(export_items[0]["output_path"]).get_base_dir()

	for index in range(export_items.size()):
		var settings: Dictionary = export_items[index]
		var source_path := str(settings["source_path"])
		var source_name := source_path.get_file()
		_set_export_result("Rendering %d/%d: %s" % [index + 1, export_items.size(), source_name], false)

		var load_result := _preview_source(source_path)
		if not load_result.ok:
			_finish_export("Export failed for %s: %s" % [source_name, load_result.message], true)
			return

		var loaded_validation := _validate_export_settings_for(settings, is_instance_valid(_loaded_source))
		if not loaded_validation.ok:
			_finish_export("Export failed for %s: %s" % [source_name, loaded_validation.message], true)
			return

		settings = loaded_validation.settings
		_sync_camera_from_controls()
		_update_background()
		_update_render_options()

		var frame_size := Vector2i(int(settings["frame_width"]), int(settings["frame_height"]))
		var capture_result: Dictionary = await Capture.capture_scene(_scene_root, frame_size, bool(settings["transparent_background"]), settings)
		if not capture_result.ok:
			_finish_export("Export failed for %s: %s" % [source_name, capture_result.message], true)
			return

		var export_result := _write_static_export(capture_result.image, settings)
		if not export_result.ok:
			_finish_export("Export failed for %s: %s" % [source_name, export_result.message], true)
			return

		var exported_paths: PackedStringArray = export_result.paths
		exported_file_count += exported_paths.size()

	_finish_export("Exported %d source model(s) to %s (%d PNG file(s))." % [export_items.size(), output_dir, exported_file_count], false)


func _write_static_export(captured_frame: Image, settings: Dictionary) -> Dictionary:
	if captured_frame == null or captured_frame.is_empty():
		return {
			"ok": false,
			"message": "Preview viewport capture produced an empty image.",
		}

	var frames := Exporter.build_repeated_frames(
		captured_frame,
		int(settings["frame_count"]),
		int(settings["frame_width"]),
		int(settings["frame_height"]),
		RenderOptions.get_resize_filter(settings)
	)
	return Exporter.export_pngs(frames, settings)


func _finish_export(message: String, is_error: bool) -> void:
	_is_exporting = false
	_export_button.disabled = false
	_set_export_result(message, is_error)


func _set_export_result(message: String, is_error: bool) -> void:
	_export_result_label.text = message
	_set_status(message, is_error)


func _profile_success(message: String) -> Dictionary:
	_set_status(message, false)
	return {
		"ok": true,
		"message": message,
	}


func _profile_failure(message: String, is_error: bool) -> Dictionary:
	_set_status(message, is_error)
	return {
		"ok": false,
		"message": message,
	}


func _set_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if is_error else Color(0.7, 0.9, 0.7))
