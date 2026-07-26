extends Node2D

const START_POSITION := Vector2(195, 292)
const INTERACTION_RANGE := 54.0
const CLICK_TARGET_RANGE := 30.0
const NORMAL_ZOOM := Vector2.ONE

@onready var model: Node = $ClarityModel
@onready var world: Node2D = $CityWorld
@onready var player: CharacterBody2D = $MaintenanceWorker
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD

var _state: Dictionary = {}
var _nearby_target := ""
var _event_message := ""
var _event_message_remaining := 0.0


func _ready() -> void:
	get_window().title = "Body City Exploration - Clarity Pass"
	player.interaction_requested.connect(_try_interact)
	_state = model.get_snapshot()
	world.set_state(_state)
	player.set_carrying_energy_cell(false)
	camera.global_position = player.global_position


func _process(delta: float) -> void:
	_state = model.step(delta)
	_event_message_remaining = maxf(0.0, _event_message_remaining - delta)
	if is_zero_approx(_event_message_remaining):
		_event_message = ""

	var recovery_started: bool = _state.get("recovery_started", false)
	player.movement_enabled = not recovery_started
	if recovery_started:
		player.stop_moving()
	_update_camera(delta)

	_nearby_target = "" if recovery_started else _find_nearby_target()
	var objective_info := _objective_info()
	var objective_target: String = objective_info.target
	var target_offset := Vector2.ZERO
	if not objective_target.is_empty():
		target_offset = world.get_target_position(objective_target) - player.global_position

	world.set_state(_state)
	world.set_interaction_context(
		_nearby_target if not _nearby_target.is_empty() else objective_target,
		player.global_position
	)
	hud.set_view(
		_state,
		objective_info.text,
		_prompt_for(_nearby_target),
		target_offset,
		objective_target,
		_event_message
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart()
			get_viewport().set_input_as_handled()
			return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and not _state.get("recovery_started", false)
	):
		var clicked_target := _target_at_world_position(get_global_mouse_position())
		if not clicked_target.is_empty():
			_try_interact(clicked_target)
		else:
			player.move_to(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _try_interact(requested_target: String = "") -> void:
	if _state.get("recovery_started", false):
		return
	var target := requested_target if not requested_target.is_empty() else _find_nearby_target()
	if target.is_empty():
		_show_message("FOLLOW THE AMBER ARROW")
		return
	if player.global_position.distance_to(world.get_target_position(target)) > INTERACTION_RANGE:
		_show_message("MOVE CLOSER")
		return

	match target:
		"energy_cell":
			if model.collect_energy_cell():
				player.set_carrying_energy_cell(true)
				_show_message("ENERGY CELL ACQUIRED")
		"lung_power":
			if model.install_energy_cell():
				player.set_carrying_energy_cell(false)
				_show_message("POWER CONNECTED")
		"air_intake":
			if model.open_air_intake():
				_show_message("AIR INTAKE OPEN")
		"chambers":
			if model.activate_chambers():
				_show_message("FIRST BREATH")
			else:
				_show_message("NO AIR - INTAKE SHUTTER CLOSED")
		"heart_valve":
			var alignment: int = model.rotate_pulmonary_valve()
			if alignment == 2:
				_show_message("ROUTE ALIGNED - OXYGEN RELEASED")
			else:
				_show_message("ROUTE STILL BROKEN - ROTATE AGAIN")


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
	if _state.get("energy_cell_collected", false):
		result.append("lung_power")
	if _state.get("energy_cell_installed", false):
		if not _state.get("air_intake_open", false):
			result.append("air_intake")
		if not _state.get("chambers_active", false):
			result.append("chambers")
	if _state.get("chambers_active", false) and not _state.get("flow_open", false):
		result.append("heart_valve")
	return result


func _objective_info() -> Dictionary:
	if not _state.get("energy_cell_collected", false) and not _state.get("energy_cell_installed", false):
		return {"target": "energy_cell", "text": "Retrieve the glowing energy cell."}
	if _state.get("energy_cell_collected", false):
		return {"target": "lung_power", "text": "Carry the cell to the Lung District socket."}
	if not _state.get("air_intake_open", false):
		return {"target": "air_intake", "text": "Open the outside air intake."}
	if not _state.get("chambers_active", false):
		return {"target": "chambers", "text": "Unfold the breathing chambers."}
	if not _state.get("lung_online", false):
		return {"target": "", "text": "The lungs are taking their first breath..."}
	if not _state.get("flow_open", false):
		return {"target": "heart_valve", "text": "Oxygen is trapped. Align the Heart Hub pipe."}
	if not _state.get("recovery_started", false):
		return {"target": "", "text": "The repairs are working. Watch the oxygen rise."}
	if not _state.get("city_recovered", false):
		return {"target": "", "text": "Air > Lungs > Blood > Heart > Body"}
	return {"target": "", "text": "CITY RESTORED"}


func _prompt_for(target: String) -> String:
	match target:
		"energy_cell":
			return "E / SPACE / CLICK  -  PICK UP"
		"lung_power":
			return "E / SPACE / CLICK  -  INSTALL CELL"
		"air_intake":
			return "E / SPACE / CLICK  -  OPEN INTAKE"
		"chambers":
			return "E / SPACE / CLICK  -  UNFOLD CHAMBERS"
		"heart_valve":
			return "E / SPACE / CLICK  -  ROTATE PIPE"
	return ""


func _update_camera(delta: float) -> void:
	var target_position := player.global_position
	var target_zoom := NORMAL_ZOOM
	var stage: String = _state.get("recovery_stage", "inactive")
	match stage:
		"heart_pulse":
			target_position = Vector2(650, 340)
			target_zoom = Vector2(1.05, 1.05)
		"oxygen_wave":
			target_position = Vector2(470, 460)
			target_zoom = Vector2(0.78, 0.78)
		"district_relight":
			target_position = Vector2(820, 340)
			target_zoom = Vector2(0.62, 0.62)
		"wide_restore", "complete":
			target_position = Vector2(640, 360)
			target_zoom = Vector2(0.5, 0.5)
	camera.global_position = camera.global_position.lerp(target_position, minf(delta * 3.0, 1.0))
	camera.zoom = camera.zoom.lerp(target_zoom, minf(delta * 2.5, 1.0))


func _show_message(message: String) -> void:
	_event_message = message
	_event_message_remaining = 3.0


func _restart() -> void:
	model.reset()
	_state = model.get_snapshot()
	player.global_position = START_POSITION
	player.stop_moving()
	player.movement_enabled = true
	player.set_carrying_energy_cell(false)
	camera.global_position = START_POSITION
	camera.zoom = NORMAL_ZOOM
	_event_message = "SYSTEM RESET"
	_event_message_remaining = 2.0
