class_name PlayerStateManagerComponent extends StateManagerComponent

@export var animation_player : AnimationPlayer
var can_transition := false

@onready var state_chart := $StateChart
@onready var animation_duration_timer = $AnimationDurationTimer


func _ready() -> void:
	input_component = actor.find_child("PlayerInputComponent")

func send_attack_signal() -> void:
	state_chart.send_event("attacking")
	animation_component.animate()
	animation_duration_timer.stop()
	animation_duration_timer.wait_time = animation_player.current_animation_length
	animation_duration_timer.start()
	

func _on_idle_state_physics_processing(delta: float) -> void:
	if(actor.velocity != Vector2.ZERO):
		state_chart.send_event("running")
	
func _on_idle_state_entered() -> void:
	current_state = "idle"
	animation_component.animate()


func _on_attacking_state_entered() -> void:
	current_state = "attacking"


func _on_attacking_state_physics_processing(delta: float) -> void:
	if(can_transition):
		if(actor.velocity != Vector2.ZERO):
			state_chart.send_event("running")
		else:
			state_chart.send_event("idle")


func _on_running_state_entered() -> void:
	current_state = "running"
	


func _on_running_state_physics_processing(delta: float) -> void:
	animation_component.animate()
	if(actor.velocity == Vector2.ZERO):
		state_chart.send_event("idle")


func _on_attacking_state_exited() -> void:
	animation_duration_timer.stop()
	can_transition = false


func _on_animation_duration_timer_timeout() -> void:
	can_transition = true
