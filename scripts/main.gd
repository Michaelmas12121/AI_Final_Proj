extends Node

@onready var run_director: RunDirector = $RunDirector
@onready var simulation: PhysiologySimulation = $PhysiologySimulation
@onready var world: Control = $World
@onready var ui: CanvasLayer = $UI


func _ready() -> void:
	run_director.setup(simulation)
	run_director.run_state_changed.connect(_on_run_state_changed)

	ui.begin_birth_requested.connect(run_director.begin_birth)
	ui.preparation_requested.connect(run_director.choose_preparation)
	ui.intervention_hold_changed.connect(run_director.set_intervention_held)
	ui.oxygen_priority_requested.connect(run_director.set_oxygen_priority)
	ui.tutorial_toggled.connect(run_director.set_tutorial_enabled)
	ui.restart_requested.connect(run_director.restart)
	ui.oxygen_adjustment_requested.connect(run_director.add_oxygen)
	ui.demand_adjustment_requested.connect(run_director.adjust_body_demand)

	run_director.restart()


func _process(delta: float) -> void:
	run_director.step(delta)


func _on_run_state_changed(snapshot: Dictionary) -> void:
	world.set_state(snapshot)
	ui.set_state(snapshot)
