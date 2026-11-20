class_name BulletEmitterComponent
extends Node2D

signal pattern_started
signal shot_fired
signal pattern_finished

@export var pattern: BulletPattern
@export var patterns: Array[BulletPattern] = []
@export var aim_source: AimSource
@export var aim_origin: Node2D
@export var muzzle: Node2D
@export var auto_start := false
@export var prewarm := true
@export var team_override := -1   # -1 = use BulletData.team; gallery uses this

var _active := false
var _delay := 0.0
var _shot_timer := 0.0
var _shot_index := 0
var _wave_index := 0
var _locked_angle := NAN
var _first_shot_done := false
var _telegraph: Telegraph
var _telegraph_lock_first := false

func _ready() -> void:
	_resolve_aim_origin()

	if prewarm:
		_prewarm_pattern(pattern)
		for p in patterns:
			_prewarm_pattern(p)

	if auto_start and pattern:
		start(pattern)
	
func _resolve_aim_origin() -> void:
	if aim_source == null or aim_source.origin != null:
		return

	if aim_origin:
		aim_source.origin = aim_origin
		return

	var parent := get_parent()
	if parent:
		var candidate = parent.get("aim_origin")
		if candidate is Node2D:
			aim_source.origin = candidate
		elif parent is Node2D:
			aim_source.origin = parent

func _prewarm_pattern(p: BulletPattern) -> void:
	if p and p.bullet:
		BulletManager.prewarm(p.bullet, p.bullet.prewarm)

func get_muzzle_position() -> Vector2:
	return muzzle.global_position if muzzle else global_position

func get_aim_angle() -> float:
	return aim_source.get_aim_angle() if aim_source else global_rotation

func start(p: BulletPattern = null) -> void:
	if p:
		pattern = p
	if pattern == null or pattern.bullet == null:
		return

	_active = true
	_shot_index = 0
	_wave_index = 0
	_shot_timer = 0.0
	_first_shot_done = false
	_locked_angle = NAN
	_telegraph_lock_first = pattern.telegraph != null and pattern.telegraph.lock_aim_at_end
	_delay = pattern.start_delay

	if pattern.telegraph:
		_ensure_telegraph()
		_telegraph.show_telegraph(
			pattern.telegraph,
			get_muzzle_position(),
			get_aim_angle()
		)
		_delay += pattern.telegraph.duration
		if _delay <= 0.0:
			_hide_telegraph()

	pattern_started.emit()
	set_physics_process(true)

func stop() -> void:
	_active = false
	set_physics_process(false)
	_hide_telegraph()

func fire_pattern(index: int = 0) -> void:
	var selected: BulletPattern = null
	if index >= 0 and index < patterns.size():
		selected = patterns[index]
	if selected == null:
		selected = pattern
	if selected == null or selected.bullet == null:
		return

	pattern = selected
	_active = false
	set_physics_process(false)
	_shot_index = 0
	_wave_index = 0
	_first_shot_done = false
	_locked_angle = NAN
	_hide_telegraph()
	_emit_shot()

func _physics_process(delta: float) -> void:
	if not _active:
		return

	if _delay > 0.0:
		_delay -= delta
		if pattern.telegraph and _telegraph and pattern.telegraph.follow_aim:
			_telegraph.set_aim(get_muzzle_position(), get_aim_angle())
		if _delay > 0.0:
			return
		if pattern.telegraph:
			if _telegraph_lock_first:
				_locked_angle = get_aim_angle()
			_hide_telegraph()

	_shot_timer -= delta
	if _shot_timer > 0.0:
		return

	_emit_shot()
	_first_shot_done = true
	_shot_index += 1

	if _shot_index >= maxi(pattern.shots_per_wave, 1):
		_shot_index = 0
		_wave_index += 1
		if _wave_index >= maxi(pattern.waves, 1):
			_finish()
			return
		_shot_timer = pattern.wave_interval
	else:
		_shot_timer = pattern.shot_interval

func _emit_shot() -> void:
	var angle := get_aim_angle()

	if not _first_shot_done and _telegraph_lock_first and not is_nan(_locked_angle):
		angle = _locked_angle
	elif not pattern.reaim_each_shot:
		if is_nan(_locked_angle):
			_locked_angle = angle
		else:
			angle = _locked_angle

	var context := BulletShotContext.new()
	context.aim_angle = angle
	context.shot_index = _shot_index
	context.wave_index = _wave_index

	var spawns := pattern.build_shot(context)
	for spawn in spawns:
		var data := spawn.bullet if spawn.bullet else pattern.bullet
		if data == null:
			continue

		var origin := get_muzzle_position() + spawn.position_offset.rotated(angle)
		var direction := Vector2.RIGHT.rotated(spawn.angle)
		var homing_target: Node2D = null
		if data.homing_strength > 0.0 and aim_source:
			homing_target = aim_source.target

		BulletManager.spawn(
			data,
			origin,
			direction,
			self,
			homing_target,
			team_override,
			spawn.speed_scale,
			spawn.damage_scale
		)

	shot_fired.emit()

func _finish() -> void:
	_active = false
	set_physics_process(false)
	_hide_telegraph()
	pattern_finished.emit()
	
func _ensure_telegraph() -> void:
	if _telegraph:
		return
	_telegraph = Telegraph.new()
	add_child(_telegraph)
	_telegraph.hide_telegraph()

func _hide_telegraph() -> void:
	if _telegraph:
		_telegraph.hide_telegraph()
