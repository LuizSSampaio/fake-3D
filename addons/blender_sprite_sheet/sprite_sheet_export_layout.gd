@tool
extends RefCounted


static func calculate_layout(frame_count: int, columns: int, frame_width: int, frame_height: int, frame_spacing: int) -> Dictionary:
	var safe_columns := max(columns, 1)
	var rows := int(ceil(frame_count / float(safe_columns)))
	var spacing := max(frame_spacing, 0)
	var sheet_width: int = safe_columns * frame_width + max(safe_columns - 1, 0) * spacing
	var sheet_height: int = rows * frame_height + max(rows - 1, 0) * spacing
	return {
		"columns": safe_columns,
		"rows": rows,
		"sheet_size": Vector2i(sheet_width, sheet_height),
	}


static func build_repeated_frames(frame: Image, frame_count: int, frame_width: int, frame_height: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Array[Image]:
	var frames: Array[Image] = []
	for _index in range(frame_count):
		frames.append(_copy_frame_at_size(frame, frame_width, frame_height, resize_filter))
	return frames


static func assemble_sprite_sheet(frames: Array[Image], frame_width: int, frame_height: int, columns: int, frame_spacing: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Image:
	var layout := calculate_layout(frames.size(), columns, frame_width, frame_height, frame_spacing)
	var sheet_size: Vector2i = layout["sheet_size"]
	var sheet := Image.create(sheet_size.x, sheet_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))

	for frame_index in range(frames.size()):
		var column: int = frame_index % int(layout["columns"])
		var row := int(frame_index / int(layout["columns"]))
		var destination := Vector2i(
			column * (frame_width + max(frame_spacing, 0)),
			row * (frame_height + max(frame_spacing, 0))
		)
		var frame := _copy_frame_at_size(frames[frame_index], frame_width, frame_height, resize_filter)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, Vector2i(frame_width, frame_height)), destination)

	return sheet


static func _copy_frame_at_size(frame: Image, frame_width: int, frame_height: int, resize_filter := Image.INTERPOLATE_LANCZOS) -> Image:
	var copy := frame.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)

	if copy.get_width() != frame_width or copy.get_height() != frame_height:
		copy.resize(frame_width, frame_height, resize_filter)

	return copy
