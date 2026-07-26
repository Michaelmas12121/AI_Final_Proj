class_name BodyCityClarityWorld
extends "res://experimental/body_city_exploration/exploration_world.gd"

const LUNG_POWER_POSITION := Vector2(352, 556)
const AIR_INTAKE_POSITION := Vector2(118, 648)
const CHAMBER_CONTROL_POSITION := Vector2(275, 648)

var _clarity_state: Dictionary = {}


func set_state(snapshot: Dictionary) -> void:
	_clarity_state = snapshot.duplicate(true)
	var display_state := snapshot.duplicate(true)
	if snapshot.get("placental_route_retired", false):
		display_state["placental_supply"] = 0.0
	super.set_state(display_state)


func get_target_position(target: String) -> Vector2:
	match target:
		"lung_power":
			return LUNG_POWER_POSITION
		"air_intake":
			return AIR_INTAKE_POSITION
		"chambers":
			return CHAMBER_CONTROL_POSITION
	return super.get_target_position(target)


func _draw() -> void:
	super._draw()
	_draw_lung_sequence_machinery()
	_draw_valve_alignment()
	_draw_pressure_feedback()
	_draw_activity_and_danger()
	_draw_recovery_payoff()


func _draw_lung_sequence_machinery() -> void:
	var installed: bool = _clarity_state.get("energy_cell_installed", false)
	var intake_open: bool = _clarity_state.get("air_intake_open", false)
	var chambers_active: bool = _clarity_state.get("chambers_active", false)
	var activation: float = _clarity_state.get("lung_activation", 0.0) / 100.0
	var error: bool = _clarity_state.get("lung_sequence_error", false)
	var shake := sin(_pulse_time * 24.0) * 3.0 if error else 0.0

	# Power socket: a cell silhouette plugs into a visible cable feeding both controls.
	draw_circle(LUNG_POWER_POSITION, 18.0, Color("#171d28"))
	draw_rect(Rect2(LUNG_POWER_POSITION - Vector2(9, 13), Vector2(18, 26)), Color("#423344"))
	if installed:
		draw_rect(Rect2(LUNG_POWER_POSITION - Vector2(6, 10), Vector2(12, 20)), Color("#ffe065"))
		draw_rect(Rect2(LUNG_POWER_POSITION - Vector2(3, 7), Vector2(6, 14)), Color("#71f3dc"))
		draw_polyline(
			PackedVector2Array(
				[LUNG_POWER_POSITION, Vector2(352, 625), CHAMBER_CONTROL_POSITION]
			),
			Color("#ffe065"),
			3.0
		)
	else:
		draw_line(LUNG_POWER_POSITION + Vector2(-6, 0), LUNG_POWER_POSITION + Vector2(6, 0), Color("#8b5664"), 3.0)
		draw_line(LUNG_POWER_POSITION + Vector2(0, -6), LUNG_POWER_POSITION + Vector2(0, 6), Color("#8b5664"), 3.0)

	# Intake shutter sits at the outside edge. Air arrows always point inward.
	draw_rect(Rect2(AIR_INTAKE_POSITION - Vector2(22, 15), Vector2(44, 30)), Color("#172a34"))
	for index in range(4):
		var shutter_x := AIR_INTAKE_POSITION.x - 16 + index * 10
		var shutter_color := Color("#72eee7") if intake_open else Color("#6e4a59")
		var top := AIR_INTAKE_POSITION.y - (4 if intake_open else 12)
		var bottom := AIR_INTAKE_POSITION.y + (4 if intake_open else 12)
		draw_line(Vector2(shutter_x, top), Vector2(shutter_x, bottom), shutter_color, 4.0)
	for index in range(3):
		var arrow_x := 52.0 + index * 18.0 + fmod(_pulse_time * 22.0, 14.0)
		var arrow_color := Color("#a8ffff") if intake_open else Color("#61505d")
		draw_line(Vector2(arrow_x, 648), Vector2(arrow_x + 10, 648), arrow_color, 2.0)
		draw_line(Vector2(arrow_x + 7, 645), Vector2(arrow_x + 10, 648), arrow_color, 2.0)
		draw_line(Vector2(arrow_x + 7, 651), Vector2(arrow_x + 10, 648), arrow_color, 2.0)

	# Chamber control uses an expand symbol. Red crossing arrows explain wrong order.
	draw_circle(CHAMBER_CONTROL_POSITION, 17.0, Color("#17242d"))
	var chamber_control_color := Color("#79f3e8") if chambers_active else Color("#b77a61")
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(
			CHAMBER_CONTROL_POSITION + direction * 3.0,
			CHAMBER_CONTROL_POSITION + direction * 11.0,
			chamber_control_color,
			3.0
		)
	if error:
		draw_line(
			CHAMBER_CONTROL_POSITION + Vector2(-13, -13),
			CHAMBER_CONTROL_POSITION + Vector2(13, 13),
			Color("#ff5964"),
			4.0
		)
		draw_line(
			CHAMBER_CONTROL_POSITION + Vector2(13, -13),
			CHAMBER_CONTROL_POSITION + Vector2(-13, 13),
			Color("#ff5964"),
			4.0
		)
		draw_polyline(
			PackedVector2Array(
				[
					CHAMBER_CONTROL_POSITION + Vector2(shake, -24),
					AIR_INTAKE_POSITION + Vector2(shake, -24),
				]
			),
			Color("#ff5964"),
			3.0
		)

	# Folded shutters cover the chambers until the sequence succeeds.
	for center in [Vector2(170, 552), Vector2(235, 552)]:
		if not chambers_active:
			draw_rect(Rect2(center - Vector2(22, 28), Vector2(18, 56)), Color("#21323d"))
			draw_rect(Rect2(center + Vector2(4, -28), Vector2(18, 56)), Color("#21323d"))
			draw_line(center + Vector2(0, -27), center + Vector2(0, 27), Color("#9a5965"), 4.0)
			draw_line(center + Vector2(-18, -18), center + Vector2(18, 18), Color("#6c4451"), 3.0)
		else:
			var expansion := 8.0 + activation * 17.0
			draw_arc(center, expansion, 0.0, TAU, 20, Color("#b5ffff"), 3.0)
			var breath := 1.0 + sin(_pulse_time * 2.2) * 0.12 * activation
			draw_arc(center, 29.0 * breath, 0.0, TAU, 24, Color("#6ff0ea"), 2.0)


func _draw_valve_alignment() -> void:
	var alignment: int = _clarity_state.get("valve_alignment", 0)
	var center := HEART_VALVE_POSITION
	draw_circle(center, 21.0, Color("#140f18"))
	draw_circle(center, 17.0, Color("#53313f"))
	var route_color := Color("#78f4e9") if alignment == 2 else Color("#ff8b67")
	draw_line(center + Vector2(-17, 0), center, route_color, 7.0)
	if alignment == 0:
		draw_line(center, center + Vector2(0, 17), route_color, 7.0)
	elif alignment == 1:
		draw_line(center, center + Vector2(0, -17), route_color, 7.0)
	else:
		draw_line(center, center + Vector2(17, 0), route_color, 7.0)
	for index in range(3):
		var dot_position := center + Vector2(-31 + index * 8, 0)
		draw_circle(dot_position, 2.5, Color("#94fff6") if alignment == 2 else Color("#ffb070"))
	if alignment != 2:
		draw_arc(center, 27.0, -1.1, 1.1, 12, Color("#fff09b"), 3.0)
		draw_line(center + Vector2(24, -10), center + Vector2(28, -3), Color("#fff09b"), 3.0)


func _draw_pressure_feedback() -> void:
	if not _clarity_state.get("trapped_oxygen", false):
		return
	var pressure := sin(_pulse_time * 18.0) * 3.0
	var pipe := PackedVector2Array(
		[
			Vector2(322, 556 + pressure),
			Vector2(402, 556 + pressure),
			Vector2(402, 430 + pressure),
			Vector2(620, 430 + pressure),
		]
	)
	draw_polyline(pipe, Color("#82fff4"), 3.0)
	for index in range(7):
		var x := 430.0 + index * 25.0
		var alpha := 0.55 + sin(_pulse_time * 7.0 + index) * 0.35
		draw_line(Vector2(x, 424 + pressure), Vector2(x + 9, 430 + pressure), Color(0.5, 1.0, 0.96, alpha), 3.0)
		draw_line(Vector2(x, 436 + pressure), Vector2(x + 9, 430 + pressure), Color(0.5, 1.0, 0.96, alpha), 3.0)
	draw_circle(Vector2(617, 430 + pressure), 10.0 + sin(_pulse_time * 12.0) * 3.0, Color("#ff5e68", 0.65))


func _draw_activity_and_danger() -> void:
	var danger: String = _clarity_state.get("danger_state", "stable")
	var speed := 26.0
	if danger == "early":
		speed = 18.0
	elif danger == "mid":
		speed = 10.0
	elif danger == "critical":
		speed = 3.0
	for index in range(8):
		var x := fmod(_pulse_time * speed + index * 155.0, 1180.0) + 45.0
		var cart_color := Color("#ffd069") if danger in ["stable", "early"] else Color("#73505b")
		draw_rect(Rect2(x, 373, 12, 6), cart_color)
		draw_circle(Vector2(x + 2, 380), 2.0, Color("#241722"))
		draw_circle(Vector2(x + 10, 380), 2.0, Color("#241722"))
	if danger == "early":
		var flicker_on := int(_pulse_time * 5.0) % 3 != 0
		if not flicker_on:
			draw_rect(Rect2(1000, 172, 130, 74), Color("#180d19", 0.42))
	if danger == "mid":
		draw_rect(Rect2(1000, 172, 60, 74), Color("#100b14", 0.42))
		draw_rect(Rect2(590, 276, 70, 70), Color("#100b14", 0.32))
	if danger == "critical":
		draw_rect(Rect2(938, 148, 238, 136), Color("#09060c", 0.68))
		draw_rect(Rect2(556, 254, 95, 126), Color("#09060c", 0.58))
		var warning := Color("#ff555f", 0.55 + sin(_pulse_time * 6.0) * 0.35)
		for pos in [Vector2(650, 220), Vector2(1055, 125), Vector2(850, 350)]:
			draw_arc(pos, 15.0 + sin(_pulse_time * 5.0) * 3.0, 0.0, TAU, 20, warning, 4.0)


func _draw_recovery_payoff() -> void:
	if not _clarity_state.get("recovery_started", false):
		return
	var elapsed: float = _clarity_state.get("recovery_elapsed", 0.0)
	var stage: String = _clarity_state.get("recovery_stage", "inactive")
	var heart_center := Vector2(650, 318)
	if stage in ["heart_pulse", "oxygen_wave", "district_relight", "wide_restore", "complete"]:
		for index in range(3):
			var radius := 45.0 + fmod(_pulse_time * 60.0 + index * 24.0, 72.0)
			var alpha := clampf(1.0 - (radius - 45.0) / 72.0, 0.0, 0.8)
			draw_arc(heart_center, radius, 0.0, TAU, 32, Color(1.0, 0.45, 0.35, alpha), 5.0)

	if elapsed >= 2.0:
		var wave_progress := clampf((elapsed - 2.0) / 3.0, 0.0, 1.0)
		var wave_path := PackedVector2Array(
			[
				Vector2(170, 552),
				Vector2(402, 552),
				Vector2(402, 430),
				Vector2(650, 430),
				Vector2(650, 318),
				Vector2(850, 318),
				Vector2(1030, 318),
			]
		)
		_draw_progressive_wave(wave_path, wave_progress)

	if elapsed >= 5.0:
		var relight := clampf((elapsed - 5.0) / 3.0, 0.0, 1.0)
		draw_rect(Rect2(556, 254, 188 * minf(relight * 2.0, 1.0), 126), Color("#ff8760", 0.16))
		draw_rect(
			Rect2(938, 148, 238 * clampf(relight * 2.0 - 1.0, 0.0, 1.0), 136),
			Color("#ffd368", 0.2)
		)

	if elapsed >= 8.0:
		for index in range(16):
			var traffic_x := fmod(_pulse_time * 55.0 + index * 78.0, 1200.0) + 30.0
			draw_circle(Vector2(traffic_x, 356 + (index % 2) * 14), 3.0, Color("#fff19a"))


func _draw_progressive_wave(path: PackedVector2Array, progress: float) -> void:
	var segment_count := path.size() - 1
	var scaled := progress * segment_count
	for index in range(segment_count):
		if float(index) > scaled:
			break
		var end_point := path[index + 1]
		if index == int(floor(scaled)) and index < segment_count:
			end_point = path[index].lerp(path[index + 1], scaled - index)
		draw_line(path[index], end_point, Color("#d8fff3", 0.28), 16.0)
		draw_line(path[index], end_point, Color("#7ff7e8"), 7.0)
		if index == int(floor(scaled)):
			draw_circle(end_point, 18.0, Color("#eaffcb", 0.25))
			draw_circle(end_point, 8.0, Color("#fff7af"))
