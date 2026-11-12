class_name EnemyInputComponent
extends InputComponent

@export var navigation_component : NavigationComponent


func handle_inputs():
	if navigation_component:
		input_direction = navigation_component.get_direction()

func start_dash():
	dash_input = true
	await get_tree().create_timer(0.1).timeout
	dash_input = false
