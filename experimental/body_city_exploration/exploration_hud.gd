class_name ExplorationHUD
extends CanvasLayer

var _objective_label: Label
var _oxygen_label: Label
var _oxygen_bar: ProgressBar
var _prompt_panel: Panel
var _prompt_label: Label
var _chain_label: Label
var _message_label: Label
var _intro_label: Label
var _intro_remaining := 10.0


func _ready() -> void:
	_build_hud()


func _process(delta: float) -> void:
	_intro_remaining = maxf(0.0, _intro_remaining - delta)
	_intro_label.visible = _intro_remaining > 0.0


func set_view(
	state: Dictionary,
	objective: String,
	prompt: String,
	direction_text: String,
	event_message: String
) -> void:
	_objective_label.text = "CURRENT OBJECTIVE\n%s\n%s" % [objective, direction_text]
	var oxygen: float = state.get("oxygen", 0.0)
	_oxygen_bar.value = oxygen
	_oxygen_label.text = "CITY OXYGEN %d%%" % roundi(oxygen)
	if oxygen >= 65.0:
		_oxygen_bar.modulate = Color("#62e5cc")
	elif oxygen >= 40.0:
		_oxygen_bar.modulate = Color("#ffc35b")
	else:
		_oxygen_bar.modulate = Color("#ff6969")

	_prompt_panel.visible = not prompt.is_empty()
	_prompt_label.text = prompt
	_message_label.text = event_message
	_message_label.visible = not event_message.is_empty()

	var lung_text := "READY" if state.get("lung_online", false) else "OFF"
	var blood_text := "OPEN" if state.get("flow_open", false) else "CLOSED"
	var body_text := "RECOVERED" if state.get("city_recovered", false) else "WAITING"
	_chain_label.text = (
		"AIR  →  LUNGS [%s]  →  BLOOD [%s]  →  HEART  →  BODY [%s]"
		% [lung_text, blood_text, body_text]
	)


func _build_hud() -> void:
	var top_panel := Panel.new()
	top_panel.position = Vector2(6, 6)
	top_panel.size = Vector2(408, 66)
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color("#160e1cdc"), Color("#ffb45f")))
	add_child(top_panel)

	var title := _label("BODY CITY • EXPLORATION PROTOTYPE", 9, Color("#ffcf82"))
	title.position = Vector2(10, 5)
	title.size = Vector2(390, 14)
	top_panel.add_child(title)

	_objective_label = _label("", 10, Color("#fff3df"))
	_objective_label.position = Vector2(10, 19)
	_objective_label.size = Vector2(390, 44)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_panel.add_child(_objective_label)

	var oxygen_panel := Panel.new()
	oxygen_panel.position = Vector2(422, 6)
	oxygen_panel.size = Vector2(212, 48)
	oxygen_panel.add_theme_stylebox_override("panel", _panel_style(Color("#160e1cdc"), Color("#56c9ca")))
	add_child(oxygen_panel)

	_oxygen_label = _label("CITY OXYGEN", 10, Color("#e8ffff"))
	_oxygen_label.position = Vector2(8, 5)
	_oxygen_label.size = Vector2(196, 14)
	_oxygen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oxygen_panel.add_child(_oxygen_label)

	_oxygen_bar = ProgressBar.new()
	_oxygen_bar.position = Vector2(9, 24)
	_oxygen_bar.size = Vector2(194, 12)
	_oxygen_bar.min_value = 0.0
	_oxygen_bar.max_value = 100.0
	_oxygen_bar.show_percentage = false
	oxygen_panel.add_child(_oxygen_bar)

	_intro_label = _label(
		"YOU ARE THE MAINTENANCE WORKER\nMOVE: WASD / ARROWS     USE: E / SPACE / CLICK",
		11,
		Color("#fff0c9")
	)
	_intro_label.position = Vector2(140, 82)
	_intro_label.size = Vector2(360, 42)
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#251226ee"), Color("#ffd269"))
	)
	add_child(_intro_label)

	_message_label = _label("", 10, Color("#fff0ad"))
	_message_label.position = Vector2(128, 78)
	_message_label.size = Vector2(384, 32)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#251226ee"), Color("#ffb45f"))
	)
	_message_label.visible = false
	add_child(_message_label)

	_chain_label = _label("", 9, Color("#bdeeed"))
	_chain_label.position = Vector2(8, 304)
	_chain_label.size = Vector2(624, 18)
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chain_label.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#120b18d9"), Color("#3c8a8b"))
	)
	add_child(_chain_label)

	_prompt_panel = Panel.new()
	_prompt_panel.position = Vector2(78, 326)
	_prompt_panel.size = Vector2(484, 28)
	_prompt_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#201020f2"), Color("#fff09b"), 5)
	)
	add_child(_prompt_panel)

	_prompt_label = _label("", 11, Color("#fff7d6"))
	_prompt_label.position = Vector2(8, 5)
	_prompt_label.size = Vector2(468, 18)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)

	var restart := _label("R: Restart experiment", 8, Color("#cabacb"))
	restart.position = Vector2(506, 57)
	restart.size = Vector2(128, 14)
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(restart)


func _label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


func _panel_style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
