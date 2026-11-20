class_name BulletData
extends Resource

enum Team { PLAYER, ENEMY }

# generic bullet scene
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
@export var sprite_frames: SpriteFrames
@export var animation := &"default"
@export var texture: Texture2D
@export var visual_color := Color.WHITE
@export var modulate := Color.WHITE
@export var visual_scale := Vector2.ONE
@export var z_index := 0

@export_group("Pool")
@export var prewarm := 32

@export var custom_data: Dictionary = {}
