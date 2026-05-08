@tool
extends RefCounted

const SUPPORTED_EXTENSIONS := ["tscn", "scn", "glb", "gltf", "obj", "fbx", "blend"]
const UNSUPPORTED_SOURCE_MESSAGE := "Unsupported source type. Choose .tscn, .scn, .glb, .gltf, .obj, .fbx, or .blend."


static func load_source(path: String) -> Dictionary:
	var source_path := path.strip_edges()
	var resource_result := load_source_resource(source_path)
	if not resource_result.ok:
		return resource_result

	var instance := instantiate_resource(resource_result.resource)
	if instance == null:
		return _failure("Source asset isn't 3D content Godot can instantiate: \"%s\" (%s)." % [
			source_path,
			resource_result.resource.get_class(),
		])

	return {
		"ok": true,
		"instance": instance,
		"path": source_path,
	}


static func load_source_resource(source_path: String) -> Dictionary:
	if source_path.is_empty():
		return _failure("Choose a source asset before reloading.")

	if not is_supported_source_path(source_path):
		return _failure(UNSUPPORTED_SOURCE_MESSAGE)

	if not ResourceLoader.exists(source_path):
		return _failure("Source asset doesn't exist: \"%s\"." % source_path)

	var resource := ResourceLoader.load(source_path)
	if resource == null:
		return _failure("Godot couldn't import or load the source asset: \"%s\". Check the import log and reimport the file." % source_path)

	var validation_instance := instantiate_resource(resource)
	if validation_instance == null:
		return _failure("Source asset isn't 3D content Godot can instantiate: \"%s\" (%s)." % [
			source_path,
			resource.get_class(),
		])
	validation_instance.free()

	return {
		"ok": true,
		"resource": resource,
		"path": source_path,
	}


static func instantiate_resource(resource: Resource) -> Node:
	if resource is PackedScene:
		return (resource as PackedScene).instantiate()

	if resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource
		mesh_instance.name = resource.resource_path.get_file().get_basename()
		return mesh_instance

	return null


static func is_supported_source_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return SUPPORTED_EXTENSIONS.has(extension)


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
