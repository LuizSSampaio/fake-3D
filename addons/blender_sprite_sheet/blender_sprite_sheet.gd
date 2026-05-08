@tool
extends EditorPlugin

const SpriteSheetRendererDock := preload("res://addons/blender_sprite_sheet/sprite_sheet_renderer_dock.gd")
const SpriteSheetContextMenu := preload("res://addons/blender_sprite_sheet/sprite_sheet_context_menu.gd")

var _dock: Control
var _context_menu: EditorContextMenuPlugin


func _enter_tree() -> void:
	_dock = SpriteSheetRendererDock.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_context_menu = SpriteSheetContextMenu.new()
	_context_menu.setup(_dock)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _context_menu)


func _exit_tree() -> void:
	if _context_menu:
		remove_context_menu_plugin(_context_menu)
		_context_menu = null

	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
