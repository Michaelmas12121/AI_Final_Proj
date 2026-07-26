extends SceneTree

const ClarityModelScript = preload(
	"res://experimental/body_city_exploration_clarity/clarity_model.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_test_installing_energy_cell_does_not_activate_lungs()
	_test_air_intake_must_open_before_the_chambers()
	_test_valve_alignment_controls_actual_pulmonary_flow()
	_test_recovery_sequence_waits_for_real_oxygen_recovery()
	_test_restart_clears_all_clarity_and_presentation_state()
	_test_critical_city_remains_recoverable()
	if _failures.is_empty():
		print("PASS: 6 gameplay clarity scenarios")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_installing_energy_cell_does_not_activate_lungs() -> void:
	var model = ClarityModelScript.new()
	_expect(model.collect_energy_cell(), "The clarity puzzle should retain the portable cell.")
	_expect(model.install_energy_cell(), "The carried cell should install in the lung console.")
	model.step(3.0)
	var state: Dictionary = model.get_snapshot()
	_expect(
		state.energy_cell_installed
		and not state.air_intake_open
		and not state.chambers_active
		and is_zero_approx(state.lung_activation),
		"Installing power alone must leave the lung machinery dormant."
	)
	model.free()


func _test_air_intake_must_open_before_the_chambers() -> void:
	var model = ClarityModelScript.new()
	model.collect_energy_cell()
	model.install_energy_cell()
	_expect(
		not model.activate_chambers(),
		"Closed air intake should make early chamber activation fail readably."
	)
	model.step(1.0)
	var incorrect_state: Dictionary = model.get_snapshot()
	_expect(
		incorrect_state.lung_sequence_error
		and is_zero_approx(incorrect_state.lung_activation),
		"Incorrect sequence should expose feedback without producing oxygen."
	)
	_expect(model.open_air_intake(), "The powered intake should open.")
	_expect(model.activate_chambers(), "Open intake should allow chamber activation.")
	model.step(3.0)
	var active_state: Dictionary = model.get_snapshot()
	_expect(
		active_state.air_intake_open
		and active_state.chambers_active
		and active_state.lung_online
		and active_state.lung_activation >= 99.0,
		"Correct physical sequence should change actual lung state."
	)
	model.free()


func _test_valve_alignment_controls_actual_pulmonary_flow() -> void:
	var model = ClarityModelScript.new()
	_activate_lungs_correctly(model)
	model.step(3.0)
	var trapped_state: Dictionary = model.get_snapshot()
	_expect(
		trapped_state.lung_online
		and trapped_state.trapped_oxygen
		and not trapped_state.flow_open,
		"Active lungs without an aligned valve should visibly trap oxygen."
	)
	_expect(
		model.rotate_pulmonary_valve() == 1,
		"First valve rotation should expose an incorrect intermediate route."
	)
	model.step(3.0)
	var incorrect_state: Dictionary = model.get_snapshot()
	_expect(
		incorrect_state.valve_alignment == 1
		and not incorrect_state.flow_open
		and incorrect_state.pulmonary_flow < 10.0,
		"Incorrect valve alignment must not change actual blood-flow state."
	)
	_expect(
		model.rotate_pulmonary_valve() == 2,
		"Second rotation should align the lung-to-heart route."
	)
	model.step(3.0)
	var aligned_state: Dictionary = model.get_snapshot()
	_expect(
		aligned_state.valve_alignment == 2
		and aligned_state.flow_open
		and aligned_state.pulmonary_flow >= 99.0,
		"Correct valve alignment must open actual pulmonary flow."
	)
	model.free()


func _test_recovery_sequence_waits_for_real_oxygen_recovery() -> void:
	var model = ClarityModelScript.new()
	model.step(180.0)
	var oxygen_before_repairs: float = model.get_snapshot().oxygen
	_activate_lungs_correctly(model)
	model.rotate_pulmonary_valve()
	model.rotate_pulmonary_valve()
	_expect(
		not model.get_snapshot().get("recovery_started", false),
		"Repair inputs alone must not play the recovery sequence."
	)
	for index in range(80):
		model.step(0.1)
		if model.get_snapshot().get("recovery_started", false):
			break
	var recovery_state: Dictionary = model.get_snapshot()
	_expect(
		recovery_state.get("recovery_started", false)
		and recovery_state.oxygen > oxygen_before_repairs
		and recovery_state.lung_oxygen_contribution > recovery_state.oxygen_consumption,
		"Recovery should begin only after the repaired simulation is restoring oxygen."
	)
	model.step(10.1)
	var complete_state: Dictionary = model.get_snapshot()
	_expect(
		complete_state.get("recovery_stage", "") == "complete"
		and complete_state.get("city_recovered", false),
		"The state-driven recovery sequence should complete after roughly ten seconds."
	)
	model.free()


func _test_restart_clears_all_clarity_and_presentation_state() -> void:
	var model = ClarityModelScript.new()
	model.collect_energy_cell()
	model.install_energy_cell()
	model.activate_chambers()
	model.open_air_intake()
	model.activate_chambers()
	model.rotate_pulmonary_valve()
	model.rotate_pulmonary_valve()
	model.step(12.0)
	model.reset()
	var state: Dictionary = model.get_snapshot()
	_expect(
		not state.energy_cell_collected
		and not state.energy_cell_installed
		and not state.air_intake_open
		and not state.chambers_active
		and not state.lung_sequence_error
		and state.valve_alignment == 0
		and not state.pulmonary_route_requested
		and not state.recovery_started
		and state.recovery_stage == "inactive"
		and is_equal_approx(state.placental_supply, 100.0),
		"Restart should clear every new puzzle and recovery presentation state."
	)
	model.free()


func _test_critical_city_remains_recoverable() -> void:
	var model = ClarityModelScript.new()
	model.step(260.0)
	var critical_state: Dictionary = model.get_snapshot()
	_expect(
		critical_state.oxygen < 35.0
		and critical_state.danger_state == "critical"
		and critical_state.get("emergency_recoverable", false),
		"Critical oxygen should create a recoverable emergency, not an immediate failure."
	)
	_activate_lungs_correctly(model)
	model.rotate_pulmonary_valve()
	model.rotate_pulmonary_valve()
	for index in range(300):
		model.step(0.1)
		if model.get_snapshot().oxygen >= 65.0:
			break
	var recovered_state: Dictionary = model.get_snapshot()
	_expect(
		recovered_state.oxygen >= 65.0
		and recovered_state.recovery_started,
		"Correct physical repairs should recover a city that reached critical oxygen."
	)
	model.free()


func _activate_lungs_correctly(model: Node) -> void:
	model.collect_energy_cell()
	model.install_energy_cell()
	model.open_air_intake()
	model.activate_chambers()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
