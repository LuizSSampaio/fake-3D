class_name SpriteSheetRendererDockTest
extends GdUnitTestSuite

const SpriteSheetRendererDock := preload("res://addons/blender_sprite_sheet/sprite_sheet_renderer_dock.gd")
const SpriteSheetExporter := preload("res://addons/blender_sprite_sheet/sprite_sheet_exporter.gd")
const SpriteSheetCapture := preload("res://addons/blender_sprite_sheet/sprite_sheet_capture.gd")
const AnimationUtils := preload("res://addons/blender_sprite_sheet/sprite_sheet_animation_utils.gd")
const ExportFrameOverlay := preload("res://addons/blender_sprite_sheet/export_frame_overlay.gd")
const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")
const ControlFactory := preload("res://addons/blender_sprite_sheet/sprite_sheet_control_factory.gd")
const VECTOR_EPSILON := Vector3(0.001, 0.001, 0.001)

var _dock: VBoxContainer


func before_test() -> void:
	_dock = auto_free(SpriteSheetRendererDock.new())
	add_child(_dock)
	await await_idle_frame()


func after_test() -> void:
	if is_instance_valid(_dock):
		_dock.queue_free()
		_dock = null
	await await_idle_frame()


func test_ready_builds_preview_dock_defaults() -> void:
	assert_str(_dock.name).is_equal("Fake3D")
	assert_vector(_dock.custom_minimum_size).is_equal(Vector2(360.0, 520.0))
	assert_str(_dock._status_label.text).is_equal("Select a supported 3D asset to preview.")
	assert_object(_dock._viewport).is_not_null()
	assert_bool(_dock._viewport.transparent_bg).is_true()
	assert_int(_dock._viewport.msaa_3d).is_equal(RenderOptions.DEFAULT_MSAA_3D)
	assert_int(_dock._viewport.screen_space_aa).is_equal(RenderOptions.DEFAULT_SCREEN_SPACE_AA)
	assert_bool(_dock._viewport.use_taa).is_false()
	assert_int(_dock._viewport.anisotropic_filtering_level).is_equal(RenderOptions.DEFAULT_ANISOTROPIC_FILTERING)
	assert_bool(_dock._preview_stack.clip_contents).is_true()
	assert_bool(_dock._checkerboard.visible).is_true()
	assert_object(_dock._export_frame_overlay).is_not_null()
	assert_vector(_dock._export_frame_overlay.frame_size).is_equal(Vector2i(256, 256))
	assert_bool(_dock._animation_option.disabled).is_true()
	assert_str(_dock._animation_option.get_item_text(0)).is_equal("No animations")
	assert_bool(_dock._animation_play_button.disabled).is_true()
	assert_str(_dock._animation_play_button.text).is_equal("Play")
	assert_bool(_dock._animation_timeline.editable).is_false()
	assert_str(_dock._animation_frame_label.text).is_equal("Frame 0 / 0")
	assert_bool(_dock._avoid_duplicate_loop_frame_check.disabled).is_true()
	assert_int(_dock._source_list.item_count).is_equal(0)
	assert_vector(_dock._source_list.custom_minimum_size).is_equal(Vector2(0.0, 112.0))
	assert_str(_dock._source_path_edit.placeholder_text).is_equal("Add model path...")
	assert_bool(_dock._source_reload_button.disabled).is_true()
	assert_bool(_dock._source_remove_button.disabled).is_true()
	assert_bool(_dock._source_clear_button.disabled).is_true()
	assert_str(_dock._output_path_edit.placeholder_text).is_equal("res://exports")
	assert_str(_dock._name_pattern_edit.text).is_equal(SpriteSheetExporter.DEFAULT_OUTPUT_NAME_PATTERN)
	assert_bool(_dock._background_color_picker.disabled).is_true()
	assert_object(_dock._object_root).is_not_null()
	assert_vector(_dock._object_root.position).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_POSITION)
	assert_vector(_dock._object_root.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_ROTATION)
	assert_vector(_dock._camera.position).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_POSITION)
	assert_vector(_dock._camera.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_ROTATION)
	assert_int(_dock._camera.projection).is_equal(Camera3D.PROJECTION_PERSPECTIVE)
	assert_bool(ControlFactory.is_numeric_read_only(_dock._camera_fov_spin)).is_false()
	assert_bool(ControlFactory.is_numeric_read_only(_dock._camera_orthographic_size_spin)).is_true()


func test_source_path_validation_accepts_supported_extensions_case_insensitively() -> void:
	for extension in SpriteSheetRendererDock.SUPPORTED_EXTENSIONS:
		assert_bool(_dock._is_supported_source_path("res://fixture.%s" % extension.to_upper())).is_true()

	assert_bool(_dock._is_supported_source_path("res://fixture.txt")).is_false()
	assert_bool(_dock._is_supported_source_path("res://fixture.tres")).is_false()


func test_load_source_reports_actionable_status_for_invalid_paths() -> void:
	_dock._load_source("   ")
	assert_str(_dock._status_label.text).is_equal("Select a supported 3D asset to preview.")

	_dock._load_source("res://missing.txt")
	assert_str(_dock._status_label.text).contains("Unsupported source type")

	_dock._load_source("res://missing_model.glb")
	assert_str(_dock._status_label.text).is_equal("Source asset doesn't exist: \"res://missing_model.glb\".")


func test_calculate_model_bounds_merges_visible_meshes_and_ignores_hidden_meshes() -> void:
	_add_mesh_instance(_dock._model_root, Vector3(2.0, 4.0, 6.0), Vector3(1.0, 2.0, 3.0))
	_add_mesh_instance(_dock._model_root, Vector3(100.0, 100.0, 100.0), Vector3(100.0, 100.0, 100.0), false)

	var bounds: Dictionary = _dock._calculate_model_bounds()

	assert_bool(bounds.has_value).is_true()
	assert_vector(bounds.aabb.position).is_equal_approx(Vector3.ZERO, VECTOR_EPSILON)
	assert_vector(bounds.aabb.size).is_equal_approx(Vector3(2.0, 4.0, 6.0), VECTOR_EPSILON)


func test_fit_model_to_preview_centers_and_scales_to_target_size() -> void:
	_dock._fit_model_to_preview(AABB(Vector3.ZERO, Vector3(2.0, 4.0, 8.0)))

	assert_vector(_dock._model_root.scale).is_equal_approx(Vector3.ONE * 0.125, VECTOR_EPSILON)
	assert_vector(_dock._model_root.position).is_equal_approx(Vector3(-0.125, -0.25, -0.5), VECTOR_EPSILON)


func test_load_source_instantiates_scene_fits_model_and_keeps_fixed_camera() -> void:
	var source_path := _save_test_scene("load_source_model.tscn")

	_dock._load_source(source_path)

	assert_str(_dock._status_label.text).is_equal("Loaded \"load_source_model.tscn\".")
	assert_object(_dock._loaded_source).is_not_null()
	assert_int(_dock._model_root.get_child_count()).is_equal(1)
	assert_int(_dock._source_paths.size()).is_equal(1)
	assert_str(_dock._source_paths[0]).is_equal(source_path)

	var bounds: Dictionary = _dock._calculate_model_bounds()
	assert_bool(bounds.has_value).is_true()
	assert_vector(bounds.aabb.size).is_equal_approx(Vector3(0.5, 0.75, 1.0), Vector3(0.01, 0.01, 0.01))
	assert_vector(_dock._camera.position).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_POSITION)
	assert_vector(_dock._camera.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_ROTATION)
	assert_float(_dock._camera_orthographic_size_spin.value).is_greater(0.0)
	assert_int(int(_dock._frame_width_spin.value)).is_equal(256)
	assert_int(int(_dock._frame_height_spin.value)).is_equal(256)
	assert_int(int(_dock._frame_count_spin.value)).is_equal(1)
	assert_int(int(_dock._columns_spin.value)).is_equal(1)
	assert_int(int(_dock._frame_spacing_spin.value)).is_equal(0)
	assert_int(_dock._get_option_id(_dock._msaa_option, -1)).is_equal(RenderOptions.DEFAULT_MSAA_3D)
	assert_int(_dock._get_option_id(_dock._screen_space_aa_option, -1)).is_equal(RenderOptions.DEFAULT_SCREEN_SPACE_AA)
	assert_bool(_dock._taa_check.button_pressed).is_false()
	assert_int(_dock._get_option_id(_dock._supersample_option, -1)).is_equal(RenderOptions.DEFAULT_SUPERSAMPLE_SCALE)
	assert_int(_dock._get_option_id(_dock._resize_filter_option, -1)).is_equal(RenderOptions.DEFAULT_RESIZE_FILTER)
	assert_int(_dock._get_option_id(_dock._anisotropic_filtering_option, -1)).is_equal(RenderOptions.DEFAULT_ANISOTROPIC_FILTERING)
	assert_str(_dock._export_result_label.text).is_equal("PNG export is ready after source models are loaded.")


func test_animation_sampling_times_can_avoid_loop_endpoint() -> void:
	var loop_times := AnimationUtils.calculate_sample_times(2.0, 4, true)
	assert_int(loop_times.size()).is_equal(4)
	assert_float(loop_times[0]).is_equal_approx(0.0, 0.001)
	assert_float(loop_times[1]).is_equal_approx(0.5, 0.001)
	assert_float(loop_times[2]).is_equal_approx(1.0, 0.001)
	assert_float(loop_times[3]).is_equal_approx(1.5, 0.001)

	var full_times := AnimationUtils.calculate_sample_times(2.0, 4, false)
	assert_float(full_times[1]).is_equal_approx(0.666, 0.01)
	assert_float(full_times[2]).is_equal_approx(1.333, 0.01)
	assert_float(full_times[3]).is_equal_approx(2.0, 0.001)
	assert_int(AnimationUtils.calculate_frame_index(1.5, 2.0, 4, true)).is_equal(3)


func test_load_source_populates_animation_selector_and_scrubber() -> void:
	var source_path := _save_test_animated_scene("animated_model.tscn", "Walk", 2.0, Animation.LOOP_LINEAR)

	_dock._load_source(source_path)

	assert_str(_dock._status_label.text).is_equal("Loaded \"animated_model.tscn\".")
	assert_bool(_dock._animation_option.disabled).is_false()
	assert_int(_dock._animation_option.item_count).is_equal(1)
	assert_str(_dock._get_selected_animation_name()).is_equal("Walk")
	assert_object(_dock._animation_player).is_not_null()
	assert_bool(_dock._animation_player.has_animation("Walk")).is_true()
	assert_str(str(_dock._animation_player_path)).contains("AnimationPlayer")
	assert_bool(_dock._animation_play_button.disabled).is_false()
	assert_str(_dock._animation_play_button.text).is_equal("Play")
	assert_bool(_dock._animation_timeline.editable).is_true()
	assert_float(_dock._animation_timeline.max_value).is_equal_approx(2.0, 0.001)
	assert_bool(_dock._avoid_duplicate_loop_frame_check.disabled).is_false()
	assert_str(_dock._animation_frame_label.text).is_equal("Frame 0 / 0")


func test_animation_controls_seek_and_toggle_preview_playback() -> void:
	var source_path := _save_test_animated_scene("animated_controls_model.tscn", "Run", 2.0, Animation.LOOP_LINEAR)
	_dock._load_source(source_path)
	_dock._frame_count_spin.set_value_no_signal(4.0)

	_dock._on_animation_timeline_changed(1.0)

	assert_float(_dock._animation_player.current_animation_position).is_equal_approx(1.0, 0.001)
	assert_float(_dock._animation_timeline.value).is_equal_approx(1.0, 0.001)
	assert_str(_dock._animation_frame_label.text).is_equal("Frame 2 / 3")

	_dock._on_animation_play_pressed()

	assert_bool(_dock._animation_player.is_playing()).is_true()
	assert_bool(_dock._is_animation_playing).is_true()
	assert_str(_dock._animation_play_button.text).is_equal("Pause")

	_dock._on_animation_play_pressed()

	assert_bool(_dock._animation_player.is_playing()).is_false()
	assert_bool(_dock._is_animation_playing).is_false()
	assert_str(_dock._animation_play_button.text).is_equal("Play")


func test_export_validation_includes_selected_animation_and_rejects_missing_animation() -> void:
	var source_path := _save_test_animated_scene("animated_export_model.tscn", "Attack", 1.5, Animation.LOOP_NONE)
	_dock._load_source(source_path)
	_dock._output_path_edit.text = _temp_resource_directory()

	var validation: Dictionary = _dock._validate_export_settings()
	assert_bool(validation.ok).is_true()
	var loaded_validation: Dictionary = _dock._validate_export_settings_for(validation.settings, true)

	assert_bool(loaded_validation.ok).is_true()
	assert_str(loaded_validation.settings.animation_name).is_equal("Attack")
	assert_str(str(loaded_validation.settings.animation_player_path)).contains("AnimationPlayer")

	var missing_settings: Dictionary = validation.settings.duplicate()
	missing_settings["animation_name"] = "Missing"
	var missing_validation: Dictionary = _dock._validate_export_settings_for(missing_settings, true)

	assert_bool(missing_validation.ok).is_false()
	assert_str(missing_validation.message).is_equal("Requested animation doesn't exist: \"Missing\".")


func test_capture_animation_sample_plan_and_seek_use_requested_frame_count() -> void:
	var source_path := _save_test_animated_scene("animated_capture_model.tscn", "Idle", 1.0, Animation.LOOP_LINEAR)
	_dock._load_source(source_path)

	var sample_plan := SpriteSheetCapture.build_animation_sample_plan(
		_dock._animation_player,
		"Idle",
		3,
		true
	)

	assert_bool(sample_plan.ok).is_true()
	assert_int(sample_plan.sample_times.size()).is_equal(3)
	assert_float(sample_plan.sample_times[0]).is_equal_approx(0.0, 0.001)
	assert_float(sample_plan.sample_times[1]).is_equal_approx(0.333, 0.01)
	assert_float(sample_plan.sample_times[2]).is_equal_approx(0.666, 0.01)

	var seek_result := AnimationUtils.seek_player(_dock._animation_player, "Idle", sample_plan.sample_times[2])

	assert_bool(seek_result.ok).is_true()
	assert_float(_dock._animation_player.current_animation_position).is_equal_approx(0.666, 0.01)


func test_source_selection_deduplicates_and_previews_first_model() -> void:
	var first_path := _save_test_scene("source_first_model.tscn")
	var second_path := _save_test_scene("source_second_model.tscn")
	var paths := PackedStringArray()
	paths.append(first_path)
	paths.append(second_path)
	paths.append(first_path)

	_dock._set_source_paths(paths)

	assert_int(_dock._source_paths.size()).is_equal(2)
	assert_int(_dock._source_list.item_count).is_equal(2)
	assert_str(_dock._source_list.get_item_text(0)).is_equal("source_first_model.tscn")
	assert_str(_dock._source_list.get_item_text(1)).is_equal("source_second_model.tscn")
	assert_str(_dock._source_path_edit.text).is_equal(first_path)
	assert_bool(_dock._source_reload_button.disabled).is_false()
	assert_bool(_dock._source_remove_button.disabled).is_false()
	assert_bool(_dock._source_clear_button.disabled).is_false()
	assert_object(_dock._loaded_source).is_not_null()
	assert_str(_dock._status_label.text).is_equal("Selected 2 source models.")


func test_source_controls_place_model_list_before_add_bar() -> void:
	var source_container: Node = _dock._source_list.get_parent()
	var add_bar: Node = _dock._source_path_edit.get_parent()

	assert_object(source_container).is_not_null()
	assert_object(add_bar).is_not_null()
	assert_int(source_container.get_child(0).get_instance_id()).is_equal(_dock._source_list.get_instance_id())
	assert_int(source_container.get_child(1).get_instance_id()).is_equal(add_bar.get_instance_id())


func test_editor_panel_uses_foldable_sections_and_subsections() -> void:
	for title in ["Models", "Object", "Settings", "Export"]:
		var section := _find_collapsible_section(title)
		assert_object(section).is_not_null()
		assert_str(section.title).is_equal(title)
		assert_bool(section.folded).is_false()

	for title in ["Sprite Sheet", "Quality", "Output"]:
		assert_object(_find_collapsible_section(title, true)).is_not_null()

	var object_section := _find_collapsible_section("Object")
	object_section.fold()
	await await_idle_frame()
	assert_bool(_dock._object_position_controls[0].is_visible_in_tree()).is_false()
	assert_bool(object_section.folded).is_true()

	object_section.expand()
	await await_idle_frame()
	assert_bool(_dock._object_position_controls[0].is_visible_in_tree()).is_true()
	assert_bool(object_section.folded).is_false()

	var quality_section := _find_collapsible_section("Quality", true)
	assert_bool(quality_section.folded).is_true()

	quality_section.expand()
	await await_idle_frame()
	assert_bool(quality_section.folded).is_false()
	assert_str(quality_section.title).is_equal("Quality")


func test_foldable_sections_have_at_least_three_items() -> void:
	for title in ["Models", "Object", "Settings", "Export", "Sprite Sheet", "Quality", "Output"]:
		var section := _find_collapsible_section(title, title in ["Sprite Sheet", "Quality", "Output"])
		var body := _get_foldable_body(section)
		assert_int(body.get_child_count()).is_greater_equal(3)


func test_editor_panel_uses_style_guide_button_text_and_tooltips() -> void:
	var source_browse_button := _source_row_button(1)
	assert_str(source_browse_button.text).is_equal("Browse...")
	assert_str(source_browse_button.tooltip_text).is_equal("Choose one or more models to add.")

	var profile_path_row: Node = _dock._profile_path_edit.get_parent()
	var profile_browse_button := profile_path_row.get_child(profile_path_row.get_child_count() - 1) as Button
	assert_str(profile_browse_button.text).is_equal("Browse...")

	var output_path_row: Node = _dock._output_path_edit.get_parent()
	var output_browse_button := output_path_row.get_child(output_path_row.get_child_count() - 1) as Button
	assert_str(output_browse_button.text).is_equal("Browse...")
	assert_str(_dock._output_path_edit.tooltip_text).is_equal("Choose where generated PNG files will be written.")
	assert_str(_dock._name_pattern_edit.tooltip_text).contains("\n")


func test_vector_numeric_controls_match_inspector_axis_style() -> void:
	var axes := ["x", "y", "z"]
	assert_int(_dock._object_position_controls.size()).is_equal(3)
	for index in range(_dock._object_position_controls.size()):
		var control: Range = _dock._object_position_controls[index]
		assert_bool(control is Range).is_true()
		assert_str(_get_axis_label(control)).is_equal(axes[index])


func test_add_source_from_bar_appends_without_replacing_existing_models() -> void:
	var first_path := _save_test_scene("bar_first_model.tscn")
	var second_path := _save_test_scene("bar_second_model.tscn")

	_dock._load_source(first_path)
	_dock._source_path_edit.text = second_path
	var result: Dictionary = _dock._add_source_from_entry()

	assert_bool(result.ok).is_true()
	assert_int(_dock._source_paths.size()).is_equal(2)
	assert_int(_dock._source_list.item_count).is_equal(2)
	assert_str(_dock._source_list.get_item_text(0)).is_equal("bar_first_model.tscn")
	assert_str(_dock._source_list.get_item_text(1)).is_equal("bar_second_model.tscn")
	assert_int(_dock._get_selected_source_index()).is_equal(1)
	assert_str(_dock._source_path_edit.text).is_equal(second_path)
	assert_object(_dock._loaded_source).is_not_null()
	assert_str(_dock._status_label.text).is_equal("Selected 2 source models.")


func test_remove_selected_source_removes_one_model_and_previews_next() -> void:
	var first_path := _save_test_scene("remove_first_model.tscn")
	var second_path := _save_test_scene("remove_second_model.tscn")
	var third_path := _save_test_scene("remove_third_model.tscn")
	var paths := PackedStringArray()
	paths.append(first_path)
	paths.append(second_path)
	paths.append(third_path)
	_dock._set_source_paths(paths)
	_dock._source_list.select(1)
	_dock._on_source_list_item_selected(1)

	_dock._remove_selected_source()

	assert_int(_dock._source_paths.size()).is_equal(2)
	assert_str(_dock._source_paths[0]).is_equal(first_path)
	assert_str(_dock._source_paths[1]).is_equal(third_path)
	assert_int(_dock._source_list.item_count).is_equal(2)
	assert_str(_dock._source_list.get_item_text(0)).is_equal("remove_first_model.tscn")
	assert_str(_dock._source_list.get_item_text(1)).is_equal("remove_third_model.tscn")
	assert_int(_dock._get_selected_source_index()).is_equal(1)
	assert_str(_dock._source_path_edit.text).is_equal(third_path)
	assert_str(_dock._status_label.text).is_equal("Removed \"remove_second_model.tscn\". Selected 2 source models.")


func test_preview_export_overlay_tracks_export_aspect_ratio() -> void:
	var wide_rect := ExportFrameOverlay.calculate_export_rect(Vector2(320.0, 240.0), Vector2i(512, 256))
	assert_vector(wide_rect.position).is_equal_approx(Vector2(0.0, 40.0), Vector2(0.001, 0.001))
	assert_vector(wide_rect.size).is_equal_approx(Vector2(320.0, 160.0), Vector2(0.001, 0.001))

	var tall_rect := ExportFrameOverlay.calculate_export_rect(Vector2(320.0, 240.0), Vector2i(128, 256))
	assert_vector(tall_rect.position).is_equal_approx(Vector2(100.0, 0.0), Vector2(0.001, 0.001))
	assert_vector(tall_rect.size).is_equal_approx(Vector2(120.0, 240.0), Vector2(0.001, 0.001))


func test_export_dimension_controls_update_preview_overlay() -> void:
	_dock._frame_width_spin.set_value_no_signal(512.0)
	_dock._frame_height_spin.set_value_no_signal(128.0)
	_dock._on_export_dimensions_changed(0.0)

	assert_vector(_dock._export_frame_overlay.frame_size).is_equal(Vector2i(512, 128))


func test_render_quality_controls_update_preview_and_export_settings() -> void:
	_select_option_by_id(_dock._msaa_option, Viewport.MSAA_8X)
	_select_option_by_id(_dock._screen_space_aa_option, Viewport.SCREEN_SPACE_AA_FXAA)
	_dock._taa_check.button_pressed = true
	_select_option_by_id(_dock._supersample_option, 2)
	_select_option_by_id(_dock._resize_filter_option, Image.INTERPOLATE_CUBIC)
	_select_option_by_id(_dock._anisotropic_filtering_option, Viewport.ANISOTROPY_16X)

	_dock._update_render_options()
	var settings: Dictionary = _dock._collect_export_settings()

	assert_int(_dock._viewport.msaa_3d).is_equal(Viewport.MSAA_8X)
	assert_int(_dock._viewport.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_bool(_dock._viewport.use_taa).is_true()
	assert_int(_dock._viewport.anisotropic_filtering_level).is_equal(Viewport.ANISOTROPY_16X)
	assert_int(settings.msaa_3d).is_equal(Viewport.MSAA_8X)
	assert_int(settings.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_bool(settings.use_taa).is_true()
	assert_int(settings.supersample_scale).is_equal(2)
	assert_int(settings.resize_filter).is_equal(Image.INTERPOLATE_CUBIC)
	assert_int(settings.anisotropic_filtering).is_equal(Viewport.ANISOTROPY_16X)


func test_apply_material_settings_sets_and_clears_surface_overrides() -> void:
	_dock._load_source(_save_test_scene("material_model.tscn"))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.4, 0.6, 1.0)
	var material_path := _temp_resource_path("preview_override_material.tres")
	assert_int(ResourceSaver.save(material, material_path)).is_equal(OK)

	_dock._material_path_edit.text = material_path
	_dock._apply_material_settings()

	var mesh_instances: Array[MeshInstance3D] = _dock._find_mesh_instances(_dock._model_root)
	assert_array(mesh_instances).has_size(1)
	var mesh_instance: MeshInstance3D = mesh_instances[0]
	var override_material: Material = mesh_instance.get_surface_override_material(0)
	assert_object(override_material).is_not_null()
	assert_bool(override_material is StandardMaterial3D).is_true()
	assert_that((override_material as StandardMaterial3D).albedo_color).is_equal(material.albedo_color)
	assert_str(_dock._status_label.text).is_equal("Applied preview material to loaded model.")

	_dock._clear_material_path()

	assert_object(mesh_instance.get_surface_override_material(0)).is_null()
	assert_str(_dock._status_label.text).is_equal("Cleared preview material override.")


func test_background_controls_switch_transparency_and_color() -> void:
	var background_color := Color(0.25, 0.5, 0.75, 1.0)

	_dock._transparent_background_check.button_pressed = false
	_dock._on_transparent_background_toggled(false)
	_dock._background_color_picker.color = background_color
	_dock._on_background_color_changed(background_color)

	assert_bool(_dock._viewport.transparent_bg).is_false()
	assert_bool(_dock._checkerboard.visible).is_false()
	assert_bool(_dock._background_color_picker.disabled).is_false()
	assert_that(_dock._world_environment.environment.background_color).is_equal(background_color)

	_dock._transparent_background_check.button_pressed = true
	_dock._on_transparent_background_toggled(true)

	assert_bool(_dock._viewport.transparent_bg).is_true()
	assert_bool(_dock._checkerboard.visible).is_true()
	assert_bool(_dock._background_color_picker.disabled).is_true()


func test_projection_selection_syncs_camera_and_editable_controls() -> void:
	_dock._camera_projection_option.select(1)
	_dock._on_projection_selected(1)

	assert_int(_dock._camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_bool(ControlFactory.is_numeric_read_only(_dock._camera_orthographic_size_spin)).is_false()
	assert_bool(ControlFactory.is_numeric_read_only(_dock._camera_fov_spin)).is_true()

	_dock._camera_projection_option.select(0)
	_dock._on_projection_selected(0)

	assert_int(_dock._camera.projection).is_equal(Camera3D.PROJECTION_PERSPECTIVE)
	assert_bool(ControlFactory.is_numeric_read_only(_dock._camera_orthographic_size_spin)).is_true()
	assert_bool(ControlFactory.is_numeric_read_only(_dock._camera_fov_spin)).is_false()


func test_object_transform_controls_move_object_root_without_moving_camera() -> void:
	var camera_position: Vector3 = _dock._camera.position
	var camera_rotation: Vector3 = _dock._camera.rotation_degrees
	var object_position := Vector3(1.25, -0.5, 2.0)
	var object_rotation := Vector3(10.0, 35.0, -15.0)

	_set_vector3_spin_values(_dock._object_position_controls, object_position)
	_set_vector3_spin_values(_dock._object_rotation_controls, object_rotation)
	_dock._on_object_control_changed(0.0)

	assert_vector(_dock._object_root.position).is_equal_approx(object_position, VECTOR_EPSILON)
	assert_vector(_dock._object_root.rotation_degrees).is_equal_approx(object_rotation, VECTOR_EPSILON)
	assert_vector(_dock._camera.position).is_equal(camera_position)
	assert_vector(_dock._camera.rotation_degrees).is_equal(camera_rotation)


func test_camera_lens_controls_keep_camera_pose_fixed() -> void:
	_dock._camera.position = Vector3(99.0, 98.0, 97.0)
	_dock._camera.rotation_degrees = Vector3(30.0, 40.0, 50.0)
	_dock._camera_fov_spin.set_value_no_signal(45.0)

	_dock._on_camera_control_changed(45.0)

	assert_float(_dock._camera.fov).is_equal(45.0)
	assert_vector(_dock._camera.position).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_POSITION)
	assert_vector(_dock._camera.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_ROTATION)


func test_profile_save_writes_reusable_json_without_source_or_output_paths() -> void:
	var object_position := Vector3(1.25, -0.5, 2.0)
	var object_rotation := Vector3(10.0, 35.0, -15.0)
	var background_color := Color(0.25, 0.5, 0.75, 1.0)
	_dock._source_path_edit.text = "res://models/book.glb"
	_dock._output_path_edit.text = "res://exports"
	_dock._material_path_edit.text = "res://materials/book.tres"
	_dock._texture_path_edit.text = "res://textures/book.png"
	_set_vector3_spin_values(_dock._object_position_controls, object_position)
	_set_vector3_spin_values(_dock._object_rotation_controls, object_rotation)
	_dock._camera_projection_option.select(1)
	_dock._camera_fov_spin.set_value_no_signal(45.0)
	_dock._camera_orthographic_size_spin.set_value_no_signal(2.5)
	_dock._transparent_background_check.button_pressed = false
	_dock._background_color_picker.color = background_color
	_dock._frame_width_spin.set_value_no_signal(128.0)
	_dock._frame_height_spin.set_value_no_signal(256.0)
	_dock._frame_count_spin.set_value_no_signal(8.0)
	_dock._columns_spin.set_value_no_signal(4.0)
	_dock._frame_spacing_spin.set_value_no_signal(2.0)
	_select_option_by_id(_dock._msaa_option, Viewport.MSAA_8X)
	_select_option_by_id(_dock._screen_space_aa_option, Viewport.SCREEN_SPACE_AA_FXAA)
	_dock._taa_check.button_pressed = true
	_select_option_by_id(_dock._supersample_option, 2)
	_select_option_by_id(_dock._resize_filter_option, Image.INTERPOLATE_CUBIC)
	_select_option_by_id(_dock._anisotropic_filtering_option, Viewport.ANISOTROPY_16X)
	_dock._export_individual_frames_check.button_pressed = true
	_dock._name_pattern_edit.text = "{index}_{model}.png"
	var profile_base_path := _temp_resource_path("book_profile")

	var result: Dictionary = _dock._save_profile(profile_base_path)
	var profile_path: String = _dock._profile_path_edit.text
	var profile: Dictionary = _read_json_file(profile_path)

	assert_bool(result.ok).is_true()
	assert_str(profile_path).ends_with(".json")
	assert_bool(FileAccess.file_exists(profile_path)).is_true()
	assert_str(profile.format).is_equal(SpriteSheetRendererDock.PROFILE_FORMAT)
	assert_int(int(profile.version)).is_equal(SpriteSheetRendererDock.PROFILE_VERSION)
	assert_bool(profile.has("source_path")).is_false()
	assert_bool(profile.has("output_path")).is_false()
	assert_vector(_vector3_from_array(profile.object.position)).is_equal_approx(object_position, VECTOR_EPSILON)
	assert_vector(_vector3_from_array(profile.object.rotation_degrees)).is_equal_approx(object_rotation, VECTOR_EPSILON)
	assert_str(profile.camera.projection).is_equal("orthographic")
	assert_float(float(profile.camera.fov)).is_equal_approx(45.0, 0.001)
	assert_float(float(profile.camera.orthographic_size)).is_equal_approx(2.5, 0.001)
	assert_bool(bool(profile.background.transparent)).is_false()
	assert_that(_color_from_array(profile.background.color)).is_equal(background_color)
	assert_str(profile.animation.name).is_equal("")
	assert_bool(bool(profile.animation.avoid_duplicate_loop_frame)).is_true()
	assert_str(profile.material.material_path).is_equal("res://materials/book.tres")
	assert_str(profile.material.texture_path).is_equal("res://textures/book.png")
	assert_int(int(profile.export.frame_width)).is_equal(128)
	assert_int(int(profile.export.frame_height)).is_equal(256)
	assert_int(int(profile.export.frame_count)).is_equal(8)
	assert_int(int(profile.export.columns)).is_equal(4)
	assert_int(int(profile.export.frame_spacing)).is_equal(2)
	assert_int(int(profile.export.msaa_3d)).is_equal(Viewport.MSAA_8X)
	assert_int(int(profile.export.screen_space_aa)).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_bool(bool(profile.export.use_taa)).is_true()
	assert_int(int(profile.export.supersample_scale)).is_equal(2)
	assert_int(int(profile.export.resize_filter)).is_equal(Image.INTERPOLATE_CUBIC)
	assert_int(int(profile.export.anisotropic_filtering)).is_equal(Viewport.ANISOTROPY_16X)
	assert_bool(bool(profile.export.export_individual_frames)).is_true()
	assert_str(profile.export.name_pattern).is_equal("{index}_{model}.png")


func test_load_profile_applies_controls_and_reuses_them_for_loaded_models() -> void:
	var object_position := Vector3(0.5, 1.0, -0.25)
	var object_rotation := Vector3(0.0, 180.0, 15.0)
	var background_color := Color(0.1, 0.2, 0.3, 1.0)
	var profile_path := _temp_resource_path("loaded_profile.json")
	_write_json_file(profile_path, {
		"object": {
			"position": [object_position.x, object_position.y, object_position.z],
			"rotation": [object_rotation.x, object_rotation.y, object_rotation.z],
		},
		"camera": {
			"projection": "orthographic",
			"fov": 55.0,
			"orthographic_size": 3.25,
		},
		"background": {
			"transparent": false,
			"color": [background_color.r, background_color.g, background_color.b, background_color.a],
		},
		"export": {
			"frame_width": 320,
			"frame_height": 160,
			"frame_count": 6,
			"columns": 3,
			"frame_spacing": 4,
			"msaa_3d": Viewport.MSAA_8X,
			"screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA,
			"use_taa": true,
			"supersample_scale": 2,
			"resize_filter": Image.INTERPOLATE_CUBIC,
			"anisotropic_filtering": Viewport.ANISOTROPY_16X,
			"export_individual_frames": true,
			"name_pattern": "{model}_{index}.png",
		},
	})

	var result: Dictionary = _dock._load_profile(profile_path)

	assert_bool(result.ok).is_true()
	assert_str(_dock._status_label.text).is_equal("Loaded profile \"loaded_profile.json\".")
	assert_vector(_dock._object_root.position).is_equal_approx(object_position, VECTOR_EPSILON)
	assert_vector(_dock._object_root.rotation_degrees).is_equal_approx(object_rotation, VECTOR_EPSILON)
	assert_int(_dock._camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_bool(ControlFactory.is_numeric_read_only(_dock._camera_orthographic_size_spin)).is_false()
	assert_float(_dock._camera.fov).is_equal_approx(55.0, 0.001)
	assert_float(_dock._camera.size).is_equal_approx(3.25, 0.001)
	assert_bool(_dock._viewport.transparent_bg).is_false()
	assert_bool(_dock._background_color_picker.disabled).is_false()
	assert_that(_dock._world_environment.environment.background_color).is_equal(background_color)
	assert_vector(_dock._export_frame_overlay.frame_size).is_equal(Vector2i(320, 160))
	assert_int(int(_dock._frame_count_spin.value)).is_equal(6)
	assert_int(int(_dock._columns_spin.value)).is_equal(3)
	assert_int(int(_dock._frame_spacing_spin.value)).is_equal(4)
	assert_int(_dock._get_option_id(_dock._msaa_option, -1)).is_equal(Viewport.MSAA_8X)
	assert_int(_dock._get_option_id(_dock._screen_space_aa_option, -1)).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_bool(_dock._taa_check.button_pressed).is_true()
	assert_int(_dock._get_option_id(_dock._supersample_option, -1)).is_equal(2)
	assert_int(_dock._get_option_id(_dock._resize_filter_option, -1)).is_equal(Image.INTERPOLATE_CUBIC)
	assert_int(_dock._get_option_id(_dock._anisotropic_filtering_option, -1)).is_equal(Viewport.ANISOTROPY_16X)
	assert_int(_dock._viewport.msaa_3d).is_equal(Viewport.MSAA_8X)
	assert_int(_dock._viewport.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_bool(_dock._viewport.use_taa).is_true()
	assert_int(_dock._viewport.anisotropic_filtering_level).is_equal(Viewport.ANISOTROPY_16X)
	assert_bool(_dock._export_individual_frames_check.button_pressed).is_true()
	assert_str(_dock._name_pattern_edit.text).is_equal("{model}_{index}.png")

	_dock._load_source(_save_test_scene("profiled_model.tscn"))

	assert_str(_dock._status_label.text).is_equal("Loaded \"profiled_model.tscn\".")
	assert_vector(_dock._object_root.position).is_equal_approx(object_position, VECTOR_EPSILON)
	assert_vector(_dock._object_root.rotation_degrees).is_equal_approx(object_rotation, VECTOR_EPSILON)
	assert_int(_dock._camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_float(_dock._camera.size).is_equal_approx(3.25, 0.001)
	assert_vector(_dock._export_frame_overlay.frame_size).is_equal(Vector2i(320, 160))


func test_load_profile_reports_invalid_json() -> void:
	var profile_path := _temp_resource_path("invalid_profile.json")
	_write_text_file(profile_path, "{")

	var result: Dictionary = _dock._load_profile(profile_path)

	assert_bool(result.ok).is_false()
	assert_str(_dock._status_label.text).contains("Profile JSON is invalid")


func test_load_profile_accepts_minimal_position_rotation_definition() -> void:
	var object_position := Vector3(2.0, 3.0, 4.0)
	var object_rotation := Vector3(15.0, 30.0, 45.0)
	var profile_path := _temp_resource_path("minimal_profile.json")
	_write_json_file(profile_path, {
		"Pos": [object_position.x, object_position.y, object_position.z],
		"Rotation": [object_rotation.x, object_rotation.y, object_rotation.z],
	})

	var result: Dictionary = _dock._load_profile(profile_path)

	assert_bool(result.ok).is_true()
	assert_vector(_dock._object_root.position).is_equal_approx(object_position, VECTOR_EPSILON)
	assert_vector(_dock._object_root.rotation_degrees).is_equal_approx(object_rotation, VECTOR_EPSILON)


func test_load_profile_applies_animation_selection_after_source_loads() -> void:
	var profile_path := _temp_resource_path("animation_profile.json")
	_write_json_file(profile_path, {
		"animation": {
			"name": "Jump",
			"avoid_duplicate_loop_frame": false,
		},
		"export": {
			"frame_count": 4,
		},
	})

	var result: Dictionary = _dock._load_profile(profile_path)

	assert_bool(result.ok).is_true()
	assert_bool(_dock._avoid_duplicate_loop_frame_check.button_pressed).is_false()

	_dock._load_source(_save_test_animated_scene("profile_animation_model.tscn", "Jump", 2.0, Animation.LOOP_LINEAR))

	assert_str(_dock._get_selected_animation_name()).is_equal("Jump")
	assert_bool(_dock._avoid_duplicate_loop_frame_check.button_pressed).is_false()
	assert_str(_dock._animation_frame_label.text).is_equal("Frame 0 / 3")


func test_reset_object_restores_object_transform_without_moving_camera() -> void:
	_dock._load_source(_save_test_scene("reset_object_model.tscn"))
	_dock._camera_orthographic_size_spin.set_value_no_signal(9.0)
	_set_vector3_spin_values(_dock._object_position_controls, Vector3(3.0, 4.0, 5.0))
	_set_vector3_spin_values(_dock._object_rotation_controls, Vector3(45.0, 90.0, 15.0))
	_dock._on_object_control_changed(0.0)

	_dock._reset_object()

	assert_vector(_dock._object_root.position).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_POSITION)
	assert_vector(_dock._object_root.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_ROTATION)
	assert_vector(_dock._camera.position).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_POSITION)
	assert_vector(_dock._camera.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_ROTATION)
	assert_float(_dock._camera_orthographic_size_spin.value).is_equal_approx(9.0, 0.01)
	assert_str(_dock._status_label.text).is_equal("Object transform reset.")


func test_frame_model_resets_object_and_updates_framing_size() -> void:
	_dock._load_source(_save_test_scene("frame_model.tscn"))
	_dock._camera_orthographic_size_spin.set_value_no_signal(9.0)
	_set_vector3_spin_values(_dock._object_position_controls, Vector3(3.0, 4.0, 5.0))
	_set_vector3_spin_values(_dock._object_rotation_controls, Vector3(45.0, 90.0, 15.0))
	_dock._on_object_control_changed(0.0)

	_dock._frame_model()

	assert_vector(_dock._object_root.position).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_POSITION)
	assert_vector(_dock._object_root.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_ROTATION)
	assert_float(_dock._camera_orthographic_size_spin.value).is_not_equal(9.0)
	assert_str(_dock._status_label.text).is_equal("Object framed in fixed camera view.")


func test_export_validation_reports_missing_source_and_invalid_output_settings() -> void:
	var output_directory := _temp_resource_directory()
	_dock._output_path_edit.text = output_directory

	var validation: Dictionary = _dock._validate_export_settings()

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).is_equal("Select at least one source model before exporting.")

	_dock._load_source(_save_test_scene("export_validation_model.tscn"))
	_dock._output_path_edit.text = ""
	validation = _dock._validate_export_settings()

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).is_equal("Choose an output folder before exporting.")

	_dock._output_path_edit.text = output_directory.path_join("missing_folder")
	validation = _dock._validate_export_settings()

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).contains("Export folder doesn't exist:")


func test_output_folder_entry_accepts_directory_and_strips_legacy_file_names() -> void:
	var output_directory := _temp_resource_directory()

	_dock._on_output_path_submitted(output_directory)

	assert_str(_dock._output_path_edit.text).is_equal(output_directory)

	_dock._on_output_path_submitted(output_directory.path_join("legacy_name.png"))

	assert_str(_dock._output_path_edit.text).is_equal(output_directory)


func test_exporter_layout_accounts_for_columns_rows_and_spacing() -> void:
	var layout := SpriteSheetExporter.calculate_layout(5, 2, 16, 8, 3)

	assert_int(layout.columns).is_equal(2)
	assert_int(layout.rows).is_equal(3)
	assert_vector(layout.sheet_size).is_equal(Vector2i(35, 30))


func test_exporter_formats_source_output_paths_from_pattern() -> void:
	var output_path := "res://exports"
	var source_path := "res://models/Book Scene.glb"

	var formatted_name := SpriteSheetExporter.format_output_name("{output}_{index}_{model}.png", source_path, 1, 12, output_path)
	var source_output_path := SpriteSheetExporter.get_source_output_path(output_path, source_path, "{output}_{index}_{model}", 1, 12)

	assert_str(formatted_name).is_equal("exports_002_Book Scene.png")
	assert_str(source_output_path).is_equal("res://exports/exports_002_Book Scene.png")


func test_export_validation_builds_source_output_paths_from_pattern() -> void:
	var first_path := _save_test_scene("source_validate_first.tscn")
	var second_path := _save_test_scene("source_validate_second.tscn")
	var paths := PackedStringArray()
	paths.append(first_path)
	paths.append(second_path)
	_dock._set_source_paths(paths, false)
	_dock._output_path_edit.text = _temp_resource_directory()
	_dock._name_pattern_edit.text = "{index}_{model}"

	var validation: Dictionary = _dock._validate_export_settings()

	assert_bool(validation.ok).is_true()
	var items: Array = validation.items
	assert_array(items).has_size(2)
	assert_str(items[0].output_path).ends_with("001_source_validate_first.png")
	assert_str(items[1].output_path).ends_with("002_source_validate_second.png")
	assert_str(items[0].source_path).is_equal(first_path)
	assert_str(items[1].source_path).is_equal(second_path)


func test_export_validation_rejects_duplicate_generated_names() -> void:
	var first_path := _save_test_scene("duplicate_source_first.tscn")
	var second_path := _save_test_scene("duplicate_source_second.tscn")
	var paths := PackedStringArray()
	paths.append(first_path)
	paths.append(second_path)
	_dock._set_source_paths(paths, false)
	_dock._output_path_edit.text = _temp_resource_directory()
	_dock._name_pattern_edit.text = "same_name.png"

	var validation: Dictionary = _dock._validate_export_settings()

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).contains("duplicate output path")


func test_exporter_assembles_sheet_and_keeps_empty_trailing_cells_transparent() -> void:
	var frames: Array[Image] = [
		_create_color_image(2, 2, Color(1.0, 0.0, 0.0, 1.0)),
		_create_color_image(2, 2, Color(0.0, 1.0, 0.0, 1.0)),
		_create_color_image(2, 2, Color(0.0, 0.0, 1.0, 1.0)),
	]

	var sheet := SpriteSheetExporter.assemble_sprite_sheet(frames, 2, 2, 2, 1)

	assert_vector(sheet.get_size()).is_equal(Vector2i(5, 5))
	assert_that(sheet.get_pixel(0, 0)).is_equal(Color(1.0, 0.0, 0.0, 1.0))
	assert_that(sheet.get_pixel(3, 0)).is_equal(Color(0.0, 1.0, 0.0, 1.0))
	assert_that(sheet.get_pixel(0, 3)).is_equal(Color(0.0, 0.0, 1.0, 1.0))
	assert_float(sheet.get_pixel(3, 3).a).is_equal(0.0)


func test_exporter_writes_sprite_sheet_and_individual_png_frames() -> void:
	var output_path := _temp_resource_path("static_export.png")
	var frames: Array[Image] = [
		_create_color_image(4, 4, Color(1.0, 0.0, 0.0, 1.0)),
		_create_color_image(4, 4, Color(0.0, 1.0, 0.0, 1.0)),
	]
	var settings := {
		"frame_width": 4,
		"frame_height": 4,
		"frame_count": 2,
		"columns": 2,
		"frame_spacing": 1,
		"output_path": output_path,
		"export_individual_frames": true,
	}

	var export_result := SpriteSheetExporter.export_pngs(frames, settings)
	var frame_paths := SpriteSheetExporter.get_individual_frame_paths(output_path, 2)

	assert_bool(export_result.ok).is_true()
	assert_vector(export_result.sheet_size).is_equal(Vector2i(9, 4))
	assert_bool(FileAccess.file_exists(output_path)).is_true()
	assert_bool(FileAccess.file_exists(frame_paths[0])).is_true()
	assert_bool(FileAccess.file_exists(frame_paths[1])).is_true()
	assert_str(frame_paths[0]).ends_with("_000.png")
	assert_str(frame_paths[1]).ends_with("_001.png")

	var sheet := Image.load_from_file(output_path)
	assert_object(sheet).is_not_null()
	assert_vector(sheet.get_size()).is_equal(Vector2i(9, 4))


func test_dock_single_source_export_writes_sheet_and_repeated_individual_frames_from_capture() -> void:
	_dock._load_source(_save_test_scene("dock_export_model.tscn"))
	_dock._frame_width_spin.set_value_no_signal(16.0)
	_dock._frame_height_spin.set_value_no_signal(16.0)
	_dock._frame_count_spin.set_value_no_signal(2.0)
	_dock._columns_spin.set_value_no_signal(2.0)
	_dock._frame_spacing_spin.set_value_no_signal(2.0)
	_dock._export_individual_frames_check.button_pressed = true
	var output_directory := _temp_resource_directory()
	_dock._output_path_edit.text = output_directory

	var validation: Dictionary = _dock._validate_export_settings()
	assert_bool(validation.ok).is_true()

	var export_result: Dictionary = _dock._write_static_export(_create_color_image(16, 16, Color(1.0, 0.0, 0.0, 1.0)), validation.settings)

	var source_output_path: String = validation.settings.output_path
	var frame_paths := SpriteSheetExporter.get_individual_frame_paths(source_output_path, 2)
	assert_bool(export_result.ok).is_true()
	assert_str(export_result.message).contains("Exported 3 PNG files.")
	assert_str(source_output_path).ends_with("dock_export_model.png")
	assert_bool(FileAccess.file_exists(source_output_path)).is_true()
	assert_bool(FileAccess.file_exists(frame_paths[0])).is_true()
	assert_bool(FileAccess.file_exists(frame_paths[1])).is_true()

	var sheet := Image.load_from_file(source_output_path)
	assert_object(sheet).is_not_null()
	assert_vector(sheet.get_size()).is_equal(Vector2i(34, 16))


func test_export_source_reload_preserves_current_object_transform_snapshot() -> void:
	var object_position := Vector3(1.25, -0.5, 2.0)
	var object_rotation := Vector3(10.0, 35.0, -15.0)
	var source_path := _save_test_scene("dock_export_position_model.tscn")
	_dock._load_source(source_path)
	_set_vector3_spin_values(_dock._object_position_controls, object_position)
	_set_vector3_spin_values(_dock._object_rotation_controls, object_rotation)
	_dock._on_object_control_changed(0.0)
	var export_scene_settings: Dictionary = _dock._collect_profile_settings()

	_dock._reset_object_transform()
	var result: Dictionary = _dock._load_source_for_export(source_path, export_scene_settings)

	assert_bool(result.ok).is_true()
	assert_vector(_dock._object_root.position).is_equal_approx(object_position, VECTOR_EPSILON)
	assert_vector(_dock._object_root.rotation_degrees).is_equal_approx(object_rotation, VECTOR_EPSILON)


func _add_mesh_instance(parent: Node, size: Vector3, position: Vector3, is_visible := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.visible = is_visible
	parent.add_child(mesh_instance)
	if parent.owner:
		mesh_instance.owner = parent.owner
	elif parent.get_parent() == null:
		mesh_instance.owner = parent
	return mesh_instance


func _set_vector3_spin_values(controls: Array[Range], value: Vector3) -> void:
	controls[0].set_value_no_signal(value.x)
	controls[1].set_value_no_signal(value.y)
	controls[2].set_value_no_signal(value.z)


func _select_option_by_id(option_button: OptionButton, item_id: int) -> void:
	for index in range(option_button.item_count):
		if option_button.get_item_id(index) == item_id:
			option_button.select(index)
			return

	if option_button.item_count > 0:
		option_button.select(0)


func _find_collapsible_section(title: String, subsection := false) -> FoldableContainer:
	return _find_collapsible_section_in(_dock, title, subsection)


func _find_collapsible_section_in(node: Node, title: String, subsection: bool) -> FoldableContainer:
	if node is FoldableContainer and node.has_meta("collapsible_title"):
		if str(node.get_meta("collapsible_title")) == title and bool(node.get_meta("collapsible_subsection")) == subsection:
			return node as FoldableContainer

	for child in node.get_children():
		var found := _find_collapsible_section_in(child, title, subsection)
		if found != null:
			return found

	return null


func _get_foldable_body(section: FoldableContainer) -> Control:
	return section.get_child(0) as Control


func _source_row_button(index: int) -> Button:
	var add_bar: Node = _dock._source_path_edit.get_parent()
	return add_bar.get_child(index) as Button


func _get_axis_label(control: Range) -> String:
	if control.has_method("get_label"):
		return str(control.call("get_label"))

	var parent := control.get_parent()
	if parent is HBoxContainer and parent.get_child_count() > 0:
		var label := parent.get_child(0) as Label
		if label != null:
			return label.text

	return ""


func _save_test_scene(file_name: String) -> String:
	var root := Node3D.new()
	root.name = "TestModel"
	_add_mesh_instance(root, Vector3(2.0, 3.0, 4.0), Vector3.ZERO)

	var packed_scene := PackedScene.new()
	assert_int(packed_scene.pack(root)).is_equal(OK)
	var scene_path := _temp_resource_path(file_name)
	assert_int(ResourceSaver.save(packed_scene, scene_path)).is_equal(OK)
	root.free()
	return scene_path


func _save_test_animated_scene(file_name: String, animation_name: String, animation_length: float, loop_mode: int) -> String:
	var root := Node3D.new()
	root.name = "AnimatedTestModel"
	_add_mesh_instance(root, Vector3(2.0, 3.0, 4.0), Vector3.ZERO)

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	root.add_child(animation_player)
	animation_player.owner = root

	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = animation_length
	animation.loop_mode = loop_mode as Animation.LoopMode
	library.add_animation(animation_name, animation)
	animation_player.add_animation_library("", library)

	var packed_scene := PackedScene.new()
	assert_int(packed_scene.pack(root)).is_equal(OK)
	var scene_path := _temp_resource_path(file_name)
	assert_int(ResourceSaver.save(packed_scene, scene_path)).is_equal(OK)
	root.free()
	return scene_path


func _temp_resource_directory() -> String:
	return create_temp_dir("blender_sprite_sheet")


func _temp_resource_path(file_name: String) -> String:
	return _temp_resource_directory().path_join(file_name)


func _write_json_file(path: String, data: Dictionary) -> void:
	_write_text_file(path, JSON.stringify(data, "\t"))


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(text)
	file.flush()
	file.close()


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	return json.data


func _vector3_from_array(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _color_from_array(values: Array) -> Color:
	return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _create_color_image(width: int, height: int, color: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image
