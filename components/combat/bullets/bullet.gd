class_name Bullet
extends Area2D

signal hit(target: Node)
signal canceled

var data: BulletData
var team: BulletData.Team = BulletData.Team.ENEMY
var direction := Vector2.RIGHT
var speed := 0.0
var lifetime := 0.0
var source: Node
var target: Node2D
var active := false

var speed_scale := 1.0
var damage_scale := 1.0

var _pierce_left := 0
var _grazed := false
var _homing_delay_left := 0.0
var _sine_time := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _default_frames: SpriteFrames

func _ready() -> void:
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape = (collision_shape.shape as CircleShape2D).duplicate() as CircleShape2D
	_default_frames = animated_sprite.sprite_frames
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)

func _draw() -> void:
	if data == null:
		return
	if data.texture != null or data.sprite_frames != null:
		return
	draw_circle(Vector2.ZERO, data.radius, data.visual_color)

func setup(
	d: BulletData,
	pos: Vector2,
	dir: Vector2,
	src: Node,
	homing_target: Node2D = null,
	team_override := -1,
	speed_multiplier := 1.0,
	damage_multiplier := 1.0
) -> void:
	data = d
	source = src
	target = homing_target
	team = team_override if team_override >= 0 else d.team
	speed_scale = speed_multiplier
	damage_scale = damage_multiplier

	global_position = pos
	direction = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	speed = d.speed * speed_scale
	lifetime = d.lifetime
	_pierce_left = d.pierce
	_grazed = false
	_homing_delay_left = d.homing_delay
	_sine_time = 0.0
	active = true

	modulate = d.modulate
	z_index = d.z_index
	rotation = direction.angle() if d.rotate_to_velocity else 0.0

	var use_animation := d.sprite_frames != null
	sprite.visible = not use_animation and d.texture != null
	sprite.texture = d.texture
	sprite.scale = d.visual_scale
	animated_sprite.visible = use_animation
	animated_sprite.scale = d.visual_scale
	if use_animation:
		animated_sprite.sprite_frames = d.sprite_frames
		if d.sprite_frames.has_animation(d.animation):
			animated_sprite.play(d.animation)
	else:
		animated_sprite.stop()
	queue_redraw()

	if collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = d.radius

	collision_layer = 32                      # physics layer 6 = bit value 32
	collision_mask = (1 | 4) if team == BulletData.Team.PLAYER else (1 | 2)

	visible = true
	set_physics_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	collision_shape.set_deferred("disabled", false)
	
func reset_for_pool() -> void:
	active = false
	set_physics_process(false)
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	data = null
	source = null
	target = null
	team = BulletData.Team.ENEMY
	direction = Vector2.ZERO
	speed = 0.0
	lifetime = 0.0
	speed_scale = 1.0
	damage_scale = 1.0
	_pierce_left = 0
	_grazed = false
	_homing_delay_left = 0.0
	_sine_time = 0.0
	modulate = Color.WHITE
	rotation = 0.0
	z_index = 0
	if sprite:
		sprite.texture = null
		sprite.visible = false
		sprite.scale = Vector2.ONE
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.sprite_frames = _default_frames
		animated_sprite.visible = false
		animated_sprite.scale = Vector2.ONE
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active or data == null:
		return

	if data.acceleration != 0.0:
		speed = move_toward(speed, data.max_speed * speed_scale, data.acceleration * delta)

	if data.homing_strength > 0.0:
		if _homing_delay_left > 0.0:
			_homing_delay_left -= delta
		elif is_instance_valid(target):
			var desired := (target.global_position - global_position).normalized()
			var weight := clampf(data.homing_strength * delta, 0.0, 1.0)
			direction = direction.lerp(desired, weight).normalized()

	if data.sine_amplitude > 0.0:
		_sine_time += delta * data.sine_frequency
		global_position += direction.orthogonal() * sin(_sine_time) * data.sine_amplitude * delta

	global_position += direction * speed * delta
	lifetime -= delta

	if lifetime <= 0.0:
		release()
		return

	if data.rotate_to_velocity:
		rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	if not active:
		return

	# only areas with health component are valid targets
	if area is HitboxComponent and area.health_component:
		var attack := Attack.new()
		attack.attack_damage = data.damage * damage_scale
		attack.attack_position = global_position
		attack.knockback_force = data.knockback
		attack.stun_time = 0.0
		area.damage(attack)

		hit.emit(area)

		if _pierce_left <= 0:
			release()
		else:
			_pierce_left -= 1

func _on_body_entered(body: Node2D) -> void:
	if not active or data == null:
		return
	if data.despawn_on_wall and body is TileMapLayer:
		release()

func _on_screen_exited() -> void:
	if active and data and data.despawn_offscreen:
		release()

func mark_grazed() -> bool:
	if _grazed:
		return false
	_grazed = true
	return true
	
func cancel() -> void:
	if not active:
		return
	canceled.emit()
	release()
	
func release() -> void:
	if not active:
		return
	BulletManager.release(self)
