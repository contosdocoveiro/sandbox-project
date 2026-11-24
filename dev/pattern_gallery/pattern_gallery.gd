extends Node2D

@export var emitter: BulletEmitterComponent
@export var pattern_root := "res://resources/patterns"

@onready var pattern_option: OptionButton = %PatternOption
@onready var team_option: OptionButton = %TeamOption
@onready var telegraph_option: OptionButton = %TelegraphOption
@onready var duration_slider: HSlider = %DurationSlider
@onready var follow_aim: CheckBox = %FollowAim
@onready var stop_button: Button = %StopButton
@onready var clear_button: Button = %ClearButton
@onready var stress_button: Button = %StressButton
@onready var move_check: CheckBox = %MoveCheck
@onready var stats: Label = %Stats

var _patterns: Array[BulletPattern] = []
var _selected: BulletPattern
var _orbit_origin: Vector2
var _time := 0.0

func _ready() -> void:
	_orbit_origin = emitter.position
	_scan_patterns(pattern_root)
	_fill_options()

	stop_button.pressed.connect(func() -> void: emitter.stop())
	clear_button.pressed.connect(func() -> void: BulletManager.clear_all())
	stress_button.pressed.connect(_on_stress)
	pattern_option.item_selected.connect(_on_pattern_selected)
	team_option.item_selected.connect(func(index: int) -> void: emitter.team_override = index)

	if not _patterns.is_empty():
		_on_pattern_selected(0)

func _process(delta: float) -> void:
	_time += delta
	if move_check.button_pressed:
		emitter.position = _orbit_origin + Vector2(cos(_time) * 80.0, sin(_time) * 40.0)
	elif emitter.position != _orbit_origin:
		emitter.position = _orbit_origin
	stats.text = "FPS %d | active %d" % [Engine.get_frames_per_second(), BulletManager.active_count()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_fire()

func _scan_patterns(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension() == "tres":
			var res = load(path.path_join(file))
			if res is BulletPattern:
				_patterns.append(res)
	for sub in dir.get_directories():
		_scan_patterns(path.path_join(sub))

func _fill_options() -> void:
	pattern_option.clear()
	for p in _patterns:
		pattern_option.add_item(p.resource_path.get_file().get_basename())
	if not _patterns.is_empty():
		pattern_option.select(0)

	team_option.clear()
	team_option.add_item("Player")
	team_option.add_item("Enemy")
	team_option.select(1)
	emitter.team_override = 1

	telegraph_option.clear()
	for shape_name in ["None", "LINE", "CONE", "RING", "CIRCLE", "RECT", "ARC"]:
		telegraph_option.add_item(shape_name)
	telegraph_option.select(0)

func _on_pattern_selected(index: int) -> void:
	if index < 0 or index >= _patterns.size():
		return
	_selected = _patterns[index]
	emitter.pattern = _selected
	if _selected.bullet:
		BulletManager.prewarm(_selected.bullet, _selected.bullet.prewarm)

func _make_test_pattern() -> BulletPattern:
	if _selected == null:
		return null

	var p := _selected.duplicate() as BulletPattern
	var shape_index := telegraph_option.selected

	if shape_index <= 0:
		p.telegraph = null
	else:
		var t := TelegraphData.new()
		match shape_index:
			1: t.shape = TelegraphData.Shape.LINE
			2: t.shape = TelegraphData.Shape.CONE
			3: t.shape = TelegraphData.Shape.RING
			4: t.shape = TelegraphData.Shape.CIRCLE
			5: t.shape = TelegraphData.Shape.RECT
			6: t.shape = TelegraphData.Shape.ARC
		t.duration = duration_slider.value
		t.follow_aim = follow_aim.button_pressed
		p.telegraph = t

	return p

func _on_fire() -> void:
	var p := _make_test_pattern()
	if p:
		emitter.start(p)

func _on_stress() -> void:
	var p := _make_test_pattern()
	if p == null:
		return
	p.waves = maxi(p.waves, 10)
	p.shots_per_wave = maxi(p.shots_per_wave, 1)
	p.wave_interval = 0.05
	p.shot_interval = 0.02
	p.start_delay = 0.0
	p.telegraph = null
	emitter.start(p)
