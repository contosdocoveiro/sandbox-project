class_name AttackRangeComponent
extends Area2D

var is_in_attack_range := false


func _on_area_entered(area: Area2D) -> void:
	if(area.is_in_group("player")):
		is_in_attack_range = true
	

func _on_area_exited(area: Area2D) -> void:
	if(area.is_in_group("player")):
		is_in_attack_range = false
