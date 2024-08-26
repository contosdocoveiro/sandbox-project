extends CharacterBody2D


const SPEED = 500.0

@onready var dog_sprite = $DogSprite

#variable to store last faced direction for animation purposes
var direction = Vector2.RIGHT

func _physics_process(delta: float) -> void:

	#gets input direction
	var direction_x := Input.get_axis("left", "right")
	var direction_y := Input.get_axis("up", "down")
	
	#moves in X axis
	if direction_x:
		velocity.x = direction_x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	#moves in Y axis
	if direction_y:
		velocity.y = direction_y * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)
		
	move_and_slide()
		
		
func _process(delta: float) -> void:
	#gets input direction
	var direction_x := Input.get_axis("left", "right")
	var direction_y := Input.get_axis("up", "down")
	
	#flips the sprite horizontally
	if direction_x > 0:
		dog_sprite.flip_h = false
	elif direction_x < 0:
		dog_sprite.flip_h = true
		
	#play animations:
	#horizontal
	if (Input.is_action_pressed("left") or Input.is_action_pressed("right")):
		dog_sprite.play("run horizontal")
		if (Input.is_action_pressed("left")):
			direction = Vector2.LEFT
		else:
			direction = Vector2.RIGHT
	
	#frontal (down direction)
	elif (Input.is_action_pressed("down")):
		dog_sprite.play("run frontal")
		direction = Vector2.DOWN
	
	#back (up direction)
	elif(Input.is_action_pressed("up")):
		dog_sprite.play("run back")
		direction = Vector2.UP
	
	#idle after horizontal
	elif ( (Input.is_action_just_released("left") or Input.is_action_just_released("right"))
	and (direction_x == 0 and direction_y == 0)):
		dog_sprite.play("idle horizontal")
	
	#idle after frontal
	elif (Input.is_action_just_released("down")
	and (direction_x == 0 and direction_y == 0)):
		dog_sprite.play("idle frontal")
	
	#idle after back
	elif (Input.is_action_just_released("up")
	and (direction_x == 0 and direction_y ==0)):
		dog_sprite.play("idle back")
