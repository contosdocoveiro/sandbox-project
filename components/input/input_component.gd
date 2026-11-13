class_name InputComponent extends Node2D

var input_direction : Vector2	#movement input
var dash_input : bool #dash input

#returns move input direction
func get_move_input() -> Vector2:
	return input_direction
	
#handles inputs
func handle_inputs():
	pass
