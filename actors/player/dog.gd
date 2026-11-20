extends CharacterBody2D
class_name PlayableCharacter

@export_category("Nodes")
@export var physics_component : PhysicsComponent
@export var input_component : PlayerInputComponent
@export var health_component : HealthComponent
@export var weapon : Weapon
@export var movement_modifier : MovementModifierComponent
@export var attack_move_multiplier := 0.5

var _last_faced_direction := Vector2.RIGHT

func _ready() -> void:
	if weapon:
		weapon.attack_started.connect(_on_attack_started)
		weapon.attack_ended.connect(_on_attack_ended)
		
func _on_attack_started() -> void:
	if movement_modifier:
		movement_modifier.add(&"attack", attack_move_multiplier)
		
func _on_attack_ended() -> void:
	if movement_modifier:
		movement_modifier.remove(&"attack")

func _physics_process(_delta: float) -> void:
	input_component.handle_inputs()
	velocity = physics_component.calculate_velocity()
	
	
	physics_component.apply_knockback()
	physics_component.move()

func _process(_delta: float) -> void:
	if physics_component.last_faced_direction.length_squared() > 0.001:
		_last_faced_direction = physics_component.last_faced_direction
	
