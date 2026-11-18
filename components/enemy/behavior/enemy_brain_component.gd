class_name EnemyBrainComponent
extends Node

@export var state_chart: StateChart
@export var behavior: EnemyBehaviorComponent
@export var attack_range: AttackRangeComponent
@export var detection_area: DetectionArea
@export var navigation_component: NavigationComponent

func _physics_process(_delta: float) -> void:
	var target = detection_area.get_target()
	navigation_component.set_target(target)
	state_chart.set_expression_property(&"has_target", is_instance_valid(target))
	state_chart.set_expression_property(&"in_attack_range", attack_range.is_in_attack_range)
	behavior.tick(_delta)
