class_name PlayerStateManagerComponent extends StateManagerComponent

var can_transition := false

@onready var state_chart := $StateChart
@onready var animation_duration_timer = $AnimationDurationTimer


func _ready() -> void:
	input_component = actor.find_child("PlayerInputComponent")

func _on_idle_state_physics_processing(delta: float) -> void:
	if(actor.velocity != Vector2.ZERO):
		state_chart.send_event("running")
	
func _on_idle_state_entered() -> void:
	current_state = "idle"
	animation_component.animate()

func _on_running_state_entered() -> void:
	current_state = "running"

func _on_running_state_physics_processing(delta: float) -> void:
	animation_component.animate()
	if(actor.velocity == Vector2.ZERO):
		state_chart.send_event("idle")
