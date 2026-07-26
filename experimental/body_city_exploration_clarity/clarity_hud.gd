class_name BodyCityClarityHUD
extends CanvasLayer

var _objective_label: Label
var _oxygen_label: Label
var _oxygen_bar: ProgressBar
var _prompt_panel: Panel
var _prompt_label: Label
var _chain_label: Label
var _message_label: Label
var _cue: Control


func _ready() -> void:
	_build_hud()


func set_view(
	state: Dictionary,
	objective: String,
	prompt: String,
	target_offset: Vector2,
	target_kind: String,
	event_message: String
) -> void:
	_objective_label.text = objective
	var oxygen: float = state.get("oxygen", 0.0)
	_oxygen_bar.value = oxygen
	_oxygen_label.text = "%d%%" % roundi(oxygen)
	match String(state.get("danger_state", "stable")):
		"critical":
			_oxygen_bar.modulate = Color("#ff555d")
		"mid":
			_oxygen_bar.modulate = Color("#ffc35b")
		_:
			_oxygen_bar.modulate = Color("#64e4cb")

	_prompt_panel.visible = not prompt.is_empty()
	_prompt_label.text = prompt
	_message_label.visible = not event_message.is_empty()
	_message_label.text = event_message
	_cue.set_target(target_offset, target_kind)

	var power := "[+]" if state.get("energy_cell_installed", false) else "[ ]"
	var air := "[+]" if state.get("air_intake_open", false) else "[ ]"
	var lungs := "[+]" if state.get("lung_online", false) else "[ ]"
	var blood := "[+]" if state.get("flow_open", false) else "[ ]"
	var body := "[+]" if state.get("city_recovered", false) else "[ ]"
	_chain_label.text = "%s POWER  >  %s AIR  >  %s LUNGS  >  %s BLOOD  >  %s CITY" % [
		power,
		air,
		lungs,
		blood,
		body,
	]


func _build_hud() -> void:
	var objective_panel := Panel.new()
	objective_panel.position = Vector2(8, 8)
	objective_panel.size = Vector2(386, 44)
	objective_panel.add_theme_stylebox_override(
		"panel",
		_style(Color("#160d1de8"), Color("#ffb85e"))
	)
	add_child(objective_panel)

	var caption := _label("CURRENT OBJECTIVE", 8, Color("#ffcc79"))
	caption.position = Vector2(10, 4)
	caption.size = Vector2(170, 12)
	objective_panel.add_child(caption)
	_objective_label = _label("", 11, Color("#fff5df"))
	_objective_label.position = Vector2(10, 17)
	_objective_label.size = Vector2(366, 20)
	objective_panel.add_child(_objective_label)

	var oxygen_panel := Panel.new()
	oxygen_panel.position = Vector2(508, 8)
	oxygen_panel.size = Vector2(124, 44)
	oxygen_panel.add_theme_stylebox_override(
		"panel",
		_style(Color("#160d1de8"), Color("#5ad8d4"))
	)
	add_child(oxygen_panel)
	_oxygen_label = _label("100%", 10, Color("#eaffff"))
	_oxygen_label.position = Vector2(78, 4)
	_oxygen_label.size = Vector2(38, 14)
	_oxygen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	oxygen_panel.add_child(_oxygen_label)
	var oxygen_icon := _label("O2", 11, Color("#ff796c"))
	oxygen_icon.position = Vector2(8, 3)
	oxygen_icon.size = Vector2(24, 18)
	oxygen_panel.add_child(oxygen_icon)
	_oxygen_bar = ProgressBar.new()
	_oxygen_bar.position = Vector2(8, 23)
	_oxygen_bar.size = Vector2(108, 11)
	_oxygen_bar.show_percentage = false
	oxygen_panel.add_child(_oxygen_bar)

	_cue = preload(
		"res://experimental/body_city_exploration_clarity/direction_cue.gd"
	).new()
	_cue.position = Vector2(445, 7)
	_cue.size = Vector2(50, 50)
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cue)

	_message_label = _label("", 12, Color("#fff0ad"))
	_message_label.position = Vector2(132, 66)
	_message_label.size = Vector2(376, 34)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_stylebox_override(
		"normal",
		_style(Color("#241126ef"), Color("#ffd263"))
	)
	_message_label.visible = false
	add_child(_message_label)

	_chain_label = _label("", 9, Color("#c8f2ef"))
	_chain_label.position = Vector2(8, 304)
	_chain_label.size = Vector2(624, 18)
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chain_label.add_theme_stylebox_override(
		"normal",
		_style(Color("#110a17df"), Color("#3f8589"), 1)
	)
	add_child(_chain_label)

	_prompt_panel = Panel.new()
	_prompt_panel.position = Vector2(82, 326)
	_prompt_panel.size = Vector2(476, 28)
	_prompt_panel.add_theme_stylebox_override(
		"panel",
		_style(Color("#201020f2"), Color("#fff09b"), 4)
	)
	add_child(_prompt_panel)
	_prompt_label = _label("", 11, Color("#fff7d6"))
	_prompt_label.position = Vector2(8, 5)
	_prompt_label.size = Vector2(460, 18)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)

	var controls := _label(
		"WASD / ARROWS  |  E / SPACE / CLICK  |  R RESTART",
		8,
		Color("#b9a8bd")
	)
	controls.position = Vector2(312, 54)
	controls.size = Vector2(320, 12)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(controls)


func _label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


func _style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.corner_radius_top_left = 2
	result.corner_radius_top_right = 2
	result.corner_radius_bottom_left = 2
	result.corner_radius_bottom_right = 2
	return result
