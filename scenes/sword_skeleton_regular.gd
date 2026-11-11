extends CharacterBody2D
class_name SwordSkeleton


@export var sprite : AnimatedSprite2D
@export var attack_vfx : AnimatedSprite2D
@export var state_manager : StateManagerComponent
@export var dash : Dash
@export var detection_area : DetectionArea
@export var navigation_component : NavigationComponent
@export var input_component : InputComponent
@export var physics_component : PhysicsComponent
@export var attack_range : AttackRangeComponent
@export var enemy_behavior : EnemyBehaviorComponent
@export var health_component : HealthComponent

func _physics_process(delta: float) -> void:
	enemy_behavior.dash_attacker_behavior()
