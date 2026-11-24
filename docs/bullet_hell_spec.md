# Bullet Hell Base System - Implementation Spec

Status: **ready for manual implementation (nothing implemented yet)**
Project: `D:\Godot\teste` (Godot 4.7)
Owner: dog / sword / skeleton bullet-hell refactor

How to read this document:

- A `gdscript` block under a file-path heading is a **full file** to create.
- A `diff` block is a change against the **existing** file; apply it by intent.
- A `text` block is a node tree or inspector setting, not code.
- Parse-check every `.gd` after writing it. The blocks are drafts, not yet compiled in this project.

---

## 0. Table of contents

1. [Goal and decisions](#1-goal-and-decisions)
2. [Architecture](#2-architecture)
3. [Folder layout](#3-folder-layout)
4. [Bullet data and patterns](#4-bullet-data-and-patterns)
5. [Telegraphs](#5-telegraphs)
6. [Bullet runtime and manager](#6-bullet-runtime-and-manager)
7. [Aim and emitter](#7-aim-and-emitter)
8. [Movement modifiers](#8-movement-modifiers)
9. [Existing code changes (diffs)](#9-existing-code-changes-diffs)
10. [Scene wiring](#10-scene-wiring)
11. [Enemy Attack-state integration](#11-enemy-attack-state-integration)
12. [Pattern gallery dev scene](#12-pattern-gallery-dev-scene)
13. [Performance rules](#13-performance-rules)
14. [Difficulty hooks (structure only)](#14-difficulty-hooks-structure-only)
15. [Implementation phases and checklist](#15-implementation-phases-and-checklist)
16. [Decisions log](#16-decisions-log)
17. [Implementation gotchas](#17-implementation-gotchas)
18. [Replacing the sword's old melee hitboxes](#18-replacing-the-swords-old-melee-hitboxes)

---

## 1. Goal and decisions

Build a reusable, data-driven bullet-hell base that can be attached to any actor or weapon.

### Confirmed decisions

| Topic | Decision |
|---|---|
| Active bullet target | **300-500** active bullets; use pooled `Area2D` bullets, no MultiMesh yet |
| Player shooting | **Only the sword shoots**; the dog has no projectile emitter for now |
| Bullet cancel | Not enabled yet; keep the layer/API hooks for later |
| Enemy movement while attacking | Per enemy: some stop, some keep moving / get slowed |
| Telegraphs | Optional per pattern; mostly bosses and big/oppressive attacks; basic attacks do not need one |
| Sword firing | Animation **method track** calls `fire_pattern(index)` at the release frame |
| Pattern authoring | `.tres` pattern resources; recursive pattern gallery |
| Bullet knockback | **0 by default**; rare exceptions can set a value |
| Difficulty | Define hooks now, do not implement scaling yet |
| Player hitbox | Keep the small hurtbox; graze/bullet cancel later |

### Non-goals for the first slice

- MultiMesh / centralized bullet server.
- Sword bullet-cancel.
- Graze scoring.
- Lasers.
- Complex boss phase timelines.
- Difficulty scaling behavior.

---

## 2. Architecture

```text
Actor / Weapon
|-- AimSource                 mouse / target / fixed / random
|-- BulletEmitterComponent    pattern timing + telegraph phase
|   `-- Muzzle (Node2D)
`-- state chart / controller  decides when to start/stop patterns

BulletEmitterComponent
`-- BulletManager (autoload)
    |-- BulletPool per bullet scene
    `-- Bullet (pooled Area2D)
        |-- BulletData         speed, damage, lifetime, motion, team, visuals
        `-- BulletPattern      geometry + timing + optional TelegraphData

Collision (decimal bit value -> project layer name)
|-- Environment           1  -> "environment" (physics layer 1)
|-- Player hurtbox        2  -> "player" (physics layer 2)
|-- Enemy hurtbox         4  -> "entities" (physics layer 3)
`-- Bullets              32  -> "bullets" (physics layer 6)
```

Responsibilities:

- **BulletData** = what a bullet is.
- **BulletPattern** = how and when bullets are arranged.
- **TelegraphData** = optional red warning shape.
- **BulletEmitterComponent** = executes patterns and telegraphs.
- **BulletManager** = pooling, active bullets, team clearing.
- **Bullet** = movement, collision, damage, lifetime.
- **Actor/state chart** = decides when to fire.
- **MovementModifierComponent** = stackable movement speed multipliers, owned by the moving actor (Dog/enemy), never by a weapon.

---

## 3. Folder layout

```text
components/
|-- combat/
|   `-- bullets/
|       |-- bullet_data.gd
|       |-- bullet_difficulty.gd
|       |-- bullet_shot_context.gd
|       |-- bullet_spawn.gd
|       |-- bullet_pattern.gd
|       |-- patterns/
|       |   |-- spread_pattern.gd
|       |   |-- ring_pattern.gd
|       |   `-- spiral_pattern.gd
|       |-- telegraph_data.gd
|       |-- telegraph.gd
|       |-- aim_source.gd
|       |-- bullet_emitter_component.gd
|       |-- bullet.gd
|       |-- bullet.tscn
|       `-- bullet_manager.gd
`-- movement/
    |-- physics_component.gd        (existing, modify)
    |-- movement_modifier_component.gd
    `-- ...

components/enemy/attack/
`-- ranged_attack_controller.gd

resources/
|-- bullets/
|   |-- skeleton_bone.tres
|   |-- skeleton_orb.tres
|   `-- sword_bolt.tres
`-- patterns/
    |-- skeleton_sword/
    |   |-- fan_3_bone.tres
    |   |-- ring_12_orb.tres
    |   `-- spiral_2arm_orb.tres
    `-- sword/
        |-- combo_1_bolt.tres
        |-- combo_2_bolt.tres
        `-- combo_3_bolt.tres

dev/
|-- pattern_gallery.tscn
|-- pattern_gallery.gd
`-- gallery_dummy.gd
```

---

## 4. Bullet data and patterns

### 4.1 `components/combat/bullets/bullet_data.gd`

```gdscript
class_name BulletData
extends Resource

enum Team { PLAYER, ENEMY }

## The generic bullet scene. All bullets can share one scene and override
## visuals through the fields below. Use a different scene only for special
## bullets (lasers, splitting bullets, etc.).
@export var scene: PackedScene
@export var team: Team = Team.ENEMY

@export_group("Motion")
@export var speed := 200.0
@export var acceleration := 0.0
@export var max_speed := 600.0
@export var lifetime := 4.0
@export var radius := 4.0
@export var homing_strength := 0.0
@export var homing_delay := 0.0
@export var sine_amplitude := 0.0
@export var sine_frequency := 0.0
@export var rotate_to_velocity := true
@export var despawn_on_wall := true
@export var despawn_offscreen := true

@export_group("Combat")
@export var damage := 10.0
@export var knockback := 0.0
@export var pierce := 0

@export_group("Visuals")
## Static visual. Assign a Texture2D for a non-animated bullet; this needs
## no SpriteFrames resource.
@export var texture: Texture2D
## Optional animated override. When set, it wins over `texture`.
@export var sprite_frames: SpriteFrames
@export var animation := &"default"
## Used only when texture and sprite_frames are both empty; the bullet then
## draws a circle using this color and its collision radius.
@export var visual_color := Color.WHITE
@export var modulate := Color.WHITE
@export var visual_scale := Vector2.ONE
@export var z_index := 0

@export_group("Pool")
@export var prewarm := 32

@export var custom_data: Dictionary = {}
```

Notes:

- `knockback = 0` is the default. The existing `HitboxComponent.damage()` path handles knockback if it is nonzero; do not apply it a second time in `Bullet`.
- `pierce = 0` means the bullet is consumed by the first valid hurtbox.
- `homing_strength` and `sine_*` are hooks; implement basic behavior in the first runtime.
- `custom_data` is for future per-bullet extensions (sounds, special cancel rules, etc.).
- **Visuals are optional.** For a test bullet, leave `texture` and `sprite_frames` empty; `Bullet._draw()` renders a circle using `radius` and `visual_color`. For real static art, assign a `Texture2D` to `texture`. Only animated bullets need a `SpriteFrames` resource, and it overrides `texture`.

### 4.2 `components/combat/bullets/bullet_difficulty.gd`

```gdscript
class_name BulletDifficulty
extends Resource

## Structure only for now. The emitter passes null and all multipliers are 1.0.
## When difficulty scaling is implemented, a DifficultyService will supply one.
@export var speed_multiplier := 1.0
@export var count_multiplier := 1.0
@export var interval_multiplier := 1.0
@export var damage_multiplier := 1.0
@export var telegraph_multiplier := 1.0
```

### 4.3 `components/combat/bullets/bullet_shot_context.gd`

```gdscript
class_name BulletShotContext
extends RefCounted

var aim_angle := 0.0
var shot_index := 0
var wave_index := 0
var difficulty: BulletDifficulty = null
```

`BulletPattern.build_shot()` receives this context. Difficulty is null until the scaling system exists.

### 4.4 `components/combat/bullets/bullet_spawn.gd`

```gdscript
class_name BulletSpawn
extends RefCounted

var bullet: BulletData          # optional override; falls back to pattern.bullet
var angle := 0.0                # absolute radians
var position_offset := Vector2.ZERO
var speed_scale := 1.0
var damage_scale := 1.0
```

### 4.5 `components/combat/bullets/bullet_pattern.gd`

```gdscript
class_name BulletPattern
extends Resource

@export var bullet: BulletData
@export var telegraph: TelegraphData       # null = no warning

@export_group("Timing")
@export var shots_per_wave := 1
@export var shot_interval := 0.1
@export var waves := 1
@export var wave_interval := 0.5
@export var start_delay := 0.0
@export var reaim_each_shot := true

@export_group("Random")
@export var random_seed := 0
@export var randomize_seed := false

## Subclasses implement geometry. Return an empty array for a no-op.
func build_shot(_context: BulletShotContext) -> Array[BulletSpawn]:
	return []
```

`BulletPattern` is a **strategy resource**. Add a new subclass when you need a new geometry; tuning remains in the `.tres`.

### 4.6 `components/combat/bullets/patterns/spread_pattern.gd`

```gdscript
class_name SpreadPattern
extends BulletPattern

@export var count := 5
@export var spread_degrees := 45.0
@export var speed_scale := 1.0

func build_shot(context: BulletShotContext) -> Array[BulletSpawn]:
	var result: Array[BulletSpawn] = []

	if count <= 1:
		var single := BulletSpawn.new()
		single.bullet = bullet
		single.angle = context.aim_angle
		single.speed_scale = speed_scale
		result.append(single)
		return result

	var total := deg_to_rad(spread_degrees)
	var step := total / maxf(count - 1, 1)
	var start := context.aim_angle - total * 0.5

	for i in count:
		var spawn := BulletSpawn.new()
		spawn.bullet = bullet
		spawn.angle = start + step * i
		spawn.speed_scale = speed_scale
		result.append(spawn)

	return result
```

`count = 1` fires one aimed bullet.

### 4.7 `components/combat/bullets/patterns/ring_pattern.gd`

```gdscript
class_name RingPattern
extends BulletPattern

@export var count := 12
@export var start_angle_degrees := 0.0
@export var spin_degrees_per_shot := 0.0
@export var use_aim := false
@export var speed_scale := 1.0

func build_shot(context: BulletShotContext) -> Array[BulletSpawn]:
	var result: Array[BulletSpawn] = []

	var shot := context.shot_index + context.wave_index * maxi(shots_per_wave, 1)
	var base := deg_to_rad(start_angle_degrees)
	base += deg_to_rad(spin_degrees_per_shot) * shot
	if use_aim:
		base += context.aim_angle

	for i in count:
		var spawn := BulletSpawn.new()
		spawn.bullet = bullet
		spawn.angle = base + TAU * i / count
		spawn.speed_scale = speed_scale
		result.append(spawn)

	return result
```

### 4.8 `components/combat/bullets/patterns/spiral_pattern.gd`

```gdscript
class_name SpiralPattern
extends BulletPattern

@export var arms := 1
@export var spin_degrees_per_shot := 15.0
@export var start_angle_degrees := 0.0
@export var use_aim := false
@export var speed_scale := 1.0

func build_shot(context: BulletShotContext) -> Array[BulletSpawn]:
	var result: Array[BulletSpawn] = []

	var shot := context.shot_index + context.wave_index * maxi(shots_per_wave, 1)
	var base := deg_to_rad(start_angle_degrees)
	base += deg_to_rad(spin_degrees_per_shot) * shot
	if use_aim:
		base += context.aim_angle

	for arm in arms:
		var spawn := BulletSpawn.new()
		spawn.bullet = bullet
		spawn.angle = base + TAU * arm / arms
		spawn.speed_scale = speed_scale
		result.append(spawn)

	return result
```

Later patterns:

- `RandomSpreadPattern` with a seeded `RandomNumberGenerator`.
- `WavePattern` / `WallPattern`.
- `SequencePattern` with phases.
- `SplitPattern` / `HomingPattern`.

### 4.9 Authoring the `.tres` files

1. In the FileSystem dock, right-click `resources/bullets/` -> **Create New** -> **Resource** -> `BulletData`. Set `team`, `speed`, `damage`, `lifetime`, `radius`, and the visuals. Leave `scene` empty so the shared bullet scene is used.
2. Right-click `resources/patterns/<folder>/` -> **Create New** -> **Resource** -> `SpreadPattern` (or `RingPattern` / `SpiralPattern`). Set `bullet` to the `BulletData`.
3. Select the `telegraph` property's dropdown -> **New TelegraphData** if the attack needs a warning, or leave it empty for a basic attack.
4. Save as `fan_3_bone.tres`, `combo_1_bolt.tres`, etc.

Team rules:

| Emitter | `BulletData.team` | Effective mask |
|---|---|---|
| Sword | `PLAYER` | `1 | 4` (environment + enemy hurtboxes) |
| Enemy | `ENEMY` | `1 | 2` (environment + player hurtbox) |

Sword patterns called from `fire_pattern()` fire exactly one shot, so keep `shots_per_wave = 1`, `waves = 1`, and `telegraph = null` for them.

#### Bullet visuals (pick one)

| You want | Set | Notes |
|---|---|---|
| Fastest placeholder | leave `texture` and `sprite_frames` empty | `Bullet._draw()` draws a circle using `radius` and `visual_color`; no asset at all |
| Static sprite | `texture` | No `SpriteFrames` needed; the `Sprite2D` displays it |
| Animated sprite | `sprite_frames` + `animation` | Optional; wins over `texture` when set |

For a static test texture without importing art, create a `GradientTexture2D` or `PlaceholderTexture2D` resource and assign it to `texture`. That is much faster than authoring a `SpriteFrames` resource.

Do **not** create a `SpriteFrames` resource for a bullet that never animates. Set `radius` to roughly match the texture's visible size so the collision matches the art.

---

## 5. Telegraphs

Telegraphs are **optional**. `BulletPattern.telegraph = null` means no warning. Use them for bosses, large patterns, and oppressive attacks; basic attacks rely on the player observing the enemy.

| Shape | Fields used | Typical use |
|---|---|---|
| `LINE` | `length`, `line_width` | Sniper shot, laser-like warning |
| `CONE` | `cone_degrees`, `length` | Shotgun/fan sweep |
| `RING` | `radius` | Ring/spiral burst centered on the enemy |
| `CIRCLE` | `radius` | Area blast around a point |
| `RECT` | `rect_size` | Corridor/wall of bullets |
| `ARC` | `radius`, `arc_start_degrees`, `arc_end_degrees` | Sweeping slash or sector attack |

The warning is drawn in the emitter's aim space: the emitter sets its origin and rotation; `follow_aim` controls whether it keeps tracking after the warning starts.

### 5.1 `components/combat/bullets/telegraph_data.gd`

```gdscript
class_name TelegraphData
extends Resource

enum Shape { LINE, CONE, RING, CIRCLE, RECT, ARC }

@export var shape := Shape.LINE
@export var duration := 0.6

## true: the warning tracks the current aim/target until the shot.
## false: the warning is fixed at the angle captured at start.
@export var follow_aim := true

## true: the first shot uses the warning's final angle, so the warning
## and the shot always agree.
@export var lock_aim_at_end := true

@export_group("Red warning look")
@export var fill_color := Color(1.0, 0.0, 0.0, 0.35)
@export var outline_color := Color(1.0, 0.1, 0.1, 0.9)
@export var line_width := 2.0
@export var pulse := true
@export var pulse_speed := 6.0
@export var z_index := 100

@export_group("Shape")
@export var length := 240.0
@export var cone_degrees := 30.0
@export var radius := 40.0
@export var arc_start_degrees := -45.0
@export var arc_end_degrees := 45.0
@export var rect_size := Vector2(120.0, 60.0)
```

### 5.2 `components/combat/bullets/telegraph.gd`

```gdscript
class_name Telegraph
extends Node2D

var data: TelegraphData
var _time := 0.0
var _duration_left := 0.0

func _ready() -> void:
	top_level = true
	visible = false
	set_process(false)

func show_telegraph(d: TelegraphData, origin: Vector2, angle: float) -> void:
	data = d
	global_position = origin
	global_rotation = angle
	_time = 0.0
	_duration_left = d.duration
	z_index = d.z_index
	visible = true
	set_process(true)
	queue_redraw()

func set_aim(origin: Vector2, angle: float) -> void:
	global_position = origin
	global_rotation = angle
	queue_redraw()

func hide_telegraph() -> void:
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	_time += delta
	_duration_left -= delta
	if _duration_left <= 0.0:
		hide_telegraph()
		return
	queue_redraw()

func _draw() -> void:
	if data == null:
		return

	var alpha := 1.0
	if data.pulse:
		alpha = 0.55 + 0.45 * sin(_time * data.pulse_speed)

	var fill := data.fill_color
	var line := data.outline_color
	fill.a *= alpha
	line.a *= alpha

	match data.shape:
		TelegraphData.Shape.LINE:
			draw_line(Vector2.ZERO, Vector2.RIGHT * data.length, line, data.line_width)

		TelegraphData.Shape.CONE:
			var half := deg_to_rad(data.cone_degrees) * 0.5
			var points := PackedVector2Array([Vector2.ZERO])
			var steps := 16
			for i in steps + 1:
				var a := -half + (2.0 * half) * float(i) / steps
				points.append(Vector2.RIGHT.rotated(a) * data.length)
			draw_colored_polygon(points, fill)
			draw_polyline(points, line, data.line_width)
			draw_line(Vector2.ZERO, points[points.size() - 1], line, data.line_width)

		TelegraphData.Shape.RING:
			draw_arc(Vector2.ZERO, data.radius, 0.0, TAU, 64, line, data.line_width, true)

		TelegraphData.Shape.CIRCLE:
			draw_circle(Vector2.ZERO, data.radius, fill)
			draw_arc(Vector2.ZERO, data.radius, 0.0, TAU, 64, line, data.line_width, true)

		TelegraphData.Shape.RECT:
			var rect := Rect2(Vector2.ZERO, data.rect_size)
			draw_rect(rect, fill, true)
			draw_rect(rect, line, false, data.line_width)

		TelegraphData.Shape.ARC:
			draw_arc(
				Vector2.ZERO,
				data.radius,
				deg_to_rad(data.arc_start_degrees),
				deg_to_rad(data.arc_end_degrees),
				48,
				line,
				data.line_width,
				true
			)
```

Behavior:

- `follow_aim = true` -> the emitter calls `set_aim()` each physics frame during the warning.
- `follow_aim = false` -> the warning stays where it started.
- `lock_aim_at_end = true` -> the first shot uses the warning's last angle.
- All shapes are red and pulse.
- The telegraph is a visual-only `Node2D`; no collision.

## 6. Bullet runtime and manager

### 6.1 `components/combat/bullets/bullet.gd`

```gdscript
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

	# Static texture is the default. SpriteFrames is only for animated
	# bullets and wins when both are set. If both are empty, _draw() paints
	# a placeholder circle using the collision radius.
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

	# Reuse the existing melee hurtbox/health path. Only areas with a
	# health component are valid targets; attack hitboxes without health
	# are ignored.
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

func _draw() -> void:
	if data == null:
		return
	if data.texture != null or data.sprite_frames != null:
		return
	# No art assigned: draw the collision circle so the bullet is visible.
	draw_set_transform(Vector2.ZERO, 0.0, data.visual_scale)
	draw_circle(Vector2.ZERO, data.radius, data.visual_color)

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
	# BulletManager.release() sets active = false immediately and defers
	# the actual pool return, so do not clear active here as well.
	BulletManager.release(self)
```

The bullet scene is shared by all bullet data. `Area2D.damage()` is the existing `HitboxComponent` path, so dash i-frames, invincibility, damage numbers, and the rare nonzero knockback all work without new hurtbox code.

### 6.2 `components/combat/bullets/bullet.tscn`

```text
Bullet (Area2D)
|-- script: bullet.gd
|-- collision_layer = 32         (physics layer 6, bit value)
|-- collision_mask = 0          (overridden in setup)
|-- monitoring = false          (enabled in setup)
|-- monitorable = false         (enabled in setup)
|-- Sprite2D                    (static texture; hidden when animated)
|-- AnimatedSprite2D            (optional; hidden for static bullets)
|-- CollisionShape2D
|   `-- CircleShape2D            (radius overridden in setup)
`-- VisibleOnScreenNotifier2D
```

`Sprite2D` is the easy path for static bullets. `AnimatedSprite2D` can stay empty until you actually need animation. If both are empty, `Bullet._draw()` paints a circle. Set both visual nodes to `texture_filter = Nearest` if the project uses pixel art.

The `VisibleOnScreenNotifier2D` emits `screen_exited`; the bullet releases when off-screen and `despawn_offscreen` is true.

### 6.3 `components/combat/bullets/bullet_manager.gd` (autoload)

Add this as an autoload named **`BulletManager`**. Do not add a `class_name` with the same name.

```gdscript
extends Node

const BULLET_LAYER_GROUP := &"bullet_layer"

@export var max_active_bullets := 1024

var _pools: Dictionary = {}          # PackedScene -> Array[Bullet]
var _active: Array[Bullet] = []
var _bullet_layer: Node2D = null
var _default_scene: PackedScene = null

func _ready() -> void:
	_resolve_bullet_layer()

func _resolve_bullet_layer() -> void:
	_bullet_layer = get_tree().get_first_node_in_group(BULLET_LAYER_GROUP) as Node2D
	if _bullet_layer == null and get_tree().current_scene is Node2D:
		_bullet_layer = get_tree().current_scene as Node2D

func _get_bullet_layer() -> Node2D:
	if is_instance_valid(_bullet_layer):
		return _bullet_layer
	_resolve_bullet_layer()
	return _bullet_layer

func _get_scene(data: BulletData) -> PackedScene:
	if data and data.scene:
		return data.scene
	return _get_default_scene()

func _get_default_scene() -> PackedScene:
	if _default_scene == null:
		# Loaded lazily to avoid a preload cycle between the autoload and
		# bullet.tscn (whose script references the BulletManager autoload).
		_default_scene = load("res://components/combat/bullets/bullet.tscn") as PackedScene
	return _default_scene

func prewarm(data: BulletData, count: int) -> void:
	if data == null:
		return
	if _get_bullet_layer() == null:
		push_error("BulletManager: add a BulletLayer (group 'bullet_layer') before prewarming.")
		return

	var scene := _get_scene(data)
	var pool: Array = _pools.get(scene, [])
	while pool.size() < count:
		var bullet := _create_bullet(scene)
		if bullet == null:
			break
		pool.append(bullet)
	_pools[scene] = pool

func _create_bullet(scene: PackedScene) -> Bullet:
	var bullet := scene.instantiate() as Bullet
	if bullet == null:
		push_error("BulletManager: bullet scene root must use bullet.gd.")
		return null
	var layer := _get_bullet_layer()
	if layer == null or not layer.is_inside_tree():
		push_error("BulletManager: add a Node2D named BulletLayer to the scene and group it as 'bullet_layer'.")
		bullet.queue_free()
		return null
	layer.add_child(bullet)
	bullet.reset_for_pool()
	return bullet

func spawn(
	data: BulletData,
	pos: Vector2,
	dir: Vector2,
	source: Node,
	target: Node2D = null,
	team_override := -1,
	speed_scale := 1.0,
	damage_scale := 1.0
) -> Bullet:
	if data == null:
		return null

	var scene := _get_scene(data)
	var pool: Array = _pools.get(scene, [])
	var bullet: Bullet = null

	if not pool.is_empty():
		bullet = pool.pop_back() as Bullet
	elif _active.size() >= max_active_bullets and not _active.is_empty():
		# Recycle the oldest active bullet instead of allocating.
		bullet = _active.pop_front() as Bullet
		bullet.active = false
		bullet.reset_for_pool()
	else:
		bullet = _create_bullet(scene)

	if bullet == null:
		return null

	_active.append(bullet)
	bullet.setup(data, pos, dir, source, target, team_override, speed_scale, damage_scale)
	return bullet

func release(bullet: Bullet) -> void:
	if not is_instance_valid(bullet) or not bullet.active:
		return
	bullet.active = false
	call_deferred("_release_now", bullet)

func _release_now(bullet: Bullet) -> void:
	# A bullet released this frame can be recycled by spawn() before this
	# deferred call runs. If it is active again, leave it alone.
	if not is_instance_valid(bullet) or bullet.active:
		return

	var pool_scene := _get_scene(bullet.data) if bullet.data else _get_default_scene()
	_active.erase(bullet)
	bullet.reset_for_pool()

	var pool: Array = _pools.get(pool_scene, [])
	pool.append(bullet)
	_pools[pool_scene] = pool

func clear_team(team: BulletData.Team) -> void:
	for bullet in _active.duplicate():
		# Use the bullet's effective team, not data.team, so gallery
		# team_override spawns are cleared correctly.
		if bullet.team == team:
			bullet.cancel()

func clear_all() -> void:
	for bullet in _active.duplicate():
		bullet.cancel()

func active_count() -> int:
	return _active.size()

func pool_count(scene: PackedScene) -> int:
	var pool: Array = _pools.get(scene, [])
	return pool.size()
```

Add a `BulletLayer` node to every gameplay level and the pattern gallery:

```text
BulletLayer (Node2D)
|-- groups: ["bullet_layer"]
`-- y_sort_enabled = true (optional)
```

The manager adds pooled bullets there. The dog scene itself is not a level; test the sword bullets in the pattern gallery or a room with a `BulletLayer`.

---

## 7. Aim and emitter

### 7.1 `components/combat/bullets/aim_source.gd`

```gdscript
class_name AimSource
extends Node2D

enum Mode { MOUSE, TARGET, FIXED, RANDOM }

@export var mode := Mode.MOUSE
@export var origin: Node2D
@export var target: Node2D
@export var fixed_angle_degrees := 0.0
@export var random_spread_degrees := 360.0

func get_origin() -> Vector2:
	return origin.global_position if is_instance_valid(origin) else global_position

func get_aim_angle() -> float:
	match mode:
		Mode.MOUSE:
			return (get_global_mouse_position() - get_origin()).angle()
		Mode.TARGET:
			if is_instance_valid(target):
				return (target.global_position - get_origin()).angle()
		Mode.RANDOM:
			var half := deg_to_rad(random_spread_degrees) * 0.5
			return randf_range(-half, half)
		_:
			return deg_to_rad(fixed_angle_degrees)
	return 0.0
```

Usage:

- Sword emitter: `mode = MOUSE`; origin = dog.
- Enemy emitter: `mode = TARGET`; origin = enemy; the enemy brain/controller sets `target = detection_area.get_target()`.
- Fixed turret: `mode = FIXED`, `fixed_angle_degrees`.
- Wild pattern: `mode = RANDOM`.

### 7.2 `components/combat/bullets/bullet_emitter_component.gd`

```gdscript
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
```

---

## 8. Movement modifiers

Use one generic component on the dog and on enemies. It does not know about state charts or weapons.

### 8.1 `components/movement/movement_modifier_component.gd`

```gdscript
class_name MovementModifierComponent
extends Node

@export var physics_component: PhysicsComponent

var _modifiers: Dictionary = {}   # StringName -> multiplier
var _timers: Dictionary = {}      # StringName -> remaining seconds

func add(source: StringName, multiplier: float, duration := -1.0) -> void:
	_modifiers[source] = maxf(multiplier, 0.0)
	if duration > 0.0:
		_timers[source] = duration
	else:
		_timers.erase(source)
	_refresh()

func remove(source: StringName) -> void:
	_modifiers.erase(source)
	_timers.erase(source)
	_refresh()

func get_speed_scale() -> float:
	var scale := 1.0
	for value in _modifiers.values():
		scale *= value
	return scale

func _process(delta: float) -> void:
	if _timers.is_empty():
		return

	for source in _timers.keys():
		_timers[source] -= delta
		if _timers[source] <= 0.0:
			remove(source)

func _refresh() -> void:
	if physics_component:
		physics_component.speed_scale = get_speed_scale()
```

Rules:

- **Source-based**: `&"attack"`, `&"sword_attack"`, `&"focus"`, `&"buff_slow"`, `&"gear_heavy"`.
- **Owned by the moving actor**: add the component to the Dog or the enemy, never to a weapon. The sword only emits `attack_started` / `attack_ended`; the dog applies its own slow.
- **Multiplicative stacking**: `0.5 * 0.8 = 0.4`.
- **0** stops movement; **1** is normal; **0.5** is half speed.
- Omit `duration` when the state/controller adds and removes explicitly.
- The component only writes `PhysicsComponent.speed_scale`; the physics component does the rest.

## 9. Existing code changes (diffs)

These are diff-style snippets against the current files. Line context may shift after other edits; apply by intent.

### 9.1 `components/movement/physics_component.gd`

```diff
@@
 var direction : Vector2
 var last_faced_direction : Vector2
 var applied_knockback : Vector2
 @export var can_be_knocked_back := true
+var speed_scale := 1.0
 
 signal facing_changed(direction: Vector2)
 
@@
 func move() -> void:
 	actor.move_and_slide()
 
+func get_effective_move_speed() -> float:
+	return move_speed * speed_scale
+
 func calculate_velocity() -> Vector2:
 	direction = input_component.input_direction
 	if(direction != Vector2.ZERO):
 		last_faced_direction = direction
 		facing_changed.emit(direction)
-	var speed := move_speed
+	var speed := get_effective_move_speed()
 	if is_instance_valid(dash_component):
 		if input_component.dash_input and not dash_component.is_dashing():
 			dash_component.start_dash(dash_duration)
 		if dash_component.is_dashing():
-			speed = dash_speed
+			speed = dash_speed * speed_scale
```

If dashes should not be affected by the attack slow, leave `speed = dash_speed` unscaled.

### 9.2 `actors/player/weapon_behavior.gd`

The sword is the **attack source**, not the movement authority. It only announces when an attack starts and ends; the dog listens and applies its own movement modifier.

Add the attack-lifecycle signals:

```diff
 @export var idle_bob_frequency := 7.0
 @export var idle_side_distance := 12.0
 +@export var aim_origin: Node2D
 
 +signal attack_started
 +signal attack_ended
 +
  var attacking := false
```

Emit them from the existing lifecycle functions:

```diff
 func begin_attack() -> void:
 	attacking = true
+	attack_started.emit()
 	
 	var dir := get_aim_direction()
@@
 func end_attack() -> void:
 	attacking = false
+	attack_ended.emit()
```

Do **not** add `movement_modifier` or `attack_move_multiplier` to the sword. It must not hold a reference to the dog's movement component.

Fix the idle follow to use the effective speed and the computed `follow_rate`:

```diff
 	#idle: lazy position
 	var player_speed: float = maxf(
-		owner.physics_component.move_speed,
+		owner.physics_component.get_effective_move_speed(),
 		owner.velocity.length()
 	)
 	var speed_ratio := player_speed / maxf(reference_speed, 0.001)
 	var follow_rate := maxf(follow_speed * speed_ratio, min_follow_speed)
 	
 	var target = get_idle_target()
-	var t := 1.0 - exp(-follow_speed * delta)
+	var t := 1.0 - exp(-follow_rate * delta)
 	global_position = global_position.lerp(target, t)
```

The current file computes `follow_rate` but still uses `follow_speed`; this diff fixes that. `lock_aim` can be removed if it is still a no-op.

The sword root also exports `aim_origin`. In `dog.tscn`, set the sword instance's `aim_origin = ..` (the Dog) so the projectile direction comes from the player, not the blade tip. This is only an aim reference; it does not give the sword movement authority.

### 9.3 `actors/player/dog.gd`

The dog owns movement, the hurtbox, and the movement modifier. It listens to the sword's attack lifecycle and decides how much an attack slows it.

```diff
 @export var physics_component : PhysicsComponent
 @export var input_component : PlayerInputComponent
 @export var health_component : HealthComponent
+@export var weapon : Weapon
+@export var movement_modifier : MovementModifierComponent
+@export var attack_move_multiplier := 0.5
 
 var _last_faced_direction := Vector2.RIGHT
+
+func _ready() -> void:
+	if weapon:
+		weapon.attack_started.connect(_on_weapon_attack_started)
+		weapon.attack_ended.connect(_on_weapon_attack_ended)
+
+func _on_weapon_attack_started() -> void:
+	if movement_modifier:
+		movement_modifier.add(&"sword_attack", attack_move_multiplier)
+
+func _on_weapon_attack_ended() -> void:
+	if movement_modifier:
+		movement_modifier.remove(&"sword_attack")
```

Notes:

- `begin_attack()` fires once per combo step; `add(&"sword_attack", ...)` replaces the same source, so the slow stays active across the whole combo.
- `end_attack()` fires when the sword returns to Idle, which removes the slow.
- If the dog can be hurt or killed mid-combo, also call `movement_modifier.remove(&"sword_attack")` in that path. Otherwise the slow can outlive the attack until the sword reaches Idle.

### 9.4 `actors/player/sword_state_machine.gd`

No movement changes are needed. The existing calls already drive the signals:

- `_sword.begin_attack()` emits `attack_started`.
- `_sword.end_attack()` emits `attack_ended`.

Leave the combo flow alone; only add the projectile method tracks to the animations (section 10.3).

Projectiles are fired by the **AnimationPlayer method tracks**, not by these functions:

- Combo 1 track -> target `BulletEmitter`, method `fire_pattern`, args `[0]`, at the release frame.
- Combo 2 -> `[1]`.
- Combo 3 -> `[2]`.

### 9.5 `components/enemy/behavior/melee_behavior_component.gd`

```diff
 class_name MeleeBehaviorComponent
 extends EnemyBehaviorComponent
 
-const LOCKED_STATES = [&"attack", &"hurt", &"dead", &"ready"]
+@export var movement_lock_states: Array[StringName] = [
+	&"attack",
+	&"ready",
+	&"hurt",
+	&"dead",
+]
@@
 func tick(_delta: float) -> void:
-	if state_manager.current_state in LOCKED_STATES:
+	if state_manager.current_state in movement_lock_states:
 		actor.velocity = Vector2.ZERO
 	else:
```

Per enemy:

- **Stationary shooter**: keep `&"attack"` and `&"ready"`.
- **Mobile shooter**: remove `&"attack"` and `&"ready"`; use the ranged controller's `attack_move_multiplier` (0.5 or 1.0).
- **Hard stop** for hurt/dead: keep them.

If an enemy should stop for attack but still be slowable by buffs, keep `attack` in the lock list; the lock wins over the modifier.

> **Two stops, not one.** `MeleeBehaviorComponent` also has
> `stop_when_in_attack_range`. It still zeroes velocity inside the attack range
> even after you remove `attack`/`ready` from `movement_lock_states`, so a
> mobile shooter must also set `stop_when_in_attack_range = false`. Otherwise
> it fires on the move in the gallery but freezes in the actual room.
>
> Quick check for a "mobile shooter" enemy:
>
> | Setting | Value |
> |---|---|
> | `movement_lock_states` | `[&"hurt", &"dead"]` |
> | `stop_when_in_attack_range` | `false` |
> | `attack_move_multiplier` | `0.5` (or `1.0`) |

### 9.6 `project.godot`

Add the autoload and collision layer:

```diff
 [autoload]
 PhantomCameraManager="*uid://cw5q835t18j6y"
 DamageNumbers="*res://services/damage_numbers.gd"
 BetterTerrain="*res://addons/better-terrain/BetterTerrain.gd"
 FrameFreeze="*res://services/frame_freeze.gd"
 _fennara_game_capture="*res://addons/fennara/runtime/game_capture_helper.gd"
+BulletManager="*res://components/combat/bullets/bullet_manager.gd"
 
 [layer_names]
 2d_physics/layer_1="environment"
 2d_physics/layer_2="player"
 2d_physics/layer_3="entities"
 2d_physics/layer_4="hitboxes"
 2d_physics/layer_5="detection_areas"
+2d_physics/layer_6="bullets"
```

The bullet layer for graze/cancel is layer **6**. Even though sword cancel is deferred, keep the layer so it can be added later without touching the bullet scene.

---

## 10. Scene wiring

Node references below are named for clarity. Assign them with the inspector's node picker (or the stored NodePath relative to the node that owns the property); do not type paths by hand unless the direction is stated.

### 10.1 `bullet.tscn`

Create `components/combat/bullets/bullet.tscn`:

```text
Bullet (Area2D)
|-- script: bullet.gd
|-- collision_layer = 32         (physics layer 6 = bit value 32)
|-- collision_mask = 0
|-- monitoring = false
|-- monitorable = false
|-- Sprite2D                    (static texture)
|-- AnimatedSprite2D            (optional animation)
|-- CollisionShape2D
|   `-- CircleShape2D (radius 4)
`-- VisibleOnScreenNotifier2D
```

`bullet.gd` connects `area_entered`, `body_entered`, and `screen_exited` in `_ready()`, so you do **not** need to wire signals in the scene. Make sure the root has `bullet.gd` attached and the child nodes use exactly these names: `Sprite2D`, `AnimatedSprite2D`, `CollisionShape2D` (with a `CircleShape2D`), `VisibleOnScreenNotifier2D`.

### 10.2 `dog.tscn`

Add one child to the Dog:

```text
MovementModifierComponent (Node)
|-- script: movement_modifier_component.gd
`-- physics_component = ../PhysicsComponent
```

Wire the **Dog** (the actor that owns movement and the hurtbox):

- `weapon = NodePath("Weapon")`
- `movement_modifier = NodePath("MovementModifierComponent")`
- `attack_move_multiplier = 0.5` (0 stops, 1 is normal)

The Sword instance only needs its aim reference:

- `aim_origin = NodePath("..")` (the Dog)

Do **not** assign a movement modifier on the Sword instance. The sword only emits `attack_started` / `attack_ended`; the dog applies and removes the slow.

The Dog scene does not need a `BulletLayer`; add that to rooms and the gallery. If you want to test the sword directly in `dog.tscn`, add a `BulletLayer` node as a child and group it `bullet_layer`, but remember its transform will inherit the Dog. Prefer testing in a room or the gallery.

### 10.3 `sword.tscn`

First remove the old melee combo hitboxes and their animation tracks (section 18.1). Then add:

```text
Sword (CharacterBody2D)
|-- ...existing...
|-- AnimatedSprite2D
|   `-- Muzzle (Marker2D at the blade tip)
|-- BulletEmitter (BulletEmitterComponent)
|   `-- AimSource (AimSource, mode = MOUSE)
`-- WeaponAnimationPlayer
```

Wire on `BulletEmitter`:

- `aim_source = NodePath("AimSource")`
- `muzzle = NodePath("../AnimatedSprite2D/Muzzle")`
- `patterns = [combo_1_bolt.tres, combo_2_bolt.tres, combo_3_bolt.tres]`

Why the muzzle is under `AnimatedSprite2D`: `Weapon.begin_attack()` rotates `_attack_sprite.global_rotation`, not the Sword root. A `Muzzle` child of the emitter would keep a fixed local offset and drift away from the blade; a `Marker2D` under the animated sprite follows the blade rotation.

The `AimSource.origin` is resolved at runtime:

- `BulletEmitter._resolve_aim_origin()` checks its parent (the Sword) for an `aim_origin` property.
- In `dog.tscn`, the Sword's `aim_origin` points to the Dog, so the direction is player -> mouse, not blade tip -> mouse.

Add method keys in each combo animation:

| Animation | Time | Track target | Method | Args |
|---|---|---|---|---|
| combo 1 | release frame | `BulletEmitter` | `fire_pattern` | `[0]` |
| combo 2 | release frame | `BulletEmitter` | `fire_pattern` | `[1]` |
| combo 3 | release frame | `BulletEmitter` | `fire_pattern` | `[2]` |

The release frame is a design choice. Use the frame where the blade visually reaches its swing apex; there is no melee hitbox to align with once section 18.1 is done. Do not use the telegraph for the player.

### 10.4 Enemy scenes

For each ranged skeleton:

```text
Skeleton (CharacterBody2D)
|-- ...existing...
|-- BulletEmitter (BulletEmitterComponent)
|   |-- Muzzle (Node2D, position at staff/hand)
|   `-- AimSource (AimSource, mode = TARGET)
|-- RangedAttackController (Node)
|-- CooldownTimer (Timer, one_shot = true, optional)
|-- MovementModifierComponent (Node)
`-- ...existing state manager / behavior...
```

Wire:

- `BulletEmitter.aim_source = AimSource`
- `BulletEmitter.muzzle = Muzzle`
- `BulletEmitter.patterns = [skeleton_fan.tres, skeleton_ring.tres]`
- `AimSource.origin = ../..` (the enemy root; AimSource sits under BulletEmitter)
- `RangedAttackController.emitter = BulletEmitter`
- `RangedAttackController.state_manager = EnemyStateManagerComponent`
- `RangedAttackController.state_chart = MeleeEnemyChart`
- `RangedAttackController.movement_modifier = MovementModifierComponent`
- `RangedAttackController.patterns = same array`
- `RangedAttackController.detection_area = DetectionArea` (if using target updates)
- `RangedAttackController.cooldown_timer = CooldownTimer` (optional; set `one_shot = true`)
- `MovementModifierComponent.physics_component = PhysicsComponent`

Do **not** keep the melee `EnemyAttackController` on a ranged enemy. The ranged controller replaces it.

Movement:

- For a stationary shooter: `movement_lock_states` includes `attack` (and `ready`), or `attack_move_multiplier = 0.0`.
- For a mobile shooter: remove `attack`/`ready` from `movement_lock_states`; set `attack_move_multiplier = 0.5` (or 1.0 for no slow).
- **Still required for mobile shooters:** set `stop_when_in_attack_range = false` on `MeleeBehaviorComponent`. That flag is a separate hard stop in `tick()` and does not read `movement_lock_states`; leaving it `true` keeps the enemy frozen in range while bullets fire.

### 10.5 Enemy state chart

For a ranged archetype, the `Attack` state is the bullet-firing state.

```text
Root
|-- Idle
|-- Chase
|-- Ready
|-- Attack
|   `-- To Ready       (event: pattern_finished)
|       or To Chase    (event: pattern_finished)
|-- Hurt
|   `-- To Idle        (event: animation_finished)
`-- ToHurt             (event: hurt, guard can_be_staggered)
```

Remove the `Attack -> Chase` transition on `animation_finished` for ranged enemies. The pattern is the authority; the animation can finish early or loop.

Do **not** add a `Cast` state. If you keep a melee chart for a melee-only enemy, that chart can keep `animation_finished`.

### 10.6 `RangedAttackController`

Create `components/enemy/attack/ranged_attack_controller.gd`:

```gdscript
class_name RangedAttackController
extends Node

@export var emitter: BulletEmitterComponent
@export var state_manager: EnemyStateManagerComponent
@export var state_chart: StateChart
@export var detection_area: DetectionArea
@export var movement_modifier: MovementModifierComponent
@export var patterns: Array[BulletPattern] = []
@export var attack_index := 0
@export var attack_move_multiplier := 1.0
@export var cooldown := 1.0
@export var cooldown_timer: Timer

func _ready() -> void:
	if state_manager:
		state_manager.state_changed.connect(_on_state_changed)
	if emitter:
		emitter.pattern_finished.connect(_on_pattern_finished)
	if cooldown_timer:
		cooldown_timer.timeout.connect(_on_cooldown_timeout)
	_update_aim_target()

func _physics_process(_delta: float) -> void:
	_update_aim_target()

func _update_aim_target() -> void:
	if detection_area and emitter and emitter.aim_source:
		emitter.aim_source.target = detection_area.get_target()

func _on_state_changed(previous: StringName, current: StringName) -> void:
	if current == &"attack":
		# Set the target before start() so the first aimed shot is correct.
		_update_aim_target()

		if movement_modifier:
			movement_modifier.add(&"attack", attack_move_multiplier)

		var p: BulletPattern = null
		if not patterns.is_empty():
			p = patterns[clampi(attack_index, 0, patterns.size() - 1)]
		if emitter:
			emitter.start(p)

	if previous == &"attack" and current != &"attack":
		if movement_modifier:
			movement_modifier.remove(&"attack")
		if emitter:
			emitter.stop()

func _on_pattern_finished() -> void:
	if state_chart:
		# The melee controller used to own attack_ready. Without a ranged
		# cooldown the chart would re-enter Attack immediately.
		if cooldown_timer:
			state_chart.set_expression_property(&"attack_ready", false)
			cooldown_timer.start(cooldown)
		state_chart.send_event(&"pattern_finished")

func _on_cooldown_timeout() -> void:
	if state_chart:
		state_chart.set_expression_property(&"attack_ready", true)
```

`CooldownTimer` is optional. If it is unassigned, the controller leaves `attack_ready` alone and the chart re-enters Attack as soon as it can; pace with `start_delay`/`wave_interval` in that case. If it is assigned, the enemy waits `cooldown` seconds between patterns.

If `patterns` is empty, `emitter.start(null)` uses the emitter's default `pattern`.

`attack_index` is static. If the enemy should alternate attacks, change it in `_on_pattern_finished()` (for example `attack_index = (attack_index + 1) % patterns.size()`) before sending the event.

### 10.7 Melee controller note

The existing `EnemyAttackController` opens melee hitboxes, plays VFX, and starts a cooldown on the `attack` state. It is for a melee archetype. A ranged enemy must not have it active, or it will both fire bullets and swing a hitbox. Keep it only on melee variants; remove it from ranged scenes. Also remove or disable `AttackVFX/HitboxComponent` and its shape tracks for ranged enemies (section 18.3).

---

## 11. Enemy Attack-state integration

Flow:

1. `Chase`/`Ready` sees the target in firing range.
2. Chart enters `Attack`.
3. `RangedAttackController` adds the movement modifier and calls `emitter.start(pattern)`.
4. The emitter shows the optional red telegraph, waits, then fires waves/shots.
5. `pattern_finished` -> chart event -> `Ready`/`Chase`.
6. If Hurt interrupts, `RangedAttackController` leaves `Attack`, removes the modifier, stops the emitter; the red telegraph disappears.

The Attack animation is cosmetic:

- Use a cast loop, or a one-shot that holds its last frame.
- The animation's `animation_finished` must not drive the state transition for ranged enemies.
- The emitter/pattern duration is the timing authority.

---

## 12. Pattern gallery dev scene

Path: `dev/pattern_gallery.tscn` (dev only; not shipped as gameplay).

```text
PatternGallery (Node2D, script pattern_gallery.gd)
|-- BulletLayer (Node2D, group "bullet_layer", y_sort_enabled = true)
|-- PlayerDummy (CharacterBody2D, gallery_dummy.gd, layer 2 hurtbox)
|-- EnemyDummy (CharacterBody2D, gallery_dummy.gd, layer 4 hurtbox)
|-- BulletEmitterComponent
|   |-- Muzzle (Node2D)
|   `-- AimSource (mode = MOUSE)
`-- UI (CanvasLayer)
    |-- PatternOption (OptionButton)
    |-- TeamOption (OptionButton: Player, Enemy)
    |-- TelegraphOption (OptionButton: None, LINE, CONE, RING, CIRCLE, RECT, ARC)
    |-- DurationSlider (HSlider: 0.0-2.0)
    |-- FollowAim (CheckBox)
    |-- StopButton (Button)
    |-- ClearButton (Button)
    |-- StressButton (Button)
    |-- MoveCheck (CheckBox)
    `-- Stats (Label)
```

Give the UI nodes scene-unique names (`%PatternOption`, etc.) and wire them in the script.

Wire the gallery emitter:

- `BulletEmitter.patterns` and/or `pattern` = one of the scanned `.tres` (the script assigns it at runtime).
- `BulletEmitter.muzzle = NodePath("Muzzle")`.
- `BulletEmitter.aim_source = NodePath("AimSource")`.
- `AimSource.origin = NodePath("..")` (the emitter itself, so orbiting the emitter also moves the aim origin).
- `AimSource.mode = MOUSE`.

Each dummy is a `CharacterBody2D` with `gallery_dummy.gd`, a `HealthComponent`, and a `HitboxComponent` child whose `health_component` points at the root's `HealthComponent`. Set the player dummy's hitbox `collision_layer = 2` and the enemy dummy's `collision_layer = 4`; both hitbox masks can stay `0`, because the bullet is the area that monitors them.

```gdscript
# dev/gallery_dummy.gd
extends CharacterBody2D

## HitboxComponent.damage() reads owner.physics_component for knockback.
## The dummy does not move, but the property must exist so bullet hits do
## not raise an invalid-property error. Leave it unassigned.
@export var physics_component: PhysicsComponent
```

### 12.1 `dev/pattern_gallery.gd`

```gdscript
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

	team_option.clear()
	team_option.add_item("Player")
	team_option.add_item("Enemy")

	telegraph_option.clear()
	for shape_name in ["None", "LINE", "CONE", "RING", "CIRCLE", "RECT", "ARC"]:
		telegraph_option.add_item(shape_name)

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
```

Gallery behavior:

- Recursively loads every `.tres` under `resources/patterns/`; new files appear after reopening the scene or refreshing.
- `Team` writes `emitter.team_override`; 0 = Player, 1 = Enemy (matches `BulletData.Team`).
- `Telegraph` override tests all shapes without editing resources.
- `MoveCheck` orbits the emitter to test firing while moving.
- `StressButton` increases waves/shot rate and removes the telegraph.
- The `Stats` label shows FPS and active bullet count.

The gallery is a dev scene; it can use direct `DirAccess` scanning and does not need to ship in the game.

---

## 13. Performance rules

Target: **300-500 active bullets** with pooled `Area2D` nodes.

- Prewarm each pattern's bullet type (`BulletData.prewarm`).
- No `instantiate()`/`queue_free()` during steady-state combat; prewarm first and use `BulletManager`.
- Reset **all** bullet state on acquire: direction, speed, lifetime, masks, visuals, graze flag, pierce, target, collision shape.
- Use `set_deferred` for `CollisionShape2D.disabled`, `monitoring`, and `monitorable`.
- Release with `call_deferred` from hit callbacks.
- Bullets are physics layer 6 (bit `32`) and only target the opposing hurtbox layer + environment; no bullet-bullet collisions.
- Use simple `CircleShape2D` collisions and shared textures/materials.
- Add a `BulletLayer` to each level; do not parent bullets to moving actors.
- Cull off-screen with `VisibleOnScreenNotifier2D`; cap lifetime.
- Do not use per-bullet particles/trails/shaders in the base.
- Stress test 300/500 and profile before optimizing.
- Future upgrade path: keep `BulletManager.spawn/release/clear_team` unchanged, replace the internals with flat arrays + a single `MultiMeshInstance2D`/`RenderingServer` runtime and manual collision for 1,000+ bullets.

---

## 14. Difficulty hooks (structure only)

The types already exist:

- `BulletDifficulty` - multipliers.
- `BulletShotContext` - aim/shot/wave + `difficulty`.

To plug scaling later without changing pattern signatures:

1. Add `@export var difficulty: BulletDifficulty` to `BulletEmitterComponent`.
2. When building the context, set `context.difficulty = difficulty`.
3. In patterns, apply `context.difficulty.count_multiplier`, `.speed_multiplier`, etc.
4. In the emitter, multiply `shot_interval`, `wave_interval`, and telegraph duration by the matching multipliers.
5. In `BulletManager`/`Bullet.setup`, apply damage/speed multipliers if desired.

Do **not** implement this yet. Patterns use baseline values; `difficulty` is null.

---

## 15. Implementation phases and checklist

### Phase 1A - Runtime and data

Do these **in order**. The autoload points at a script that must already exist, and `Bullet`/`BulletManager` reference each other, so creating files out of order produces misleading startup errors.

1. [ ] Create the folders from section 3: `components/combat/bullets/`, `components/combat/bullets/patterns/`, `resources/bullets/`, `resources/patterns/`.
2. [ ] Add the data/reference scripts and parse-check them: `bullet_data.gd`, `bullet_difficulty.gd`, `bullet_shot_context.gd`, `bullet_spawn.gd`, `bullet_pattern.gd`, `spread_pattern.gd`, `ring_pattern.gd`, `spiral_pattern.gd`.
3. [ ] Add `bullet.gd` and parse-check it.
4. [ ] Create `bullet.tscn` with the `Bullet` script attached and the node layout from section 10.1. Save the scene once so it has a real `.tscn` on disk.
5. [ ] Add `bullet_manager.gd` (no `class_name`).
6. [ ] **Only now** edit `project.godot`: add the `BulletManager` autoload and `2d_physics/layer_6="bullets"`. Adding the autoload earlier leaves Godot pointing at a missing script.
7. [ ] Add a `BulletLayer` Node2D with group `bullet_layer` to a test room (or the gallery in Phase 1E).
8. [ ] Create a test `BulletData` resource in `resources/bullets/` (speed `200`, lifetime `4`, radius `4`, damage `10`, team `Enemy`). Leave `scene` empty so the manager falls back to `bullet.tscn`.
9. [ ] Run the smoke test below.

Smoke test (temporary script on a `Node2D` in the test room; delete it once Phase 1E exists):

```gdscript
extends Node2D

## Temporary. The room must contain a BulletLayer (group "bullet_layer")
## and a dummy with HitboxComponent + HealthComponent.
@export var bullet_data: BulletData

func _ready() -> void:
	if bullet_data == null:
		push_warning("Assign a BulletData resource to the smoke test.")
		return

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_spawn_one)
	add_child(timer)

	_spawn_one()

func _spawn_one() -> void:
	var direction := Vector2.RIGHT.rotated(randf_range(-0.35, 0.35))
	BulletManager.spawn(bullet_data, global_position, direction, self)
	print("active=%d" % BulletManager.active_count())
```

For the dummy in this smoke test, use an actor-like root (or `dev/gallery_dummy.gd`) that declares `physics_component`; `HitboxComponent.damage()` reads `owner.physics_component` for knockback and logs an invalid-property error if the property is missing. Bullets still deal damage, but the console stays clean with the property present.

Verification for Phase 1A:

- The bullet is visible and travels in the spawn direction.
- The dummy loses health (and shows a damage number if your room wires `DamageNumbers`).
- `active_count()` drops after `lifetime` expires or the bullet leaves the screen.
- Spamming spawns does not keep growing the scene tree: released bullets stay pooled under `BulletLayer`.

### Phase 1B - Emitter, aim, telegraphs

- [ ] Add `AimSource`.
- [ ] Add `TelegraphData`, `Telegraph`.
- [ ] Add `BulletEmitterComponent` with start/stop/fire_pattern and optional telegraph phase.
- [ ] Verify: all six telegraph shapes draw in red; the telegraph follows/locks correctly; basic patterns can omit it.

### Phase 1C - Sword

- [ ] Add `MovementModifierComponent` to the dog and wire `physics_component`.
- [ ] Add `PhysicsComponent.speed_scale`, `get_effective_move_speed`, and `get_effective_dash_speed`.
- [ ] Add `attack_started` / `attack_ended` signals to `Weapon`; connect them in `dog.gd` to add/remove `&"sword_attack"`.
- [ ] Remove the sword's three combo hitbox nodes and their `RESET`/combo animation tracks (section 18.1).
- [ ] Add the sword's `BulletEmitter`, `AimSource`, and a `Muzzle` Marker2D under `AnimatedSprite2D`.
- [ ] Add method tracks in combo 1/2/3 calling `fire_pattern(index)`.
- [ ] Verify: sword fires on the animation frame; the dog slows during the combo; the sword has no movement references; no dog state is modified.

### Phase 1D - Enemy

- [ ] Add enemy `BulletEmitter`, `AimSource` (TARGET), `Muzzle`, `RangedAttackController`, `MovementModifierComponent`.
- [ ] Keep the enemy `Body/HitboxComponent` hurtbox; remove/disable the melee `AttackVFX/HitboxComponent` (section 18.3).
- [ ] Change the ranged enemy chart's `Attack` exit to `pattern_finished`; remove `animation_finished`.
- [ ] Configure `movement_lock_states` and `attack_move_multiplier` per enemy.
- [ ] For a mobile shooter, also set `stop_when_in_attack_range = false`.
- [ ] Verify: skeleton fires while moving; stationary variant stops; telegraph optional; Hurt stops the pattern.

### Phase 1E - Gallery

- [ ] Create `dev/pattern_gallery.tscn`, `pattern_gallery.gd`, and `gallery_dummy.gd`.
- [ ] Recursive pattern scan.
- [ ] Team toggle, telegraph shape override, stress test, stats.
- [ ] Verify all telegraph shapes and a 500-bullet stress run.

### Acceptance

- 300-500 pooled bullets stable.
- Sword fires from the animation method track.
- Sword has no melee combo hitboxes; bullet damage comes from `BulletData`.
- Dog moves (possibly slowed) while attacking; sword/dog state separation preserved.
- Enemy Attack state fires patterns; no Cast state.
- Optional red telegraphs for big attacks; basic attacks can omit.
- Recursive pattern gallery works.
- No bullet knockback by default.
- Parse-check all changed scripts.

---

## 16. Decisions log

| # | Decision |
|---|---|
| 1 | 300-500 active bullets; pooled `Area2D` runtime, no MultiMesh now. |
| 2 | Only the sword shoots for the player. |
| 3 | Sword bullet-cancel deferred; keep layer 6 and `cancel()`/`clear_team()` hooks. |
| 4 | Enemies may stop or move/slow while attacking; configured per enemy. |
| 5 | Telegraphs are optional per pattern; red; all shapes available; basic attacks can have none. |
| 6 | Patterns are `.tres` resources; recursive dev gallery. |
| 7 | Bullet knockback defaults to 0; rare exceptions use `BulletData.knockback`. |
| 8 | Difficulty hooks are defined but not implemented. |
| 9 | Enemy `Attack` is the bullet-firing state; no `Cast` state. |
| 10 | Sword projectiles fire from animation method tracks. |
| 11 | Movement speed reductions use a source-based `MovementModifierComponent` on the moving actor (dog/enemy); the sword only emits attack lifecycle signals. 0 = stop, 0.5 = half, 1 = normal. |
| 12 | `movement_lock_states` remains for hard stops; the modifier handles partial slows. |
| 13 | Sword is ranged-only for this pass; the old melee combo hitboxes and their animation tracks are removed. `HitboxComponent` remains for hurtboxes and for melee enemies. |

### Future work (not now)

- Sword bullet cancel upgrade / bomb clear.
- Graze area and score.
- MultiMesh/centralized bullet server for 1,000+.
- Difficulty profile and scaling.
- Lasers.
- Boss phase sequences.
- Pattern preview/editor tooling beyond the dev gallery.

---

## 17. Implementation gotchas

- **Bullet layer:** add a `BulletLayer` Node2D with group `bullet_layer` to every gameplay level and the gallery. If it is missing, `BulletManager` falls back to `current_scene`; in a test scene whose root is an actor, bullets would inherit that actor's transform.
- **Prewarm order:** if your level creates the `BulletLayer` dynamically, call `BulletManager.prewarm()` deferred or after the layer enters the tree.
- **Autoload name:** the manager script must not declare `class_name BulletManager`; the autoload singleton already owns that name.
- **Pooled collision:** use `set_deferred` for `CollisionShape2D.disabled`, `monitoring`, and `monitorable`. Release from a physics callback through `call_deferred`.
- **Reset everything:** a pooled bullet must reset static texture, animated frames, animation, scale, modulate, rotation, z-index, target, graze flag, pierce, masks, and lifetime. Do not rely on `_ready()` running again.
- **Visuals:** the easy path is `BulletData.texture` + the scene's `Sprite2D`; no `SpriteFrames` resource is needed. If both `texture` and `sprite_frames` are empty, `Bullet._draw()` paints a circle using `radius` and `visual_color`. Only animated bullets need `sprite_frames`, and it overrides `texture`.
- **One shape instance per bullet:** duplicate the `CircleShape2D` in `Bullet._ready()` before changing its radius.
- **Use one generic bullet scene** for normal bullets; add separate scenes only for special behavior (lasers, splitting bullets). Pool by scene.
- **Layer 6 / masks (bit values, not layer numbers):** `project.godot` stores decimal bitmasks. Physics layer 6 is bit value **32**, so `Bullet.collision_layer = 32`; writing `6` would put bullets on layers 2+3. In this project the enemy hurtbox sits on "entities" (bit `4`) and the player hurtbox on "player" (bit `2`), so player bullets use `1 | 4 = 5` (environment + entities) and enemy bullets use `1 | 2 = 3` (environment + player). Bullets never collide with each other. A future graze/cancel area should mask `32`.
- **Hurtbox filter:** `Bullet` only damages `HitboxComponent` areas that have a `health_component`; this ignores attack hitboxes without health and the player's non-health `Body/Area2D`.
- **Do not delete `HitboxComponent`:** it is still the hurtbox/damage interface for the Dog, enemies, and melee attacks. Only the sword's old attack hitboxes go away for a ranged-only sword.
- **Stale sword hitbox tracks:** removing the `combo N hitbox` nodes without removing their `RESET` / `combo 1` / `combo 2` / `combo 3` value tracks makes the AnimationPlayer write to freed nodes and log errors on every combo. Remove the tracks too (section 18.1).
- **Walls:** `_on_body_entered` releases only on `TileMapLayer` when `despawn_on_wall` is true. If a room uses `StaticBody2D` walls, extend the check (for example `body is TileMapLayer or body is StaticBody2D`) or bullets will pass through.
- **Aim origin:** the direction should come from the player/actor, not the muzzle. For the sword, set `Sword.aim_origin = ..` in `dog.tscn`.
- **Telegraph vs start delay:** `start_delay` is additive after the telegraph. If the warning must cover the entire windup, put that time in `TelegraphData.duration` instead.
- **Sword method tracks:** `fire_pattern()` fires exactly one shot and ignores waves/telegraph/start delay. The `patterns` array order must match the method-track arguments (`[0]`, `[1]`, `[2]`).
- **Two movement systems:** `movement_lock_states` is a hard stop and wins over the modifier. Use the modifier for partial slows; use the lock list for hurt/dead or a truly stationary attack.
- **Modifier ownership:** put `MovementModifierComponent` on the actor with the `PhysicsComponent` and hurtbox (Dog or enemy), never on a weapon. The sword emits `attack_started` / `attack_ended`; the dog adds/removes `&"sword_attack"` itself. If you find a `movement_modifier` field on `Weapon`, it is the old design and should be removed.
- **Two attack stops:** `MeleeBehaviorComponent.stop_when_in_attack_range` is a second, independent hard stop. A mobile shooter needs `movement_lock_states = [&"hurt", &"dead"]` **and** `stop_when_in_attack_range = false`.
- **Ranged Attack chart:** do not transition `Attack -> Chase` on `animation_finished` for a ranged enemy. Exit on `pattern_finished`; the cast animation is cosmetic.
- **Melee controller:** remove/disable the old `EnemyAttackController` from ranged enemies; otherwise `Attack` both fires bullets and opens melee hitboxes.
- **Pattern resources are shared:** duplicate a `.tres` when an enemy needs different tuning. Do not mutate a shared pattern at runtime except in the gallery, which duplicates before applying overrides.
- **Gallery dummies:** they need a `HitboxComponent` with a `health_component`, and their root must expose `physics_component` (see `gallery_dummy.gd`); otherwise bullets pass through or log an invalid-property error.
- **Difficulty:** all multipliers stay at `1.0` and `context.difficulty` stays null for now. Do not wire scaling behavior yet.

---

## 18. Replacing the sword's old melee hitboxes

`HitboxComponent` currently has two jobs. The name is shared; the behavior depends on which fields are set:

| Role | Fields | Used by |
|---|---|---|
| **Hurtbox** | `health_component` set, `can_deal_damage = false` | Player `Dog/Body`, enemy `Body` |
| **Attack hitbox** | `can_deal_damage = true`, no health | Sword `combo N hitbox`, enemy `AttackVFX` |

Bullets do **not** use an attack hitbox. `Bullet` is its own `Area2D` with a `CircleShape2D`; on `area_entered` it looks for a `HitboxComponent` **with a `health_component`** and calls `area.damage(attack)`. So:

- Keep `HitboxComponent` and `hitbox_component.tscn`. It is still the hurtbox/damage interface.
- Keep the player and enemy hurtboxes.
- The sword does not need its own attack hitboxes for ranged attacks.

### 18.1 Ranged-only sword: remove the melee hitboxes

If the sword only fires bullets (the current plan):

1. In `actors/player/sword.tscn`, delete these nodes and their `CollisionShape2D` children:
   - `AnimatedSprite2D/combo 1 hitbox` + `combo 1 hitbox shape`
   - `AnimatedSprite2D/combo 2 hitbox` + `combo 2 hitbox shape`
   - `AnimatedSprite2D/combo 3 hitbox` + `combo 3 hitbox shape`
2. In the Animation panel, delete **every** value track whose path contains `combo N hitbox`. In the current file they are in:
   - `RESET`
   - `combo 1`
   - `combo 2`
   - `combo 3`
   Check `combo 1 end`, `combo 2 end`, and `idle entered` as well; they currently have none, but verify after editing. If stale tracks remain, the AnimationPlayer tries to write to freed nodes and logs errors every combo.
3. Keep every other track: sprite frames, visibility, `can_input_attack`, `sfx_player`, offsets, rotations, and the new `BulletEmitter.fire_pattern` method tracks.
4. Move the combo damage tuning from the old hitboxes to `BulletData`:

   | Old sword hitbox field | Bullet equivalent |
   |---|---|
   | `attack_damage` | `BulletData.damage` |
   | `knockback` | `BulletData.knockback` (default `0`) |
   | `knockback_owner_upon_hit` | no direct equivalent; the player no longer gets pushed by their own hit |
   | `frame_freeze` / `camera_shake` | not in the base bullet; add a hit-effect hook later |

5. Do not remove the sword's `Muzzle` marker, `Weapon`, or `SwordStateMachine` nodes.

### 18.2 Hybrid sword (optional)

If the sword should keep melee damage:

- Keep the hitboxes and their animation tracks.
- Add the emitter and method tracks on top.
- Decide whether one swing can hit the same target twice (melee hitbox + bullet). The base system does not arbitrate this. A simple rule is to use melee at close range and fire bullets only at range, or to give each target a per-swing hit cooldown.

### 18.3 Enemy cleanup for ranged enemies

For each enemy converted to ranged:

- Keep `Body/HitboxComponent`; bullets need it as the hurtbox.
- Remove `EnemyAttackController` (section 10.7).
- Remove or disable the melee `AttackVFX/HitboxComponent`:
  - delete `AttackVFX/HitboxComponent` and its shape, or
  - leave it but set `can_deal_damage = false` and keep the shape disabled.
- Remove/disable the animation tracks that enable the attack hitbox shape.
- Keep `AttackVFX` only if you reuse it as a cast visual; otherwise it is safe to delete with the hitbox.
- Keep `AttackRange` only if the enemy's ready/movement logic still uses it. The ranged controller uses `DetectionArea` and the pattern range instead.

### 18.4 The bullet's hit path

```text
Bullet (Area2D, layer 32, mask 5 or 3)
  -> area_entered
  -> area is HitboxComponent and area.health_component
  -> area.damage(Attack)
  -> HealthComponent / dash i-frames / damage numbers
```

There is no `HitboxComponent` on the bullet. Radius, damage, lifetime, and knockback come from `BulletData`, not from the old sword hitbox exports.

### 18.5 Naming

`HitboxComponent` means both "hurtbox" and "attack hitbox" in this project. Renaming it is out of scope; do not rename it during the bullet work because scenes and scripts reference it. Add a comment in `hitbox_component.gd` if the dual role is confusing.



