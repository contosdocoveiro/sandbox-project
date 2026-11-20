class_name Telegraph
extends Node2D

var data: TelegraphData
var _time := 0.0
var _duration_left := 0.0

func _ready() -> void:
	top_level = true
	visible = false
	set_process(false)
	
func show_telegraph(d: TelegraphData, origin: Vector2, angle: float) -> void:
	data = d
	global_position = origin
	global_rotation = angle
	_time = 0.0
	_duration_left = d.duration
	z_index = d.z_index
	visible = true
	set_process(true)
	queue_redraw()

func set_aim(origin: Vector2, angle: float) -> void:
	global_position = origin
	global_rotation = angle
	queue_redraw()

func _draw() -> void:
	if data == null:
		return

	var alpha := 1.0
	if data.pulse:
		alpha = 0.55 + 0.45 * sin(_time * data.pulse_speed)

	var fill := data.fill_color
	var line := data.outline_color
	fill.a *= alpha
	line.a *= alpha

	match data.shape:
		TelegraphData.Shape.LINE:
			draw_line(Vector2.ZERO, Vector2.RIGHT * data.length, line, data.line_width)

		TelegraphData.Shape.CONE:
			var half := deg_to_rad(data.cone_degrees) * 0.5
			var points := PackedVector2Array([Vector2.ZERO])
			var steps := 16
			for i in steps + 1:
				var a := -half + (2.0 * half) * float(i) / steps
				points.append(Vector2.RIGHT.rotated(a) * data.length)
			draw_colored_polygon(points, fill)
			draw_polyline(points, line, data.line_width)
			draw_line(Vector2.ZERO, points[points.size() - 1], line, data.line_width)

		TelegraphData.Shape.RING:
			draw_arc(Vector2.ZERO, data.radius, 0.0, TAU, 64, line, data.line_width, true)

		TelegraphData.Shape.CIRCLE:
			draw_circle(Vector2.ZERO, data.radius, fill)
			draw_arc(Vector2.ZERO, data.radius, 0.0, TAU, 64, line, data.line_width, true)

		TelegraphData.Shape.RECT:
			var rect := Rect2(Vector2.ZERO, data.rect_size)
			draw_rect(rect, fill, true)
			draw_rect(rect, line, false, data.line_width)

		TelegraphData.Shape.ARC:
			draw_arc(
				Vector2.ZERO,
				data.radius,
				deg_to_rad(data.arc_start_degrees),
				deg_to_rad(data.arc_end_degrees),
				48,
				line,
				data.line_width,
				true
			)
