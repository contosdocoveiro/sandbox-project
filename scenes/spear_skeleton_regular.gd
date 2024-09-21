extends CharacterBody2D
class_name SpearSkeleton


@export var sprite : AnimatedSprite2D
@export var attack_sprite : AnimatedSprite2D
@export var state_machine : Node
@export var dash_speed : float
@export var dash : Dash
@export var detection_area : DetectionArea
@export var navigation_component : NavigationComponent
@export_category("stats")
@export var damage : float
@export var stun : float
@export var knockback : float
var is_in_attack_range = false
var last_velocity = Vector2.RIGHT

func _physics_process(delta: float) -> void:

	move_and_slide()
	
	
func _process(_delta: float) -> void:
	if(velocity != Vector2.ZERO):
		last_velocity = velocity
	if last_velocity.x < -7 and not sprite.flip_h:
		sprite.flip_h = true
	elif last_velocity.x > 7 and sprite.flip_h:
		sprite.flip_h = false

func _on_attack_range_area_entered(area: Area2D) -> void:
	is_in_attack_range = true
func _on_attack_range_area_exited(area: Area2D) -> void:
	is_in_attack_range = false
func rotate_attack_sprite():
	if(navigation_component.target):
		attack_sprite.rotation = global_position.direction_to(navigation_component.target.global_position).angle()
func set_attack_dash_velocity():
	if(navigation_component.target):
		velocity = global_position.direction_to(navigation_component.target.global_position) * dash_speed

func _on_hitbox_component_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		var attack = Attack.new()
		attack.attack_damage = damage
		attack.attack_position = global_position
		attack.knockback_force = knockback
		attack.stun_time = stun
		area.damage(attack)

func apply_knockback_on_wall_hit(body : Node2D) -> void:
	state_machine.is_attacking = false
	velocity = -(body.global_position.direction_to(self.global_position)) * 100
	slow_down(0.3)
	
func start_dash() -> void:
	dash.start_dash(1000)
	pass
func end_dash() -> void:
	dash.end_dash()
	pass
	
func slow_down(time : float) -> void:
	var tween = create_tween()
	if(state_machine.is_attacking):
		tween.stop()
		tween.kill()
		return
	tween.tween_property(self, "velocity", Vector2.ZERO, time)
	await tween.finished
	tween.kill()
