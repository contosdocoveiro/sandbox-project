class_name RingPattern
extends BulletPattern

@export var count := 12
@export var start_angle_degrees := 0.0
@export var spin_degrees_per_shot := 0.0
@export var use_aim := false
@export var speed_scale := 1.0

func build_shot(context: BulletShotContext) -> Array[BulletSpawn]:
	var result: Array[BulletSpawn] = []
	
	var shot := context.shot_index + context.wave_index * maxi(shots_per_wave, 1)
	var base := deg_to_rad(spin_degrees_per_shot) * shot
	if use_aim:
		base += context.aim_angle
	
	for i in count:
		var spawn := BulletSpawn.new()
		spawn.bullet = bullet
		spawn.angle = base + TAU * i/count
		spawn.speed_scale = speed_scale
		result.append(spawn)
	
	return result
