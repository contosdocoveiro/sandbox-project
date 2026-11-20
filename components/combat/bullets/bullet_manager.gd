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
