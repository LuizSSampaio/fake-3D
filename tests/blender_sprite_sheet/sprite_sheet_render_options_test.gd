class_name SpriteSheetRenderOptionsTest
extends GdUnitTestSuite

const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")


func test_normalize_accepts_option_keys_and_defaults_unknown_values() -> void:
	var settings := RenderOptions.normalize({
		"msaa_3d": "8x",
		"screen_space_aa": "fxaa",
		"use_taa": true,
		"supersample_scale": "2x",
		"resize_filter": "cubic",
		"anisotropic_filtering": "16x",
	})

	assert_int(settings.msaa_3d).is_equal(Viewport.MSAA_8X)
	assert_int(settings.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_bool(settings.use_taa).is_true()
	assert_int(settings.supersample_scale).is_equal(2)
	assert_int(settings.resize_filter).is_equal(Image.INTERPOLATE_CUBIC)
	assert_int(settings.anisotropic_filtering).is_equal(Viewport.ANISOTROPY_16X)

	var defaults := RenderOptions.normalize({
		"msaa_3d": "invalid",
		"resize_filter": -99,
	})

	assert_int(defaults.msaa_3d).is_equal(RenderOptions.DEFAULT_MSAA_3D)
	assert_int(defaults.resize_filter).is_equal(RenderOptions.DEFAULT_RESIZE_FILTER)


func test_quality_options_include_style_guide_performance_hints() -> void:
	assert_str(RenderOptions.get_msaa_options()[0].label).is_equal("Disabled (Fastest)")
	assert_str(RenderOptions.get_msaa_options().back().label).contains("(Slow)")
	assert_str(RenderOptions.get_screen_space_aa_options()[1].label).is_equal("FXAA (Fast)")
	assert_str(RenderOptions.get_supersample_options().back().label).is_equal("4x (Slowest)")
	assert_str(RenderOptions.get_resize_filter_options().back().label).is_equal("Lanczos (Slowest)")
	assert_str(RenderOptions.get_anisotropic_filtering_options().back().label).is_equal("16x (Slower)")


func test_apply_to_viewport_sets_antialiasing_and_texture_filtering() -> void:
	var viewport: SubViewport = auto_free(SubViewport.new())

	RenderOptions.apply_to_viewport(viewport, {
		"msaa_3d": Viewport.MSAA_8X,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA,
		"use_taa": true,
		"anisotropic_filtering": Viewport.ANISOTROPY_16X,
	})

	assert_int(viewport.msaa_3d).is_equal(Viewport.MSAA_8X)
	assert_int(viewport.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_bool(viewport.use_taa).is_true()
	assert_int(viewport.anisotropic_filtering_level).is_equal(Viewport.ANISOTROPY_16X)


func test_capture_size_uses_supersampling_and_limits_extreme_renders() -> void:
	var capture_size := RenderOptions.get_capture_size(Vector2i(64, 32), {
		"supersample_scale": 4,
	})

	assert_vector(capture_size).is_equal(Vector2i(256, 128))

	var validation := RenderOptions.validate_capture_size(Vector2i(8192, 8192), {
		"supersample_scale": 4,
	})

	assert_bool(validation.ok).is_false()
	assert_str(validation.message).contains("Supersampling would render")


func test_taa_capture_waits_for_extra_accumulation_frames() -> void:
	assert_int(RenderOptions.get_capture_frame_count({"use_taa": false})).is_equal(2)
	assert_int(RenderOptions.get_capture_frame_count({"use_taa": true})).is_equal(8)
