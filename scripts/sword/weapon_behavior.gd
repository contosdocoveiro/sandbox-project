extends CharacterBody2D
class_name Weapon



var _time = 0
var _default_position = get_position()
var _owner_position_offset := Vector2.RIGHT
var mouse_pos = Vector2(0,0)
var angle_to_mouse
var attack_position: Vector2
var move_speed = 500

@export_category("Animation Parameters")
@export var _animation_amplitude := 0.5
@export var _animation_frequency := 7
@export var _animation_player : AnimationPlayer
@export var _attack_sprite : AnimatedSprite2D
@export var attack_playing := false
@export var radius := 16
@export var combo_finished := false


@export_category("Attack 1")
@export var attack1_attack_damage: float
@export var attack1_knockback_force: float
@export var attack1_stun_time: float

@export_category("Attack 2")
@export var attack2_attack_damage: float
@export var attack2_knockback_force: float
@export var attack2_stun_time: float

@export_category("Attack 3")
@export var attack3_attack_damage: float
@export var attack3_knockback_force: float
@export var attack3_stun_time: float
	

func _physics_process(delta: float) -> void:
	
	_move(delta)
	_animate(delta)
	

func _move(delta):
	
	
	mouse_pos = get_global_mouse_position()
	angle_to_mouse = global_position.direction_to(mouse_pos).angle()
	var player_pos = owner.global_transform.origin 
	var distance = player_pos.distance_to(mouse_pos)
	var mouse_dir = (mouse_pos-player_pos).normalized()
	mouse_pos = player_pos + (mouse_dir * radius)
	
	#if(!_animation_player.is_playing()):
		#global_transform.origin = lerp(global_transform.origin, mouse_pos, 0.05)
		
	if(!_animation_player.is_playing()):
		global_transform.origin = global_transform.origin.move_toward(mouse_pos, delta*move_speed)

	
	if(combo_finished):
		_attack_sprite.rotation = 0
		return
	
	if(distance > radius):
		return
	else:
		mouse_pos = player_pos + (owner._last_faced_direction * radius)
		angle_to_mouse = owner._last_faced_direction.angle()
		

func _animate(delta: float) -> void:
	
	if(_animation_player.is_playing()):
		return
	_default_position = get_position()
	_time += delta * _animation_frequency
	set_position(_default_position + Vector2(0, sin(_time)*_animation_amplitude))
	

func _on_combo_1_hitbox_area_entered(area: Area2D) -> void:
	var attack := Attack.new()
	
	attack.attack_damage = attack1_attack_damage
	attack.attack_position = global_position
	attack.stun_time = attack1_stun_time
	attack.knockback_force = attack1_knockback_force
	
	_process_attack(area, attack)

func _on_combo_2_hitbox_area_entered(area: Area2D) -> void:
	var attack := Attack.new()
	
	attack.attack_damage = attack2_attack_damage
	attack.attack_position = global_position
	attack.stun_time = attack2_stun_time
	attack.knockback_force = attack2_knockback_force
	
	_process_attack(area, attack)
	
func _on_combo_3_hitbox_area_entered(area: Area2D) -> void:
	var attack := Attack.new()
	
	attack.attack_damage = attack3_attack_damage
	attack.attack_position = global_position
	attack.stun_time = attack3_stun_time
	attack.knockback_force = attack3_knockback_force
	
	_process_attack(area, attack)

func _process_attack(area, attack):
	if area is HitboxComponent:
		area.damage(attack)
