class_name EnemyBehaviorComponent
extends Node2D

@export var actor : CharacterBody2D
@export var physics_component : PhysicsComponent
@export var state_manager : StateManagerComponent
@export var input_component : EnemyInputComponent
@export var charge_hitbox : HitboxComponent
@export var attack_hitbox : HitboxComponent
@export var attack_range : AttackRangeComponent
@export var attack_vfx : AnimatedSprite2D
@export var stop_when_in_attack_range := true

@onready var timer := $Timer

func _ready() -> void:
	if(charge_hitbox):
		charge_hitbox.collided_with_wall.connect(_on_wall_collision)

func dash_attacker_behavior():
	if(!actor.dash.is_dashing()):
		input_component.handle_inputs()
		
	actor.velocity = physics_component.calculate_velocity()

	if(attack_range.is_in_attack_range and state_manager.current_state == "running"):
		if(stop_when_in_attack_range):
			actor.velocity = Vector2.ZERO
			signal_attack()
	
	if((state_manager.current_state == "attacking" and !actor.dash.is_dashing())
	or (!state_manager.timer.is_stopped() and state_manager.current_state != "attacking")):
		actor.velocity = Vector2.ZERO
	
	physics_component.apply_knockback()
	physics_component.move()

func signal_attack():
	physics_component.can_be_knocked_back = false
	state_manager.attack()

func dash_attack(duration : float):
	if(actor.navigation_component):
		if(actor.navigation_component.target):
			var target = actor.navigation_component.target
			physics_component.dash_duration = duration
			actor.dash.dash_cooldown = 0.0
			input_component.start_dash()
			attack_vfx.rotation = global_position.direction_to(target.global_position).angle()
			attack_vfx.visible = true
			attack_vfx.play("attack")
			attack_hitbox.collision_shape.disabled = false
			timer.wait_time = duration
			timer.start()
			await timer.timeout
			attack_vfx.visible = false
			attack_vfx.stop()
			attack_hitbox.collision_shape.disabled = true

func charger_behavior():
	if(!actor.dash.is_dashing()):
		input_component.handle_inputs()
		
	actor.velocity = physics_component.calculate_velocity()
	
	if(attack_range.is_in_attack_range and state_manager.current_state == "running"):
		if(stop_when_in_attack_range):
			actor.velocity = Vector2.ZERO
		signal_charge()
	
	if((state_manager.current_state == "charging" and !actor.dash.is_dashing())
	or state_manager.current_state == "charge end" 
	or !state_manager.timer.is_stopped()):
		actor.velocity = Vector2.ZERO
	
	
	physics_component.apply_knockback()
	physics_component.move()

func signal_charge():
	physics_component.can_be_knocked_back = false
	state_manager.charge()

func charge():
	if(actor.navigation_component):
		if(actor.navigation_component.target):
			var target = actor.navigation_component.target
			attack_vfx.rotation = global_position.direction_to(target.global_position).angle()
			attack_vfx.visible = true
			attack_vfx.play("attack")
			charge_hitbox.collision_shape.disabled = false
	input_component.start_dash()

func _on_wall_collision(body):
	physics_component.can_be_knocked_back = true
	attack_vfx.visible = false
	charge_hitbox.collision_shape.set_deferred("disabled", true)
	physics_component.end_dash()
	state_manager.state_chart.send_event("charge end")
	physics_component.calculate_knockback(body.global_position, 40)
