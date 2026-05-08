@tool
extends RefCounted

const ModelUtils := preload("res://addons/blender_sprite_sheet/sprite_sheet_model_utils.gd")


static func apply_to_model(root: Node, material_path: String, texture_path: String) -> Dictionary:
	var clean_material_path := material_path.strip_edges()
	var clean_texture_path := texture_path.strip_edges()
	if clean_material_path.is_empty() and clean_texture_path.is_empty():
		set_mesh_surface_override(root, null)
		return _success("Cleared preview material override.")

	var material: Material = null
	if not clean_material_path.is_empty():
		var material_result := _load_material(clean_material_path)
		if not material_result.ok:
			return material_result
		material = material_result.material

	var texture: Texture2D = null
	if not clean_texture_path.is_empty():
		var texture_result := _load_texture(clean_texture_path)
		if not texture_result.ok:
			return texture_result
		texture = texture_result.texture

	if material == null:
		material = StandardMaterial3D.new()

	if texture != null:
		if has_object_property(material, "albedo_texture"):
			material.set("albedo_texture", texture)
		else:
			return _failure("Selected material doesn't support an albedo texture property.")

	set_mesh_surface_override(root, material)
	return _success("Applied preview material to loaded model.")


static func set_mesh_surface_override(root: Node, material: Material) -> void:
	for mesh_instance in ModelUtils.find_mesh_instances(root):
		if mesh_instance.mesh == null:
			continue

		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface_index, material)


static func has_object_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if property_info["name"] == property_name:
			return true
	return false


static func _load_material(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return _failure("Material resource doesn't exist: \"%s\"." % path)

	var material_resource := ResourceLoader.load(path)
	if not (material_resource is Material):
		return _failure("Selected resource isn't a Material: \"%s\"." % path)

	return {
		"ok": true,
		"material": (material_resource as Material).duplicate(true),
	}


static func _load_texture(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return _failure("Texture resource doesn't exist: \"%s\"." % path)

	var texture_resource := ResourceLoader.load(path)
	if not (texture_resource is Texture2D):
		return _failure("Selected resource isn't a Texture2D: \"%s\"." % path)

	return {
		"ok": true,
		"texture": texture_resource as Texture2D,
	}


static func _success(message: String) -> Dictionary:
	return {
		"ok": true,
		"message": message,
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
