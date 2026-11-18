extends CharacterBody2D
class_name PlayableCharacter

@export_category("Nodes")
@export var physics_component : PhysicsComponent
@export var input_component : PlayerInputComponent
@export var health_component : HealthComponent

var _last_faced_direction := Vector2.RIGHT


func _physics_process(_delta: float) -> void:
	input_component.handle_inputs()
	velocity = physics_component.calculate_velocity()
	
	
	physics_component.apply_knockback()
	physics_component.move()

func _process(_delta: float) -> void:
	if physics_component.last_faced_direction.length_squared() > 0.001:
		_last_faced_direction = physics_component.last_faced_direction
	
