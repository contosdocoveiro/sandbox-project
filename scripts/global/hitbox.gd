class_name HitBox
extends Area2D

@export_category("Hitbox Stats")
@export var damage := 10

func _init() -> void:
	collision_layer = 8
	collision_mask = 0
