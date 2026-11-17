class_name EnemyAttackController
extends Node

@export var state_chart: StateChart
@export var state_manager: EnemyStateManagerComponent
@export var attack_hitbox: HitboxComponent
@export var attack_vfx: AnimatedSprite2D
@export var cooldown_timer: Timer

func _ready() -> void:
	state_manager.state_changed.connect(_on_state_changed)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	disable_hitbox()

func _on_state_changed(previous: StringName, current: StringName) -> void:
	if previous == &"attack" and current != &"attack":
		cancel()
		cooldown_timer.start()
		state_chart.set_expression_property(&"attack_ready", false)
	if current == &"attack":
		begin()

func _on_cooldown_timeout() -> void:
	state_chart.set_expression_property(&"attack_ready", true)

func begin() -> void:
	attack_vfx.visible = true
	attack_vfx.play(&"attack")
	# Stage B: aim/face the target here

func cancel() -> void:
	disable_hitbox()
	attack_vfx.visible = false

func enable_hitbox() -> void:
	attack_hitbox.collision_shape.set_deferred(&"disabled", false)

func disable_hitbox() -> void:
	attack_hitbox.collision_shape.set_deferred(&"disabled", true)
