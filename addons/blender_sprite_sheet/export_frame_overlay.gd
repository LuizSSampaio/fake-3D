@tool
extends Control

const DEFAULT_FRAME_SIZE := Vector2i(256, 256)
const MASK_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const BORDER_WIDTH := 1.0

var frame_size := DEFAULT_FRAME_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_frame_size(value: Vector2i) -> void:
	frame_size = Vector2i(max(value.x, 1), max(value.y, 1))
	queue_redraw()


func get_export_rect() -> Rect2:
	return calculate_export_rect(get_size(), frame_size)


static func calculate_export_rect(container_size: Vector2, export_size: Vector2i) -> Rect2:
	if container_size.x <= 0.0 or container_size.y <= 0.0 or export_size.x <= 0 or export_size.y <= 0:
		return Rect2()

	var export_aspect := float(export_size.x) / float(export_size.y)
	var container_aspect := container_size.x / container_size.y
	var rect_size := Vector2.ZERO
	if container_aspect > export_aspect:
		rect_size = Vector2(container_size.y * export_aspect, container_size.y)
	else:
		rect_size = Vector2(container_size.x, container_size.x / export_aspect)

	return Rect2((container_size - rect_size) * 0.5, rect_size)


func _draw() -> void:
	var preview_rect := Rect2(Vector2.ZERO, get_size())
	var export_rect := get_export_rect()
	if export_rect.size.x <= 0.0 or export_rect.size.y <= 0.0:
		return

	_draw_mask_rect(Rect2(preview_rect.position, Vector2(preview_rect.size.x, export_rect.position.y)))
	_draw_mask_rect(Rect2(Vector2(preview_rect.position.x, export_rect.end.y), Vector2(preview_rect.size.x, preview_rect.end.y - export_rect.end.y)))
	_draw_mask_rect(Rect2(Vector2(preview_rect.position.x, export_rect.position.y), Vector2(export_rect.position.x, export_rect.size.y)))
	_draw_mask_rect(Rect2(Vector2(export_rect.end.x, export_rect.position.y), Vector2(preview_rect.end.x - export_rect.end.x, export_rect.size.y)))
	draw_rect(export_rect, BORDER_COLOR, false, BORDER_WIDTH)


func _draw_mask_rect(rect: Rect2) -> void:
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		draw_rect(rect, MASK_COLOR)
