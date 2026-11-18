extends Camera2D
class_name ShakeableCamera

var shake_intensity : float
var shake_duration : float
var start_time : float
var rng = RandomNumberGenerator.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	set_process(false)


#shake loop
func _process(delta: float) -> void:
	var decreaser = (shake_duration - (Time.get_ticks_msec() - start_time)) / shake_duration
	
	var rand_x = rng.randf_range(-1,1) * shake_intensity * decreaser
	var rand_y = rng.randf_range(-1,1) * shake_intensity * decreaser
	
	offset = Vector2(rand_x, rand_y)
	
	if(decreaser < 0):
		offset = Vector2.ZERO
		set_process(false)
		
func shake_camera(intensity = 0.3, duration = 0.2):
	shake_intensity = intensity
	shake_duration = (duration * 1000)
	start_time = Time.get_ticks_msec()
	
	set_process(true)
