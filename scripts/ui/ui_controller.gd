extends CanvasLayer

signal begin_birth_requested
signal preparation_requested(choice: String)
signal intervention_hold_changed(action: String, held: bool)
signal oxygen_priority_requested(priority: String)
signal tutorial_toggled(enabled: bool)
signal restart_requested
signal oxygen_adjustment_requested(amount: float)
signal demand_adjustment_requested(amount: float)

const ACTION_LUNGS := "lungs"
const ACTION_FLOW := "flow"

var _value_labels: Dictionary = {}
var _phase_label: Label
var _time_label: Label
var _warning_label: Label
var _context_label: Label
var _causal_chain: RichTextLabel
var _begin_button: Button
var _lungs_button: Button
var _flow_button: Button
var _tutorial_button: Button
var _prep_panel: Panel
var _preparation_summary_label: Label
var _prep_budget_label: Label
var _prep_buttons: Dictionary = {}
var _distribution_panel: Panel
var _vital_priority_button: Button
var _growth_priority_button: Button
var _distribution_status_label: Label
var _debug_panel: Panel
var _debug_text: Label
var _outcome_overlay: Panel
var _outcome_title: Label
var _outcome_body: Label
var _phase_banner: Panel
var _phase_banner_label: Label
var _phase_banner_timer := 0.0
var _last_phase := ""
var _highlighted_action := ""
var _last_energy_notice := 0.0
var _latest_state: Dictionary = {}


func _ready() -> void:
	_build_hud()
	_build_preparation_panel()
	_build_distribution_panel()
	_build_objective_panel()
	_build_phase_banner()
	_build_debug_panel()
	_build_outcome_overlay()


func _process(delta: float) -> void:
	if _phase_banner_timer > 0.0:
		_phase_banner_timer -= delta
		if _phase_banner_timer <= 0.0 and _latest_state.get("phase", "") != "BIRTH_COUNTDOWN":
			_phase_banner.hide()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	_lungs_button.modulate = (
		Color(1.0, 0.82 + pulse * 0.18, 0.68 + pulse * 0.32)
		if _highlighted_action == ACTION_LUNGS
		else Color.WHITE
	)
	_flow_button.modulate = (
		Color(0.68 + pulse * 0.32, 0.9 + pulse * 0.1, 1.0)
		if _highlighted_action == ACTION_FLOW
		else Color.WHITE
	)
	_vital_priority_button.modulate = (
		Color(1.0, 0.82 + pulse * 0.18, 0.68 + pulse * 0.32)
		if _highlighted_action == "distribution_vital"
		else Color.WHITE
	)
	_growth_priority_button.modulate = (
		Color(0.68 + pulse * 0.32, 0.9 + pulse * 0.1, 1.0)
		if _highlighted_action == "distribution_growth"
		else Color.WHITE
	)


func set_state(state: Dictionary) -> void:
	if _phase_label == null:
		return
	_latest_state = state
	var phase: String = state.get("phase", "PRE_BIRTH")
	if phase != _last_phase:
		_on_phase_changed(phase)
		_last_phase = phase

	_phase_label.text = "PHASE  %s" % _readable_phase(phase)
	_time_label.text = (
		"%s  %04.1fs" % [state.get("time_label", "PHASE TIME"), state.get("time_remaining", 0.0)]
		if phase in ["BIRTH_COUNTDOWN", "TRANSITION", "STABILIZATION"]
		else "PHASE TIME  --"
	)
	_set_value("oxygen", state.get("oxygen", 0.0))
	_set_value("placental_supply", state.get("placental_supply", 0.0))
	_set_value("lung_activation", state.get("lung_activation", 0.0))
	_set_value("pulmonary_flow", state.get("pulmonary_flow", 0.0))
	_set_value("circulation_efficiency", state.get("circulation_efficiency", 0.0))
	_set_value("body_demand", state.get("body_demand", 0.0))
	_update_warning(state)
	_update_preparation_panel(state)
	_update_action_buttons(state)
	_update_distribution_panel(state)
	_update_context(state)
	_update_causal_chain(state)
	_update_debug(state)
	_update_outcome(state)
	_update_countdown(state)
	_update_energy_notice(state)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_B:
			if (
				key_event.pressed
				and _latest_state.get("phase", "") == "PRE_BIRTH"
				and _latest_state.get("preparation_budget_remaining", 2) == 0
			):
				begin_birth_requested.emit()
		KEY_L:
			if key_event.pressed:
				intervention_hold_changed.emit(ACTION_LUNGS, true)
		KEY_F:
			if key_event.pressed:
				intervention_hold_changed.emit(ACTION_FLOW, true)
		KEY_R:
			if key_event.pressed:
				restart_requested.emit()
		KEY_F3:
			if key_event.pressed:
				_debug_panel.visible = not _debug_panel.visible


func _build_hud() -> void:
	var panel := Panel.new()
	panel.position = Vector2(430, 0)
	panel.size = Vector2(210, 360)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#190b18"), Color("#5c304e")))
	add_child(panel)

	var title := _label("FIRST BREATH", 16, Color("#fff0e7"))
	title.position = Vector2(10, 8)
	panel.add_child(title)

	_phase_label = _label("PHASE  BEFORE BIRTH", 10, Color("#79e4f0"))
	_phase_label.position = Vector2(10, 34)
	panel.add_child(_phase_label)

	_time_label = _label("PHASE TIME  --", 10, Color("#d6b5c8"))
	_time_label.position = Vector2(10, 49)
	panel.add_child(_time_label)

	var fields := [
		["oxygen", "Blood oxygen"],
		["placental_supply", "Placental supply"],
		["lung_activation", "Lung activation"],
		["pulmonary_flow", "Pulmonary flow"],
		["circulation_efficiency", "Circulation"],
		["body_demand", "Body demand"],
	]
	for index in range(fields.size()):
		var label := _label("", 9, Color("#eadde5"))
		label.position = Vector2(10, 65 + index * 13)
		label.size = Vector2(190, 13)
		panel.add_child(label)
		_value_labels[fields[index][0]] = [label, fields[index][1]]

	_warning_label = _label("CITY OXYGEN STABLE", 9, Color("#70e6d0"))
	_warning_label.position = Vector2(10, 145)
	_warning_label.size = Vector2(190, 18)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_warning_label)

	_begin_button = _button("Choose 2 Preparations", Vector2(10, 164), Vector2(190, 27))
	_begin_button.pressed.connect(func(): begin_birth_requested.emit())
	panel.add_child(_begin_button)

	_lungs_button = _button(
		"Activate Lungs [L]\nLet the lungs begin\ntaking in oxygen.",
		Vector2(10, 196),
		Vector2(190, 53)
	)
	_lungs_button.add_theme_font_size_override("font_size", 9)
	_lungs_button.pressed.connect(
		func(): intervention_hold_changed.emit(ACTION_LUNGS, true)
	)
	panel.add_child(_lungs_button)

	_flow_button = _button(
		"Redirect Blood Flow [F]\nSend blood through the lungs\nto collect oxygen.",
		Vector2(10, 254),
		Vector2(190, 53)
	)
	_flow_button.add_theme_font_size_override("font_size", 9)
	_flow_button.pressed.connect(
		func(): intervention_hold_changed.emit(ACTION_FLOW, true)
	)
	panel.add_child(_flow_button)

	_tutorial_button = _button("Tutorial: ON", Vector2(10, 315), Vector2(92, 28))
	_tutorial_button.add_theme_font_size_override("font_size", 9)
	_tutorial_button.pressed.connect(
		func():
			tutorial_toggled.emit(not _latest_state.get("tutorial_enabled", true))
	)
	panel.add_child(_tutorial_button)

	var restart_button := _button("Restart [R]", Vector2(108, 315), Vector2(92, 28))
	restart_button.add_theme_font_size_override("font_size", 9)
	restart_button.pressed.connect(func(): restart_requested.emit())
	panel.add_child(restart_button)


func _build_preparation_panel() -> void:
	_prep_panel = Panel.new()
	_prep_panel.position = Vector2(12, 4)
	_prep_panel.size = Vector2(406, 112)
	_prep_panel.z_index = 8
	_prep_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#170e1fe8"), Color("#d98e62"))
	)
	add_child(_prep_panel)

	var title := _label("HOW OXYGEN CHANGES AT BIRTH", 10, Color("#ffe1b5"))
	title.position = Vector2(9, 5)
	_prep_panel.add_child(title)

	_preparation_summary_label = _label(
		"Before birth, the placenta supplies oxygen.\n"
		+ "After birth, the lungs must take over.",
		9,
		Color("#f7e9ee")
	)
	_preparation_summary_label.position = Vector2(9, 20)
	_preparation_summary_label.size = Vector2(388, 25)
	_preparation_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preparation_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prep_panel.add_child(_preparation_summary_label)

	var choice_title := _label(
		"CHOOSE TWO — YOU MUST LEAVE ONE BEHIND",
		9,
		Color("#ffe1b5")
	)
	choice_title.position = Vector2(9, 47)
	_prep_panel.add_child(choice_title)

	_prep_budget_label = _label("Choose 2 of 3", 10, Color("#83e1df"))
	_prep_budget_label.position = Vector2(276, 47)
	_prep_panel.add_child(_prep_budget_label)

	var choices := [
		[
			"heart",
			"Test Heart",
			"Moves blood better.",
		],
		[
			"lungs",
			"Prepare Lungs",
			"Lungs start faster.",
		],
		[
			"energy",
			"Reserve Energy",
			"Uses less oxygen briefly.",
		],
	]
	for index in range(choices.size()):
		var x := 8.0 + index * 130.0
		var button := _button(
			"%s\n%s" % [choices[index][1], choices[index][2]],
			Vector2(x, 63),
			Vector2(125, 41)
		)
		button.add_theme_font_size_override("font_size", 8)
		var choice_code: String = choices[index][0]
		button.pressed.connect(func(): preparation_requested.emit(choice_code))
		_prep_panel.add_child(button)
		_prep_buttons[choice_code] = button


func _build_distribution_panel() -> void:
	_distribution_panel = Panel.new()
	_distribution_panel.position = Vector2(430, 190)
	_distribution_panel.size = Vector2(210, 120)
	_distribution_panel.z_index = 12
	_distribution_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#130b18f5"), Color("#62d8de"))
	)
	_distribution_panel.hide()
	add_child(_distribution_panel)

	var title := _label("OXYGEN DISTRIBUTION", 10, Color("#a8f6f2"))
	title.position = Vector2(10, 5)
	title.size = Vector2(190, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distribution_panel.add_child(title)

	_vital_priority_button = _button(
		"Prioritize Vital Core\n65% core / 35% growth",
		Vector2(10, 23),
		Vector2(190, 34)
	)
	_vital_priority_button.add_theme_font_size_override("font_size", 9)
	_vital_priority_button.pressed.connect(
		func(): oxygen_priority_requested.emit("vital")
	)
	_distribution_panel.add_child(_vital_priority_button)

	_growth_priority_button = _button(
		"Support Growing Body\n40% core / 60% growth",
		Vector2(10, 61),
		Vector2(190, 34)
	)
	_growth_priority_button.add_theme_font_size_override("font_size", 9)
	_growth_priority_button.pressed.connect(
		func(): oxygen_priority_requested.emit("growth")
	)
	_distribution_panel.add_child(_growth_priority_button)

	_distribution_status_label = _label("", 8, Color("#fff0e7"))
	_distribution_status_label.position = Vector2(8, 99)
	_distribution_status_label.size = Vector2(194, 15)
	_distribution_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distribution_panel.add_child(_distribution_status_label)


func _build_objective_panel() -> void:
	var objective_panel := Panel.new()
	objective_panel.position = Vector2(16, 274)
	objective_panel.size = Vector2(398, 76)
	objective_panel.z_index = 7
	objective_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#130b18ed"), Color("#d99a5d"))
	)
	add_child(objective_panel)

	var title := _label("CURRENT OBJECTIVE", 9, Color("#ffd082"))
	title.position = Vector2(9, 4)
	title.size = Vector2(380, 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_panel.add_child(title)

	_context_label = _label("", 10, Color("#fff0e7"))
	_context_label.position = Vector2(10, 18)
	_context_label.size = Vector2(378, 31)
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_panel.add_child(_context_label)

	_causal_chain = RichTextLabel.new()
	_causal_chain.bbcode_enabled = true
	_causal_chain.fit_content = true
	_causal_chain.position = Vector2(10, 52)
	_causal_chain.size = Vector2(378, 18)
	_causal_chain.add_theme_font_size_override("normal_font_size", 10)
	objective_panel.add_child(_causal_chain)


func _build_phase_banner() -> void:
	_phase_banner = Panel.new()
	_phase_banner.position = Vector2(80, 82)
	_phase_banner.size = Vector2(270, 72)
	_phase_banner.z_index = 18
	_phase_banner.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#180d1df0"), Color("#f2bd69"))
	)
	_phase_banner.hide()
	add_child(_phase_banner)

	_phase_banner_label = _label("", 17, Color("#fff0cf"))
	_phase_banner_label.position = Vector2(10, 9)
	_phase_banner_label.size = Vector2(250, 54)
	_phase_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_banner.add_child(_phase_banner_label)


func _build_debug_panel() -> void:
	_debug_panel = Panel.new()
	_debug_panel.position = Vector2(8, 8)
	_debug_panel.size = Vector2(252, 344)
	_debug_panel.z_index = 40
	_debug_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#130c17f2"), Color("#61cbd8"))
	)
	_debug_panel.hide()
	add_child(_debug_panel)

	_debug_text = _label("", 9, Color("#d6faff"))
	_debug_text.position = Vector2(8, 7)
	_debug_text.size = Vector2(236, 294)
	_debug_panel.add_child(_debug_text)

	var controls := [
		["O2 -", Vector2(8, 307), func(): oxygen_adjustment_requested.emit(-10.0)],
		["O2 +", Vector2(68, 307), func(): oxygen_adjustment_requested.emit(10.0)],
		["Demand -", Vector2(128, 307), func(): demand_adjustment_requested.emit(-10.0)],
		["Demand +", Vector2(190, 307), func(): demand_adjustment_requested.emit(10.0)],
	]
	for control in controls:
		var button := _button(control[0], control[1], Vector2(54, 26))
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(control[2])
		_debug_panel.add_child(button)


func _build_outcome_overlay() -> void:
	_outcome_overlay = Panel.new()
	_outcome_overlay.position = Vector2(24, 20)
	_outcome_overlay.size = Vector2(382, 300)
	_outcome_overlay.z_index = 30
	_outcome_overlay.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#160c1af5"), Color("#f2c56b"))
	)
	_outcome_overlay.hide()
	add_child(_outcome_overlay)

	_outcome_title = _label("", 16, Color("#fff2c7"))
	_outcome_title.position = Vector2(14, 12)
	_outcome_title.size = Vector2(354, 25)
	_outcome_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_overlay.add_child(_outcome_title)

	_outcome_body = _label("", 10, Color("#f2e8ee"))
	_outcome_body.position = Vector2(20, 45)
	_outcome_body.size = Vector2(342, 205)
	_outcome_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome_overlay.add_child(_outcome_body)

	var restart_button := _button("Try Again [R]", Vector2(96, 260), Vector2(190, 28))
	restart_button.pressed.connect(func(): restart_requested.emit())
	_outcome_overlay.add_child(restart_button)


func _update_warning(state: Dictionary) -> void:
	var status: String = state.get("oxygen_status", "healthy")
	if status == "critical":
		_warning_label.text = "CRITICAL OXYGEN - RECOVER NOW"
		_warning_label.modulate = Color("#ff4c58")
	elif status == "distress":
		_warning_label.text = "DISTRESS - SUPPLY TOO LOW"
		_warning_label.modulate = Color("#ff9a55")
	elif status == "falling":
		_warning_label.text = "OXYGEN FALLING"
		_warning_label.modulate = Color("#ffd36a")
	else:
		_warning_label.text = "CITY OXYGEN STABLE"
		_warning_label.modulate = Color("#70e6d0")


func _update_preparation_panel(state: Dictionary) -> void:
	var phase: String = state.get("phase", "PRE_BIRTH")
	_prep_panel.visible = phase == "PRE_BIRTH"
	if phase != "PRE_BIRTH":
		return
	var remaining: int = state.get("preparation_budget_remaining", 2)
	var selected: Array = state.get("preparation_choices", [])
	_prep_budget_label.text = "Choices remaining: %d" % remaining
	var summary: String = state.get("preparation_summary", "")
	_preparation_summary_label.text = (
		summary
		if not summary.is_empty()
		else (
			"Before birth, the placenta supplies oxygen.\n"
			+ "After birth, the lungs must take over."
		)
	)
	_preparation_summary_label.add_theme_font_size_override(
		"font_size",
		8 if not summary.is_empty() else 9
	)
	for code in _prep_buttons:
		var button: Button = _prep_buttons[code]
		button.disabled = code in selected or remaining <= 0
		button.text = _preparation_button_text(code, code in selected)
	_begin_button.disabled = remaining > 0
	_begin_button.text = "Begin Birth [B]" if remaining == 0 else "Choose 2 Preparations"


func _update_action_buttons(state: Dictionary) -> void:
	var phase: String = state.get("phase", "PRE_BIRTH")
	var actions_allowed := phase == "TRANSITION" or phase == "STABILIZATION"
	var metrics: Dictionary = state.get("metrics", {})
	var lungs_committed: bool = metrics.get("lung_activation_time", -1.0) >= 0.0
	var flow_committed: bool = metrics.get("flow_redirection_time", -1.0) >= 0.0
	_lungs_button.disabled = not actions_allowed or lungs_committed
	_flow_button.disabled = not actions_allowed or flow_committed

	var held_action: String = state.get("held_action", "")
	var hold_required: float = maxf(0.01, state.get("hold_required", 1.0))
	var progress: float = state.get("hold_progress", 0.0) / hold_required
	_lungs_button.text = _action_button_text(
		"Activate Lungs",
		"L",
		held_action == ACTION_LUNGS,
		progress,
		lungs_committed,
		"Let the lungs begin\ntaking in oxygen."
	)
	_flow_button.text = _action_button_text(
		"Redirect Blood Flow",
		"F",
		held_action == ACTION_FLOW,
		progress,
		flow_committed,
		"Send blood through the lungs\nto collect oxygen."
	)
	_highlighted_action = (
		state.get("objective_action", "")
		if state.get("tutorial_enabled", true) and actions_allowed
		else ""
	)
	_tutorial_button.text = (
		"Tutorial: ON"
		if state.get("tutorial_enabled", true)
		else "Tutorial: OFF"
	)
	_begin_button.disabled = phase != "PRE_BIRTH" or state.get("preparation_budget_remaining", 2) > 0


func _update_distribution_panel(state: Dictionary) -> void:
	var active: bool = state.get("phase", "") == "STABILIZATION"
	_distribution_panel.visible = active
	if not active:
		return

	var priority: String = state.get("distribution_priority", "unassigned")
	_vital_priority_button.text = (
		"VITAL CORE ACTIVE\n65% core / 35% growth"
		if priority == "vital"
		else "Prioritize Vital Core\n65% core / 35% growth"
	)
	_growth_priority_button.text = (
		"GROWING BODY ACTIVE\n40% core / 60% growth"
		if priority == "growth"
		else "Support Growing Body\n40% core / 60% growth"
	)
	_highlighted_action = (
		state.get("objective_action", "")
		if state.get("tutorial_enabled", true)
		else ""
	)

	var vital_neglect: float = state.get("vital_core_neglect", 0.0)
	var growth_neglect: float = state.get("growing_body_neglect", 0.0)
	if priority == "unassigned":
		_distribution_status_label.text = "No route selected — oxygen is being lost"
		_distribution_status_label.modulate = Color("#ffb36f")
	elif vital_neglect > 0.1:
		_distribution_status_label.text = "Vital Core is under-supplied"
		_distribution_status_label.modulate = Color("#ff7777")
	elif growth_neglect > 0.1:
		_distribution_status_label.text = "Growing Body is under-supplied"
		_distribution_status_label.modulate = Color("#ffb36f")
	else:
		_distribution_status_label.text = "Distribution matches current demand"
		_distribution_status_label.modulate = Color("#8af0d3")


func _update_context(state: Dictionary) -> void:
	_context_label.text = state.get("objective_text", state.get("context_prompt", ""))
	var code: String = state.get("context_code", "MONITOR")
	_context_label.modulate = (
		Color("#ffbf70")
		if code in [
			"LUNGS_INACTIVE",
			"FLOW_LOW",
			"DEMAND_EXCEEDS_DELIVERY",
			"DISTRIBUTE_OXYGEN",
			"VITAL_DEMAND",
			"GROWTH_DEMAND",
		]
		else Color("#fff0e7")
	)


func _update_causal_chain(state: Dictionary) -> void:
	var focus: String = state.get("causal_chain_focus", "")
	var parts := [
		_chain_part("Air", focus == "air"),
		_chain_part("Lungs", focus == "lungs"),
		_chain_part("Blood", focus == "blood"),
		_chain_part("Heart", focus == "heart"),
		_chain_part("Body", focus == "body"),
	]
	_causal_chain.text = (
		"[center]%s  [color=#d6a56b]→[/color]  %s  "
		+ "[color=#d6a56b]→[/color]  %s  [color=#d6a56b]→[/color]  %s  "
		+ "[color=#d6a56b]→[/color]  %s[/center]"
	) % parts


func _update_debug(state: Dictionary) -> void:
	_debug_text.text = (
		"RAW SIMULATION\n"
		+ "oxygen                 %6.2f\n" % state.get("oxygen", 0.0)
		+ "placental_supply       %6.2f\n" % state.get("placental_supply", 0.0)
		+ "lung_activation        %6.2f\n" % state.get("lung_activation", 0.0)
		+ "pulmonary_flow         %6.2f\n" % state.get("pulmonary_flow", 0.0)
		+ "circulation_efficiency %6.2f\n" % state.get("circulation_efficiency", 0.0)
		+ "body_demand            %6.2f\n" % state.get("body_demand", 0.0)
		+ "energy reserve         %6.2fs\n\n" % state.get("energy_reserve_remaining", 0.0)
		+ "distribution           %s\n" % state.get("distribution_priority", "unassigned")
		+ "vital allocation       %6.2f\n" % state.get("vital_core_allocation", 0.0)
		+ "growth allocation      %6.2f\n" % state.get("growing_body_allocation", 0.0)
		+ "vital neglect          %6.2fs\n" % state.get("vital_core_neglect", 0.0)
		+ "growth neglect         %6.2fs\n\n" % state.get("growing_body_neglect", 0.0)
		+ "placenta O2            %6.2f/s\n" % state.get("placental_oxygen_contribution", 0.0)
		+ "lung O2                %6.2f/s\n" % state.get("lung_oxygen_contribution", 0.0)
		+ "consumption            %6.2f/s\n" % state.get("oxygen_consumption", 0.0)
		+ "critical timer         %6.2fs" % state.get("critical_state_timer", 0.0)
	)


func _update_outcome(state: Dictionary) -> void:
	var phase: String = state.get("phase", "PRE_BIRTH")
	if phase == "SUCCESS":
		var metrics: Dictionary = state.get("metrics", {})
		_outcome_title.text = "CITY STABILIZED"
		_outcome_body.text = (
			"Pre-birth primary oxygen source: Placenta\n"
			+ "Post-birth primary oxygen source: Lungs\n"
			+ "Lowest oxygen reached: %.1f\n" % metrics.get("lowest_oxygen", 0.0)
			+ "Time spent in distress: %.1fs\n" % metrics.get("distress_time", 0.0)
			+ "Lung activation time: %s\n" % _metric_time(metrics.get("lung_activation_time", -1.0))
			+ "Flow redirection time: %s\n" % _metric_time(metrics.get("flow_redirection_time", -1.0))
			+ "Preparations: %s\n\n" % _preparation_list(metrics.get("preparation_choices", []))
			+ state.get("success_explanation", "")
			+ "\n\nThis is a simplified educational model, not a diagnostic model."
		)
		_outcome_overlay.show()
	elif phase == "FAILURE":
		var metrics: Dictionary = state.get("metrics", {})
		_outcome_title.text = "TRANSITION NEEDS SUPPORT"
		_outcome_body.text = (
			"Primary bottleneck: %s\n" % state.get("failure_bottleneck", "Unknown")
			+ "Lowest oxygen reached: %.1f\n\n" % metrics.get("lowest_oxygen", 0.0)
			+ "Next attempt: %s\n\n" % state.get("failure_suggestion", "Act earlier.")
			+ "This is a simplified educational model. "
			+ "The result is not a medical judgment."
		)
		_outcome_overlay.show()
	else:
		_outcome_overlay.hide()


func _update_countdown(state: Dictionary) -> void:
	if state.get("phase", "") != "BIRTH_COUNTDOWN":
		return
	_phase_banner.show()
	_phase_banner_label.text = "BIRTH BEGINNING\n%d" % ceili(state.get("countdown_remaining", 0.0))


func _update_energy_notice(state: Dictionary) -> void:
	var notice: float = state.get("energy_expiration_notice", 0.0)
	if notice > 0.0 and _last_energy_notice <= 0.0:
		_phase_banner_label.text = "STORED ENERGY USED UP\nBODY DEMAND RETURNS"
		_phase_banner_timer = notice
		_phase_banner.show()
	_last_energy_notice = notice


func _on_phase_changed(phase: String) -> void:
	match phase:
		"TRANSITION":
			_phase_banner_label.text = "PLACENTAL SUPPORT\nIS FALLING"
			_phase_banner_timer = 1.8
			_phase_banner.show()
		"STABILIZATION":
			_phase_banner_label.text = "POST-BIRTH\nSTABILIZATION"
			_phase_banner_timer = 1.8
			_phase_banner.show()
		"SUCCESS":
			_phase_banner.hide()
		"FAILURE":
			_phase_banner.hide()


func _action_button_text(
	label: String,
	key: String,
	is_held: bool,
	progress: float,
	is_committed: bool,
	description: String
) -> String:
	if is_committed:
		return "%s: COMMITTED\n%s" % [label, description]
	if is_held:
		return "%s [%s]  CHARGING %d%%\n%s" % [
			label,
			key,
			roundi(progress * 100.0),
			description,
		]
	return "%s [%s]\n%s" % [label, key, description]


func _chain_part(label: String, highlighted: bool) -> String:
	return (
		"[color=#fff1a8][b]%s[/b][/color]" % label
		if highlighted
		else "[color=#bfaeb8]%s[/color]" % label
	)


func _set_value(key: String, value: float) -> void:
	var field: Array = _value_labels[key]
	field[0].text = "%-19s %6.1f" % [field[1], value]


func _readable_phase(phase: String) -> String:
	match phase:
		"PRE_BIRTH":
			return "PRE-BIRTH"
		"BIRTH_COUNTDOWN":
			return "BIRTH BEGINNING"
		"TRANSITION":
			return "BIRTH TRANSITION"
		"STABILIZATION":
			return "POST-BIRTH"
		"SUCCESS":
			return "STABLE"
		"FAILURE":
			return "CRITICAL FAILURE"
	return phase


func _preparation_name(code: String) -> String:
	match code:
		"heart":
			return "Test Heart"
		"lungs":
			return "Prepare Lungs"
		"energy":
			return "Reserve Energy"
	return code


func _preparation_button_text(code: String, selected: bool) -> String:
	if selected:
		return "SELECTED\n%s" % _preparation_name(code)
	match code:
		"heart":
			return "Test Heart\nMoves blood better."
		"lungs":
			return "Prepare Lungs\nLungs start faster."
		"energy":
			return "Reserve Energy\nUses less oxygen briefly."
	return code


func _preparation_list(choices: Array) -> String:
	if choices.is_empty():
		return "None"
	var names: Array[String] = []
	for choice in choices:
		names.append(_preparation_name(choice))
	return ", ".join(names)


func _metric_time(value: float) -> String:
	return "%.1fs after birth began" % value if value >= 0.0 else "Not completed"


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, position: Vector2, size := Vector2(190, 26)) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override(
		"normal",
		_button_style(Color("#35182d"), Color("#75536e"))
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(Color("#543047"), Color("#edb977"))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(Color("#74405a"), Color("#7fe0df"))
	)
	button.add_theme_stylebox_override(
		"disabled",
		_button_style(Color("#21141f"), Color("#493945"))
	)
	return button


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
