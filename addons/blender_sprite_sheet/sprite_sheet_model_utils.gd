@tool
extends RefCounted


static func calculate_model_bounds(root: Node) -> Dictionary:
	var mesh_instances := find_mesh_instances(root)
	var has_value := false
	var bounds := AABB()

	for mesh_instance in mesh_instances:
		var local_aabb := mesh_instance.get_aabb()
		if local_aabb.size == Vector3.ZERO:
			continue

		var global_aabb := transform_aabb(mesh_instance.global_transform, local_aabb)
		if has_value:
			bounds = bounds.merge(global_aabb)
		else:
			bounds = global_aabb
			has_value = true

	return {
		"has_value": has_value,
		"aabb": bounds,
	}


static func fit_model_to_preview(model_root: Node3D, bounds: AABB, target_size: float) -> void:
	var largest_axis := max(bounds.size.x, max(bounds.size.y, bounds.size.z))
	var preview_scale := 1.0
	if largest_axis > 0.0:
		preview_scale = target_size / largest_axis

	model_root.scale = Vector3.ONE * preview_scale
	model_root.position = -bounds.get_center() * preview_scale


static func find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root == null:
		return result

	for child in root.get_children():
		if child is MeshInstance3D and child.visible:
			result.append(child)
		result.append_array(find_mesh_instances(child))
	return result


static func transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var points := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
	]

	var transformed := AABB(transform * points[0], Vector3.ZERO)
	for index in range(1, points.size()):
		transformed = transformed.expand(transform * points[index])
	return transformed
