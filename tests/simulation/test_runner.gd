extends SceneTree

const SimulationScript = preload("res://scripts/simulation/physiology_simulation.gd")
const DirectorScript = preload("res://scripts/core/run_director.gd")
const BalanceResource = preload("res://data/balance/physiology_balance.tres")

var _failures: Array[String] = []


func _init() -> void:
	_test_prebirth_supply_keeps_oxygen_stable()
	_test_no_action_after_birth_fails()
	_test_lung_activation_alone_fails()
	_test_flow_redirection_alone_fails()
	_test_lungs_and_flow_together_succeed()
	_test_failure_waits_for_critical_grace_period()
	_test_restart_restores_prebirth_state()
	_test_preparation_budget_allows_two_distinct_choices()
	_test_well_prepared_timely_run_succeeds()
	_test_unprepared_late_run_enters_distress()
	_test_lung_preparation_still_requires_pulmonary_flow()
	_test_energy_reserve_temporarily_lowers_demand_then_expires()
	_test_post_birth_stabilization_completes_before_success()
	_test_post_birth_destabilization_can_fail()
	_test_repeated_action_inputs_do_not_stack()
	_test_summary_metrics_match_the_simulated_run()
	_test_contextual_prompts_identify_the_current_bottleneck()
	_test_tutorial_guidance_follows_live_physiology()
	_test_tutorial_toggle_persists_across_restart()
	_test_oxygen_distribution_changes_delivery()
	_test_oxygen_distribution_is_zero_sum()
	_test_vital_core_cannot_be_neglected_indefinitely()
	_test_growing_body_cannot_be_neglected_indefinitely()
	_test_passive_stabilization_fails_without_distribution()
	_test_success_is_achievable_with_every_preparation_combination()
	_test_safe_timer_resets_below_fifty_five()
	_test_restart_resets_distribution_and_presentation_state()
	_test_tutorial_never_performs_distribution_decisions()
	if _failures.is_empty():
		print("PASS: 28 deterministic simulation scenarios")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_prebirth_supply_keeps_oxygen_stable() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	simulation.reset_model()
	var starting_oxygen: float = simulation.get_snapshot().oxygen
	for index in range(100):
		simulation.step(0.1)
	var ending_oxygen: float = simulation.get_snapshot().oxygen
	_expect(absf(ending_oxygen - starting_oxygen) < 5.0, "Placental supply should keep pre-birth oxygen stable.")
	simulation.free()


func _test_no_action_after_birth_fails() -> void:
	var result := _run_birth_scenario(false, false)
	_expect(result == "FAILURE", "Taking no action after birth should fail.")


func _test_lung_activation_alone_fails() -> void:
	var result := _run_birth_scenario(true, false)
	_expect(result == "FAILURE", "Lung activation without pulmonary flow should fail.")


func _test_flow_redirection_alone_fails() -> void:
	var result := _run_birth_scenario(false, true)
	_expect(result == "FAILURE", "Pulmonary flow without lung activation should fail.")


func _test_lungs_and_flow_together_succeed() -> void:
	var result := _run_birth_scenario(true, true)
	_expect(result == "SUCCESS", "Lung activation plus pulmonary flow should succeed.")


func _test_failure_waits_for_critical_grace_period() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.begin_birth()
	director.add_oxygen(-100.0)
	director.step(BalanceResource.critical_grace_seconds - 0.1)
	_expect(
		director.get_snapshot().phase == "TRANSITION",
		"Critical oxygen should not cause immediate failure."
	)
	director.step(0.2)
	_expect(
		director.get_snapshot().phase == "FAILURE",
		"Critical oxygen should fail after the grace period."
	)
	director.free()
	simulation.free()


func _test_restart_restores_prebirth_state() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.choose_preparation("lungs")
	director.choose_preparation("energy")
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	director.activate_lungs()
	director.redirect_blood_flow()
	for index in range(100):
		director.step(0.1)
	director.restart()
	var state: Dictionary = director.get_snapshot()
	_expect(state.phase == "PRE_BIRTH", "Restart should return to the pre-birth phase.")
	_expect(is_equal_approx(state.oxygen, BalanceResource.initial_oxygen), "Restart should restore oxygen.")
	_expect(is_equal_approx(state.placental_supply, 100.0), "Restart should restore placental supply.")
	_expect(is_zero_approx(state.lung_activation), "Restart should deactivate the lungs.")
	_expect(
		is_equal_approx(state.pulmonary_flow, BalanceResource.initial_pulmonary_flow),
		"Restart should restore fetal pulmonary flow."
	)
	_expect(state.preparation_choices.is_empty(), "Restart should clear preparation choices.")
	_expect(
		state.preparation_budget_remaining == BalanceResource.preparation_budget,
		"Restart should restore the preparation budget."
	)
	_expect(is_zero_approx(state.birth_elapsed), "Restart should clear birth timers.")
	_expect(is_zero_approx(state.metrics.distress_time), "Restart should clear distress metrics.")
	_expect(state.metrics.lung_activation_time < 0.0, "Restart should clear intervention times.")
	director.free()
	simulation.free()


func _test_preparation_budget_allows_two_distinct_choices() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	simulation.reset_model()
	var chose_heart: bool = simulation.choose_preparation("heart")
	var chose_lungs: bool = simulation.choose_preparation("lungs")
	var chose_energy: bool = simulation.choose_preparation("energy")
	var state: Dictionary = simulation.get_snapshot()
	_expect(chose_heart, "The first preparation choice should be accepted.")
	_expect(chose_lungs, "The second preparation choice should be accepted.")
	_expect(not chose_energy, "The third preparation choice should exceed the budget.")
	_expect(state.preparation_choices.size() == 2, "Exactly two preparation choices should be stored.")
	_expect(state.preparation_budget_remaining == 0, "Preparation budget should be exhausted.")
	simulation.free()


func _test_well_prepared_timely_run_succeeds() -> void:
	var result := _run_prepared_scenario(["lungs", "energy"], 0.0, true, true)
	_expect(result == "SUCCESS", "A well-prepared run with timely interventions should succeed.")


func _test_unprepared_late_run_enters_distress() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.begin_birth()
	for index in range(31 + 160):
		director.step(0.1)
	director.activate_lungs()
	director.redirect_blood_flow()
	for index in range(10):
		director.step(0.1)
	var state: Dictionary = director.get_snapshot()
	_expect(
		state.metrics.distress_time > 0.0,
		"An unprepared run with late interventions should enter visible distress."
	)
	director.free()
	simulation.free()


func _test_lung_preparation_still_requires_pulmonary_flow() -> void:
	var result := _run_prepared_scenario(["lungs"], 0.0, true, false)
	_expect(
		result == "FAILURE",
		"Lung preparation must not remove the need to redirect pulmonary flow."
	)


func _test_energy_reserve_temporarily_lowers_demand_then_expires() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	simulation.reset_model()
	simulation.choose_preparation("energy")
	simulation.begin_birth()
	simulation.step(1.0)
	var reserved_demand: float = simulation.get_snapshot().body_demand
	for index in range(int(BalanceResource.energy_reserve_seconds) + 8):
		simulation.step(1.0)
	var expired_state: Dictionary = simulation.get_snapshot()
	_expect(
		reserved_demand < BalanceResource.initial_body_demand,
		"Energy reserve should lower demand during the dangerous transition."
	)
	_expect(
		is_equal_approx(expired_state.energy_reserve_remaining, 0.0),
		"Energy reserve should expire."
	)
	_expect(
		expired_state.body_demand >= BalanceResource.initial_body_demand - 0.1,
		"Demand should return after the energy reserve expires."
	)
	simulation.free()


func _test_post_birth_stabilization_completes_before_success() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.choose_preparation("lungs")
	director.choose_preparation("energy")
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	director.activate_lungs()
	director.redirect_blood_flow()
	var entered_stabilization := false
	for index in range(900):
		_respond_to_distribution(director)
		director.step(0.1)
		var phase: String = director.get_snapshot().phase
		if phase == "STABILIZATION":
			entered_stabilization = true
		if phase == "SUCCESS":
			break
	_expect(entered_stabilization, "A successful run should enter post-birth stabilization.")
	_expect(
		director.get_snapshot().phase == "SUCCESS",
		"Safe oxygen throughout stabilization should complete the run."
	)
	director.free()
	simulation.free()


func _test_post_birth_destabilization_can_fail() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.choose_preparation("lungs")
	director.choose_preparation("energy")
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	director.activate_lungs()
	director.redirect_blood_flow()
	for index in range(400):
		director.step(0.1)
		if director.get_snapshot().phase == "STABILIZATION":
			break
	_expect(
		director.get_snapshot().phase == "STABILIZATION",
		"Test setup should reach stabilization."
	)
	director.add_oxygen(-100.0)
	for index in range(60):
		director.step(0.1)
		if director.get_snapshot().phase == "FAILURE":
			break
	_expect(
		director.get_snapshot().phase == "FAILURE",
		"Sustained critical oxygen during stabilization should still fail."
	)
	director.free()
	simulation.free()


func _test_repeated_action_inputs_do_not_stack() -> void:
	var single = SimulationScript.new()
	single.balance = BalanceResource
	single.reset_model()
	single.begin_birth()
	single.activate_lungs()
	single.redirect_blood_flow()
	single.step(1.0)

	var repeated = SimulationScript.new()
	repeated.balance = BalanceResource
	repeated.reset_model()
	repeated.begin_birth()
	for index in range(20):
		repeated.activate_lungs()
		repeated.redirect_blood_flow()
	repeated.step(1.0)

	_expect(
		is_equal_approx(single.get_snapshot().lung_activation, repeated.get_snapshot().lung_activation),
		"Repeated lung inputs should not accelerate activation."
	)
	_expect(
		is_equal_approx(single.get_snapshot().pulmonary_flow, repeated.get_snapshot().pulmonary_flow),
		"Repeated flow inputs should not accelerate redirection."
	)
	single.free()
	repeated.free()


func _test_summary_metrics_match_the_simulated_run() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.choose_preparation("heart")
	director.choose_preparation("lungs")
	var observed_lowest: float = director.get_snapshot().oxygen
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
		observed_lowest = minf(observed_lowest, director.get_snapshot().oxygen)
	director.activate_lungs()
	director.redirect_blood_flow()
	for index in range(900):
		_respond_to_distribution(director)
		director.step(0.1)
		var state: Dictionary = director.get_snapshot()
		observed_lowest = minf(observed_lowest, state.oxygen)
		if state.phase == "SUCCESS" or state.phase == "FAILURE":
			break
	var summary: Dictionary = director.get_snapshot()
	_expect(summary.phase == "SUCCESS", "Summary test setup should complete successfully.")
	_expect(
		is_equal_approx(summary.metrics.lowest_oxygen, observed_lowest),
		"Summary lowest oxygen should match the simulated minimum."
	)
	_expect(
		summary.metrics.preparation_choices == ["heart", "lungs"],
		"Summary should report the selected preparations."
	)
	_expect(summary.metrics.lung_activation_time >= 0.0, "Summary should record lung timing.")
	_expect(summary.metrics.flow_redirection_time >= 0.0, "Summary should record flow timing.")
	director.free()
	simulation.free()


func _test_contextual_prompts_identify_the_current_bottleneck() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	_expect(
		director.get_snapshot().context_code == "LUNGS_INACTIVE",
		"Context should identify inactive lungs first."
	)
	director.activate_lungs()
	for index in range(45):
		director.step(0.1)
	_expect(
		director.get_snapshot().context_code == "FLOW_LOW",
		"Context should identify low pulmonary flow after lung activation."
	)
	director.redirect_blood_flow()
	for index in range(60):
		director.step(0.1)
	var recovered_context: String = director.get_snapshot().context_code
	_expect(
		recovered_context == "PULMONARY_TAKEOVER" or recovered_context == "MONITOR",
		"Context should acknowledge pulmonary takeover once both interventions work."
	)
	director.free()
	simulation.free()


func _test_tutorial_guidance_follows_live_physiology() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	var state: Dictionary = director.get_snapshot()
	_expect(state.get("tutorial_step", "") == "PRE_BIRTH", "Tutorial should begin before birth.")
	_expect(
		state.get("onboarding_message", "").contains("placenta supplies oxygen"),
		"Pre-birth guidance should explain the oxygen-source handoff."
	)

	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	state = director.get_snapshot()
	_expect(
		state.get("tutorial_step", "") == "IDENTIFY_PLACENTA",
		"Tutorial should first identify fading placental support."
	)

	for index in range(11):
		director.step(0.1)
	state = director.get_snapshot()
	_expect(
		state.get("tutorial_step", "") == "ACTIVATE_LUNGS",
		"Fading placental supply should reveal the lung objective."
	)
	_expect(
		state.get("objective_action", "") == "lungs",
		"The live lung objective should highlight Activate Lungs."
	)
	_expect(
		state.metrics.lung_activation_time < 0.0 and is_zero_approx(state.lung_activation),
		"Tutorial guidance must not activate the lungs for the player."
	)

	director.activate_lungs()
	director.step(0.1)
	state = director.get_snapshot()
	_expect(
		state.get("tutorial_step", "") == "REDIRECT_FLOW",
		"Lung activation without flow should teach the missing blood connection."
	)
	_expect(
		state.get("objective_action", "") == "flow",
		"The low-flow objective should highlight Redirect Blood Flow."
	)
	_expect(
		state.metrics.flow_redirection_time < 0.0,
		"Tutorial guidance must not redirect blood flow for the player."
	)
	director.redirect_blood_flow()
	director.step(1.0)
	state = director.get_snapshot()
	_expect(
		state.get("objective_action", "unexpected").is_empty(),
		"Committed interventions should clear action highlighting."
	)
	_expect(
		state.get("causal_chain_focus", "") == "blood",
		"Low pulmonary flow should keep the causal chain focused on blood."
	)
	director.free()
	simulation.free()


func _test_tutorial_toggle_persists_across_restart() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.set_tutorial_enabled(false)
	var state: Dictionary = director.get_snapshot()
	_expect(not state.get("tutorial_enabled", true), "Tutorial toggle should disable guidance.")
	_expect(state.get("tutorial_step", "") == "OFF", "Disabled tutorial should report no guided step.")
	_expect(
		state.get("objective_action", "unexpected").is_empty(),
		"Disabled tutorial should not highlight an intervention."
	)
	director.restart()
	_expect(
		not director.get_snapshot().get("tutorial_enabled", true),
		"Tutorial preference should persist for later runs."
	)
	director.free()
	simulation.free()


func _test_oxygen_distribution_changes_delivery() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	simulation.reset_model()
	simulation.begin_birth()
	simulation.activate_lungs()
	simulation.redirect_blood_flow()
	simulation.step(6.0)
	simulation.begin_stabilization()

	simulation.set_oxygen_priority("vital")
	simulation.step(0.1)
	var vital_state: Dictionary = simulation.get_snapshot()
	simulation.set_oxygen_priority("growth")
	simulation.step(0.1)
	var growth_state: Dictionary = simulation.get_snapshot()

	_expect(
		growth_state.lung_oxygen_contribution < vital_state.lung_oxygen_contribution,
		"Wrong distribution for the live demand should reduce effective oxygen delivery."
	)
	simulation.free()


func _test_oxygen_distribution_is_zero_sum() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	simulation.reset_model()
	simulation.begin_stabilization()
	simulation.set_oxygen_priority("vital")
	var vital_state: Dictionary = simulation.get_snapshot()
	simulation.set_oxygen_priority("growth")
	var growth_state: Dictionary = simulation.get_snapshot()
	_expect(
		is_equal_approx(
			vital_state.vital_core_allocation + vital_state.growing_body_allocation,
			100.0
		)
		and is_equal_approx(
			growth_state.vital_core_allocation + growth_state.growing_body_allocation,
			100.0
		),
		"Each oxygen priority should allocate exactly 100 percent total supply."
	)
	_expect(
		growth_state.growing_body_allocation > vital_state.growing_body_allocation
		and growth_state.vital_core_allocation < vital_state.vital_core_allocation,
		"Giving more oxygen to one district should reduce the other's share."
	)
	simulation.free()


func _test_vital_core_cannot_be_neglected_indefinitely() -> void:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.choose_preparation("lungs")
	director.choose_preparation("energy")
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	director.activate_lungs()
	director.redirect_blood_flow()
	for index in range(300):
		director.step(0.1)
		if director.get_snapshot().phase == "STABILIZATION":
			break
	_expect(
		director.get_snapshot().phase == "STABILIZATION",
		"Vital-neglect test should reach stabilization."
	)
	director.set_oxygen_priority("growth")
	for index in range(90):
		director.step(0.1)
		if director.get_snapshot().phase == "FAILURE":
			break
	_expect(
		director.get_snapshot().phase == "FAILURE",
		"Prioritizing growth through a vital demand event should eventually fail."
	)
	_expect(
		director.get_snapshot().failure_bottleneck.contains("Vital Core"),
		"Vital neglect should report the Vital Core as the bottleneck."
	)
	director.free()
	simulation.free()


func _test_growing_body_cannot_be_neglected_indefinitely() -> void:
	var setup := _create_stabilizing_run(["lungs", "energy"])
	var director: Node = setup.director
	var simulation: Node = setup.simulation
	director.set_oxygen_priority("vital")
	for index in range(170):
		director.step(0.1)
		if director.get_snapshot().phase == "FAILURE":
			break
	_expect(
		director.get_snapshot().phase == "FAILURE",
		"Keeping Vital Core priority through a growth event should eventually fail."
	)
	_expect(
		director.get_snapshot().failure_bottleneck.contains("Growing Body"),
		"Growth neglect should report the Growing Body as the bottleneck."
	)
	director.free()
	simulation.free()


func _test_passive_stabilization_fails_without_distribution() -> void:
	var setup := _create_stabilizing_run(["heart", "lungs"])
	var director: Node = setup.director
	var simulation: Node = setup.simulation
	for index in range(100):
		director.step(0.1)
		if director.get_snapshot().phase == "FAILURE":
			break
	var state: Dictionary = director.get_snapshot()
	_expect(
		state.phase == "FAILURE",
		"Passive non-interaction during stabilization should fail."
	)
	_expect(
		state.distribution_priority == "unassigned",
		"Tutorial and simulation must not choose a distribution automatically."
	)
	director.free()
	simulation.free()


func _test_success_is_achievable_with_every_preparation_combination() -> void:
	var heart_lungs: Array[String] = ["heart", "lungs"]
	var heart_energy: Array[String] = ["heart", "energy"]
	var lungs_energy: Array[String] = ["lungs", "energy"]
	for preparations: Array[String] in [heart_lungs, heart_energy, lungs_energy]:
		var result := _run_prepared_scenario(preparations, 0.0, true, true)
		_expect(
			result == "SUCCESS",
			"Preparation combination %s should remain capable of success." % [preparations]
		)


func _test_safe_timer_resets_below_fifty_five() -> void:
	var setup := _create_stabilizing_run(["heart", "lungs"])
	var director: Node = setup.director
	var simulation: Node = setup.simulation
	director.set_oxygen_priority("vital")
	for index in range(20):
		director.step(0.1)
	_expect(
		director.get_snapshot().stabilization_safe_time > 1.0,
		"Safe timer test should first accumulate safe stabilization time."
	)
	director.add_oxygen(-100.0)
	director.step(0.1)
	_expect(
		is_zero_approx(director.get_snapshot().stabilization_safe_time),
		"Oxygen below 55 should reset the continuous safe timer."
	)
	director.free()
	simulation.free()


func _test_restart_resets_distribution_and_presentation_state() -> void:
	var setup := _create_stabilizing_run(["lungs", "energy"])
	var director: Node = setup.director
	var simulation: Node = setup.simulation
	director.set_oxygen_priority("vital")
	director.step(2.0)
	director.restart()
	var state: Dictionary = director.get_snapshot()
	_expect(state.distribution_priority == "unassigned", "Restart should clear distribution priority.")
	_expect(
		is_zero_approx(state.vital_core_allocation)
		and is_zero_approx(state.growing_body_allocation),
		"Restart should clear district allocation."
	)
	_expect(
		state.distribution_event == "inactive"
		and is_zero_approx(state.stabilization_elapsed),
		"Restart should clear demand events and stabilization time."
	)
	_expect(
		is_zero_approx(state.vital_core_neglect)
		and is_zero_approx(state.growing_body_neglect)
		and is_zero_approx(state.stabilization_safe_time),
		"Restart should clear neglect and safe timers."
	)
	_expect(
		is_zero_approx(state.screen_shake)
		and is_zero_approx(state.takeover_flash)
		and is_zero_approx(state.energy_expiration_notice),
		"Restart should clear transient presentation state."
	)
	director.free()
	simulation.free()


func _test_tutorial_never_performs_distribution_decisions() -> void:
	var setup := _create_stabilizing_run(["heart", "energy"])
	var director: Node = setup.director
	var simulation: Node = setup.simulation
	var state: Dictionary = director.get_snapshot()
	_expect(
		state.tutorial_step == "DISTRIBUTE_OXYGEN"
		and state.objective_action == "distribution_vital",
		"Tutorial should explain and highlight the live distribution need."
	)
	for index in range(20):
		director.step(0.1)
	_expect(
		director.get_snapshot().distribution_priority == "unassigned",
		"Tutorial must never allocate oxygen automatically."
	)
	director.free()
	simulation.free()


func _create_stabilizing_run(preparations: Array[String]) -> Dictionary:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	for preparation in preparations:
		director.choose_preparation(preparation)
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	director.activate_lungs()
	director.redirect_blood_flow()
	for index in range(300):
		director.step(0.1)
		if director.get_snapshot().phase == "STABILIZATION":
			break
	return {"director": director, "simulation": simulation}


func _run_prepared_scenario(
	preparations: Array[String],
	intervention_delay: float,
	activate_lungs: bool,
	redirect_flow: bool
) -> String:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	for preparation in preparations:
		director.choose_preparation(preparation)
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	for index in range(int(intervention_delay * 10.0)):
		director.step(0.1)
	if activate_lungs:
		director.activate_lungs()
	if redirect_flow:
		director.redirect_blood_flow()
	for index in range(900):
		_respond_to_distribution(director)
		director.step(0.1)
		var phase: String = director.get_snapshot().phase
		if phase == "SUCCESS" or phase == "FAILURE":
			director.free()
			simulation.free()
			return phase
	director.free()
	simulation.free()
	return "TIMEOUT"


func _run_birth_scenario(activate_lungs: bool, redirect_flow: bool) -> String:
	var simulation = SimulationScript.new()
	simulation.balance = BalanceResource
	var director = DirectorScript.new()
	director.setup(simulation)
	director.restart()
	director.begin_birth()
	for index in range(31):
		director.step(0.1)
	if activate_lungs:
		director.activate_lungs()
	if redirect_flow:
		director.redirect_blood_flow()
	for index in range(600):
		_respond_to_distribution(director)
		director.step(0.1)
		var phase: String = director.get_snapshot().phase
		if phase == "SUCCESS" or phase == "FAILURE":
			director.free()
			simulation.free()
			return phase
	var timeout_state: Dictionary = director.get_snapshot()
	print(
		"Scenario timed out: phase=%s oxygen=%.2f safe_hold=%.2f" %
		[
			timeout_state.phase,
			timeout_state.oxygen,
			timeout_state.stabilization_safe_time,
		]
	)
	director.free()
	simulation.free()
	return "TIMEOUT"


func _respond_to_distribution(director: Node) -> void:
	var state: Dictionary = director.get_snapshot()
	if state.phase != "STABILIZATION":
		return
	var desired_priority := (
		"vital"
		if state.distribution_event == "vital_surge"
		else "growth"
	)
	if state.distribution_priority != desired_priority:
		director.set_oxygen_priority(desired_priority)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
