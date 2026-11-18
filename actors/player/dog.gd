extends CharacterBody2D
class_name PlayableCharacter

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


func _physics_process(delta: float) -> void:
	input_component.handle_inputs()
	velocity = physics_component.calculate_velocity()
	
	
	physics_component.apply_knockback()
	physics_component.move()

func _process(delta: float) -> void:
	if physics_component.last_faced_direction.length_squared() > 0.001:
		_last_faced_direction = physics_component.last_faced_direction
	
