@tool
extends RefCounted

const CheckerboardBackdrop := preload("res://addons/blender_sprite_sheet/checkerboard_backdrop.gd")
const ExportFrameOverlay := preload("res://addons/blender_sprite_sheet/export_frame_overlay.gd")
const Exporter := preload("res://addons/blender_sprite_sheet/sprite_sheet_exporter.gd")
const PreviewScene := preload("res://addons/blender_sprite_sheet/sprite_sheet_preview_scene.gd")
const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")
const ControlFactory := preload("res://addons/blender_sprite_sheet/sprite_sheet_control_factory.gd")


static func build(dock: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	var models_content := create_source_controls(dock) as VBoxContainer

	dock._status_label = Label.new()
	dock._status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock._status_label.text = "Select a supported 3D asset to preview."
	models_content.add_child(dock._status_label)
	add_collapsible_section(content, "Models", models_content)

	content.add_child(create_preview_controls(dock))

	add_collapsible_section(content, "Object", create_object_controls(dock))

	add_collapsible_section(content, "Settings", create_settings_controls(dock))

	add_collapsible_section(content, "Export", create_export_controls(dock))

	create_file_dialogs(dock)


static func add_collapsible_section(parent: BoxContainer, title: String, body: Control, collapsed := false, subsection := false) -> FoldableContainer:
	var section := FoldableContainer.new()
	section.title = title
	section.folded = collapsed
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.set_meta("collapsible_title", title)
	section.set_meta("collapsible_subsection", subsection)

	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(body)

	parent.add_child(section)
	return section


static func create_source_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var folder_row := HBoxContainer.new()
	folder_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_row.add_child(ControlFactory.create_row_label("Folder"))

	dock._models_folder_edit = LineEdit.new()
	dock._models_folder_edit.placeholder_text = "res://models"
	dock._models_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._models_folder_edit.text_submitted.connect(dock._on_models_folder_submitted)
	folder_row.add_child(dock._models_folder_edit)

	var folder_browse_button := Button.new()
	folder_browse_button.text = "Browse..."
	folder_browse_button.tooltip_text = "Choose a folder to scan for supported 3D assets."
	folder_browse_button.pressed.connect(dock._on_models_folder_browse_pressed)
	folder_row.add_child(folder_browse_button)

	var folder_import_button := Button.new()
	folder_import_button.text = "Import"
	folder_import_button.tooltip_text = "Load the supported models from the folder into the list."
	folder_import_button.pressed.connect(dock._import_models_from_folder)
	folder_row.add_child(folder_import_button)
	container.add_child(folder_row)

	dock._models_recursive_check = CheckBox.new()
	dock._models_recursive_check.text = "Recursive"
	container.add_child(dock._models_recursive_check)

	dock._source_list = ItemList.new()
	dock._source_list.custom_minimum_size = Vector2(0.0, 112.0)
	dock._source_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._source_list.select_mode = ItemList.SELECT_SINGLE
	dock._source_list.item_selected.connect(dock._on_source_list_item_selected)
	container.add_child(dock._source_list)

	var add_row := HBoxContainer.new()
	add_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(add_row)

	dock._source_path_edit = LineEdit.new()
	dock._source_path_edit.placeholder_text = "Add model path..."
	dock._source_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._source_path_edit.text_submitted.connect(dock._on_source_path_submitted)
	add_row.add_child(dock._source_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse..."
	browse_button.tooltip_text = "Choose one or more models to add."
	browse_button.pressed.connect(dock._on_browse_pressed)
	add_row.add_child(browse_button)

	dock._source_add_button = Button.new()
	dock._source_add_button.text = "Add"
	dock._source_add_button.tooltip_text = "Add the typed model path to the list."
	dock._source_add_button.pressed.connect(dock._add_source_from_entry)
	add_row.add_child(dock._source_add_button)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	dock._source_reload_button = Button.new()
	dock._source_reload_button.text = "Reload Selected"
	dock._source_reload_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._source_reload_button.pressed.connect(dock._reload_source)
	action_row.add_child(dock._source_reload_button)

	dock._source_remove_button = Button.new()
	dock._source_remove_button.text = "Remove Selected"
	dock._source_remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._source_remove_button.pressed.connect(dock._remove_selected_source)
	action_row.add_child(dock._source_remove_button)

	dock._source_clear_button = Button.new()
	dock._source_clear_button.text = "Clear All"
	dock._source_clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._source_clear_button.pressed.connect(dock._clear_sources)
	action_row.add_child(dock._source_clear_button)
	container.add_child(action_row)

	dock._update_source_actions()

	return container


static func create_profile_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var path_row := HBoxContainer.new()
	path_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(ControlFactory.create_row_label("Config"))

	dock._profile_path_edit = LineEdit.new()
	dock._profile_path_edit.placeholder_text = "res://sprite_sheet_config.json"
	dock._profile_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._profile_path_edit.text_submitted.connect(dock._on_profile_path_submitted)
	path_row.add_child(dock._profile_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse..."
	browse_button.pressed.connect(dock._on_profile_browse_pressed)
	path_row.add_child(browse_button)
	container.add_child(path_row)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var load_button := Button.new()
	load_button.text = "Load Config"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(dock._on_load_profile_pressed)
	action_row.add_child(load_button)

	var save_button := Button.new()
	save_button.text = "Save Config"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(dock._on_save_profile_pressed)
	action_row.add_child(save_button)
	container.add_child(action_row)

	return container


static func create_material_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(create_resource_picker_row(dock, "Material", "res://path/to/material.tres", dock._on_material_browse_pressed, dock._on_material_path_submitted, dock._clear_material_path))
	container.add_child(create_resource_picker_row(dock, "Texture", "res://path/to/texture.png", dock._on_texture_browse_pressed, dock._on_texture_path_submitted, dock._clear_texture_path))

	var apply_button := Button.new()
	apply_button.text = "Apply Material"
	apply_button.pressed.connect(dock._apply_material_settings)
	container.add_child(apply_button)

	return container


static func create_resource_picker_row(dock: VBoxContainer, label_text: String, placeholder: String, browse_callback: Callable, submit_callback: Callable, clear_callback: Callable) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ControlFactory.create_row_label(label_text))

	var path_edit := LineEdit.new()
	path_edit.placeholder_text = placeholder
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.text_submitted.connect(submit_callback)
	row.add_child(path_edit)

	if label_text == "Material":
		dock._material_path_edit = path_edit
	else:
		dock._texture_path_edit = path_edit

	var browse_button := Button.new()
	browse_button.text = "Browse..."
	browse_button.pressed.connect(browse_callback)
	row.add_child(browse_button)

	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(clear_callback)
	row.add_child(clear_button)

	return row


static func create_preview_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 6)

	dock._preview_stack = Control.new()
	dock._preview_stack.custom_minimum_size = Vector2(320, 240)
	dock._preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock._preview_stack.clip_contents = true

	dock._checkerboard = CheckerboardBackdrop.new()
	dock._checkerboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock._preview_stack.add_child(dock._checkerboard)

	dock._viewport_container = SubViewportContainer.new()
	dock._viewport_container.stretch = true
	dock._viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock._preview_stack.add_child(dock._viewport_container)

	dock._viewport = SubViewport.new()
	dock._viewport.size = Vector2i(640, 480)
	dock._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	dock._viewport.own_world_3d = true
	dock._viewport.transparent_bg = true
	dock._viewport_container.add_child(dock._viewport)

	dock._export_frame_overlay = ExportFrameOverlay.new()
	dock._export_frame_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock._preview_stack.add_child(dock._export_frame_overlay)

	container.add_child(dock._preview_stack)
	container.add_child(create_animation_controls(dock))
	return container


static func create_animation_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 4)

	var selector_row := HBoxContainer.new()
	selector_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_row.add_child(ControlFactory.create_row_label("Animation"))

	dock._animation_option = OptionButton.new()
	dock._animation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._animation_option.item_selected.connect(dock._on_animation_selected)
	selector_row.add_child(dock._animation_option)

	dock._animation_play_button = Button.new()
	dock._animation_play_button.text = "Play"
	dock._animation_play_button.tooltip_text = "Play or pause the selected animation."
	dock._animation_play_button.pressed.connect(dock._on_animation_play_pressed)
	selector_row.add_child(dock._animation_play_button)
	container.add_child(selector_row)

	var timeline_row := HBoxContainer.new()
	timeline_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_row.add_child(ControlFactory.create_row_label("Timeline"))

	dock._animation_timeline = HSlider.new()
	dock._animation_timeline.min_value = 0.0
	dock._animation_timeline.max_value = 0.0
	dock._animation_timeline.step = 0.001
	dock._animation_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._animation_timeline.value_changed.connect(dock._on_animation_timeline_changed)
	timeline_row.add_child(dock._animation_timeline)

	dock._animation_frame_label = Label.new()
	dock._animation_frame_label.custom_minimum_size.x = 72.0
	dock._animation_frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timeline_row.add_child(dock._animation_frame_label)
	container.add_child(timeline_row)

	dock._avoid_duplicate_loop_frame_check = CheckBox.new()
	dock._avoid_duplicate_loop_frame_check.text = "Avoid duplicate loop frame"
	dock._avoid_duplicate_loop_frame_check.button_pressed = true
	dock._avoid_duplicate_loop_frame_check.toggled.connect(dock._on_avoid_duplicate_loop_frame_toggled)
	container.add_child(dock._avoid_duplicate_loop_frame_check)

	return container


static func create_object_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var transform_controls := VBoxContainer.new()
	transform_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._object_position_controls = ControlFactory.create_vector3_row(transform_controls, "Position", dock.DEFAULT_OBJECT_POSITION, -1000.0, 1000.0, 0.01, dock._on_object_control_changed)
	dock._object_rotation_controls = ControlFactory.create_vector3_row(transform_controls, "Rotation", dock.DEFAULT_OBJECT_ROTATION, -360.0, 360.0, 0.1, dock._on_object_control_changed)
	add_plain_group(container, "Transform", transform_controls)

	var camera_controls := VBoxContainer.new()
	camera_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var projection_row := HBoxContainer.new()
	projection_row.add_child(ControlFactory.create_row_label("Projection"))
	dock._camera_projection_option = OptionButton.new()
	dock._camera_projection_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._camera_projection_option.add_item("Perspective", Camera3D.PROJECTION_PERSPECTIVE)
	dock._camera_projection_option.add_item("Orthographic", Camera3D.PROJECTION_ORTHOGONAL)
	dock._camera_projection_option.item_selected.connect(dock._on_projection_selected)
	projection_row.add_child(dock._camera_projection_option)
	camera_controls.add_child(projection_row)

	dock._camera_fov_spin = ControlFactory.create_spin_box(1.0, 179.0, 0.1, 70.0)
	ControlFactory.add_labeled_control(camera_controls, "FOV", dock._camera_fov_spin)
	dock._camera_fov_spin.value_changed.connect(dock._on_camera_control_changed)

	dock._camera_orthographic_size_spin = ControlFactory.create_spin_box(0.001, 1000.0, 0.01, 4.0)
	ControlFactory.add_labeled_control(camera_controls, "Ortho Size", dock._camera_orthographic_size_spin)
	dock._camera_orthographic_size_spin.value_changed.connect(dock._on_camera_control_changed)
	add_plain_group(container, "Camera", camera_controls)

	var action_controls := VBoxContainer.new()
	action_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_button := Button.new()
	frame_button.text = "Frame Model"
	frame_button.pressed.connect(dock._frame_model)
	action_controls.add_child(frame_button)

	var reset_button := Button.new()
	reset_button.text = "Reset Object"
	reset_button.pressed.connect(dock._reset_object)
	action_controls.add_child(reset_button)
	add_plain_group(container, "Actions", action_controls)

	return container


static func create_settings_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_plain_group(container, "Config", create_profile_controls(dock))
	add_plain_group(container, "Material", create_material_controls(dock))
	add_plain_group(container, "Background", create_background_controls(dock))
	return container


static func add_plain_group(parent: BoxContainer, title: String, body: Control) -> void:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 4)

	var label := ControlFactory.create_section_label(title)
	label.add_theme_font_size_override("font_size", 14)
	group.add_child(label)

	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(body)
	parent.add_child(group)


static func create_background_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	dock._transparent_background_check = CheckBox.new()
	dock._transparent_background_check.text = "Transparent preview background"
	dock._transparent_background_check.button_pressed = true
	dock._transparent_background_check.toggled.connect(dock._on_transparent_background_toggled)
	container.add_child(dock._transparent_background_check)

	dock._background_color_picker = ColorPickerButton.new()
	dock._background_color_picker.color = Color(0.12, 0.12, 0.12)
	dock._background_color_picker.color_changed.connect(dock._on_background_color_changed)
	ControlFactory.add_labeled_control(container, "Color", dock._background_color_picker)

	dock._lighting_preset_option = create_lighting_preset_option()
	dock._lighting_preset_option.item_selected.connect(dock._on_lighting_preset_selected)
	ControlFactory.add_labeled_control(container, "Lighting", dock._lighting_preset_option)

	return container


static func create_export_controls(dock: VBoxContainer) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sheet_controls := VBoxContainer.new()
	sheet_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._frame_width_spin = ControlFactory.create_spin_box(1.0, 8192.0, 1.0, 256.0)
	ControlFactory.add_labeled_control(sheet_controls, "Width", dock._frame_width_spin)
	dock._frame_width_spin.value_changed.connect(dock._on_export_dimensions_changed)

	dock._frame_height_spin = ControlFactory.create_spin_box(1.0, 8192.0, 1.0, 256.0)
	ControlFactory.add_labeled_control(sheet_controls, "Height", dock._frame_height_spin)
	dock._frame_height_spin.value_changed.connect(dock._on_export_dimensions_changed)

	dock._frame_count_spin = ControlFactory.create_spin_box(1.0, 10000.0, 1.0, 1.0)
	ControlFactory.add_labeled_control(sheet_controls, "Frames", dock._frame_count_spin)
	dock._frame_count_spin.value_changed.connect(dock._on_frame_count_changed)

	dock._columns_spin = ControlFactory.create_spin_box(1.0, 10000.0, 1.0, 1.0)
	ControlFactory.add_labeled_control(sheet_controls, "Columns", dock._columns_spin)

	dock._frame_spacing_spin = ControlFactory.create_spin_box(0.0, 1024.0, 1.0, 0.0)
	ControlFactory.add_labeled_control(sheet_controls, "Spacing", dock._frame_spacing_spin)

	dock._turntable_enabled_check = CheckBox.new()
	dock._turntable_enabled_check.text = "Turntable static model"
	dock._turntable_enabled_check.tooltip_text = "Rotate static models around the vertical axis across exported frames."
	dock._turntable_enabled_check.toggled.connect(dock._on_turntable_toggled)
	sheet_controls.add_child(dock._turntable_enabled_check)

	dock._turntable_degrees_spin = ControlFactory.create_spin_box(-3600.0, 3600.0, 1.0, 360.0)
	ControlFactory.add_labeled_control(sheet_controls, "Turntable Degrees", dock._turntable_degrees_spin)
	add_collapsible_section(container, "Sprite Sheet", sheet_controls, false, true)

	var quality_controls := VBoxContainer.new()
	quality_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._msaa_option = ControlFactory.create_option_button(RenderOptions.get_msaa_options(), RenderOptions.DEFAULT_MSAA_3D)
	ControlFactory.add_labeled_control(quality_controls, "MSAA", dock._msaa_option)
	dock._msaa_option.item_selected.connect(dock._on_render_option_selected)

	dock._screen_space_aa_option = ControlFactory.create_option_button(RenderOptions.get_screen_space_aa_options(), RenderOptions.DEFAULT_SCREEN_SPACE_AA)
	ControlFactory.add_labeled_control(quality_controls, "Edge AA", dock._screen_space_aa_option)
	dock._screen_space_aa_option.item_selected.connect(dock._on_render_option_selected)

	dock._taa_check = CheckBox.new()
	dock._taa_check.text = "Temporal anti-aliasing"
	dock._taa_check.button_pressed = RenderOptions.DEFAULT_USE_TAA
	dock._taa_check.toggled.connect(dock._on_taa_toggled)
	quality_controls.add_child(dock._taa_check)

	dock._supersample_option = ControlFactory.create_option_button(RenderOptions.get_supersample_options(), RenderOptions.DEFAULT_SUPERSAMPLE_SCALE)
	ControlFactory.add_labeled_control(quality_controls, "Supersample", dock._supersample_option)
	dock._supersample_option.item_selected.connect(dock._on_render_option_selected)

	dock._resize_filter_option = ControlFactory.create_option_button(RenderOptions.get_resize_filter_options(), RenderOptions.DEFAULT_RESIZE_FILTER)
	ControlFactory.add_labeled_control(quality_controls, "Resize Filter", dock._resize_filter_option)
	dock._resize_filter_option.item_selected.connect(dock._on_render_option_selected)

	dock._anisotropic_filtering_option = ControlFactory.create_option_button(RenderOptions.get_anisotropic_filtering_options(), RenderOptions.DEFAULT_ANISOTROPIC_FILTERING)
	ControlFactory.add_labeled_control(quality_controls, "Texture Filter", dock._anisotropic_filtering_option)
	dock._anisotropic_filtering_option.item_selected.connect(dock._on_render_option_selected)
	add_collapsible_section(container, "Quality", quality_controls, true, true)

	var output_controls := VBoxContainer.new()
	output_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var output_row := HBoxContainer.new()
	output_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_row.add_child(ControlFactory.create_row_label("Folder"))

	dock._output_path_edit = LineEdit.new()
	dock._output_path_edit.placeholder_text = "res://exports"
	dock._output_path_edit.tooltip_text = "Choose where generated image files will be written."
	dock._output_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock._output_path_edit.text_submitted.connect(dock._on_output_path_submitted)
	output_row.add_child(dock._output_path_edit)

	var output_browse_button := Button.new()
	output_browse_button.text = "Browse..."
	output_browse_button.pressed.connect(dock._on_output_browse_pressed)
	output_row.add_child(output_browse_button)
	output_controls.add_child(output_row)

	dock._output_format_option = create_output_format_option(dock)
	ControlFactory.add_labeled_control(output_controls, "Format", dock._output_format_option)

	dock._name_pattern_edit = LineEdit.new()
	dock._name_pattern_edit.text = Exporter.DEFAULT_OUTPUT_NAME_PATTERN
	dock._name_pattern_edit.placeholder_text = Exporter.DEFAULT_OUTPUT_NAME_PATTERN
	dock._name_pattern_edit.tooltip_text = "Use tokens: {model}, {source}, {index}, {index0}, {count},\n{output} (folder name)."
	ControlFactory.add_labeled_control(output_controls, "Name Pattern", dock._name_pattern_edit)

	dock._export_individual_frames_check = CheckBox.new()
	dock._export_individual_frames_check.text = "Export individual frames"
	output_controls.add_child(dock._export_individual_frames_check)

	dock._export_normal_map_check = CheckBox.new()
	dock._export_normal_map_check.text = "Export 2D normal map"
	dock._export_normal_map_check.tooltip_text = "Write PNG normal map sidecars for Godot 2D lighting."
	output_controls.add_child(dock._export_normal_map_check)

	dock._export_metadata_check = CheckBox.new()
	dock._export_metadata_check.text = "Export metadata JSON"
	output_controls.add_child(dock._export_metadata_check)

	dock._export_sprite_frames_check = CheckBox.new()
	dock._export_sprite_frames_check.text = "Export SpriteFrames resource"
	output_controls.add_child(dock._export_sprite_frames_check)

	dock._overwrite_existing_check = CheckBox.new()
	dock._overwrite_existing_check.text = "Overwrite existing files"
	dock._overwrite_existing_check.button_pressed = true
	output_controls.add_child(dock._overwrite_existing_check)
	add_collapsible_section(container, "Output", output_controls, false, true)

	dock._export_button = Button.new()
	dock._export_button.text = "Export Sprite Sheet"
	dock._export_button.pressed.connect(dock._on_export_pressed)
	container.add_child(dock._export_button)

	dock._export_result_label = Label.new()
	dock._export_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock._export_result_label.text = "Image export is ready after source models are loaded."
	container.add_child(dock._export_result_label)

	return container


static func create_output_format_option(dock: VBoxContainer) -> OptionButton:
	var option_button := OptionButton.new()
	for option in Exporter.get_output_format_options():
		option_button.add_item(str(option["label"]))
		option_button.set_item_metadata(option_button.item_count - 1, str(option["key"]))

	dock._select_output_format(Exporter.DEFAULT_OUTPUT_FORMAT, option_button)
	option_button.item_selected.connect(dock._on_output_format_selected)
	return option_button


static func create_lighting_preset_option() -> OptionButton:
	var option_button := OptionButton.new()
	for option in PreviewScene.get_lighting_preset_options():
		option_button.add_item(str(option["label"]))
		option_button.set_item_metadata(option_button.item_count - 1, str(option["key"]))

	for index in range(option_button.item_count):
		if PreviewScene.normalize_lighting_preset(option_button.get_item_metadata(index)) == PreviewScene.DEFAULT_LIGHTING_PRESET:
			option_button.select(index)
			break

	return option_button


static func create_file_dialogs(dock: VBoxContainer) -> void:
	if not Engine.is_editor_hint():
		return

	dock._source_file_dialog = EditorFileDialog.new()
	dock._source_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	dock._source_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dock._source_file_dialog.title = "Select 3D Assets"
	dock._source_file_dialog.add_filter("*.tscn, *.scn, *.glb, *.gltf, *.obj, *.fbx, *.blend ; Supported 3D assets")
	dock._source_file_dialog.add_filter("*.tscn, *.scn ; Godot scenes")
	dock._source_file_dialog.add_filter("*.glb, *.gltf, *.obj, *.fbx, *.blend ; Imported 3D assets")
	dock._source_file_dialog.files_selected.connect(dock._on_source_files_selected)
	dock.add_child(dock._source_file_dialog)

	dock._models_folder_dialog = _create_file_dialog("Select Models Folder", dock._on_models_folder_selected)
	dock._models_folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dock._models_folder_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dock._models_folder_dialog.dir_selected.connect(dock._on_models_folder_selected)
	dock.add_child(dock._models_folder_dialog)

	dock._profile_open_dialog = _create_file_dialog("Load Sprite Sheet Config", dock._on_profile_file_selected)
	dock._profile_open_dialog.add_filter("*.json ; Sprite sheet config")
	dock.add_child(dock._profile_open_dialog)

	dock._profile_save_dialog = EditorFileDialog.new()
	dock._profile_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dock._profile_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dock._profile_save_dialog.title = "Save Sprite Sheet Config"
	dock._profile_save_dialog.add_filter("*.json ; Sprite sheet config")
	dock._profile_save_dialog.file_selected.connect(dock._on_profile_save_file_selected)
	dock.add_child(dock._profile_save_dialog)

	dock._material_file_dialog = _create_file_dialog("Select Material", dock._on_material_file_selected)
	dock._material_file_dialog.add_filter("*.tres, *.res, *.material ; Godot material resources")
	dock.add_child(dock._material_file_dialog)

	dock._texture_file_dialog = _create_file_dialog("Select Texture", dock._on_texture_file_selected)
	dock._texture_file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.tga, *.bmp, *.svg, *.exr, *.hdr ; Texture resources")
	dock.add_child(dock._texture_file_dialog)

	dock._output_file_dialog = EditorFileDialog.new()
	dock._output_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dock._output_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dock._output_file_dialog.title = "Select Export Folder"
	dock._output_file_dialog.dir_selected.connect(dock._on_output_directory_selected)
	dock.add_child(dock._output_file_dialog)


static func _create_file_dialog(title: String, selected_callback: Callable) -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.title = title
	dialog.file_selected.connect(selected_callback)
	return dialog
