extends Node2D
class_name NavigationComponent

@export var look_ahead : float


#context array
var num_rays = 8
var ray_directions = []
var interest = []
var danger = []
@export var actor : CharacterBody2D
@onready var raycasts = get_node("ContextMap").get_children()

@onready var navigation_agent = $NavigationAgent2D
var target = null
var chosen_dir = Vector2.ZERO
var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO



func _ready() -> void:
	num_rays = raycasts.size()
	ray_directions.resize(num_rays)
	interest.resize(num_rays)
	danger.resize(num_rays)
	
	for i in num_rays:
		var ray := raycasts[i] as RayCast2D
		if ray == null:
			ray_directions[i] = Vector2.ZERO
			interest[i] = 0.0
			danger[i] = 0.0
			continue
		ray_directions[i] = ray.target_position.normalized().rotated(ray.rotation)
		interest[i] = 0.0
		danger[i] = 0.0

func get_direction() -> Vector2:
	if actor == null or navigation_agent == null or raycasts.is_empty():
		return chosen_dir
	
	if actor.detection_area:
		target = actor.detection_area._player_ref
	
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
			var d = ray_directions[i].rotated(rotation).dot(path_direction)
			interest[i] = max(0,d)
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
			interest[i] = 0
	chosen_dir = Vector2.ZERO
	for i in num_rays:
		chosen_dir += ray_directions[i] * interest[i]
	chosen_dir = chosen_dir.normalized()
