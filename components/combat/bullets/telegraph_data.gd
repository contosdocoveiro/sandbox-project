class_name TelegraphData
extends Resource

enum Shape { LINE, CONE, RING, CIRCLE, RECT, ARC }

@export var shape := Shape.LINE
@export var duration := 0.6

@export var follow_aim := true


@export var lock_aim_at_end := true

@export_group("Red warning look")
@export var fill_color := Color(1.0, 0.0, 0.0, 0.35)
@export var outline_color := Color(1.0, 0.1, 0.1, 0.9)
@export var line_width := 2.0
@export var pulse := true
@export var pulse_speed := 6.0
@export var z_index := 100

@export_group("Shape")
@export var length := 240.0
@export var cone_degrees := 30.0
@export var radius := 40.0
@export var arc_start_degrees := -45.0
@export var arc_end_degrees := 45.0
@export var rect_size := Vector2(120.0, 60.0)
