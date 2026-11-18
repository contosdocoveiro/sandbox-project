class_name EnemyBehaviorComponent
extends Node2D

@export var actor: CharacterBody2D
@export var physics_component: PhysicsComponent
@export var input_component: InputComponent
@export var state_manager: EnemyStateManagerComponent

func tick(_delta: float) -> void:
	pass
