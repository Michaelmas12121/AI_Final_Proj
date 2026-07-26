class_name MaintenanceWorker
extends CharacterBody2D

signal interaction_requested

const MOVE_SPEED := 62.0

var carrying_energy_cell := false
var movement_enabled := true
var _move_target := Vector2.ZERO
var _has_move_target := false


func _ready() -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		return

	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	if not input_vector.is_zero_approx():
		_has_move_target = false
	elif _has_move_target:
		var offset := _move_target - global_position
		if offset.length() <= 4.0:
			_has_move_target = false
		else:
			input_vector = offset.normalized()
	velocity = input_vector.normalized() * MOVE_SPEED
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]
	):
		interaction_requested.emit()


func set_carrying_energy_cell(value: bool) -> void:
	if carrying_energy_cell == value:
		return
	carrying_energy_cell = value
	queue_redraw()


func move_to(world_position: Vector2) -> void:
	_move_target = world_position
	_has_move_target = true


func stop_moving() -> void:
	_has_move_target = false
	velocity = Vector2.ZERO


func _draw() -> void:
	# Shadow and boots.
	draw_rect(Rect2(-7, 6, 14, 5), Color("#2b1830"))
	draw_rect(Rect2(-6, 4, 5, 6), Color("#412538"))
	draw_rect(Rect2(1, 4, 5, 6), Color("#412538"))
	# Orange maintenance suit.
	draw_rect(Rect2(-6, -5, 12, 11), Color("#e9824f"))
	draw_rect(Rect2(-4, -3, 8, 6), Color("#ffb45f"))
	# Helmet with a cyan visor.
	draw_rect(Rect2(-7, -12, 14, 8), Color("#f6e7ce"))
	draw_rect(Rect2(-5, -10, 10, 4), Color("#63d8d6"))
	draw_rect(Rect2(-4, -9, 7, 2), Color("#b8ffff"))
	# Tool pack makes the silhouette readable from behind.
	draw_rect(Rect2(-9, -3, 3, 7), Color("#59435b"))
	if carrying_energy_cell:
		draw_rect(Rect2(7, -7, 6, 8), Color("#ffe06d"))
		draw_rect(Rect2(8, -6, 4, 6), Color("#7df4dc"))
		draw_line(Vector2(7, -8), Vector2(12, -11), Color("#fff4a8"), 2.0)
