class_name EnemyInputComponent
extends InputComponent

@export var navigation_component : NavigationComponent


func handle_inputs():
	if navigation_component:
		input_direction = navigation_component.get_direction()
