@tool
extends EditorPlugin

const SpriteSheetRendererDock := preload("res://addons/blender_sprite_sheet/sprite_sheet_renderer_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = SpriteSheetRendererDock.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
