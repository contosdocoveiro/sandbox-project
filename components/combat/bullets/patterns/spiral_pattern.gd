class_name SpiralPattern
extends BulletPattern

@export var arms := 1
@export var spin_degrees_per_shot := 15.0
@export var start_angle_degrees := 0.0
@export var use_aim := false
@export var speed_scale := 1.0

func build_shot(context: BulletShotContext) -> Array[BulletSpawn]:
	var result: Array[BulletSpawn] = []
	
	var shot := context.shot_index + context.wave_index * maxi(shots_per_wave,1)
	var base := deg_to_rad(start_angle_degrees)
	base += deg_to_rad(spin_degrees_per_shot) * shot
	if use_aim:
		base += context.aim_angle
	
	for arm in arms:
		var spawn := BulletSpawn.new()
		spawn.bullet = bullet
		spawn.angle = base + TAU * arm / arms
		spawn.speed_scale = speed_scale
		result.append(spawn)
	
	return result
