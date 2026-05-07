@tool
extends RefCounted


static func build(viewport: SubViewport) -> Dictionary:
	var scene_root := Node3D.new()
	scene_root.name = "PreviewScene"
	viewport.add_child(scene_root)

	var object_root := Node3D.new()
	object_root.name = "ObjectRoot"
	scene_root.add_child(object_root)

	var model_root := Node3D.new()
	model_root.name = "ModelRoot"
	object_root.add_child(model_root)

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.current = true
	camera.near = 0.001
	camera.far = 10000.0
	scene_root.add_child(camera)

	_add_light(scene_root, "KeyLight", 2.0, Vector3(-45.0, -30.0, 0.0))
	_add_light(scene_root, "FillLight", 0.7, Vector3(-20.0, 120.0, 0.0))

	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	world_environment.environment.background_mode = Environment.BG_COLOR
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment.ambient_light_color = Color.WHITE
	world_environment.environment.ambient_light_energy = 0.35
	scene_root.add_child(world_environment)

	return {
		"scene_root": scene_root,
		"object_root": object_root,
		"model_root": model_root,
		"camera": camera,
		"world_environment": world_environment,
	}


static func _add_light(parent: Node3D, light_name: String, energy: float, rotation_degrees: Vector3) -> void:
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.light_energy = energy
	light.rotation_degrees = rotation_degrees
	parent.add_child(light)
