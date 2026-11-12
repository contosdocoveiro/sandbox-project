class_name PhysicsComponent extends Node2D

@export var move_speed : float
@export var dash_speed : float
@export var dash_duration : float
@export var actor : CharacterBody2D
@export var steer_force : float
@export_category("Nodes")
@export var dash_component : Dash
@export var input_component : InputComponent

var direction : Vector2
var last_faced_direction : Vector2
var applied_knockback : Vector2
@export var knockback_resistance : float
@export var can_be_knocked_back := true

func _ready() -> void:
	if(actor.health_component):
		var health_component = actor.health_component
		health_component.damage_taken.connect(process_attack_knockback)

func move() -> void:
	actor.move_and_slide()

func calculate_velocity() -> Vector2:
	direction = input_component.input_direction
	if(direction != Vector2.ZERO):
		last_faced_direction = direction
	var speed
	if(input_component.dash_input):
		if(!dash_component.is_dashing()):
			dash_component.start_dash(dash_duration)
	if(dash_component.is_dashing()):
		speed = dash_speed
	else:
		speed = move_speed
	
	if(steer_force != 0):
		var final_velocity = direction * speed
		return actor.velocity.lerp(final_velocity, steer_force)
	else:
		return speed * direction
	

func calculate_knockback(knockback_origin : Vector2, knockback_force : float):
	var knockback_dir = knockback_origin.direction_to(actor.global_position).normalized()
	applied_knockback = knockback_dir * knockback_force
	
func apply_knockback():
	actor.velocity += applied_knockback
	applied_knockback = applied_knockback.move_toward(Vector2.ZERO, knockback_resistance)
	
func process_attack_knockback(attack : Attack):
	if(can_be_knocked_back):
		calculate_knockback(attack.attack_position, attack.knockback_force)
	
func end_dash():
	dash_component.end_dash()
	
