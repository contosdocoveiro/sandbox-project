extends Node2D
class_name NavigationComponent

@export var look_ahead : float


#context array
var num_rays: int = 0
var ray_directions: Array[Vector2] = []
var interest: Array[float] = []
var danger: Array [float] = []
@export var actor : CharacterBody2D
@onready var raycasts = get_node("ContextMap").get_children()

@onready var navigation_agent = $NavigationAgent2D
var target: Node2D = null
var chosen_dir = Vector2.ZERO
var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO



func _ready() -> void:
	num_rays = raycasts.size()
	ray_directions.resize(num_rays)
	interest.resize(num_rays)
	danger.resize(num_rays)
	
	for i in num_rays:
		var raycast := raycasts[i] as RayCast2D
		if raycast == null:
			ray_directions[i] = Vector2.ZERO
			interest[i] = 0.0
			danger[i] = 0.0
			continue
		ray_directions[i] = Vector2.RIGHT.rotated(raycast.global_rotation - global_rotation)
		interest[i] = 0.0
		danger[i] = 0.0

func set_target(new_target: Node2D) -> void:
	target = new_target if is_instance_valid(new_target) else null
	if target == null and navigation_agent:
		navigation_agent.target_position = global_position

func get_direction() -> Vector2:
	if(is_instance_valid(target)):
		navigation_agent.target_position = target.global_position
	set_interest()
	set_danger()
	choose_direction()
	return chosen_dir.rotated(rotation)
	
func set_interest():
	if actor:
		var path_direction = actor.global_position.direction_to(navigation_agent.get_next_path_position()).normalized()
		for i in num_rays:
			var d = ray_directions[i].dot(path_direction)
			interest[i] = maxf(0.0,d)
func set_danger():
	for i in num_rays:
		var is_colliding = raycasts[i].is_colliding()
		if(is_colliding):
			danger[i] = 1.0
		else:
			danger[i] = 0.0
func choose_direction():
	for i in num_rays:
		if danger[i] > 0.0:
			interest[i] = 0.0
	chosen_dir = Vector2.ZERO
	for i in num_rays:
		chosen_dir += ray_directions[i] * interest[i]
	chosen_dir = chosen_dir.normalized()
