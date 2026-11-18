extends CharacterBody2D

@export var detection_area: DetectionArea
@onready var animation_player = $AnimationPlayer


func _physics_process(delta: float) -> void: #Movement Function that follows player
	move_and_slide()
