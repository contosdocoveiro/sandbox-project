class_name Hitbox 
extends Area2D

var damage := 10

func _init() -> void:
	collision_layer = 8
	collision_mask = 0
