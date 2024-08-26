extends CharacterBody2D

@onready var dog = $"../Dog"
@onready var horizontal_attack = $SwordSprite/HorizontalAttack
var time = 0
var animation_amplitude := 0.5
var animation_frequency := 7
var default_position = get_position()


func _physics_process(delta: float) -> void:
	##floating animation and positioning
	var dog_position_offset = dog.position
	
	if(dog.direction == Vector2.RIGHT):
		dog_position_offset[0] += 70
		dog_position_offset[1] -= 90
	elif(dog.direction == Vector2.LEFT):
		dog_position_offset[0] -= 70
		dog_position_offset[1] -= 90
	elif(dog.direction == Vector2.UP):
		dog_position_offset[0] += 70
		dog_position_offset[1] -= 90
	elif(dog.direction == Vector2.DOWN):
		dog_position_offset[0] -= 70
		dog_position_offset[1] += 0
	
		
	
	global_transform.origin = lerp(global_transform.origin, dog_position_offset, 0.025)
	
	##attack input
	if(Input.is_action_just_pressed("click")):
		horizontal_attack.play("horizontal slash")
		
	
func _process(delta: float) -> void:
	default_position = get_position()
	time += delta * animation_frequency
	set_position(default_position + Vector2(0, sin(time)*animation_amplitude))
