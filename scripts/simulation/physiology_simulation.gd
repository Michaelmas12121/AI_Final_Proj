class_name PhysiologySimulation
extends Node

signal state_changed(snapshot: Dictionary)

const BalanceScript = preload("res://scripts/simulation/physiology_balance.gd")

@export var balance: Resource

var oxygen: float
var placental_supply: float
var lung_activation: float
var pulmonary_flow: float
var circulation_efficiency: float
var body_demand: float

var placental_oxygen_contribution: float
var lung_oxygen_capacity: float
var lung_oxygen_contribution: float
var oxygen_consumption: float
var critical_state_timer: float
var birth_elapsed: float
var energy_reserve_remaining: float
var stabilization_elapsed: float
var vital_core_allocation: float
var growing_body_allocation: float
var vital_core_need: float
var growing_body_need: float
var vital_core_neglect: float
var growing_body_neglect: float
var distribution_efficiency: float
var distribution_priority: String
var distribution_event: String

var _birth_started := false
var _stabilization_started := false
var _lungs_requested := false
var _flow_requested := false
var _base_body_demand: float
var _preparation_choices: Array[String] = []
var _snapshot: Dictionary = {}


func _ready() -> void:
	if balance == null:
		balance = BalanceScript.new()
	reset_model()


func reset_model() -> void:
	if balance == null:
		balance = BalanceScript.new()
	oxygen = balance.initial_oxygen
	placental_supply = 100.0
	lung_activation = 0.0
	pulmonary_flow = balance.initial_pulmonary_flow
	circulation_efficiency = balance.initial_circulation_efficiency
	body_demand = balance.initial_body_demand
	_base_body_demand = balance.initial_body_demand
	placental_oxygen_contribution = 0.0
	lung_oxygen_capacity = 0.0
	lung_oxygen_contribution = 0.0
	oxygen_consumption = 0.0
	critical_state_timer = 0.0
	birth_elapsed = 0.0
	energy_reserve_remaining = 0.0
	stabilization_elapsed = 0.0
	vital_core_allocation = 0.0
	growing_body_allocation = 0.0
	vital_core_need = 0.0
	growing_body_need = 0.0
	vital_core_neglect = 0.0
	growing_body_neglect = 0.0
	distribution_efficiency = 1.0
	distribution_priority = "unassigned"
	distribution_event = "inactive"
	_birth_started = false
	_stabilization_started = false
	_lungs_requested = false
	_flow_requested = false
	_preparation_choices.clear()
	_recalculate_rates()
	_publish_snapshot()


func begin_birth() -> void:
	_birth_started = true
	if _preparation_choices.has("energy"):
		energy_reserve_remaining = balance.energy_reserve_seconds


func begin_stabilization() -> void:
	_stabilization_started = true
	stabilization_elapsed = 0.0
	placental_supply = 0.0
	vital_core_allocation = 0.0
	growing_body_allocation = 0.0
	distribution_priority = "unassigned"
	_update_distribution_state(0.0)
	_recalculate_rates()
	_publish_snapshot()


func choose_preparation(choice: String) -> bool:
	if _birth_started:
		return false
	if not choice in ["heart", "lungs", "energy"]:
		return false
	if _preparation_choices.has(choice):
		return false
	if _preparation_choices.size() >= balance.preparation_budget:
		return false

	_preparation_choices.append(choice)
	if choice == "heart":
		circulation_efficiency = minf(
			100.0,
			circulation_efficiency + balance.heart_preparation_efficiency_bonus
		)
	_publish_snapshot()
	return true


func activate_lungs() -> void:
	_lungs_requested = true


func redirect_blood_flow() -> void:
	_flow_requested = true


func set_oxygen_priority(priority: String) -> bool:
	if not _stabilization_started:
		return false
	if priority == "vital":
		vital_core_allocation = balance.distribution_vital_priority_core
		growing_body_allocation = balance.distribution_vital_priority_growth
	elif priority == "growth":
		vital_core_allocation = balance.distribution_growth_priority_core
		growing_body_allocation = balance.distribution_growth_priority_growth
	else:
		return false
	distribution_priority = priority
	_update_distribution_state(0.0)
	_recalculate_rates()
	_publish_snapshot()
	return true


func add_oxygen(amount: float) -> void:
	oxygen = clampf(oxygen + amount, 0.0, 100.0)
	_publish_snapshot()


func adjust_body_demand(amount: float) -> void:
	_base_body_demand = clampf(_base_body_demand + amount, 40.0, 180.0)
	body_demand = _base_body_demand
	_publish_snapshot()


func step(delta: float) -> Dictionary:
	if delta <= 0.0:
		return get_snapshot()

	if _birth_started:
		birth_elapsed += delta
		placental_supply = maxf(
			0.0,
			100.0 - balance.placental_decline_per_second * birth_elapsed
		)

	if energy_reserve_remaining > 0.0:
		energy_reserve_remaining = maxf(0.0, energy_reserve_remaining - delta)

	if _stabilization_started:
		placental_supply = 0.0
		_update_distribution_state(delta)
		stabilization_elapsed += delta

	var demand_target := _base_body_demand
	if energy_reserve_remaining > 0.0:
		demand_target *= balance.energy_reserve_demand_multiplier
	elif _stabilization_started:
		demand_target *= (
			balance.stabilization_demand_multiplier
			* balance.distribution_demand_multiplier
		)
	var demand_ramp_rate: float = (
		_base_body_demand * balance.stabilization_demand_multiplier
		/ balance.stabilization_demand_ramp_seconds
	)
	body_demand = move_toward(body_demand, demand_target, demand_ramp_rate * delta)

	if _lungs_requested:
		var lung_speed_multiplier: float = (
			balance.lung_preparation_speed_multiplier
			if _preparation_choices.has("lungs")
			else 1.0
		)
		lung_activation = move_toward(
			lung_activation,
			100.0,
			100.0 * delta * lung_speed_multiplier / balance.lung_activation_seconds
		)

	if _flow_requested:
		pulmonary_flow = move_toward(
			pulmonary_flow,
			100.0,
			100.0 * delta / balance.pulmonary_flow_seconds
		)

	_recalculate_rates()
	var oxygen_delta := (
		(placental_oxygen_contribution + lung_oxygen_contribution)
		* _circulation_factor()
		- oxygen_consumption
	)
	oxygen = clampf(oxygen + oxygen_delta * delta, 0.0, 100.0)

	if oxygen < balance.critical_oxygen:
		critical_state_timer += delta
	else:
		critical_state_timer = maxf(0.0, critical_state_timer - delta * 2.0)

	_publish_snapshot()
	return get_snapshot()


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func is_birth_started() -> bool:
	return _birth_started


func _recalculate_rates() -> void:
	placental_oxygen_contribution = (
		placental_supply / 100.0 * balance.placenta_max_output
	)
	lung_oxygen_capacity = (
		lung_activation / 100.0
		* pulmonary_flow / 100.0
		* balance.lung_max_output
	)
	lung_oxygen_contribution = (
		lung_oxygen_capacity * distribution_efficiency
		if _stabilization_started
		else lung_oxygen_capacity
	)
	oxygen_consumption = body_demand / 100.0 * balance.base_consumption


func _update_distribution_state(delta: float) -> void:
	var event_index := int(
		floor(stabilization_elapsed / balance.distribution_event_seconds)
	) % 2
	if event_index == 0:
		distribution_event = "vital_surge"
		vital_core_need = balance.distribution_vital_event_core_need
		growing_body_need = balance.distribution_vital_event_growth_need
	else:
		distribution_event = "growth_surge"
		vital_core_need = balance.distribution_growth_event_core_need
		growing_body_need = balance.distribution_growth_event_growth_need

	var vital_shortage := maxf(0.0, vital_core_need - vital_core_allocation) / 100.0
	var growth_shortage := maxf(0.0, growing_body_need - growing_body_allocation) / 100.0
	distribution_efficiency = clampf(
		1.0 - (
			vital_shortage + growth_shortage
		) * balance.distribution_shortage_delivery_penalty,
		balance.distribution_minimum_efficiency,
		1.0
	)

	if vital_shortage > 0.001:
		vital_core_neglect += delta
	else:
		vital_core_neglect = maxf(
			0.0,
			vital_core_neglect - delta * balance.district_neglect_recovery_rate
		)
	if growth_shortage > 0.001:
		growing_body_neglect += delta
	else:
		growing_body_neglect = maxf(
			0.0,
			growing_body_neglect - delta * balance.district_neglect_recovery_rate
		)


func _circulation_factor() -> float:
	var normalized := circulation_efficiency / 100.0
	return lerpf(balance.minimum_circulation_factor, 1.0, normalized)


func _oxygen_status() -> String:
	if oxygen < balance.critical_oxygen:
		return "critical"
	if oxygen < balance.distress_oxygen:
		return "distress"
	if oxygen < balance.safe_oxygen:
		return "falling"
	return "healthy"


func _publish_snapshot() -> void:
	_snapshot = {
		"oxygen": oxygen,
		"placental_supply": placental_supply,
		"lung_activation": lung_activation,
		"pulmonary_flow": pulmonary_flow,
		"circulation_efficiency": circulation_efficiency,
		"body_demand": body_demand,
		"placental_oxygen_contribution": placental_oxygen_contribution,
		"lung_oxygen_capacity": lung_oxygen_capacity,
		"lung_oxygen_contribution": lung_oxygen_contribution,
		"oxygen_consumption": oxygen_consumption,
		"critical_state_timer": critical_state_timer,
		"birth_elapsed": birth_elapsed,
		"energy_reserve_remaining": energy_reserve_remaining,
		"stabilization_elapsed": stabilization_elapsed,
		"vital_core_allocation": vital_core_allocation,
		"growing_body_allocation": growing_body_allocation,
		"vital_core_need": vital_core_need,
		"growing_body_need": growing_body_need,
		"vital_core_neglect": vital_core_neglect,
		"growing_body_neglect": growing_body_neglect,
		"distribution_efficiency": distribution_efficiency,
		"distribution_priority": distribution_priority,
		"distribution_event": distribution_event,
		"birth_started": _birth_started,
		"stabilization_started": _stabilization_started,
		"preparation_choices": _preparation_choices.duplicate(),
		"preparation_budget_remaining": (
			balance.preparation_budget - _preparation_choices.size()
		),
		"oxygen_status": _oxygen_status(),
	}
	state_changed.emit(get_snapshot())
