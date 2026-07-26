class_name BodyCityClarityModel
extends Node

signal state_changed(snapshot: Dictionary)

const SimulationScript = preload("res://scripts/simulation/physiology_simulation.gd")
const BalanceScript = preload("res://scripts/simulation/physiology_balance.gd")

var _simulation: Node
var _energy_cell_collected := false
var _energy_cell_installed := false
var _air_intake_open := false
var _chambers_active := false
var _lung_sequence_error := false
var _lung_error_feedback_remaining := 0.0
var _valve_alignment := 0
var _pulmonary_route_requested := false
var _recovery_started := false
var _recovery_elapsed := 0.0
var _recovery_stage := "inactive"
var _snapshot: Dictionary = {}


func _init() -> void:
	reset()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_simulation):
		_simulation.free()


func reset() -> void:
	if is_instance_valid(_simulation):
		_simulation.free()
	_simulation = SimulationScript.new()
	_simulation.balance = _clarity_balance()
	_simulation.reset_model()
	_simulation.begin_birth()
	_energy_cell_collected = false
	_energy_cell_installed = false
	_air_intake_open = false
	_chambers_active = false
	_lung_sequence_error = false
	_lung_error_feedback_remaining = 0.0
	_valve_alignment = 0
	_pulmonary_route_requested = false
	_recovery_started = false
	_recovery_elapsed = 0.0
	_recovery_stage = "inactive"
	_publish_snapshot()


func step(delta: float) -> Dictionary:
	if delta > 0.0:
		var oxygen_before: float = _simulation.get_snapshot().oxygen
		_simulation.step(delta)
		var physiology_after: Dictionary = _simulation.get_snapshot()
		_update_recovery(delta, oxygen_before, physiology_after)
		_lung_error_feedback_remaining = maxf(0.0, _lung_error_feedback_remaining - delta)
		if is_zero_approx(_lung_error_feedback_remaining):
			_lung_sequence_error = false
	_publish_snapshot()
	return get_snapshot()


func collect_energy_cell() -> bool:
	if _energy_cell_collected or _energy_cell_installed:
		return false
	_energy_cell_collected = true
	_publish_snapshot()
	return true


func install_energy_cell() -> bool:
	if not _energy_cell_collected or _energy_cell_installed:
		return false
	_energy_cell_collected = false
	_energy_cell_installed = true
	_publish_snapshot()
	return true


func open_air_intake() -> bool:
	if not _energy_cell_installed or _air_intake_open:
		return false
	_air_intake_open = true
	_lung_sequence_error = false
	_lung_error_feedback_remaining = 0.0
	_publish_snapshot()
	return true


func activate_chambers() -> bool:
	if not _energy_cell_installed or _chambers_active:
		return false
	if not _air_intake_open:
		_lung_sequence_error = true
		_lung_error_feedback_remaining = 2.5
		_publish_snapshot()
		return false
	_chambers_active = true
	_simulation.activate_lungs()
	_publish_snapshot()
	return true


func rotate_pulmonary_valve() -> int:
	if _valve_alignment == 2:
		return _valve_alignment
	_valve_alignment = (_valve_alignment + 1) % 3
	if _valve_alignment == 2:
		_pulmonary_route_requested = true
		_simulation.redirect_blood_flow()
	_publish_snapshot()
	return _valve_alignment


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _update_recovery(
	delta: float,
	oxygen_before: float,
	physiology: Dictionary
) -> void:
	var just_started := false
	if (
		not _recovery_started
		and physiology.lung_activation >= 99.0
		and physiology.pulmonary_flow >= 99.0
		and physiology.lung_oxygen_contribution > physiology.oxygen_consumption
		and physiology.oxygen > oxygen_before + 0.001
	):
		_recovery_started = true
		_recovery_elapsed = 0.0
		_recovery_stage = "heart_pulse"
		just_started = true
	if _recovery_started and not just_started:
		_recovery_elapsed += delta
		if _recovery_elapsed < 2.0:
			_recovery_stage = "heart_pulse"
		elif _recovery_elapsed < 5.0:
			_recovery_stage = "oxygen_wave"
		elif _recovery_elapsed < 8.0:
			_recovery_stage = "district_relight"
		elif _recovery_elapsed < 10.0:
			_recovery_stage = "wide_restore"
		else:
			_recovery_stage = "complete"


func _clarity_balance() -> Resource:
	var result: Resource = BalanceScript.new()
	result.initial_oxygen = 92.0
	result.placental_decline_per_second = 0.25
	result.placenta_max_output = 7.0
	result.base_consumption = 4.6
	result.lung_max_output = 10.0
	result.lung_activation_seconds = 2.5
	result.pulmonary_flow_seconds = 2.5
	result.initial_pulmonary_flow = 5.0
	return result


func _publish_snapshot() -> void:
	var physiology: Dictionary = _simulation.get_snapshot()
	var lung_online: bool = physiology.lung_activation >= 99.0
	var flow_open: bool = physiology.pulmonary_flow >= 99.0
	var danger_state := "stable"
	if physiology.oxygen < 35.0:
		danger_state = "critical"
	elif physiology.oxygen < 65.0:
		danger_state = "mid"
	elif physiology.placental_supply < 80.0:
		danger_state = "early"
	_snapshot = physiology
	_snapshot.merge(
		{
			"energy_cell_collected": _energy_cell_collected,
			"energy_cell_installed": _energy_cell_installed,
			"air_intake_open": _air_intake_open,
			"chambers_active": _chambers_active,
			"lung_sequence_error": _lung_sequence_error,
			"lung_online": lung_online,
			"valve_alignment": _valve_alignment,
			"pulmonary_route_requested": _pulmonary_route_requested,
			"flow_open": flow_open,
			"trapped_oxygen": lung_online and not flow_open,
			"supply_chain_complete": lung_online and flow_open,
			"danger_state": danger_state,
			"emergency_recoverable": danger_state == "critical" and _recovery_stage != "complete",
			"recovery_started": _recovery_started,
			"recovery_elapsed": _recovery_elapsed,
			"recovery_stage": _recovery_stage,
			"city_recovered": _recovery_stage == "complete",
			"placental_route_retired": _recovery_started,
		},
		true
	)
	state_changed.emit(get_snapshot())
