@tool
extends Control

const CHECKER_LIGHT := Color(0.48, 0.48, 0.48)
const CHECKER_DARK := Color(0.36, 0.36, 0.36)

var tile_size := 16


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect_size := get_size()
	for y in range(0, int(ceil(rect_size.y)), tile_size):
		for x in range(0, int(ceil(rect_size.x)), tile_size):
			var checker_index := int(x / tile_size) + int(y / tile_size)
			var color := CHECKER_LIGHT if checker_index % 2 == 0 else CHECKER_DARK
			var tile_rect := Rect2(Vector2(x, y), Vector2(tile_size, tile_size)).intersection(Rect2(Vector2.ZERO, rect_size))
			draw_rect(tile_rect, color)
