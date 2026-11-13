class_name OutlineComponent extends Node

enum FlashKind { DAMAGE, INVINCIBLE, BUFF }
@export var damage_color := Color.RED
@export var invincible_color := Color.WHITE
@export var buff_color := Color(0.5, 0.8, 1.0)
@export_range(0.05, 1.0, 0.01) var pulse_step := 0.15
@export_range(0.0, 1.0, 0.01) var pulse_low := 0.25
@export_range(0.0, 1.0, 0.01) var pulse_high := 0.65

@export var body: CanvasItem
@export var outline_color : Color
@export var outline_width := 1.0
@export var pattern := 0
@export var inside := false
@export var add_margins := true
@export var sheet_columns := 1
@export var sheet_rows := 1

@export var health_component: HealthComponent

var _material: ShaderMaterial
var _pulse_tween: Tween

# kind -> { "end_time": int, "color": Color, "priority": int }
# end_time == -1 means indefinite.
var _sources: Dictionary = {}

func _ready() -> void:
	if body == null:
		push_warning("OutlineComponent has no body")
		return
	
	var mat := body.material as ShaderMaterial
	if mat == null:
		mat = preload("res://shaders/outline.tres").duplicate() as ShaderMaterial
	else:
		mat = mat.duplicate() as ShaderMaterial
	
	mat.set_shader_parameter(&"color", outline_color)
	mat.set_shader_parameter(&"width", outline_width)
	mat.set_shader_parameter(&"pattern", pattern)
	mat.set_shader_parameter(&"inside", inside)
	mat.set_shader_parameter(&"add_margins", add_margins)
	mat.set_shader_parameter(&"number_of_images", Vector2(sheet_columns, sheet_rows))
	
	body.material = mat
	_material = mat
	set_process(false)
	
	if health_component:
		health_component.invincibility_started.connect(_on_invincibility_started)
		health_component.invincibility_ended.connect(_on_invincibility_ended)
	
func _process(delta: float) -> void:
	var now = Time.get_ticks_msec()
	for kind in _sources.keys():
		var entry : Dictionary = _sources[kind]
		if entry["end_time"] >= 0 and now >= entry["end_time"]:
			_sources.erase(kind)
	
	if _sources.is_empty():
		_stop_pulse()
	else:
		_refresh_color()
		
func _refresh_color() -> void:
	var best: Dictionary = {}
	for entry in _sources.values():
		if best.is_empty() or entry["priority"] > best["priority"]:
			best = entry
	if not best.is_empty():
		_material.set_shader_parameter(&"flash_color", best["color"])

func _longer_end(a: int, b: int) -> int:
	if a < 0 or b < 0:
		return -1
	return maxi(a, b)

func _ensure_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_flash, pulse_low, pulse_high, pulse_step)
	_pulse_tween.tween_method(_set_flash, pulse_high, pulse_low, pulse_step)

func _color_for(kind: FlashKind) -> Color:
	match kind:
		FlashKind.INVINCIBLE:
			return invincible_color
		FlashKind.BUFF:
			return buff_color
		_:
			return damage_color
	
func start_pulse(kind: FlashKind, duration: float, priority: int = 0) -> void:
	if _material == null:
		return
	var now := Time.get_ticks_msec()
	var end_time = -1 if duration <= 0.0 else now + int(duration * 1000.0)
	var entry: Dictionary = _sources.get(kind, {})
	
	if entry.is_empty():
		_sources[kind] = {
			"end_time": end_time,
			"color": _color_for(kind),
			"priority": priority
		}
	else:
		entry["end_time"] = _longer_end(entry["end_time"], end_time)
		entry["color"] = _color_for(kind)
		entry["priority"] = priority
		_sources[kind] = entry
		
	set_process(true)
	_refresh_color()
	_ensure_pulse()

func stop_pulse(kind: FlashKind) -> void:
	if not _sources.has(kind):
		return
	_sources.erase(kind)
	
	if _sources.is_empty():
		_stop_pulse()
	else:
		_refresh_color()

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_set_flash(0.0)
	set_process(false)

func extend_pulse(kind: FlashKind, seconds:float) -> void:
	if not _sources.has(kind):
		return
	
	var entry: Dictionary = _sources[kind]
	var now = Time.get_ticks_msec()
	if entry["end_time"] < 0:
		return
	
	entry["end_time"] = now + int(seconds * 1000.0)

func _set_flash(value: float) -> void:
	if _material:
		_material.set_shader_parameter(&"flash", value)
		

func _on_invincibility_started(kind: StringName, duration: float) -> void:
	match kind:
		&"damage":
			start_pulse(FlashKind.DAMAGE, duration, 30)
		&"buff", &"invincible":
			start_pulse(FlashKind.BUFF, duration, 20)
		_:
			start_pulse(FlashKind.BUFF, duration, 20)

func _on_invincibility_ended(kind: StringName) -> void:
	match kind:
		&"damage":
			stop_pulse(FlashKind.DAMAGE)
		&"buff", &"invincible":
			stop_pulse(FlashKind.BUFF)
