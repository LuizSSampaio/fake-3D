@tool
extends RefCounted

const ROW_LABEL_WIDTH := 86.0
const SECTION_FONT_SIZE := 16
const AXIS_LABELS := ["x", "y", "z"]
const AXIS_THEME_COLORS := ["property_color_x", "property_color_y", "property_color_z"]
const AXIS_FALLBACK_COLORS := [
	Color(0.94, 0.38, 0.36),
	Color(0.47, 0.75, 0.35),
	Color(0.38, 0.56, 0.95),
]


static func create_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	return label


static func create_row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = ROW_LABEL_WIDTH
	return label


static func create_spin_box(min_value: float, max_value: float, step: float, value: float, label := "") -> Range:
	var spin := _create_numeric_control(label)
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


static func create_option_button(options: Array[Dictionary], selected_id: int) -> OptionButton:
	var option_button := OptionButton.new()
	for option in options:
		option_button.add_item(str(option["label"]), int(option["value"]))

	select_option_by_id(option_button, selected_id)
	return option_button


static func select_option_by_id(option_button: OptionButton, item_id: int) -> void:
	if option_button == null:
		return

	for index in range(option_button.item_count):
		if option_button.get_item_id(index) == item_id:
			option_button.select(index)
			return

	if option_button.item_count > 0:
		option_button.select(0)


static func get_selected_option_id(option_button: OptionButton, fallback: int) -> int:
	if option_button == null or option_button.selected < 0:
		return fallback

	return option_button.get_item_id(option_button.selected)


static func create_vector3_row(
	parent: BoxContainer,
	label_text: String,
	initial_value: Vector3,
	min_value: float,
	max_value: float,
	step: float,
	callback: Callable
) -> Array[Range]:
	var row := HBoxContainer.new()
	row.add_child(create_row_label(label_text))

	var controls: Array[Range] = []
	var values := [initial_value.x, initial_value.y, initial_value.z]
	for axis_index in range(AXIS_LABELS.size()):
		var axis := str(AXIS_LABELS[axis_index])
		var spin := create_spin_box(min_value, max_value, step, values[axis_index], axis)
		spin.tooltip_text = "%s %s" % [label_text, axis.to_upper()]
		spin.value_changed.connect(callback)
		_add_vector_control(row, spin, axis_index)
		controls.append(spin)

	parent.add_child(row)
	return controls


static func add_labeled_control(parent: BoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_child(create_row_label(label_text))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


static func set_numeric_read_only(control: Range, read_only: bool) -> void:
	if control == null:
		return

	if control.has_method("set_read_only"):
		control.call("set_read_only", read_only)
	elif control is SpinBox:
		(control as SpinBox).editable = not read_only


static func is_numeric_read_only(control: Range) -> bool:
	if control == null:
		return true

	if control.has_method("is_read_only"):
		return bool(control.call("is_read_only"))
	if control is SpinBox:
		return not (control as SpinBox).editable

	return false


static func _create_numeric_control(label := "") -> Range:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorSpinSlider") and ClassDB.can_instantiate("EditorSpinSlider"):
		var editor_spin := ClassDB.instantiate("EditorSpinSlider") as Range
		if editor_spin != null:
			if not label.is_empty() and editor_spin.has_method("set_label"):
				editor_spin.call("set_label", label)
			if editor_spin.has_method("set_flat"):
				editor_spin.call("set_flat", true)
			return editor_spin

	return SpinBox.new()


static func _add_vector_control(parent: BoxContainer, spin: Range, axis_index: int) -> void:
	if spin.has_method("set_label"):
		_apply_axis_color(spin, axis_index)
		parent.add_child(spin)
		return

	var axis_box := HBoxContainer.new()
	axis_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var axis_label := Label.new()
	axis_label.text = str(AXIS_LABELS[axis_index])
	axis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	axis_label.custom_minimum_size.x = 12.0
	axis_label.add_theme_color_override("font_color", _get_axis_color(axis_label, axis_index))
	axis_box.add_child(axis_label)
	axis_box.add_child(spin)
	parent.add_child(axis_box)


static func _apply_axis_color(control: Control, axis_index: int) -> void:
	control.add_theme_color_override("label_color", _get_axis_color(control, axis_index))


static func _get_axis_color(control: Control, axis_index: int) -> Color:
	var color_name := str(AXIS_THEME_COLORS[axis_index])
	if control.has_theme_color(color_name, "Editor"):
		return control.get_theme_color(color_name, "Editor")

	return AXIS_FALLBACK_COLORS[axis_index]
