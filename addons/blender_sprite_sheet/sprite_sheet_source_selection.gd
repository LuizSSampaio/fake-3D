@tool
extends RefCounted


static func normalize_paths(paths: PackedStringArray) -> PackedStringArray:
	var normalized := PackedStringArray()
	var seen := {}
	for path in paths:
		var clean_path := path.strip_edges()
		if clean_path.is_empty() or seen.has(clean_path):
			continue

		seen[clean_path] = true
		normalized.append(clean_path)

	return normalized


static func populate_item_list(source_list: ItemList, source_paths: PackedStringArray) -> void:
	if source_list == null:
		return

	source_list.clear()
	for path in source_paths:
		source_list.add_item(path.get_file())
		var index := source_list.item_count - 1
		source_list.set_item_tooltip(index, path)
		source_list.set_item_metadata(index, path)
