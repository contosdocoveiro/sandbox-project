extends CharacterBody2D
class_name Weapon

@export var attack_offset := 16.0
@export var idle_rest_offset := Vector2.ZERO
@export var follow_speed := 1.0   
@export var reference_speed := 120.0  
@export var min_follow_speed := 0.25   
@export var idle_blade : Sprite2D
@export var _attack_sprite: AnimatedSprite2D
@export var idle_bob_amplitude := 0.5
@export var idle_bob_frequency := 7.0
@export var idle_side_distance := 12.0
@export var aim_origin: Node2D

var attacking := false
var _idle_time = 0.0
var _idle_blade_base := Vector2.ZERO
var _idle_side := 1.0
var locked_offset := Vector2.ZERO

signal attack_started
signal attack_ended

func _ready() -> void:
	top_level = true
	if is_instance_valid(owner):
		global_position = owner.global_position + idle_rest_offset
		
	if idle_blade:
		_idle_blade_base = idle_blade.position

func emit_attack_started() -> void:
	attack_started.emit()
	
func emit_attack_ended() -> void:
	attack_ended.emit()
	
func begin_attack() -> void:
	attacking = true
	
	var dir := get_aim_direction()
	locked_offset = dir * attack_offset
	
	#teleport
	global_position = owner.global_position + locked_offset
	_attack_sprite.global_rotation = dir.angle()

func lock_aim() -> void:
	pass

func end_attack() -> void:
	attacking = false

func _physics_process(delta: float) -> void:
	if attacking:
		global_position = owner.global_position + locked_offset
		return
	
	#idle: lazy position
	var player_speed: float = maxf(
	owner.physics_component.get_effective_move_speed(),
	owner.velocity.length()
	)
	var speed_ratio := player_speed / maxf(reference_speed, 0.001)
	var follow_rate := maxf(follow_speed * speed_ratio, min_follow_speed)
	
	var target = get_idle_target()
	var t := 1.0 - exp(-follow_rate * delta)
	global_position = global_position.lerp(target, t)
	
	_animate_idle_blade(delta)

func get_idle_target() -> Vector2:
	var facing_x = owner._last_faced_direction.x
	
	if facing_x != 0.0:
		_idle_side = signf(facing_x)
	
	return owner.global_position + Vector2(_idle_side * idle_side_distance, 0.0)

func _animate_idle_blade(delta: float) -> void:
	if idle_blade == null:
		return
	_idle_time += delta * idle_bob_frequency
	idle_blade.position = _idle_blade_base + Vector2(0.0, sin(_idle_time) * idle_bob_amplitude)

func get_aim_direction() -> Vector2:
	var to_mouse = get_global_mouse_position() - owner.global_position
	
	if to_mouse.length_squared() > 0.001:
		return to_mouse.normalized()
	
	var fallback: Vector2 = owner._last_faced_direction
	if fallback.length_squared() <= 0.001:
		fallback = Vector2.RIGHT
	return fallback.normalized()
	
