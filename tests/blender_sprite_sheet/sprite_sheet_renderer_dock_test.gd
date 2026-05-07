class_name SpriteSheetRendererDockTest
extends GdUnitTestSuite

const SpriteSheetRendererDock := preload("res://addons/blender_sprite_sheet/sprite_sheet_renderer_dock.gd")
const SpriteSheetExporter := preload("res://addons/blender_sprite_sheet/sprite_sheet_exporter.gd")
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
	assert_bool(_dock._checkerboard.visible).is_true()
	assert_bool(_dock._background_color_picker.disabled).is_true()
	assert_object(_dock._object_root).is_not_null()
	assert_vector(_dock._object_root.position).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_POSITION)
	assert_vector(_dock._object_root.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_OBJECT_ROTATION)
	assert_vector(_dock._camera.position).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_POSITION)
	assert_vector(_dock._camera.rotation_degrees).is_equal(SpriteSheetRendererDock.DEFAULT_CAMERA_ROTATION)
	assert_int(_dock._camera.projection).is_equal(Camera3D.PROJECTION_PERSPECTIVE)
	assert_bool(_dock._camera_fov_spin.editable).is_true()
	assert_bool(_dock._camera_orthographic_size_spin.editable).is_false()


func test_source_path_validation_accepts_supported_extensions_case_insensitively() -> void:
	for extension in SpriteSheetRendererDock.SUPPORTED_EXTENSIONS:
		assert_bool(_dock._is_supported_source_path("res://fixture.%s" % extension.to_upper())).is_true()

	assert_bool(_dock._is_supported_source_path("res://fixture.txt")).is_false()
	assert_bool(_dock._is_supported_source_path("res://fixture.tres")).is_false()


func test_load_source_reports_actionable_status_for_invalid_paths() -> void:
	_dock._load_source("   ")
	assert_str(_dock._status_label.text).is_equal("Choose a source asset before reloading.")

	_dock._load_source("res://missing.txt")
	assert_str(_dock._status_label.text).contains("Unsupported source type")

	_dock._load_source("res://missing_model.glb")
	assert_str(_dock._status_label.text).is_equal("Source asset does not exist: res://missing_model.glb")


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

	assert_str(_dock._status_label.text).is_equal("Loaded load_source_model.tscn")
	assert_object(_dock._loaded_source).is_not_null()
	assert_int(_dock._model_root.get_child_count()).is_equal(1)

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
	assert_str(_dock._export_result_label.text).is_equal("Static PNG export is ready after a source is loaded.")


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
	assert_bool(_dock._camera_orthographic_size_spin.editable).is_true()
	assert_bool(_dock._camera_fov_spin.editable).is_false()

	_dock._camera_projection_option.select(0)
	_dock._on_projection_selected(0)

	assert_int(_dock._camera.projection).is_equal(Camera3D.PROJECTION_PERSPECTIVE)
	assert_bool(_dock._camera_orthographic_size_spin.editable).is_false()
	assert_bool(_dock._camera_fov_spin.editable).is_true()


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
	_dock._output_path_edit.text = _temp_resource_path("missing_source.png")

	var validation: Dictionary = _dock._validate_export_settings()

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).is_equal("Load a source asset before exporting.")

	_dock._load_source(_save_test_scene("export_validation_model.tscn"))
	_dock._output_path_edit.text = ""
	validation = _dock._validate_export_settings()

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).is_equal("Choose an output PNG path before exporting.")

	_dock._output_path_edit.text = _temp_resource_path("export_validation.txt")
	validation = _dock._validate_export_settings()

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).is_equal("Output format must be PNG for static sprite export.")


func test_exporter_layout_accounts_for_columns_rows_and_spacing() -> void:
	var layout := SpriteSheetExporter.calculate_layout(5, 2, 16, 8, 3)

	assert_int(layout.columns).is_equal(2)
	assert_int(layout.rows).is_equal(3)
	assert_vector(layout.sheet_size).is_equal(Vector2i(35, 30))


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


func test_dock_static_export_writes_sheet_and_repeated_individual_frames_from_capture() -> void:
	_dock._load_source(_save_test_scene("dock_export_model.tscn"))
	_dock._frame_width_spin.set_value_no_signal(16.0)
	_dock._frame_height_spin.set_value_no_signal(16.0)
	_dock._frame_count_spin.set_value_no_signal(2.0)
	_dock._columns_spin.set_value_no_signal(2.0)
	_dock._frame_spacing_spin.set_value_no_signal(2.0)
	_dock._export_individual_frames_check.button_pressed = true
	var output_path := _temp_resource_path("dock_static_export.png")
	_dock._output_path_edit.text = output_path

	var validation: Dictionary = _dock._validate_export_settings()
	assert_bool(validation.ok).is_true()

	var export_result: Dictionary = _dock._write_static_export(_create_color_image(16, 16, Color(1.0, 0.0, 0.0, 1.0)), validation.settings)

	var frame_paths := SpriteSheetExporter.get_individual_frame_paths(output_path, 2)
	assert_bool(export_result.ok).is_true()
	assert_str(export_result.message).contains("Exported 3 PNG file(s).")
	assert_bool(FileAccess.file_exists(output_path)).is_true()
	assert_bool(FileAccess.file_exists(frame_paths[0])).is_true()
	assert_bool(FileAccess.file_exists(frame_paths[1])).is_true()

	var sheet := Image.load_from_file(output_path)
	assert_object(sheet).is_not_null()
	assert_vector(sheet.get_size()).is_equal(Vector2i(34, 16))


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


func _set_vector3_spin_values(controls: Array[SpinBox], value: Vector3) -> void:
	controls[0].set_value_no_signal(value.x)
	controls[1].set_value_no_signal(value.y)
	controls[2].set_value_no_signal(value.z)


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


func _temp_resource_path(file_name: String) -> String:
	return create_temp_dir("blender_sprite_sheet").path_join(file_name)


func _create_color_image(width: int, height: int, color: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image
