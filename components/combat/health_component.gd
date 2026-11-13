extends Node
class_name HealthComponent

@export var damage_numbers_component : DamageNumbersComponent
@export var MAX_HEALTH := 10.0

@onready var invincibility_timer = $InvincibilityTime

var invincible := false
var health : float

signal damage_taken(attack : Attack)
signal invincibility_started(kind: StringName, duration: float)
signal invincibility_ended(kind: StringName)

var _invincibility_kind: StringName = &"damage"

func _ready():
	health = MAX_HEALTH

func damage(attack: Attack):
	if(invincible):
		return
	
	health -= attack.attack_damage
	emit_signal("damage_taken", attack)
	
	if(owner.is_in_group("player")):
		invulnerability_start()
	
	if damage_numbers_component:
		damage_numbers_component.display_damage_numbers(attack.attack_damage)
	
	if health <= 0:
		get_parent().queue_free()

func invulnerability_start(kind: StringName = &"damage", duration: float = 1.0) -> void:
	_invincibility_kind = kind
	invincible = true
	invincibility_timer.wait_time = duration
	invincibility_timer.start()
	invincibility_started.emit(kind, duration)


func _on_invincibility_time_timeout() -> void:
	invincible = false
	invincibility_ended.emit(_invincibility_kind)
