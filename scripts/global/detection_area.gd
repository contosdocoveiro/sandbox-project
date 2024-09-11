extends Area2D
class_name DetectionArea
var _player_ref = null

func _ready() -> void:
	connect("area_entered", self._on_area_entered)
	connect("area_exited", self._on_area_exited)

func _on_area_entered(_body) -> void: #Detect player entering area
	if _body.is_in_group("player"):
		_player_ref = _body
	
		
		
func _on_area_exited(_body) -> void: #Detects if player exited the area
	if _body.is_in_group("player"):
		_player_ref = null
	
