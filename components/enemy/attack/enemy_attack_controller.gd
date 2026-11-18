class_name EnemyAttackController
extends Node

@export var state_chart: StateChart
@export var state_manager: EnemyStateManagerComponent
@export var attack_hitbox: HitboxComponent
@export var attack_vfx: AnimatedSprite2D
@export var detection_area: DetectionArea
@export var cooldown_timer: Timer
@export var rotate_attack := true

func _ready() -> void:
	state_manager.state_changed.connect(_on_state_changed)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	disable_hitbox()

func _on_state_changed(previous: StringName, current: StringName) -> void:
	if previous == &"attack" and current != &"attack":
		close_attack_window()
		cooldown_timer.start()
		state_chart.set_expression_property(&"attack_ready", false)

func _on_cooldown_timeout() -> void:
	state_chart.set_expression_property(&"attack_ready", true)

func open_attack_window() -> void:
	if rotate_attack:
		aim_at_target()
	attack_vfx.visible = true
	attack_vfx.play(&"attack")
	enable_hitbox()

func close_attack_window() -> void:
	disable_hitbox()
	attack_vfx.stop()
	attack_vfx.visible = false

func aim_at_target() -> void:
	var target := detection_area.get_target()
	var direction := Vector2.RIGHT
	
	if is_instance_valid(target):
		direction = state_manager.actor.global_position.direction_to(target.global_position)
	elif state_manager.actor.velocity.length_squared() > 0.01:
		direction = state_manager.actor.velocity.normalized()
	
	attack_vfx.global_rotation = direction.angle()
	
func enable_hitbox() -> void:
	attack_hitbox.collision_shape.set_deferred(&"disabled", false)

func disable_hitbox() -> void:
	attack_hitbox.collision_shape.set_deferred(&"disabled", true)
