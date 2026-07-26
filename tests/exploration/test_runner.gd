extends SceneTree

const ExplorationModelScript = preload(
	"res://experimental/body_city_exploration/exploration_model.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_test_placental_supply_declines_after_start()
	_test_lung_machine_requires_the_energy_cell()
	_test_either_single_task_leaves_the_supply_chain_incomplete()
	_test_completing_both_tasks_restores_simulated_oxygen()
	_test_reset_restores_the_disposable_experiment()
	if _failures.is_empty():
		print("PASS: 5 exploration prototype scenarios")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_placental_supply_declines_after_start() -> void:
	var model = ExplorationModelScript.new()
	var initial_state: Dictionary = model.get_snapshot()
	model.step(10.0)
	var later_state: Dictionary = model.get_snapshot()
	_expect(
		later_state.placental_supply < initial_state.placental_supply,
		"Exploration time should reduce placental supply."
	)
	model.free()


func _test_lung_machine_requires_the_energy_cell() -> void:
	var model = ExplorationModelScript.new()
	_expect(
		not model.activate_lung_machine(),
		"The lung machine should reject activation before the energy cell is collected."
	)
	_expect(model.collect_energy_cell(), "The loose energy cell should be collectible once.")
	_expect(model.activate_lung_machine(), "Carrying the energy cell should activate the lung machine.")
	_expect(
		model.get_snapshot().energy_cell_installed,
		"The installed cell should be visible through the model interface."
	)
	model.free()


func _test_either_single_task_leaves_the_supply_chain_incomplete() -> void:
	var lungs_only = ExplorationModelScript.new()
	lungs_only.collect_energy_cell()
	lungs_only.activate_lung_machine()
	lungs_only.step(3.0)
	var lungs_state: Dictionary = lungs_only.get_snapshot()
	_expect(
		not lungs_state.supply_chain_complete
		and lungs_state.get("chain_state", "missing") == "air_waiting_for_blood",
		"Lungs alone should leave oxygen waiting for a blood route."
	)
	lungs_only.free()

	var flow_only = ExplorationModelScript.new()
	flow_only.open_pulmonary_route()
	flow_only.step(3.0)
	var flow_state: Dictionary = flow_only.get_snapshot()
	_expect(
		not flow_state.supply_chain_complete
		and flow_state.get("chain_state", "missing") == "route_waiting_for_air",
		"An open blood route alone should still wait for the lungs."
	)
	flow_only.free()


func _test_completing_both_tasks_restores_simulated_oxygen() -> void:
	var model = ExplorationModelScript.new()
	model.step(180.0)
	var oxygen_before_repair: float = model.get_snapshot().oxygen
	model.collect_energy_cell()
	model.activate_lung_machine()
	model.open_pulmonary_route()
	model.step(12.0)
	var repaired_state: Dictionary = model.get_snapshot()
	_expect(
		repaired_state.supply_chain_complete
		and repaired_state.oxygen > oxygen_before_repair
		and repaired_state.city_recovered,
		"Completing both physical tasks should restore oxygen and recover the city."
	)
	model.free()


func _test_reset_restores_the_disposable_experiment() -> void:
	var model = ExplorationModelScript.new()
	model.collect_energy_cell()
	model.activate_lung_machine()
	model.open_pulmonary_route()
	model.step(12.0)
	model.reset()
	var state: Dictionary = model.get_snapshot()
	_expect(
		not state.energy_cell_collected
		and not state.energy_cell_installed
		and not state.pulmonary_route_requested
		and not state.supply_chain_complete
		and is_equal_approx(state.placental_supply, 100.0),
		"Reset should restore the exploration puzzle and placental supply."
	)
	model.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
