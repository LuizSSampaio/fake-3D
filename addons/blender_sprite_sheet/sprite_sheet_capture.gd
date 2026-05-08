@tool
extends RefCounted

const RenderOptions := preload("res://addons/blender_sprite_sheet/sprite_sheet_render_options.gd")
const AnimationUtils := preload("res://addons/blender_sprite_sheet/sprite_sheet_animation_utils.gd")


static func capture_scene(scene_root: Node3D, frame_size: Vector2i, transparent_background: bool, render_settings := {}) -> Dictionary:
	if scene_root == null:
		return _failure("Preview scene is not available for capture.")

	if frame_size.x <= 0 or frame_size.y <= 0:
		return _failure("Export frame size must be greater than zero.")

	var normalized_render_settings := RenderOptions.normalize(render_settings)
	var capture_validation := RenderOptions.validate_capture_size(frame_size, normalized_render_settings)
	if not capture_validation.ok:
		return capture_validation

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return _failure("Scene tree is not available for capture.")

	var viewport := SubViewport.new()
	viewport.size = capture_validation.capture_size
	viewport.own_world_3d = true
	viewport.transparent_bg = transparent_background
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	RenderOptions.apply_to_viewport(viewport, normalized_render_settings)
	tree.root.add_child(viewport)

	var captured_scene := scene_root.duplicate()
	viewport.add_child(captured_scene)

	for _index in range(RenderOptions.get_capture_frame_count(normalized_render_settings)):
		await tree.process_frame

	var texture := viewport.get_texture()
	if texture == null or not texture.get_rid().is_valid():
		viewport.queue_free()
		return _failure("Preview viewport did not produce a render texture.")

	var image := texture.get_image()
	viewport.queue_free()

	if image == null or image.is_empty():
		return _failure("Preview viewport capture produced an empty image.")

	if image.get_size() != frame_size:
		image.resize(frame_size.x, frame_size.y, RenderOptions.get_resize_filter(normalized_render_settings))

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	return {
		"ok": true,
		"image": image,
	}


static func capture_animation_frames(
	scene_root: Node3D,
	frame_size: Vector2i,
	transparent_background: bool,
	animation_player_path: NodePath,
	animation_name: String,
	frame_count: int,
	avoid_duplicate_loop_frame: bool,
	render_settings := {}
) -> Dictionary:
	if scene_root == null:
		return _failure("Preview scene is not available for capture.")

	if frame_size.x <= 0 or frame_size.y <= 0:
		return _failure("Export frame size must be greater than zero.")

	if frame_count <= 0:
		return _failure("Frame count must be greater than zero.")

	var normalized_render_settings := RenderOptions.normalize(render_settings)
	var capture_validation := RenderOptions.validate_capture_size(frame_size, normalized_render_settings)
	if not capture_validation.ok:
		return capture_validation

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return _failure("Scene tree is not available for capture.")

	var viewport := SubViewport.new()
	viewport.size = capture_validation.capture_size
	viewport.own_world_3d = true
	viewport.transparent_bg = transparent_background
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	RenderOptions.apply_to_viewport(viewport, normalized_render_settings)
	tree.root.add_child(viewport)

	var captured_scene := scene_root.duplicate()
	viewport.add_child(captured_scene)

	var animation_player := captured_scene.get_node_or_null(animation_player_path) as AnimationPlayer
	if animation_player == null:
		viewport.queue_free()
		return _failure("Animation player is not available for export.")

	if animation_name.is_empty() or not animation_player.has_animation(animation_name):
		viewport.queue_free()
		return _failure("Requested animation doesn't exist: \"%s\"." % animation_name)

	var sample_plan := build_animation_sample_plan(animation_player, animation_name, frame_count, avoid_duplicate_loop_frame)
	if not sample_plan.ok:
		viewport.queue_free()
		return sample_plan

	var sample_times: PackedFloat32Array = sample_plan.sample_times
	var frames: Array[Image] = []
	for sample_time in sample_times:
		var seek_result := AnimationUtils.seek_player(animation_player, animation_name, sample_time)
		if not seek_result.ok:
			viewport.queue_free()
			return seek_result

		for _index in range(RenderOptions.get_capture_frame_count(normalized_render_settings)):
			await tree.process_frame

		var frame_result := _read_viewport_image(viewport, frame_size, normalized_render_settings)
		if not frame_result.ok:
			viewport.queue_free()
			return frame_result

		frames.append(frame_result.image)

	viewport.queue_free()
	return {
		"ok": true,
		"frames": frames,
		"sample_times": sample_times,
	}


static func build_animation_sample_plan(
	animation_player: AnimationPlayer,
	animation_name: String,
	frame_count: int,
	avoid_duplicate_loop_frame: bool
) -> Dictionary:
	if animation_player == null:
		return _failure("Animation player is not available for export.")

	if animation_name.is_empty() or not animation_player.has_animation(animation_name):
		return _failure("Requested animation doesn't exist: \"%s\"." % animation_name)

	if frame_count <= 0:
		return _failure("Frame count must be greater than zero.")

	var avoid_endpoint := avoid_duplicate_loop_frame and AnimationUtils.animation_loops(animation_player, animation_name)
	return {
		"ok": true,
		"sample_times": AnimationUtils.calculate_sample_times(
			AnimationUtils.get_animation_length(animation_player, animation_name),
			frame_count,
			avoid_endpoint
		),
	}


static func _read_viewport_image(viewport: SubViewport, frame_size: Vector2i, render_settings: Dictionary) -> Dictionary:
	var texture := viewport.get_texture()
	if texture == null or not texture.get_rid().is_valid():
		return _failure("Preview viewport did not produce a render texture.")

	var image := texture.get_image()
	if image == null or image.is_empty():
		return _failure("Preview viewport capture produced an empty image.")

	if image.get_size() != frame_size:
		image.resize(frame_size.x, frame_size.y, RenderOptions.get_resize_filter(render_settings))

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	return {
		"ok": true,
		"image": image,
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
