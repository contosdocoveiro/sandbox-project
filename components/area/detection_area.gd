extends Area2D
class_name DetectionArea

signal target_acquired(target: Node2D)
signal target_lost(target: Node2D)

@export var can_lose_target : bool

var _player_ref: Node2D = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func get_target() -> Node2D:
	return _player_ref if is_instance_valid(_player_ref) else null
	
func has_target() -> bool:
	return is_instance_valid(_player_ref)

func _on_area_entered(area: Area2D) -> void: #Detect player entering area
	if area.is_in_group("player") and _player_ref != area:
		_player_ref = area
		target_acquired.emit(area)

func _on_area_exited(area: Area2D) -> void: #Detects if player exited the area
	if can_lose_target and area == _player_ref:
		_player_ref = null
		target_lost.emit(area)
	
