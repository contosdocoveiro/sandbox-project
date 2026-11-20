class_name SpreadPattern
extends BulletPattern

@export var count := 5
@export var spread_degrees := 45.0
@export var speed_scale := 1.0

func build_shot(context: BulletShotContext) -> Array[BulletSpawn]:
	var result: Array[BulletSpawn] = []

	if count <= 1:
		var single := BulletSpawn.new()
		single.bullet = bullet
		single.angle = context.aim_angle
		single.speed_scale = speed_scale
		result.append(single)
		return result

	var total := deg_to_rad(spread_degrees)
	var step := total / maxf(count - 1, 1)
	var start := context.aim_angle - total * 0.5

	for i in count:
		var spawn := BulletSpawn.new()
		spawn.bullet = bullet
		spawn.angle = start + step * i
		spawn.speed_scale = speed_scale
		result.append(spawn)

	return result
