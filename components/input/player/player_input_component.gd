class_name PlayerInputComponent extends InputComponent

var attack_input : bool		#attack input
var move_input_key : String

func handle_inputs():
	input_direction = Input.get_vector("left", "right", "up", "down").normalized()
	dash_input = Input.is_action_just_pressed("dash")
	attack_input = Input.is_action_just_pressed("attack")
	
	if(Input.is_action_pressed("left")):
		move_input_key = "left"
	elif(Input.is_action_pressed("right")):
		move_input_key = "right"
	elif(Input.is_action_pressed("up")):
		move_input_key = "up"
	elif(Input.is_action_pressed("down")):
		move_input_key = "down"
