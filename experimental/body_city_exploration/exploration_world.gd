class_name ExplorationWorld
extends Node2D

const WORLD_SIZE := Vector2(1280, 720)
const ENERGY_CELL_POSITION := Vector2(1080, 360)
const LUNG_MACHINE_POSITION := Vector2(352, 556)
const HEART_VALVE_POSITION := Vector2(650, 430)

const PLACENTA_RECT := Rect2(60, 70, 300, 175)
const LUNG_RECT := Rect2(55, 450, 340, 210)
const HEART_RECT := Rect2(520, 220, 260, 245)
const BODY_RECT := Rect2(900, 105, 320, 510)

var _state: Dictionary = {}
var _pulse_time := 0.0
var _highlighted_target := ""
var _player_position := Vector2.ZERO

var _collision_rects: Array[Rect2] = [
	Rect2(80, 92, 250, 112),
	Rect2(92, 486, 230, 132),
	Rect2(556, 254, 188, 126),
	Rect2(938, 148, 238, 136),
	Rect2(948, 440, 220, 132),
	Rect2(-16, 0, 16, 720),
	Rect2(1280, 0, 16, 720),
	Rect2(0, -16, 1280, 16),
	Rect2(0, 720, 1280, 16),
]


func _ready() -> void:
	_build_collision_geometry()
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func set_state(snapshot: Dictionary) -> void:
	_state = snapshot.duplicate(true)


func set_interaction_context(target: String, player_position: Vector2) -> void:
	_highlighted_target = target
	_player_position = player_position


func get_target_position(target: String) -> Vector2:
	match target:
		"energy_cell":
			return ENERGY_CELL_POSITION
		"lung_machine":
			return LUNG_MACHINE_POSITION
		"heart_valve":
			return HEART_VALVE_POSITION
	return _player_position


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#351529"))
	_draw_ground_blocks()
	_draw_roads()
	_draw_transport_network()
	_draw_facilities()
	_draw_interaction_objects()
	_draw_city_lighting()


func _draw_ground_blocks() -> void:
	var block_color := Color("#491d32")
	for x in range(0, 1280, 64):
		for y in range(0, 720, 64):
			var alternate := ((x / 64) + (y / 64)) as int
			var color := block_color.lightened(0.025 if alternate % 2 == 0 else 0.0)
			draw_rect(Rect2(x + 2, y + 2, 60, 60), color)
	draw_rect(PLACENTA_RECT.grow(8), Color("#4b243f"), true)
	draw_rect(LUNG_RECT.grow(8), Color("#263d4b"), true)
	draw_rect(HEART_RECT.grow(8), Color("#522031"), true)
	draw_rect(BODY_RECT.grow(8), Color("#3e2938"), true)


func _draw_roads() -> void:
	var road := Color("#2a2735")
	var road_edge := Color("#6a4b5f")
	draw_rect(Rect2(25, 324, 1230, 72), road)
	draw_line(Vector2(25, 324), Vector2(1255, 324), road_edge, 3.0)
	draw_line(Vector2(25, 396), Vector2(1255, 396), road_edge, 3.0)
	draw_rect(Rect2(365, 40, 72, 620), road)
	draw_line(Vector2(365, 40), Vector2(365, 660), road_edge, 3.0)
	draw_line(Vector2(437, 40), Vector2(437, 660), road_edge, 3.0)
	draw_rect(Rect2(815, 55, 72, 610), road)
	draw_line(Vector2(815, 55), Vector2(815, 665), road_edge, 3.0)
	draw_line(Vector2(887, 55), Vector2(887, 665), road_edge, 3.0)
	for x in range(40, 1250, 42):
		draw_rect(Rect2(x, 357, 22, 5), Color("#8a6a64"))
	for y in range(58, 650, 42):
		draw_rect(Rect2(398, y, 5, 22), Color("#8a6a64"))
		draw_rect(Rect2(848, y, 5, 22), Color("#8a6a64"))
	# Sidewalk bolts and amber utility lamps.
	for x in range(50, 1240, 80):
		draw_circle(Vector2(x, 316), 3.0, Color("#df9d55"))
		draw_circle(Vector2(x, 404), 3.0, Color("#df9d55"))


func _draw_transport_network() -> void:
	var placenta_strength: float = _state.get("placental_supply", 100.0) / 100.0
	var placenta_color := Color("#ff7188", placenta_strength)
	var placenta_route := PackedVector2Array(
		[Vector2(330, 170), Vector2(402, 170), Vector2(402, 270), Vector2(556, 270)]
	)
	draw_polyline(placenta_route, Color("#24141f"), 14.0)
	draw_polyline(placenta_route, placenta_color, 5.0)
	if placenta_strength > 0.05:
		_draw_packets(placenta_route, placenta_color, placenta_strength, 5)

	var lung_route := PackedVector2Array(
		[Vector2(322, 556), Vector2(402, 556), Vector2(402, 430), Vector2(650, 430)]
	)
	var flow_requested: bool = _state.get("pulmonary_route_requested", false)
	var flow_open: bool = _state.get("flow_open", false)
	draw_polyline(lung_route, Color("#171923"), 16.0)
	draw_polyline(
		lung_route,
		Color("#398f99") if flow_requested else Color("#3d3542"),
		6.0
	)
	for index in range(9):
		var valve_x := 425.0 + index * 25.0
		draw_line(
			Vector2(valve_x, 423),
			Vector2(valve_x, 437),
			Color("#7cd7d6") if flow_open else Color("#754454"),
			2.0
		)

	var body_route := PackedVector2Array(
		[Vector2(744, 300), Vector2(850, 300), Vector2(850, 350), Vector2(938, 350)]
	)
	draw_polyline(body_route, Color("#24141f"), 16.0)
	draw_polyline(
		body_route,
		Color("#ff765c") if _state.get("supply_chain_complete", false) else Color("#593642"),
		6.0
	)

	if _state.get("supply_chain_complete", false):
		_draw_packets(lung_route, Color("#76f3ea"), 1.0, 8)
		_draw_packets(body_route, Color("#ffb85e"), 1.0, 6)
	elif _state.get("lung_online", false):
		for index in range(4):
			draw_circle(
				Vector2(330 + index * 7, 556),
				3.0,
				Color("#77eff0")
			)
		draw_rect(Rect2(360, 544, 8, 24), Color("#ff6c6c"))


func _draw_facilities() -> void:
	var brightness := _district_brightness()
	_draw_facility(
		Rect2(80, 92, 250, 112),
		"PLACENTAL SUPPLY STATION",
		Color("#8c385e"),
		Color("#ff769a"),
		brightness * (_state.get("placental_supply", 100.0) / 100.0)
	)
	_draw_facility(
		Rect2(92, 486, 230, 132),
		"LUNG DISTRICT • AIR WORKS",
		Color("#2e7280"),
		Color("#74e4df"),
		brightness if _state.get("lung_online", false) else brightness * 0.38
	)
	_draw_facility(
		Rect2(556, 254, 188, 126),
		"HEART TRANSPORT HUB",
		Color("#9d3e50"),
		Color("#ff8a76"),
		brightness
	)
	_draw_facility(
		Rect2(938, 148, 238, 136),
		"BODY DISTRICT • HOMES",
		Color("#75553e"),
		Color("#ffd06f"),
		brightness
	)
	_draw_facility(
		Rect2(948, 440, 220, 132),
		"BODY MAINTENANCE YARD",
		Color("#675046"),
		Color("#f0b85c"),
		brightness
	)
	_draw_lung_machinery(brightness)
	_draw_heart_machinery(brightness)
	_draw_body_details(brightness)


func _draw_facility(
	rect: Rect2,
	title: String,
	base: Color,
	accent: Color,
	brightness: float
) -> void:
	draw_rect(Rect2(rect.position + Vector2(5, 7), rect.size), Color("#1a1018"))
	draw_rect(rect, base.darkened(0.55 * (1.0 - brightness)))
	draw_rect(rect, accent.darkened(0.35 * (1.0 - brightness)), false, 4.0)
	draw_rect(Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 18)), Color("#271622"))
	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(14, 21),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 24,
		10,
		Color("#fff1d9")
	)
	var window_color := Color("#ffd36b").lerp(Color("#4c3340"), 1.0 - brightness)
	for row in range(2):
		for column in range(5):
			var window_pos := rect.position + Vector2(16 + column * 38, 40 + row * 28)
			if window_pos.x < rect.end.x - 16:
				draw_rect(Rect2(window_pos, Vector2(15, 14)), Color("#37212e"))
				draw_rect(Rect2(window_pos + Vector2(3, 3), Vector2(9, 8)), window_color)


func _draw_lung_machinery(brightness: float) -> void:
	var online: bool = _state.get("lung_online", false)
	var lung_color := Color("#a9ffff") if online else Color("#52646d")
	for center in [Vector2(170, 552), Vector2(235, 552)]:
		draw_circle(center, 31.0, Color("#172631"))
		draw_circle(center, 25.0, lung_color.darkened(0.25 * (1.0 - brightness)))
		draw_line(center + Vector2(0, -24), center + Vector2(0, 24), Color("#d4ffff"), 2.0)
		if online:
			var fan_angle := _pulse_time * 3.5
			for index in range(4):
				var direction := Vector2.RIGHT.rotated(fan_angle + index * PI / 2.0)
				draw_line(center, center + direction * 18.0, Color("#65d9dd"), 4.0)
	draw_rect(Rect2(321, 536, 31, 40), Color("#1c3038"))
	draw_rect(
		Rect2(327, 543, 19, 12),
		Color("#74f5dc") if online else Color("#a34d5b")
	)


func _draw_heart_machinery(brightness: float) -> void:
	var center := Vector2(650, 318)
	var pulse := 1.0 + sin(_pulse_time * 4.0) * 0.08
	draw_circle(center, 38.0 * pulse, Color("#6f2037"))
	draw_circle(
		center,
		27.0 * pulse,
		Color("#ff806a").darkened(0.35 * (1.0 - brightness))
	)
	draw_circle(center + Vector2(-9, -4), 6.0, Color("#ffd5aa"))
	draw_circle(center + Vector2(10, 7), 7.0, Color("#d84a54"))
	draw_line(Vector2(650, 356), Vector2(650, 420), Color("#774050"), 10.0)


func _draw_body_details(brightness: float) -> void:
	var light := Color("#ffd36e").lerp(Color("#503643"), 1.0 - brightness)
	for row in range(4):
		for column in range(4):
			var pos := Vector2(968 + column * 48, 316 + row * 27)
			draw_rect(Rect2(pos, Vector2(23, 15)), Color("#3c2934"))
			draw_rect(Rect2(pos + Vector2(5, 4), Vector2(13, 7)), light)
	for x in range(930, 1190, 38):
		draw_line(Vector2(x, 410), Vector2(x + 16, 397), Color("#93714f"), 3.0)


func _draw_interaction_objects() -> void:
	if not _state.get("energy_cell_collected", false) and not _state.get("energy_cell_installed", false):
		draw_circle(ENERGY_CELL_POSITION, 13.0, Color("#3b2b34"))
		draw_rect(Rect2(ENERGY_CELL_POSITION - Vector2(8, 10), Vector2(16, 20)), Color("#ffce55"))
		draw_rect(Rect2(ENERGY_CELL_POSITION - Vector2(4, 7), Vector2(8, 14)), Color("#7bf2dc"))
		draw_line(
			ENERGY_CELL_POSITION + Vector2(-8, -12),
			ENERGY_CELL_POSITION + Vector2(7, -17),
			Color("#fff1a4"),
			3.0
		)
	if _state.get("energy_cell_installed", false):
		draw_rect(Rect2(335, 545, 10, 20), Color("#ffdb5d"))

	var valve_color := Color("#6fe8dd") if _state.get("pulmonary_route_requested", false) else Color("#e46b72")
	draw_circle(HEART_VALVE_POSITION, 16.0, Color("#271923"))
	draw_circle(HEART_VALVE_POSITION, 10.0, valve_color)
	draw_line(HEART_VALVE_POSITION + Vector2(-13, 0), HEART_VALVE_POSITION + Vector2(13, 0), Color("#f4d9c0"), 3.0)
	draw_line(HEART_VALVE_POSITION + Vector2(0, -13), HEART_VALVE_POSITION + Vector2(0, 13), Color("#f4d9c0"), 3.0)

	var highlighted_position := get_target_position(_highlighted_target)
	if not _highlighted_target.is_empty():
		var radius := 24.0 + sin(_pulse_time * 5.0) * 3.0
		draw_arc(highlighted_position, radius, 0.0, TAU, 24, Color("#fff29b"), 3.0)
		draw_line(
			highlighted_position + Vector2(0, -radius - 14),
			highlighted_position + Vector2(0, -radius - 4),
			Color("#fff29b"),
			4.0
		)


func _draw_city_lighting() -> void:
	var oxygen: float = _state.get("oxygen", 92.0)
	var darkness := clampf((62.0 - oxygen) / 62.0, 0.0, 0.58)
	if darkness > 0.01:
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.07, 0.02, 0.09, darkness))
		var warning_color := Color("#ff795f", 0.55 + sin(_pulse_time * 4.0) * 0.18)
		for warning_pos in [
			Vector2(402, 314),
			Vector2(850, 314),
			Vector2(920, 400),
		]:
			draw_circle(warning_pos, 5.0, warning_color)
			draw_line(warning_pos + Vector2(0, -10), warning_pos, warning_color, 2.0)


func _draw_packets(
	points: PackedVector2Array,
	color: Color,
	strength: float,
	count: int
) -> void:
	if points.size() < 2:
		return
	var segment_count := points.size() - 1
	for index in range(count):
		var progress := fmod(_pulse_time * (0.22 + strength * 0.18) + float(index) / count, 1.0)
		var scaled := progress * segment_count
		var segment := mini(int(floor(scaled)), segment_count - 1)
		var local_progress := scaled - segment
		var packet_position := points[segment].lerp(points[segment + 1], local_progress)
		draw_circle(packet_position, 4.0, Color(color, 0.28))
		draw_circle(packet_position, 2.0, color)


func _district_brightness() -> float:
	var oxygen: float = _state.get("oxygen", 92.0)
	return clampf(oxygen / 75.0, 0.23, 1.0)


func _build_collision_geometry() -> void:
	for rect in _collision_rects:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		body.add_child(shape_node)
		add_child(body)
