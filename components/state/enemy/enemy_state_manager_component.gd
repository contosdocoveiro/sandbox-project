class_name EnemyStateManagerComponent
extends StateManagerComponent

@export var state_chart: StateChart
@export var health_component: HealthComponent


func _ready() -> void:
	_connect_states(state_chart)
	if health_component:
		health_component.damage_taken.connect(_on_damage_taken)

func _connect_states(node: Node) -> void:
	for child in node.get_children():
		if child is AtomicState:
			child.state_entered.connect(_on_state_entered.bind(child))
		_connect_states(child)

func _on_state_entered(state: StateChartState) -> void:
	set_state(StringName(String(state.name).to_snake_case()))

func _on_damage_taken(_attack: Attack) -> void:
	var was_hurt := current_state == &"hurt"
	state_chart.send_event(&"hurt")
	if was_hurt:
		animation_component.animation_player.stop()
		animation_component.animation_player.play(&"hurt")

func notify_animation_finished() -> void:
	state_chart.send_event(&"animation_finished")
