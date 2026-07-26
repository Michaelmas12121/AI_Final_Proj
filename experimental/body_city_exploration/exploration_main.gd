extends Node2D

const START_POSITION := Vector2(195, 292)
const INTERACTION_RANGE := 54.0
const CLICK_TARGET_RANGE := 30.0

@onready var model: Node = $ExplorationModel
@onready var world: Node2D = $CityWorld
@onready var player: CharacterBody2D = $MaintenanceWorker
@onready var hud: CanvasLayer = $HUD

var _state: Dictionary = {}
var _nearby_target := ""
var _event_message := ""
var _event_message_remaining := 0.0


func _ready() -> void:
	get_window().title = "Body City Exploration Prototype"
	player.interaction_requested.connect(_try_interact)
	_state = model.get_snapshot()
	world.set_state(_state)
	player.set_carrying_energy_cell(false)


func _process(delta: float) -> void:
	_state = model.step(delta)
	_event_message_remaining = maxf(0.0, _event_message_remaining - delta)
	if is_zero_approx(_event_message_remaining):
		_event_message = ""

	_nearby_target = _find_nearby_target()
	var objective_info := _objective_info()
	var objective_target: String = objective_info.target
	var direction_text := _direction_to(world.get_target_position(objective_target))
	if objective_target.is_empty():
		direction_text = "Walk the restored streets and follow the oxygen lights."

	world.set_state(_state)
	world.set_interaction_context(_nearby_target, player.global_position)
	hud.set_view(
		_state,
		objective_info.text,
		_prompt_for(_nearby_target),
		direction_text,
		_event_message
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_restart()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_target := _target_at_world_position(get_global_mouse_position())
		if not clicked_target.is_empty():
			_try_interact(clicked_target)
		else:
			player.move_to(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _try_interact(requested_target: String = "") -> void:
	var target := requested_target if not requested_target.is_empty() else _find_nearby_target()
	if target.is_empty():
		_show_message("Move closer to a glowing maintenance control.")
		return
	if player.global_position.distance_to(world.get_target_position(target)) > INTERACTION_RANGE:
		_show_message("That machine is too far away. Walk closer.")
		return

	match target:
		"energy_cell":
			if model.collect_energy_cell():
				player.set_carrying_energy_cell(true)
				_show_message("ENERGY CELL ACQUIRED • Carry it to the Lung District.")
		"lung_machine":
			if model.activate_lung_machine():
				player.set_carrying_energy_cell(false)
				_show_message("AIR PROCESSOR ONLINE • Oxygen still needs a blood route.")
			elif not _state.get("energy_cell_installed", false):
				_show_message("The air processor has no power. Find its energy cell.")
		"heart_valve":
			if model.open_pulmonary_route():
				_show_message("PULMONARY ROUTE OPEN • Blood can now visit the lungs.")


func _find_nearby_target() -> String:
	var best_target := ""
	var best_distance := INTERACTION_RANGE
	for target in _available_targets():
		var distance := player.global_position.distance_to(world.get_target_position(target))
		if distance <= best_distance:
			best_target = target
			best_distance = distance
	return best_target


func _target_at_world_position(world_position: Vector2) -> String:
	for target in _available_targets():
		if world_position.distance_to(world.get_target_position(target)) <= CLICK_TARGET_RANGE:
			return target
	return ""


func _available_targets() -> Array[String]:
	var result: Array[String] = []
	if not _state.get("energy_cell_collected", false) and not _state.get("energy_cell_installed", false):
		result.append("energy_cell")
	if not _state.get("energy_cell_installed", false):
		result.append("lung_machine")
	if not _state.get("pulmonary_route_requested", false):
		result.append("heart_valve")
	return result


func _objective_info() -> Dictionary:
	if not _state.get("energy_cell_collected", false) and not _state.get("energy_cell_installed", false):
		return {
			"target": "energy_cell",
			"text": "Find the portable ENERGY CELL in the Body Maintenance Yard.",
		}
	if _state.get("energy_cell_collected", false):
		return {
			"target": "lung_machine",
			"text": "Carry the cell to the Lung District air processor.",
		}
	if not _state.get("pulmonary_route_requested", false):
		return {
			"target": "heart_valve",
			"text": "Air is ready, but blood cannot collect it. Open the Heart Hub valve.",
		}
	if not _state.get("city_recovered", false):
		return {
			"target": "",
			"text": "Supply chain complete. Watch oxygen move from lungs to heart to body.",
		}
	return {
		"target": "",
		"text": "CITY RECOVERED • Air and blood flow are working together.",
	}


func _prompt_for(target: String) -> String:
	match target:
		"energy_cell":
			return "[E / SPACE / CLICK]  PICK UP ENERGY CELL"
		"lung_machine":
			if _state.get("energy_cell_collected", false):
				return "[E / SPACE / CLICK]  INSTALL CELL + START AIR PROCESSOR"
			return "AIR PROCESSOR NEEDS THE PORTABLE ENERGY CELL"
		"heart_valve":
			return "[E / SPACE / CLICK]  OPEN PULMONARY BLOOD-FLOW VALVE"
	return ""


func _direction_to(target_position: Vector2) -> String:
	var offset := target_position - player.global_position
	var distance_blocks := maxi(1, roundi(offset.length() / 32.0))
	var horizontal := "EAST" if offset.x >= 0.0 else "WEST"
	var vertical := "SOUTH" if offset.y >= 0.0 else "NORTH"
	var direction := horizontal if absf(offset.x) > absf(offset.y) else vertical
	return "Street signs point %s • about %d city blocks" % [direction, distance_blocks]


func _show_message(message: String) -> void:
	_event_message = message
	_event_message_remaining = 4.5


func _restart() -> void:
	model.reset()
	player.global_position = START_POSITION
	player.stop_moving()
	player.set_carrying_energy_cell(false)
	_event_message = "EXPERIMENT RESTARTED"
	_event_message_remaining = 2.5
