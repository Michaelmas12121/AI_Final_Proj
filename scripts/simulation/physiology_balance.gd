class_name PhysiologyBalance
extends Resource

@export_category("Timing")
@export var birth_transition_seconds: float = 20.0
@export var birth_countdown_seconds: float = 3.0
@export var lung_activation_seconds: float = 4.0
@export var pulmonary_flow_seconds: float = 5.0
@export var critical_grace_seconds: float = 5.0
@export var intervention_hold_seconds: float = 1.1
@export var stabilization_safe_seconds: float = 25.0

@export_category("Oxygen thresholds")
@export var safe_oxygen: float = 55.0
@export var distress_oxygen: float = 45.0
@export var critical_oxygen: float = 25.0

@export_category("Supply and demand")
@export var placenta_max_output: float = 9.0
@export var placental_decline_per_second: float = 5.0
@export var lung_max_output: float = 15.0
@export var base_consumption: float = 8.0
@export var minimum_circulation_factor: float = 0.45

@export_category("Initial state")
@export var initial_oxygen: float = 82.0
@export var initial_circulation_efficiency: float = 85.0
@export var initial_body_demand: float = 100.0
@export var initial_pulmonary_flow: float = 5.0

@export_category("Preparation")
@export var preparation_budget: int = 2
@export var heart_preparation_efficiency_bonus: float = 10.0
@export var lung_preparation_speed_multiplier: float = 1.35
@export var energy_reserve_demand_multiplier: float = 0.76
@export var energy_reserve_seconds: float = 16.0

@export_category("Stabilization")
@export var stabilization_demand_multiplier: float = 1.18
@export var stabilization_demand_ramp_seconds: float = 5.0
@export var distribution_event_seconds: float = 8.0
@export var distribution_vital_priority_core: float = 65.0
@export var distribution_vital_priority_growth: float = 35.0
@export var distribution_growth_priority_core: float = 40.0
@export var distribution_growth_priority_growth: float = 60.0
@export var distribution_vital_event_core_need: float = 65.0
@export var distribution_vital_event_growth_need: float = 35.0
@export var distribution_growth_event_core_need: float = 40.0
@export var distribution_growth_event_growth_need: float = 60.0
@export var distribution_demand_multiplier: float = 1.08
@export var distribution_shortage_delivery_penalty: float = 2.0
@export var distribution_minimum_efficiency: float = 0.25
@export var district_neglect_failure_seconds: float = 7.5
@export var district_neglect_recovery_rate: float = 1.5

@export_category("Outcome requirements")
@export var success_placenta_maximum: float = 10.0
@export var success_lung_minimum: float = 80.0
@export var success_flow_minimum: float = 80.0
