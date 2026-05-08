@tool
extends EditorContextMenuPlugin

const ProfileStore := preload("res://addons/blender_sprite_sheet/sprite_sheet_profile_store.gd")

var _dock: Control


func setup(dock: Control) -> void:
	_dock = dock


func _popup_menu(paths: PackedStringArray) -> void:
	var config_path := _get_runnable_config_path(paths)
	if config_path.is_empty():
		return

	add_context_menu_item("Run Fake3D With This Config", _run_fake3d)


func _run_fake3d(paths: Array) -> void:
	if not is_instance_valid(_dock) or not _dock.has_method("run_config"):
		return

	var config_path := _get_runnable_config_path(PackedStringArray(paths))
	if config_path.is_empty():
		return

	_dock.run_config(config_path)


func _get_runnable_config_path(paths: PackedStringArray) -> String:
	if paths.size() != 1:
		return ""

	var path := paths[0].strip_edges()
	if not ProfileStore.is_runnable_config_path(path):
		return ""

	return path
