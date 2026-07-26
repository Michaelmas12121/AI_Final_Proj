class_name BodyCityDirectionCue
extends Control

var target_offset := Vector2.RIGHT
var target_kind := ""
var pulse_time := 0.0


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func set_target(offset: Vector2, kind: String) -> void:
	target_offset = offset
	target_kind = kind
	visible = not kind.is_empty()


func _draw() -> void:
	if target_kind.is_empty():
		return
	var center := Vector2(25, 25)
	var direction := target_offset.normalized()
	var perpendicular := direction.orthogonal()
	var pulse := sin(pulse_time * 5.0) * 3.0
	var tip := center + direction * (18.0 + pulse)
	var base := center + direction * 5.0
	var arrow := PackedVector2Array(
		[tip, base + perpendicular * 7.0, base - perpendicular * 7.0]
	)
	draw_colored_polygon(arrow, Color("#fff09b"))
	draw_circle(center, 10.0, Color("#211424e6"))
	draw_arc(center, 11.0, 0.0, TAU, 16, Color("#ffbc63"), 2.0)
	match target_kind:
		"energy_cell":
			draw_rect(Rect2(center - Vector2(4, 6), Vector2(8, 12)), Color("#71f1d9"))
			draw_line(center + Vector2(-5, -7), center + Vector2(5, -10), Color("#ffe16c"), 2.0)
		"lung_power":
			draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), Color("#ffe16c"), 3.0)
			draw_line(center + Vector2(0, -5), center + Vector2(0, 5), Color("#ffe16c"), 3.0)
		"air_intake":
			for y in [-5.0, 0.0, 5.0]:
				draw_line(center + Vector2(-6, y), center + Vector2(5, y), Color("#8ff7f0"), 2.0)
				draw_line(center + Vector2(2, y - 2), center + Vector2(5, y), Color("#8ff7f0"), 2.0)
		"chambers":
			draw_line(center + Vector2(-6, 0), center + Vector2(-1, 0), Color("#8ff7f0"), 2.0)
			draw_line(center + Vector2(1, 0), center + Vector2(6, 0), Color("#8ff7f0"), 2.0)
			draw_line(center + Vector2(-6, 0), center + Vector2(-3, -3), Color("#8ff7f0"), 2.0)
			draw_line(center + Vector2(6, 0), center + Vector2(3, 3), Color("#8ff7f0"), 2.0)
		"heart_valve":
			draw_line(center + Vector2(-6, 4), center + Vector2(1, 4), Color("#ff8e73"), 3.0)
			draw_line(center + Vector2(1, 4), center + Vector2(1, -5), Color("#ff8e73"), 3.0)
