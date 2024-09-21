extends Node2D
class_name NavigationComponent

@export var max_speed : float
@export var steer_force: float
@export var look_ahead : float


#context array
var num_rays = 8
var ray_directions = []
var interest = []
var danger = []
@onready var raycasts = get_node("ContextMap").get_children()

@onready var navigation_agent = $NavigationAgent2D
var target = null
var chosen_dir = Vector2.ZERO
var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO

func _ready() -> void:
	for raycast in raycasts:
		raycast.target_position.x = look_ahead
	if(owner.detection_area):
		target = owner.detection_area._player_ref
	interest.resize(num_rays)
	danger.resize(num_rays)
	ray_directions.resize(num_rays)
	for i in num_rays:
		var angle = i * 2 * PI / num_rays
		ray_directions[i] = Vector2.RIGHT.rotated(angle)

func _physics_process(delta: float) -> void:
	if(is_instance_valid(target)):
		navigation_agent.target_position = target.global_position
	if(owner.detection_area):
		target = owner.detection_area._player_ref
	set_interest()
	set_danger()
	choose_direction()
	var desired_velocity = chosen_dir.rotated(rotation) * max_speed
	owner.velocity = owner.velocity.lerp(desired_velocity, steer_force)
	
func set_interest():
	if owner:
		var path_direction = owner.global_position.direction_to(navigation_agent.get_next_path_position()).normalized()
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
