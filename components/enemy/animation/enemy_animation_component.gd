class_name EnemyAnimationComponent
extends Node

@export var state_manager: EnemyStateManagerComponent
@export var animation_player: AnimationPlayer
@export var sprite: AnimatedSprite2D
@export var physics_component: PhysicsComponent

@export var animations: Dictionary = {
	&"idle": &"idle",
	&"ready": &"idle",
	&"chase": &"run",
	&"attack": &"attack",
	&"hurt": &"hurt",
}

func _ready() -> void:
	state_manager.state_changed.connect(_on_state_changed)
	animation_player.animation_finished.connect(_on_animation_finished)
	physics_component.facing_changed.connect(_on_facing_changed)
	
func _on_state_changed(_previous: StringName, current: StringName) -> void:
	var anim: StringName = animations.get(current, &"")
	if anim != &"":
		animation_player.play(anim)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == animations.get(state_manager.current_state, &""):
		state_manager.notify_animation_finished()

func _on_facing_changed(direction: Vector2) -> void:
	sprite.flip_h = direction.x < 0
