class_name ExplorationModel
extends Node

signal state_changed(snapshot: Dictionary)

const SimulationScript = preload("res://scripts/simulation/physiology_simulation.gd")
const BalanceScript = preload("res://scripts/simulation/physiology_balance.gd")

var _simulation: Node
var _energy_cell_collected := false
var _energy_cell_installed := false
var _pulmonary_route_requested := false
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
	_simulation.balance = _exploration_balance()
	_simulation.reset_model()
	_simulation.begin_birth()
	_energy_cell_collected = false
	_energy_cell_installed = false
	_pulmonary_route_requested = false
	_publish_snapshot()


func step(delta: float) -> Dictionary:
	if delta > 0.0:
		_simulation.step(delta)
	_publish_snapshot()
	return get_snapshot()


func collect_energy_cell() -> bool:
	if _energy_cell_collected or _energy_cell_installed:
		return false
	_energy_cell_collected = true
	_publish_snapshot()
	return true


func activate_lung_machine() -> bool:
	if not _energy_cell_collected or _energy_cell_installed:
		return false
	_energy_cell_collected = false
	_energy_cell_installed = true
	_simulation.activate_lungs()
	_publish_snapshot()
	return true


func open_pulmonary_route() -> bool:
	if _pulmonary_route_requested:
		return false
	_pulmonary_route_requested = true
	_simulation.redirect_blood_flow()
	_publish_snapshot()
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _exploration_balance() -> Resource:
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
	var chain_state := "placental_support"
	if lung_online and flow_open:
		chain_state = "complete"
	elif lung_online:
		chain_state = "air_waiting_for_blood"
	elif flow_open:
		chain_state = "route_waiting_for_air"
	_snapshot = physiology
	_snapshot.merge(
		{
			"energy_cell_collected": _energy_cell_collected,
			"energy_cell_installed": _energy_cell_installed,
			"pulmonary_route_requested": _pulmonary_route_requested,
			"lung_online": lung_online,
			"flow_open": flow_open,
			"chain_state": chain_state,
			"supply_chain_complete": lung_online and flow_open,
			"city_recovered": lung_online and flow_open and physiology.oxygen >= 80.0,
		},
		true
	)
	state_changed.emit(get_snapshot())
