class_name Hurtbox
extends Area2D


func _init() -> void:
	collision_mask = 8
	collision_layer = 0

func _ready() -> void:
	connect("area_entered", self._on_area_entered)

func _on_area_entered(hitbox: Area2D) -> void:
	if hitbox == null:
		return
	if hitbox.owner == owner or hitbox.owner.owner == owner:
		return
	
	if owner.has_method("take_damage"):
		owner.take_damage(hitbox.damage)
	
