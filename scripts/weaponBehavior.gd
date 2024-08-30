class_name Weapon
extends CharacterBody2D

@export_category("Variables")
@export var can_input_attack := false

var _time = 0
var _animation_amplitude := 0.5
var _animation_frequency := 7
var _default_position = get_position()
var _owner_position_offset := Vector2.RIGHT
var _state_machine
var _animation_player

func _ready() -> void:
	_state_machine = $AnimationTree["parameters/playback"]
	_animation_player = $AnimationPlayer

func teleport_to_attack_location() -> void:
	set_position(_owner_position_offset)
	

func _physics_process(delta: float) -> void:
	
	_move()
	_detect_states()
	_animate(delta)
	

func _move():
	
	_owner_position_offset = owner.position
	
	
	if(owner.last_faced_direction == Vector2.RIGHT):
		_owner_position_offset[0] += 20
		_owner_position_offset[1] -= 20
	elif(owner.last_faced_direction == Vector2.LEFT):
		_owner_position_offset[0] -= 20
		_owner_position_offset[1] -= 20
	elif(owner.last_faced_direction == Vector2.UP):
		_owner_position_offset[0] -= 2
		_owner_position_offset[1] -= 5
	elif(owner.last_faced_direction == Vector2.DOWN):
		_owner_position_offset[0] -= 2
		_owner_position_offset[1] += 5
	
	global_transform.origin = lerp(global_transform.origin, _owner_position_offset, 0.025)
	
	

func _detect_states() -> void:
	if(Input.is_action_just_pressed("attack")):
		_on_attack_pressed()

func _animate(delta: float) -> void:
	_default_position = get_position()
	_time += delta * _animation_frequency
	set_position(_default_position + Vector2(0, sin(_time)*_animation_amplitude))
	
func _on_attack_pressed():
	$StateChart.send_event("attack_pressed")


func _on_combo_1_state_entered() -> void:
	_state_machine.travel("combo 1")


func _on_combo_1_state_physics_processing(delta: float) -> void:
	if(Input.is_action_just_pressed("attack") and can_input_attack):
		$StateChart.send_event("attack_pressed_combo1")


func _on_idle_state_entered() -> void:
	_state_machine.travel("idle")


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if(anim_name == "combo 1" or "combo 2"):
		$StateChart.send_event("combo_finished")


func _on_combo_2_state_physics_processing(delta: float) -> void:
	_state_machine.travel("combo 2")
