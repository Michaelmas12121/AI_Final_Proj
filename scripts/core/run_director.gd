class_name RunDirector
extends Node

signal run_state_changed(snapshot: Dictionary)

enum Phase {
	PRE_BIRTH,
	BIRTH_COUNTDOWN,
	TRANSITION,
	STABILIZATION,
	SUCCESS,
	FAILURE,
}

const ACTION_LUNGS := "lungs"
const ACTION_FLOW := "flow"
const ONBOARDING_MESSAGE := (
	"Before birth, the placenta supplies oxygen. "
	+ "After birth, the lungs must take over."
)

var _simulation: Node
var _phase: Phase = Phase.PRE_BIRTH
var _snapshot: Dictionary = {}
var _countdown_remaining := 0.0
var _stabilization_safe_time := 0.0
var _held_action := ""
var _hold_progress := 0.0
var _screen_shake_remaining := 0.0
var _takeover_flash_remaining := 0.0
var _pulmonary_dominant_seen := false
var _tutorial_enabled := true
var _energy_notice_remaining := 0.0
var _metrics: Dictionary = {}


func setup(simulation: Node) -> void:
	_simulation = simulation
	if _simulation.get_snapshot().is_empty():
		_simulation.reset_model()
	_publish_snapshot()


func restart() -> void:
	_require_simulation()
	_simulation.reset_model()
	_phase = Phase.PRE_BIRTH
	_countdown_remaining = 0.0
	_stabilization_safe_time = 0.0
	_held_action = ""
	_hold_progress = 0.0
	_screen_shake_remaining = 0.0
	_takeover_flash_remaining = 0.0
	_pulmonary_dominant_seen = false
	_energy_notice_remaining = 0.0
	_metrics = {
		"lowest_oxygen": _simulation.get_snapshot().oxygen,
		"distress_time": 0.0,
		"lung_activation_time": -1.0,
		"flow_redirection_time": -1.0,
		"total_run_time": 0.0,
	}
	_publish_snapshot()


func choose_preparation(choice: String) -> bool:
	if _phase != Phase.PRE_BIRTH:
		return false
	var accepted: bool = _simulation.choose_preparation(choice)
	_publish_snapshot()
	return accepted


func set_tutorial_enabled(enabled: bool) -> void:
	_tutorial_enabled = enabled
	_publish_snapshot()


func begin_birth() -> void:
	if _phase != Phase.PRE_BIRTH:
		return
	_phase = Phase.BIRTH_COUNTDOWN
	_countdown_remaining = _simulation.balance.birth_countdown_seconds
	_publish_snapshot()


func activate_lungs() -> void:
	if _phase != Phase.TRANSITION and _phase != Phase.STABILIZATION:
		return
	if _metrics.lung_activation_time < 0.0:
		_metrics.lung_activation_time = _simulation.get_snapshot().birth_elapsed
	_simulation.activate_lungs()
	_publish_snapshot()


func redirect_blood_flow() -> void:
	if _phase != Phase.TRANSITION and _phase != Phase.STABILIZATION:
		return
	if _metrics.flow_redirection_time < 0.0:
		_metrics.flow_redirection_time = _simulation.get_snapshot().birth_elapsed
	_simulation.redirect_blood_flow()
	_publish_snapshot()


func set_oxygen_priority(priority: String) -> bool:
	if _phase != Phase.STABILIZATION:
		return false
	var accepted: bool = _simulation.set_oxygen_priority(priority)
	_publish_snapshot()
	return accepted


func set_intervention_held(action: String, held: bool) -> void:
	if _phase != Phase.TRANSITION and _phase != Phase.STABILIZATION:
		_held_action = ""
		_hold_progress = 0.0
		return
	if action != ACTION_LUNGS and action != ACTION_FLOW:
		return
	if held:
		if _held_action != action:
			_held_action = action
			_hold_progress = 0.0
	elif _held_action == action:
		_held_action = ""
		_hold_progress = 0.0
	_publish_snapshot()


func add_oxygen(amount: float) -> void:
	if _phase != Phase.SUCCESS and _phase != Phase.FAILURE:
		_simulation.add_oxygen(amount)
		_publish_snapshot()


func adjust_body_demand(amount: float) -> void:
	if _phase != Phase.SUCCESS and _phase != Phase.FAILURE:
		_simulation.adjust_body_demand(amount)
		_publish_snapshot()


func step(delta: float) -> Dictionary:
	_require_simulation()
	if delta <= 0.0:
		return get_snapshot()
	if _phase == Phase.SUCCESS or _phase == Phase.FAILURE:
		return get_snapshot()

	_metrics.total_run_time += delta
	_screen_shake_remaining = maxf(0.0, _screen_shake_remaining - delta)
	_takeover_flash_remaining = maxf(0.0, _takeover_flash_remaining - delta)
	_energy_notice_remaining = maxf(0.0, _energy_notice_remaining - delta)
	var energy_before: float = _simulation.get_snapshot().energy_reserve_remaining

	var simulation_delta := delta
	if _phase == Phase.BIRTH_COUNTDOWN:
		var countdown_delta := minf(delta, _countdown_remaining)
		_simulation.step(countdown_delta)
		_countdown_remaining -= countdown_delta
		simulation_delta -= countdown_delta
		if _countdown_remaining <= 0.0:
			_countdown_remaining = 0.0
			_simulation.begin_birth()
			_phase = Phase.TRANSITION
			_screen_shake_remaining = 0.8

	if simulation_delta > 0.0:
		_advance_held_action(simulation_delta)
		_simulation.step(simulation_delta)
	var energy_after: float = _simulation.get_snapshot().energy_reserve_remaining
	if energy_before > 0.0 and energy_after <= 0.0:
		_energy_notice_remaining = 3.5

	_update_metrics(delta)
	_update_pulmonary_takeover()

	if _phase == Phase.TRANSITION:
		_evaluate_transition()
	elif _phase == Phase.STABILIZATION:
		_evaluate_stabilization(delta)

	_publish_snapshot()
	return get_snapshot()


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _advance_held_action(delta: float) -> void:
	if _held_action.is_empty():
		return
	_hold_progress = minf(
		_simulation.balance.intervention_hold_seconds,
		_hold_progress + delta
	)
	if _hold_progress < _simulation.balance.intervention_hold_seconds:
		return

	var completed_action := _held_action
	_held_action = ""
	_hold_progress = 0.0
	if completed_action == ACTION_LUNGS:
		activate_lungs()
	elif completed_action == ACTION_FLOW:
		redirect_blood_flow()


func _evaluate_transition() -> void:
	var state: Dictionary = _simulation.get_snapshot()
	var balance: Resource = _simulation.balance

	if state.critical_state_timer >= balance.critical_grace_seconds:
		_phase = Phase.FAILURE
		return

	if (
		state.placental_supply <= balance.success_placenta_maximum
		and state.oxygen >= balance.safe_oxygen
		and state.lung_activation >= balance.success_lung_minimum
		and state.pulmonary_flow >= balance.success_flow_minimum
	):
		_phase = Phase.STABILIZATION
		_stabilization_safe_time = 0.0
		_simulation.begin_stabilization()


func _evaluate_stabilization(delta: float) -> void:
	var state: Dictionary = _simulation.get_snapshot()
	var balance: Resource = _simulation.balance

	if (
		state.vital_core_neglect >= balance.district_neglect_failure_seconds
		or state.growing_body_neglect >= balance.district_neglect_failure_seconds
	):
		_phase = Phase.FAILURE
		return

	if state.critical_state_timer >= balance.critical_grace_seconds:
		_phase = Phase.FAILURE
		return

	if state.oxygen >= balance.safe_oxygen:
		_stabilization_safe_time += delta
	else:
		_stabilization_safe_time = 0.0

	if _stabilization_safe_time >= balance.stabilization_safe_seconds:
		_phase = Phase.SUCCESS


func _update_metrics(delta: float) -> void:
	var state: Dictionary = _simulation.get_snapshot()
	_metrics.lowest_oxygen = minf(_metrics.lowest_oxygen, state.oxygen)
	if state.oxygen < _simulation.balance.distress_oxygen:
		_metrics.distress_time += delta


func _update_pulmonary_takeover() -> void:
	if _pulmonary_dominant_seen:
		return
	var state: Dictionary = _simulation.get_snapshot()
	if (
		state.lung_oxygen_contribution > state.placental_oxygen_contribution
		and state.lung_oxygen_contribution > 1.0
	):
		_pulmonary_dominant_seen = true
		_takeover_flash_remaining = 2.0


func _context_state(state: Dictionary) -> Dictionary:
	if _phase == Phase.PRE_BIRTH:
		return {
			"code": "PREPARE",
			"text": "Choose two preparations, then begin birth.",
		}
	if _phase == Phase.BIRTH_COUNTDOWN:
		return {
			"code": "COUNTDOWN",
			"text": "Birth is beginning. Prepare to switch oxygen sources.",
		}
	if _phase == Phase.STABILIZATION:
		if state.distribution_priority == "unassigned":
			return {
				"code": "DISTRIBUTE_OXYGEN",
				"text": (
					"The new oxygen system is working. "
					+ "Now distribute oxygen while the city adapts."
				),
			}
		if state.distribution_event == "vital_surge":
			return {
				"code": "VITAL_DEMAND",
				"text": (
					"The Vital Core needs steady oxygen. "
					+ "Give it priority until demand changes."
				),
			}
		if state.distribution_event == "growth_surge":
			return {
				"code": "GROWTH_DEMAND",
				"text": (
					"The Growing Body is adapting. "
					+ "Shift oxygen toward growth."
				),
			}
		if state.oxygen < _simulation.balance.safe_oxygen:
			return {
				"code": "DEMAND_EXCEEDS_DELIVERY",
				"text": "Oxygen delivery cannot meet the body's rising demand.",
			}
		return {
			"code": "STABILIZING",
			"text": "Maintain safe oxygen while the city stabilizes.",
		}
	if state.lung_activation < 25.0:
		return {
			"code": "LUNGS_INACTIVE",
			"text": "The lungs have not begun exchanging oxygen.",
		}
	if state.pulmonary_flow < 45.0:
		return {
			"code": "FLOW_LOW",
			"text": "Air has entered the lungs, but too little blood is reaching them.",
		}
	if state.oxygen < _simulation.balance.safe_oxygen:
		return {
			"code": "DEMAND_EXCEEDS_DELIVERY",
			"text": "Oxygen delivery cannot meet body demand.",
		}
	if state.lung_oxygen_contribution > state.placental_oxygen_contribution:
		return {
			"code": "PULMONARY_TAKEOVER",
			"text": "Pulmonary oxygenation is taking over.",
		}
	return {
		"code": "MONITOR",
		"text": "Watch oxygen supply as placental support declines.",
	}


func _failure_feedback(state: Dictionary) -> Dictionary:
	if state.get("vital_core_neglect", 0.0) >= _simulation.balance.district_neglect_failure_seconds:
		return {
			"bottleneck": "The Vital Core went too long without enough oxygen.",
			"suggestion": "Prioritize the Vital Core when its demand warning appears.",
		}
	if state.get("growing_body_neglect", 0.0) >= _simulation.balance.district_neglect_failure_seconds:
		return {
			"bottleneck": "The Growing Body went too long without enough oxygen.",
			"suggestion": "Shift oxygen toward growth when the body demand warning appears.",
		}
	if state.lung_activation < _simulation.balance.success_lung_minimum:
		return {
			"bottleneck": "Lung activation remained too low.",
			"suggestion": "Prepare or activate the lungs earlier on the next attempt.",
		}
	if state.pulmonary_flow < _simulation.balance.success_flow_minimum:
		return {
			"bottleneck": "Too little blood reached the lungs.",
			"suggestion": "Redirect pulmonary blood flow earlier on the next attempt.",
		}
	return {
		"bottleneck": "Oxygen delivery could not keep up with body demand.",
		"suggestion": "Reserve energy or complete both interventions sooner.",
	}


func _preparation_summary(choices: Array) -> String:
	if choices.size() < _simulation.balance.preparation_budget:
		return ""
	var strengths: Array[String] = []
	if "heart" in choices:
		strengths.append("stronger oxygen transport")
	if "lungs" in choices:
		strengths.append("faster lung startup")
	if "energy" in choices:
		strengths.append("lower early oxygen demand")
	var weakness := ""
	if not "heart" in choices:
		weakness = "transport routes are not boosted"
	elif not "lungs" in choices:
		weakness = "lungs start at normal speed"
	else:
		weakness = "early oxygen demand stays normal"
	return "Strengths: %s. Unprepared weakness: %s." % [
		" and ".join(strengths),
		weakness,
	]


func _tutorial_guidance(state: Dictionary, context: Dictionary) -> Dictionary:
	if not _tutorial_enabled:
		return {
			"step": "OFF",
			"objective": context.text,
			"action": "",
			"chain_focus": "",
		}
	if _phase == Phase.PRE_BIRTH:
		return {
			"step": "PRE_BIRTH",
			"objective": "Choose two preparations, then begin birth.",
			"action": "",
			"chain_focus": "placenta",
		}
	if _phase == Phase.BIRTH_COUNTDOWN:
		return {
			"step": "IDENTIFY_PLACENTA",
			"objective": "Watch the placenta. Its oxygen supply is about to fade.",
			"action": "",
			"chain_focus": "placenta",
		}
	if _phase == Phase.TRANSITION:
		if state.placental_supply > 95.0:
			return {
				"step": "IDENTIFY_PLACENTA",
				"objective": "Placental oxygen is fading. The lungs must take over.",
				"action": "",
				"chain_focus": "placenta",
			}
		if _metrics.lung_activation_time < 0.0:
			return {
				"step": "ACTIVATE_LUNGS",
				"objective": "Activate Lungs so air can bring in oxygen.",
				"action": ACTION_LUNGS,
				"chain_focus": "lungs",
			}
		if _metrics.flow_redirection_time < 0.0:
			return {
				"step": "REDIRECT_FLOW",
				"objective": (
					"The lungs have oxygen, but blood must collect it. "
					+ "Redirect Blood Flow."
				),
				"action": ACTION_FLOW,
				"chain_focus": "blood",
			}
		return {
			"step": "CONNECT_SYSTEMS",
			"objective": context.text,
			"action": "",
			"chain_focus": (
				"blood"
				if context.code == "FLOW_LOW"
				else "lungs"
				if context.code == "LUNGS_INACTIVE"
				else "body"
			),
		}
	if _phase == Phase.STABILIZATION:
		var requested_priority := (
			"vital"
			if state.distribution_event == "vital_surge"
			else "growth"
		)
		return {
			"step": (
				"DISTRIBUTE_OXYGEN"
				if state.distribution_priority == "unassigned"
				else "BALANCE_DISTRICTS"
			),
			"objective": context.text,
			"action": (
				"distribution_%s" % requested_priority
				if state.distribution_priority != requested_priority
				else ""
			),
			"chain_focus": (
				"heart"
				if requested_priority == "vital"
				else "body"
			),
		}
	return {
		"step": "COMPLETE",
		"objective": context.text,
		"action": "",
		"chain_focus": "body",
	}


func _publish_snapshot() -> void:
	if _simulation == null:
		return
	_snapshot = _simulation.get_snapshot()
	var phase_name: String = Phase.keys()[_phase]
	var context := _context_state(_snapshot)
	var tutorial := _tutorial_guidance(_snapshot, context)
	var failure := _failure_feedback(_snapshot)
	var balance: Resource = _simulation.balance

	_snapshot["phase"] = phase_name
	_snapshot["countdown_remaining"] = _countdown_remaining
	_snapshot["stabilization_safe_time"] = _stabilization_safe_time
	_snapshot["time_remaining"] = _phase_time_remaining()
	_snapshot["time_label"] = _phase_time_label()
	_snapshot["held_action"] = _held_action
	_snapshot["hold_progress"] = _hold_progress
	_snapshot["hold_required"] = balance.intervention_hold_seconds
	_snapshot["screen_shake"] = (
		_screen_shake_remaining / 0.8
		if _screen_shake_remaining > 0.0
		else 0.0
	)
	_snapshot["takeover_flash"] = (
		_takeover_flash_remaining / 2.0
		if _takeover_flash_remaining > 0.0
		else 0.0
	)
	_snapshot["pulmonary_dominant"] = _pulmonary_dominant_seen
	_snapshot["context_code"] = context.code
	_snapshot["context_prompt"] = context.text
	_snapshot["distribution_enabled"] = _phase == Phase.STABILIZATION
	_snapshot["energy_expiration_notice"] = _energy_notice_remaining
	_snapshot["tutorial_enabled"] = _tutorial_enabled
	_snapshot["tutorial_step"] = tutorial.step
	_snapshot["objective_text"] = tutorial.objective
	_snapshot["objective_action"] = tutorial.action
	_snapshot["causal_chain_focus"] = tutorial.chain_focus
	_snapshot["onboarding_message"] = ONBOARDING_MESSAGE
	_snapshot["preparation_summary"] = _preparation_summary(_snapshot.preparation_choices)
	_snapshot["primary_source"] = (
		"Lungs"
		if _snapshot.lung_oxygen_contribution > _snapshot.placental_oxygen_contribution
		else "Placenta"
	)
	_snapshot["metrics"] = _metrics.duplicate(true)
	_snapshot.metrics["preparation_choices"] = _snapshot.preparation_choices.duplicate()
	_snapshot["failure_bottleneck"] = failure.bottleneck
	_snapshot["failure_suggestion"] = failure.suggestion
	_snapshot["success_explanation"] = (
		"The lungs and pulmonary blood flow replaced placental oxygen "
		+ "while delivery stayed above the body's demand."
	)
	run_state_changed.emit(get_snapshot())


func _phase_time_remaining() -> float:
	match _phase:
		Phase.BIRTH_COUNTDOWN:
			return _countdown_remaining
		Phase.TRANSITION:
			return maxf(
				0.0,
				_simulation.balance.birth_transition_seconds
				- _simulation.get_snapshot().birth_elapsed
			)
		Phase.STABILIZATION:
			return maxf(
				0.0,
				_simulation.balance.stabilization_safe_seconds
				- _stabilization_safe_time
			)
	return 0.0


func _phase_time_label() -> String:
	match _phase:
		Phase.BIRTH_COUNTDOWN:
			return "BIRTH STARTS"
		Phase.TRANSITION:
			return "BIRTH WINDOW"
		Phase.STABILIZATION:
			return "SAFE HOLD"
	return "PHASE TIME"


func _require_simulation() -> void:
	assert(_simulation != null, "RunDirector.setup must be called before use.")
