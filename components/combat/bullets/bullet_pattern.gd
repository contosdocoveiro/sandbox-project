class_name BulletPattern
extends Resource

@export var bullet: BulletData
@export var telegraph: TelegraphData

@export_group("Timing")
@export var shots_per_wave := 1
@export var shot_interval := 0.1
@export var waves := 1
@export var wave_interval := 0.5
@export var start_delay := 0.0
@export var reaim_each_shot := true

@export_group("Random")
@export var random_seed := 0
@export var randomize_seed := false


func build_shot(_context: BulletShotContext) -> Array[BulletSpawn]:
	return []
