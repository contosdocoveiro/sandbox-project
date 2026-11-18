class_name MeleeBehaviorComponent
extends EnemyBehaviorComponent

const LOCKED_STATES = [&"attack", &"hurt", &"dead", &"ready"]

@export var attack_range: AttackRangeComponent
@export var stop_when_in_attack_range := true

func tick(_delta: float) -> void:
	if state_manager.current_state in LOCKED_STATES:
		actor.velocity = Vector2.ZERO
	else:
		input_component.handle_inputs()
		actor.velocity = physics_component.calculate_velocity()
		if stop_when_in_attack_range and attack_range.is_in_attack_range:
			actor.velocity = Vector2.ZERO
	physics_component.apply_knockback()
	physics_component.move()
