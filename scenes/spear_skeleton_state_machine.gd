extends Node

@onready var state_chart = $"../StateChart"
@onready var animation_player = $"../AnimationPlayer"
@onready var sprite = $"../Body"
@export var is_attacking := false
@export var attack_cooldown : Timer
@export var attack_ready = true
	

func _on_idle_state_entered() -> void:
	animation_player.play("idle")
func _on_idle_state_physics_processing(delta: float) -> void:
	if (owner.is_in_attack_range and attack_ready):
		state_chart.send_event("attacking")
	elif (owner.velocity != Vector2.ZERO and !is_attacking):
		state_chart.send_event("walking")



func _on_walking_state_entered() -> void:
	animation_player.play("walk")
func _on_walking_state_physics_processing(delta: float) -> void:
	if (owner.is_in_attack_range and attack_ready):
		state_chart.send_event("attacking")
	elif owner.velocity == Vector2.ZERO:
		state_chart.send_event("idle")


func _on_attacking_state_entered() -> void:
	attack_ready = false


func _on_attack_cooldown_timeout() -> void:
	attack_ready = true
	
	


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "spear lunge end"):
		state_chart.send_event("idle")
	if(anim_name == "hurt"):
		state_chart.send_event("history")

func _on_attack_wall_collision_body_entered(body: Node2D) -> void:
	if(is_attacking):
		attack_cooldown.start()
		state_chart.send_event("attack end")

func _on_health_component_damage_taken(attack : Attack) -> void:
	if(attack_cooldown.is_stopped()):
		attack_ready = true
	state_chart.send_event("hurt")
