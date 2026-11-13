class_name EnemyStateManagerComponent
extends StateManagerComponent

@onready var timer = $Timer
@onready var stun_timer = $StunTimer
@onready var state_chart = $StateChart
@export var attack_cooldown : float


func _ready() -> void:
	var health_component = get_parent().find_child("HealthComponent")
	if(health_component):
		health_component.damage_taken.connect(_on_damage_taken)

func attack():
	if(timer.is_stopped()):
		state_chart.send_event("attacking")
		timer.wait_time = animation_component.animation_player.current_animation_length
		timer.start()
		
func charge():
	if(timer.is_stopped()):
		state_chart.send_event("charging")

func _on_idle_state_entered() -> void:
	current_state = "idle"
	animation_component.animate()


func _on_idle_state_physics_processing(delta: float) -> void:
	if(actor.velocity != Vector2.ZERO):
		state_chart.send_event("running")


func _on_running_state_entered() -> void:
	current_state = "running"
	animation_component.animate()

func _on_running_state_physics_processing(delta: float) -> void:
	if(actor.velocity == Vector2.ZERO):
		state_chart.send_event("idle")
		

func _on_attacking_state_entered() -> void:
	if(timer.is_stopped()):
		current_state = "attacking"
		animation_component.animate()
	else:
		state_chart.send_event("idle")


func _on_attacking_state_physics_processing(delta: float) -> void:
	if(timer.is_stopped()):
		state_chart.send_event("attack end")


func _on_hurt_state_entered() -> void:
	current_state = "hurt"
	

	
func _on_damage_taken(attack : Attack):
	state_chart.send_event("hurt")
	animation_component.animate()
	stun_timer.stop()
	stun_timer.wait_time = animation_component.animation_player.current_animation_length
	stun_timer.start()


func _on_stun_timer_timeout() -> void:
	state_chart.send_event("history")


func _on_attack_phase_end_state_entered() -> void:
	timer.wait_time = attack_cooldown
	timer.start()
	state_chart.send_event("idle")


func _on_charging_state_entered() -> void:
	current_state = "charging"
	animation_component.animate()
	

func _on_charge_end_state_entered() -> void:
	current_state = "charge end"
	animation_component.animate()
	await get_tree().create_timer(animation_component.animation_player.current_animation_length).timeout 
	state_chart.send_event("attack end")


func _on_charge_end_event_received(event: StringName) -> void:
	if(event == "hurt"):
		timer.wait_time = attack_cooldown
		timer.start()
