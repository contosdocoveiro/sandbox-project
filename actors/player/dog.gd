extends CharacterBody2D
class_name PlayableCharacter


@export_category("Modifiers")
@export  var can_move_during_attack := false

@export_category("Stats")
@export var _move_speed = 120
@export var life = 100
@export var dash_speed = 250
@export var dash_duration = 0.2

@export_category("Nodes")
@export var state_manager : PlayerStateManagerComponent
@export var dash : Dash
@export var _sprite : Node2D
@export var physics_component : PhysicsComponent
@export var input_component : PlayerInputComponent
@export var animation_component : PlayerAnimationComponent
@export var health_component : HealthComponent

var _direction := Vector2.ZERO
var _last_faced_direction := Vector2.RIGHT


func send_attack_signal() -> void:
	state_manager.send_attack_signal()

func _physics_process(delta: float) -> void:
	input_component.handle_inputs()
	velocity = physics_component.calculate_velocity()
	if(state_manager.current_state == "attacking" and !can_move_during_attack):
		velocity = Vector2.ZERO
	
	
	physics_component.apply_knockback()
	physics_component.move()

func _process(delta: float) -> void:
	_last_faced_direction = physics_component.last_faced_direction
	
