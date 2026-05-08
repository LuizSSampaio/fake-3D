@tool
extends RefCounted

const ROW_LABEL_WIDTH := 86.0
const SECTION_FONT_SIZE := 16


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


static func create_spin_box(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.allow_greater = true
	spin.allow_lesser = true
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
) -> Array[SpinBox]:
	var row := HBoxContainer.new()
	row.add_child(create_row_label(label_text))

	var controls: Array[SpinBox] = []
	var values := [initial_value.x, initial_value.y, initial_value.z]
	for axis in ["X", "Y", "Z"]:
		var spin := create_spin_box(min_value, max_value, step, values[controls.size()])
		spin.tooltip_text = "%s %s" % [label_text, axis]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(callback)
		row.add_child(spin)
		controls.append(spin)

	parent.add_child(row)
	return controls


static func add_labeled_control(parent: BoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_child(create_row_label(label_text))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)
