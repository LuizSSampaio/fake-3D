@tool
extends RefCounted

const DEFAULT_LIGHTING_PRESET := "studio"
const LIGHTING_PRESETS := {
	"studio": {
		"label": "Studio",
		"ambient_energy": 0.35,
		"lights": {
			"KeyLight": {"energy": 2.0, "rotation_degrees": Vector3(-45.0, -30.0, 0.0)},
			"FillLight": {"energy": 0.7, "rotation_degrees": Vector3(-20.0, 120.0, 0.0)},
		},
	},
	"soft": {
		"label": "Soft",
		"ambient_energy": 0.65,
		"lights": {
			"KeyLight": {"energy": 1.2, "rotation_degrees": Vector3(-50.0, -35.0, 0.0)},
			"FillLight": {"energy": 0.9, "rotation_degrees": Vector3(-25.0, 130.0, 0.0)},
		},
	},
	"dramatic": {
		"label": "Dramatic",
		"ambient_energy": 0.12,
		"lights": {
			"KeyLight": {"energy": 3.0, "rotation_degrees": Vector3(-55.0, -55.0, 0.0)},
			"FillLight": {"energy": 0.15, "rotation_degrees": Vector3(-15.0, 145.0, 0.0)},
		},
	},
	"flat": {
		"label": "Flat",
		"ambient_energy": 1.0,
		"lights": {
			"KeyLight": {"energy": 0.0, "rotation_degrees": Vector3(-45.0, -30.0, 0.0)},
			"FillLight": {"energy": 0.0, "rotation_degrees": Vector3(-20.0, 120.0, 0.0)},
		},
	},
}


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
	scene_root.add_child(world_environment)
	apply_lighting_preset(scene_root, DEFAULT_LIGHTING_PRESET)

	return {
		"scene_root": scene_root,
		"object_root": object_root,
		"model_root": model_root,
		"camera": camera,
		"world_environment": world_environment,
	}


static func get_lighting_preset_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for key in ["studio", "soft", "dramatic", "flat"]:
		options.append({
			"label": LIGHTING_PRESETS[key]["label"],
			"key": key,
			"value": key,
		})
	return options


static func normalize_lighting_preset(value: Variant) -> String:
	var text_value := str(value).strip_edges().to_lower()
	for key in LIGHTING_PRESETS.keys():
		if text_value == key or text_value == str(LIGHTING_PRESETS[key]["label"]).to_lower():
			return key

	return DEFAULT_LIGHTING_PRESET


static func apply_lighting_preset(scene_root: Node, preset: Variant) -> String:
	if scene_root == null:
		return DEFAULT_LIGHTING_PRESET

	var preset_key := normalize_lighting_preset(preset)
	var preset_data: Dictionary = LIGHTING_PRESETS[preset_key]
	var light_settings: Dictionary = preset_data["lights"]
	for light_name in light_settings.keys():
		var light := scene_root.get_node_or_null(NodePath(light_name)) as DirectionalLight3D
		if light == null:
			continue

		var settings: Dictionary = light_settings[light_name]
		light.light_energy = float(settings["energy"])
		light.rotation_degrees = settings["rotation_degrees"]

	var world_environment := _find_world_environment(scene_root)
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ambient_light_energy = float(preset_data["ambient_energy"])

	return preset_key


static func _add_light(parent: Node3D, light_name: String, energy: float, rotation_degrees: Vector3) -> void:
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.light_energy = energy
	light.rotation_degrees = rotation_degrees
	parent.add_child(light)


static func _find_world_environment(root: Node) -> WorldEnvironment:
	if root is WorldEnvironment:
		return root as WorldEnvironment

	for child in root.get_children():
		var found := _find_world_environment(child)
		if found != null:
			return found

	return null
