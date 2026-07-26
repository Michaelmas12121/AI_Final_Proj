extends Control

const WORLD_SIZE := Vector2(430.0, 360.0)
const PLACENTA_RECT := Rect2(22.0, 72.0, 104.0, 78.0)
const HEART_RECT := Rect2(164.0, 72.0, 104.0, 78.0)
const LUNGS_RECT := Rect2(164.0, 210.0, 104.0, 78.0)
const BODY_RECT := Rect2(306.0, 72.0, 104.0, 78.0)

var _state: Dictionary = {
	"oxygen": 82.0,
	"placental_supply": 100.0,
	"lung_activation": 0.0,
	"pulmonary_flow": 5.0,
	"oxygen_status": "healthy",
	"phase": "PRE_BIRTH",
}
var _packet_phase := 0.0
var _packet_speed := 0.22
var _brightness := 1.0
var _pulse_time := 0.0
var _success_time := 0.0


func _ready() -> void:
	set_process(true)
	queue_redraw()


func set_state(snapshot: Dictionary) -> void:
	_state = snapshot


func _process(delta: float) -> void:
	var oxygen: float = _state.get("oxygen", 82.0)
	var target_brightness := remap(clampf(oxygen, 0.0, 100.0), 0.0, 100.0, 0.32, 1.0)
	if _state.get("phase", "") == "SUCCESS":
		target_brightness = 1.16
		_success_time += delta
	else:
		_success_time = 0.0
	_brightness = lerpf(_brightness, target_brightness, 1.0 - exp(-delta * 2.5))

	var status: String = _state.get("oxygen_status", "healthy")
	var target_packet_speed := 0.22
	if status == "falling":
		target_packet_speed = 0.16
	elif status == "distress":
		target_packet_speed = 0.10
	elif status == "critical":
		target_packet_speed = 0.045
	var circulation: float = _state.get("circulation_efficiency", 85.0)
	target_packet_speed *= remap(clampf(circulation, 85.0, 100.0), 85.0, 100.0, 1.0, 1.28)
	_packet_speed = lerpf(_packet_speed, target_packet_speed, 1.0 - exp(-delta * 2.0))
	_packet_phase = fmod(_packet_phase + delta * _packet_speed, 1.0)
	_pulse_time += delta
	var shake: float = _state.get("screen_shake", 0.0)
	position = Vector2(
		sin(_pulse_time * 71.0),
		cos(_pulse_time * 53.0)
	) * shake * 4.0
	queue_redraw()


func _draw() -> void:
	var phase: String = _state.get("phase", "PRE_BIRTH")
	var background_base := Color("#3f0d23")
	if phase == "STABILIZATION" or phase == "SUCCESS":
		background_base = background_base.lerp(Color("#54233b"), 0.45)
	var background := background_base * _brightness
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), background)
	_draw_soft_grid()

	var placental_route := PackedVector2Array([
		Vector2(PLACENTA_RECT.end.x, PLACENTA_RECT.get_center().y),
		Vector2(HEART_RECT.position.x, HEART_RECT.get_center().y),
	])
	var systemic_route := PackedVector2Array([
		Vector2(HEART_RECT.end.x, HEART_RECT.get_center().y),
		Vector2(BODY_RECT.position.x, BODY_RECT.get_center().y),
	])
	var pulmonary_route := PackedVector2Array([
		Vector2(LUNGS_RECT.get_center().x, LUNGS_RECT.position.y),
		Vector2(HEART_RECT.get_center().x, HEART_RECT.end.y),
		Vector2(HEART_RECT.get_center().x, HEART_RECT.get_center().y),
	])
	var placental_packet_path := PackedVector2Array([
		Vector2(PLACENTA_RECT.end.x, PLACENTA_RECT.get_center().y),
		Vector2(HEART_RECT.position.x, HEART_RECT.get_center().y),
		Vector2(HEART_RECT.end.x, HEART_RECT.get_center().y),
		Vector2(BODY_RECT.position.x, BODY_RECT.get_center().y),
	])
	var pulmonary_packet_path := PackedVector2Array([
		Vector2(LUNGS_RECT.get_center().x, LUNGS_RECT.position.y),
		Vector2(HEART_RECT.get_center().x, HEART_RECT.end.y),
		Vector2(HEART_RECT.get_center().x, HEART_RECT.get_center().y),
		Vector2(BODY_RECT.position.x, BODY_RECT.get_center().y),
	])

	var placental_strength: float = _state.get("placental_supply", 100.0) / 100.0
	var lung_strength: float = (
		_state.get("lung_activation", 0.0)
		/ 100.0
		* _state.get("pulmonary_flow", 5.0)
		/ 100.0
	)
	var placenta_color := Color(1.0, 0.25, 0.29, 0.12 + placental_strength * 0.88)
	var pulmonary_color := Color(0.30, 0.87, 1.0, 0.18 + lung_strength * 0.82)
	var systemic_color := Color("#71314d").lerp(
		Color("#ff4f58"),
		clampf(_state.get("oxygen", 82.0) / 100.0, 0.0, 1.0)
	)
	var transport_boost := clampf(
		(_state.get("circulation_efficiency", 85.0) - 85.0) / 10.0,
		0.0,
		1.0
	)
	systemic_color = systemic_color.lightened(transport_boost * 0.22)
	_draw_route(placental_route, placenta_color)
	_draw_route(pulmonary_route, pulmonary_color)
	_draw_route(systemic_route, systemic_color)
	_draw_route_arrows(placental_route, placenta_color)
	_draw_route_arrows(pulmonary_route, pulmonary_color)
	_draw_route_arrows(systemic_route, systemic_color)

	var heart_pulse := (sin(_pulse_time * 5.2) + 1.0) * 1.6
	var lung_pulse: float = (
		(sin(_pulse_time * (2.0 + _state.get("lung_activation", 0.0) / 28.0)) + 1.0)
		* _state.get("lung_activation", 0.0)
		/ 100.0
		* 2.2
	)
	_draw_district(
		PLACENTA_RECT,
		"PLACENTA",
		Color("#d65b87"),
		_state.get("placental_supply", 100.0) / 100.0
	)
	_draw_district(HEART_RECT.grow(heart_pulse), "HEART", Color("#ed3f5f"), 0.85)
	_draw_district(
		LUNGS_RECT.grow(lung_pulse),
		"LUNGS",
		Color("#4fcce8"),
		0.22 + _state.get("lung_activation", 0.0) / 128.0
	)
	_draw_body_city()
	_draw_district_activity(heart_pulse, lung_pulse)

	_draw_packets(placental_packet_path, placental_strength, Color("#ff575f"))
	_draw_packets(pulmonary_packet_path, lung_strength, Color("#66e2ff"))
	_draw_distribution_routes(lung_strength)
	_draw_energy_reserve()

	if placental_strength <= 0.04 and _state.get("birth_started", false):
		var sever_position := Vector2(PLACENTA_RECT.end.x + 18.0, PLACENTA_RECT.get_center().y)
		draw_line(
			sever_position + Vector2(-5, -7),
			sever_position + Vector2(5, 7),
			Color("#ffca8a"),
			2.0
		)
		draw_line(
			sever_position + Vector2(-5, 7),
			sever_position + Vector2(5, -7),
			Color("#ffca8a"),
			2.0
		)

	var takeover_flash: float = _state.get("takeover_flash", 0.0)
	if takeover_flash > 0.0:
		draw_rect(
			Rect2(Vector2.ZERO, WORLD_SIZE),
			Color(0.42, 0.93, 1.0, takeover_flash * 0.22)
		)

	var status: String = _state.get("oxygen_status", "healthy")
	if status == "falling" or status == "distress" or status == "critical":
		_draw_warning_indicator(status)
	if status == "critical":
		var critical_progress := clampf(
			_state.get("critical_state_timer", 0.0) / 5.0,
			0.0,
			1.0
		)
		var pulse := 0.08 + (sin(_pulse_time * 7.0) + 1.0) * (0.06 + critical_progress * 0.09)
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.85, 0.02, 0.05, pulse))
		_draw_partial_blackout()
	if phase == "SUCCESS":
		_draw_success_relight()


func _draw_soft_grid() -> void:
	var grid_color := Color(1.0, 0.56, 0.63, 0.035 * _brightness)
	for x in range(0, int(WORLD_SIZE.x), 16):
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), grid_color, 1.0)
	for y in range(0, int(WORLD_SIZE.y), 16):
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), grid_color, 1.0)


func _draw_route(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, Color(0.10, 0.02, 0.06, 0.8), 11.0, false)
	draw_polyline(points, color * _brightness, 5.0, false)


func _draw_route_arrows(points: PackedVector2Array, color: Color) -> void:
	for progress in [0.3, 0.62, 0.86]:
		var center := _point_on_path(points, progress)
		var ahead := _point_on_path(points, minf(1.0, progress + 0.025))
		var direction := center.direction_to(ahead)
		if direction.is_zero_approx():
			continue
		var side := direction.rotated(PI * 0.5)
		var triangle := PackedVector2Array([
			center + direction * 5.0,
			center - direction * 4.0 + side * 3.0,
			center - direction * 4.0 - side * 3.0,
		])
		draw_colored_polygon(triangle, color.lightened(0.2) * _brightness)


func _draw_district(rect: Rect2, label: String, color: Color, activity: float) -> void:
	var clamped_activity := clampf(activity, 0.0, 1.0)
	var shadow := rect.grow(4.0)
	draw_rect(shadow, Color(0.04, 0.01, 0.025, 0.65))
	draw_rect(rect, color.darkened(0.48) * _brightness)
	draw_rect(rect.grow(-5.0), color * (0.52 + clamped_activity * 0.48) * _brightness)
	draw_rect(rect, color.lightened(0.25) * _brightness, false, 2.0)

	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var text_position := Vector2(
		rect.get_center().x - text_size.x * 0.5,
		rect.end.y - 9.0
	)
	draw_string(font, text_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _draw_body_city() -> void:
	var oxygen_level := clampf(_state.get("oxygen", 82.0) / 100.0, 0.0, 1.0)
	var left := Rect2(BODY_RECT.position, Vector2(BODY_RECT.size.x * 0.5 - 1.0, BODY_RECT.size.y))
	var right := Rect2(
		Vector2(BODY_RECT.get_center().x + 1.0, BODY_RECT.position.y),
		Vector2(BODY_RECT.size.x * 0.5 - 1.0, BODY_RECT.size.y)
	)
	var vital_ratio := _district_supply_ratio("vital")
	var growth_ratio := _district_supply_ratio("growth")
	var vital_activity := minf(oxygen_level, vital_ratio)
	var growth_activity := minf(oxygen_level, growth_ratio)

	draw_rect(BODY_RECT.grow(4.0), Color(0.04, 0.01, 0.025, 0.65))
	draw_rect(BODY_RECT, Color("#5e2f35") * _brightness)
	draw_rect(left.grow(-3.0), Color("#ef6c5b") * (0.32 + vital_activity * 0.68) * _brightness)
	draw_rect(right.grow(-3.0), Color("#e7a35a") * (0.32 + growth_activity * 0.68) * _brightness)
	draw_rect(BODY_RECT, Color("#ffd088") * _brightness, false, 2.0)
	draw_line(
		Vector2(BODY_RECT.get_center().x, BODY_RECT.position.y + 4.0),
		Vector2(BODY_RECT.get_center().x, BODY_RECT.end.y - 4.0),
		Color("#2b1222"),
		2.0
	)

	for column in range(2):
		for row in range(2):
			var vital_window := left.position + Vector2(13 + column * 16, 15 + row * 16)
			var growth_window := right.position + Vector2(10 + column * 16, 15 + row * 16)
			draw_rect(
				Rect2(vital_window, Vector2(7, 7)),
				Color("#fff0b0").lerp(Color("#512b3c"), 1.0 - vital_activity) * _brightness
			)
			draw_rect(
				Rect2(growth_window, Vector2(7, 7)),
				Color("#ffe078").lerp(Color("#512b3c"), 1.0 - growth_activity) * _brightness
			)

	var font := ThemeDB.fallback_font
	draw_string(
		font,
		left.position + Vector2(7, 70),
		"CORE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		Color.WHITE
	)
	draw_string(
		font,
		right.position + Vector2(5, 70),
		"GROW",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		Color.WHITE
	)
	if _state.get("vital_core_neglect", 0.0) > 0.1:
		_draw_district_alert(left.get_center(), "CORE")
	if _state.get("growing_body_neglect", 0.0) > 0.1:
		_draw_district_alert(right.get_center(), "GROW")


func _draw_distribution_routes(lung_strength: float) -> void:
	if _state.get("phase", "") != "STABILIZATION" and _state.get("phase", "") != "SUCCESS":
		return
	var entry := Vector2(BODY_RECT.position.x, BODY_RECT.get_center().y)
	var core_target := Vector2(BODY_RECT.position.x + 25.0, BODY_RECT.get_center().y)
	var growth_target := Vector2(BODY_RECT.end.x - 25.0, BODY_RECT.get_center().y)
	var vital_strength: float = _state.get("vital_core_allocation", 0.0) / 100.0
	var growth_strength: float = _state.get("growing_body_allocation", 0.0) / 100.0
	var core_path := PackedVector2Array([entry, core_target])
	var growth_path := PackedVector2Array([entry, growth_target])
	_draw_route(core_path, Color(1.0, 0.35, 0.38, 0.18 + vital_strength))
	_draw_route(growth_path, Color(1.0, 0.72, 0.25, 0.18 + growth_strength))
	_draw_packets(core_path, lung_strength * vital_strength * 1.7, Color("#ff6468"))
	_draw_packets(growth_path, lung_strength * growth_strength * 1.7, Color("#ffd05f"))


func _draw_energy_reserve() -> void:
	var remaining: float = _state.get("energy_reserve_remaining", 0.0)
	if remaining <= 0.0:
		return
	var ratio := clampf(remaining / 16.0, 0.0, 1.0)
	var bar := Rect2(BODY_RECT.position + Vector2(8, -15), Vector2(88, 7))
	draw_rect(bar, Color("#251322"))
	draw_rect(
		Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2.0) * ratio, 5)),
		Color("#ffd35d") * _brightness
	)
	draw_rect(bar, Color("#fff0a8"), false, 1.0)


func _district_supply_ratio(district: String) -> float:
	if not _state.get("stabilization_started", false):
		return clampf(_state.get("oxygen", 82.0) / 100.0, 0.0, 1.0)
	var allocation: float = (
		_state.get("vital_core_allocation", 0.0)
		if district == "vital"
		else _state.get("growing_body_allocation", 0.0)
	)
	var need: float = (
		_state.get("vital_core_need", 1.0)
		if district == "vital"
		else _state.get("growing_body_need", 1.0)
	)
	return clampf(allocation / maxf(1.0, need), 0.0, 1.0)


func _draw_district_alert(center: Vector2, label: String) -> void:
	var font := ThemeDB.fallback_font
	draw_circle(center - Vector2(0, 12), 9.0, Color("#250d18"))
	draw_circle(center - Vector2(0, 12), 8.0, Color("#ffb45f"), false, 2.0)
	draw_string(
		font,
		center + Vector2(-2.5, -8.0),
		"!",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color("#fff2d5")
	)
	draw_string(
		font,
		center + Vector2(-14, 4),
		label + " LOW",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		7,
		Color("#fff2d5")
	)


func _draw_warning_indicator(status: String) -> void:
	var font := ThemeDB.fallback_font
	var label := "OXYGEN FALLING"
	if status == "distress":
		label = "SUPPLY TOO LOW"
	elif status == "critical":
		label = "BLACKOUT RISK"
	var center := Vector2(WORLD_SIZE.x * 0.5, 32.0)
	var triangle := PackedVector2Array([
		center + Vector2(0, -12),
		center + Vector2(-13, 10),
		center + Vector2(13, 10),
	])
	draw_colored_polygon(triangle, Color("#ffb555"))
	draw_string(font, center + Vector2(-2.5, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#39131d"))
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(
		font,
		Vector2(center.x - width * 0.5, 55),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color("#fff0d0")
	)


func _draw_partial_blackout() -> void:
	var flicker := 0.35 + (sin(_pulse_time * 9.0) + 1.0) * 0.12
	draw_rect(Rect2(Vector2(0, 164), Vector2(150, 54)), Color(0.03, 0.01, 0.025, flicker))
	draw_rect(Rect2(Vector2(286, 210), Vector2(144, 70)), Color(0.03, 0.01, 0.025, flicker))


func _draw_district_activity(heart_pulse: float, lung_pulse: float) -> void:
	var heart_center := HEART_RECT.get_center() - Vector2(0, 8)
	draw_circle(
		heart_center,
		10.0 + heart_pulse,
		Color("#ff8a91") * _brightness
	)
	draw_circle(heart_center, 5.0 + heart_pulse * 0.5, Color("#fff0d7") * _brightness)

	var lungs_center := LUNGS_RECT.get_center() - Vector2(0, 8)
	var lung_color := Color("#9cecff") * _brightness
	draw_circle(lungs_center + Vector2(-14, 0), 12.0 + lung_pulse, lung_color)
	draw_circle(lungs_center + Vector2(14, 0), 12.0 + lung_pulse, lung_color)
	draw_line(
		lungs_center + Vector2(0, -17),
		lungs_center + Vector2(0, 9),
		Color("#e8fcff") * _brightness,
		3.0
	)

	for index in range(5):
		var angle := _pulse_time * 0.8 + index * TAU / 5.0
		var node_position := PLACENTA_RECT.get_center() + Vector2(cos(angle), sin(angle)) * 18.0
		draw_circle(node_position, 3.0, Color("#ffd0df") * _brightness)

func _draw_packets(path: PackedVector2Array, strength: float, color: Color) -> void:
	if strength <= 0.015:
		return
	var packet_count := maxi(1, ceili(7.0 * strength))
	var oxygenation := clampf(_state.get("oxygen", 82.0) / 100.0, 0.0, 1.0)
	for index in range(packet_count):
		var progress := fmod(_packet_phase + float(index) / float(packet_count), 1.0)
		var position := _point_on_path(path, progress)
		var is_oxygen_rich := float(index + 1) / float(packet_count) <= oxygenation
		draw_circle(position, 4.0, Color(0.06, 0.01, 0.03, 0.8))
		if is_oxygen_rich:
			draw_circle(position, 2.5, color * _brightness)
		else:
			draw_circle(position, 2.8, Color("#315c82") * _brightness, false, 1.5)


func _draw_success_relight() -> void:
	var glow := 0.06 + (sin(_success_time * 3.0) + 1.0) * 0.025
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(1.0, 0.76, 0.42, glow))
	for index in range(18):
		var x := fmod(float(index * 83) + _success_time * (8.0 + index % 3), WORLD_SIZE.x)
		var y := fmod(float(index * 47) - _success_time * (10.0 + index % 4), WORLD_SIZE.y)
		draw_circle(Vector2(x, y), 1.5 + index % 2, Color("#ffe8a3"))


func _point_on_path(path: PackedVector2Array, progress: float) -> Vector2:
	var total_length := 0.0
	for index in range(path.size() - 1):
		total_length += path[index].distance_to(path[index + 1])

	var target_distance := progress * total_length
	for index in range(path.size() - 1):
		var segment_length := path[index].distance_to(path[index + 1])
		if target_distance <= segment_length:
			return path[index].lerp(path[index + 1], target_distance / segment_length)
		target_distance -= segment_length
	return path[path.size() - 1]
