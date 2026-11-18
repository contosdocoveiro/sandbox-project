extends Node

func freeze_frame(time_scale, duration):
	Engine.time_scale = time_scale
	var timer = get_tree().create_timer(time_scale * duration)
	await timer.timeout
	Engine.time_scale = 1
