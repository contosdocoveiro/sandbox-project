extends AnimatedSprite2D
class_name Door

var room_detection_area : Area2D
@onready var animation_player := $AnimationPlayer


func close_door():
	animation_player.play("close")
	
func open_door():
	animation_player.play("open")
