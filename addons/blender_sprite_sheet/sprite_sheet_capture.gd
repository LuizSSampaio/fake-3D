@tool
extends RefCounted


static func capture_scene(scene_root: Node3D, frame_size: Vector2i, transparent_background: bool) -> Dictionary:
	if scene_root == null:
		return _failure("Preview scene is not available for capture.")

	if frame_size.x <= 0 or frame_size.y <= 0:
		return _failure("Export frame size must be greater than zero.")

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return _failure("Scene tree is not available for capture.")

	var viewport := SubViewport.new()
	viewport.size = frame_size
	viewport.own_world_3d = true
	viewport.transparent_bg = transparent_background
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)

	var captured_scene := scene_root.duplicate()
	viewport.add_child(captured_scene)

	await tree.process_frame
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
		image.resize(frame_size.x, frame_size.y, Image.INTERPOLATE_LANCZOS)

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
