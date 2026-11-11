class_name HitboxComponent
extends Area2D

@export_category("Components")
@export var health_component : HealthComponent
@export var dash_component : Dash
@export_category("Modifiers")
@export var can_deal_damage : bool
@export var can_collide_with_walls : bool
@export var knockback_owner_upon_hit : bool
@export var frame_freeze : bool
@export var camera_shake : bool
@export_category("Stats")
@export var knockback_owner_amount : float
@export var attack_damage : float
@export var stun : float
@export var knockback : float
@export_category("Frame Freeze Params")
@export var frame_freeze_time_scale : float
@export var frame_freeze_duration : float
@export_category("Camera Shake Params")
@export var shake_intensity : float
@export var shake_duration : float

var collision_shape : CollisionShape2D

signal collided_with_wall(body)

func _ready() -> void:
	collision_shape = get_child(0)

func damage(attack: Attack): #tradução: dano (se lê dã -> noh)
	if dash_component:
		if dash_component.is_dashing():
			return
	if health_component:
		health_component.damage(attack)
		if owner.physics_component:
			if(health_component.invincible):
				return
			owner.physics_component.calculate_knockback(attack.attack_position, attack.knockback_force)
	
			

func _on_area_entered(area: Area2D) -> void:
	if(can_deal_damage):
		if area is HitboxComponent:
			if(frame_freeze):
				if(!area.owner.health_component.invincible):
					FrameFreeze.freeze_frame(frame_freeze_time_scale, frame_freeze_duration)
			
			var attack = Attack.new()
			attack.attack_damage = attack_damage
			attack.attack_position = global_position
			attack.knockback_force = knockback
			attack.stun_time = stun
			area.damage(attack)
			
			if knockback_owner_upon_hit:
				if owner.owner.is_in_group("player"):
					owner.owner.physics_component.calculate_knockback(global_position, knockback_owner_amount)
			
			if camera_shake:
				var camera = get_viewport().get_camera_2d()
				camera.shake_camera()

func _on_body_entered(body: Node2D) -> void:
	if(can_collide_with_walls):
		if body is TileMapLayer:
			collided_with_wall.emit(body)
