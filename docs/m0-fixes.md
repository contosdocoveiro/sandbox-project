# M0 — Proposed Fixes (review-only)

Companion to [`refactor-plan.md`](refactor-plan.md) and [`ecs-architecture-review.md`](ecs-architecture-review.md).

**Status:** proposal only. Nothing in this document has been applied. Apply in the order below, one commit per section, and run the smoke check after each.

**Rule:** these are bug fixes/refactors. New behavior logic stays with you.

---

## Apply order

| # | Fix | Files | Risk |
|---|---|---|---|
| 1 | Navigation arrays + null guard (P0-1) | `components/navigation/navigation_component.gd` | Low |
| 2 | Spear charge duration (P0-2/P0-10) | `components/behavior/enemy_behavior_component.gd`, `actors/enemies/spear_skeleton_regular.tscn` | Low |
| 3 | Remove stale wall signal (P0-3) | `actors/enemies/spear_skeleton_regular.tscn` | Low |
| 4 | Health visual target (P0-4) | `components/combat/health_component.gd`, optionally scenes | Low |
| 5 | Enemy animation guard (P0-6) | `components/animation/enemy/enemy_animation_component.gd` | Low |
| 6 | Sword combo finish checks (P0-7) | `actors/player/sword_state_machine.gd` | Low |
| 7 | Hitbox shape cache + deferred toggles (P0-8) | `components/combat/hitbox_component.gd`, `components/behavior/enemy_behavior_component.gd` | Low/medium |
| 8 | Defensive hitbox guards (P0-9 support) | `components/combat/hitbox_component.gd` | Low |
| 9 | Scene validation tool | new `tests/scene_validation.*` | Low |
| 10 | Dead scripts/autoload/temp files | `project.godot`, git files | Low |
| 11 | Debug overlay (optional) | new dev scene/script | Low |

Deferred to later milestones: hitbox/hurtbox split (M2), death events (M2), input intent (M3), state/animation authority (M4), animation-track gameplay (M4), player/sword state unification (M4).

---

## 1. P0-1 — Initialize `NavigationComponent`

**File:** `components/navigation/navigation_component.gd`

### Current

```gdscript
var num_rays = 8
var ray_directions = []
var interest = []
var danger = []
@export var actor : CharacterBody2D
@onready var raycasts = get_node("ContextMap").get_children()

@onready var navigation_agent = $NavigationAgent2D
var target = null
var chosen_dir = Vector2.ZERO
var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO

func get_direction() -> Vector2:
	if(is_instance_valid(target)):
		navigation_agent.target_position = target.global_position
	if(actor.detection_area):
		target = actor.detection_area._player_ref
	set_interest()
	set_danger()
	choose_direction()
	return chosen_dir.rotated(rotation)
```

### Proposed

Add `_ready()` and a guard:

```gdscript
func _ready() -> void:
	num_rays = raycasts.size()
	ray_directions.resize(num_rays)
	interest.resize(num_rays)
	danger.resize(num_rays)

	for i in num_rays:
		var ray := raycasts[i] as RayCast2D
		if ray == null:
			ray_directions[i] = Vector2.ZERO
			interest[i] = 0.0
			danger[i] = 0.0
			continue
		# Ray local direction. set_interest() applies the component's rotation.
		ray_directions[i] = ray.target_position.normalized().rotated(ray.rotation)
		interest[i] = 0.0
		danger[i] = 0.0


func get_direction() -> Vector2:
	if actor == null or navigation_agent == null or raycasts.is_empty():
		return chosen_dir

	# Update the target before asking the agent for a path position.
	if actor.detection_area:
		target = actor.detection_area._player_ref
	if is_instance_valid(target):
		navigation_agent.target_position = target.global_position

	set_interest()
	set_danger()
	choose_direction()
	return chosen_dir.rotated(rotation)
```

**Why:** `ray_directions`, `interest`, and `danger` are indexed `0..num_rays-1` but are empty. The first enemy navigation tick throws an index error. Deriving the directions from the actual `ContextMap` rays also keeps the code and scene from drifting if a ray angle changes.

**Verify:** run an enemy scene; no `Index p_index ... out of bounds`; enemy steers toward the player.

**Note:** `actor.detection_area` and `_player_ref` are still actor-specific; M1/M5 will replace them with a target signal. Do not expand this dependency now.

---

## 2. P0-2 / P0-10 — Spear charge duration

**Files:** `components/behavior/enemy_behavior_component.gd`, `actors/enemies/spear_skeleton_regular.tscn`

### Current behavior

`charge()` calls `input_component.start_dash()` without setting `physics_component.dash_duration`; the spear scene value is `1000.0`, so the dash timer runs for ~16 minutes.

### Proposed

Add a named export to `EnemyBehaviorComponent`:

```gdscript
@export var stop_when_in_attack_range := true
@export var charge_duration := 1.0
```

Set it explicitly before starting the dash:

```gdscript
func charge():
	if actor.navigation_component:
		if actor.navigation_component.target:
			var target = actor.navigation_component.target
			attack_vfx.rotation = global_position.direction_to(target.global_position).angle()
			attack_vfx.visible = true
			attack_vfx.play("attack")
			# Section 7 replaces this direct toggle with _set_hitbox_active().
			charge_hitbox.collision_shape.disabled = false

	physics_component.dash_duration = charge_duration
	input_component.start_dash()
```

And change the spear scene value:

```diff
- dash_duration = 1000.0
+ dash_duration = 1.0
```

Choose the intended gameplay value; `1.0` is only a safe placeholder. In M4 this becomes `AbilityData.dash_duration`.

**Verify:** spear charge moves for ~1 second, not minutes; `DashComponent/DurationTimer` stops; wall collision ends the charge.

---

## 3. P0-3 — Remove the stale wall signal

**File:** `actors/enemies/spear_skeleton_regular.tscn`

### Current connection

```text
[connection signal="collided_with_wall" from="AttackVFX/HitboxComponent" to="." method="_on_hitbox_component_collided_with_wall"]
```

There is no `_on_hitbox_component_collided_with_wall` method. The real connection is made in code:

```gdscript
func _ready() -> void:
	if(charge_hitbox):
		charge_hitbox.collided_with_wall.connect(_on_wall_collision)
```

### Proposed

Delete the `[connection ...]` line from the spear scene. Optionally make the code connection idempotent:

```gdscript
func _ready() -> void:
	if charge_hitbox and not charge_hitbox.collided_with_wall.is_connected(_on_wall_collision):
		charge_hitbox.collided_with_wall.connect(_on_wall_collision)
```

**Why:** one stale connection would log a missing-method error on wall hit; keeping one code connection avoids double callbacks.

**Verify:** charge into a wall; `_on_wall_collision` runs once; no missing-method error.

---

## 4. P0-4 — Stop `HealthComponent` assuming a `Body` child

**File:** `components/combat/health_component.gd`

### Current

```gdscript
func _ready():
	health = MAX_HEALTH
	tween = create_tween().set_loops()
	tween.pause()
	tween.tween_property(owner.find_child("Body"), "modulate", Color.WHITE, 0.1)
	tween.tween_property(owner.find_child("Body"), "modulate", Color.RED, 0.1)
```

`TestDummy` has `Sprite2D`, not `Body`, so the tween target is `null`. This also makes the component unusable on props/other entity types.

### Proposed

Add an optional visual target and use it everywhere:

```gdscript
@export var body_path: NodePath

var body: CanvasItem

func _ready():
	health = MAX_HEALTH

	if not body_path.is_empty():
		body = get_node_or_null(body_path) as CanvasItem
	if body == null and owner:
		body = owner.find_child("Body", true, false) as CanvasItem
	if body == null:
		push_warning("%s: no visual body; damage flash disabled." % get_path())
		return

	tween = create_tween().set_loops()
	tween.pause()
	tween.tween_property(body, "modulate", Color.WHITE, 0.1)
	tween.tween_property(body, "modulate", Color.RED, 0.1)
```

Replace the remaining `owner.find_child("Body")` calls:

```gdscript
func invulnerability_start():
	if body:
		body.set_material(null)
	invincible = true
	invincibility_timer.wait_time = 1.0
	invincibility_timer.start()


func play_player_damage_effect():
	if tween and tween.is_valid():
		tween.play()


func _on_invincibility_time_timeout() -> void:
	if tween:
		tween.kill()
		tween = null

	if body:
		tween = create_tween().set_loops()
		tween.stop()
		tween.tween_property(body, "modulate", Color.WHITE, 0.1)
		tween.tween_property(body, "modulate", Color.RED, 0.1)
		body.set_material(outline_shader_material)

	invincible = false
```

### Scene wiring

- In `actors/test_dummy.tscn`, set `HealthComponent.body_path = NodePath("../Sprite2D")` (inspector or `.tscn`).
- Dog and enemy scenes can keep the fallback, or set `body_path = NodePath("../Body")` explicitly.
- `TestDummy` is not in the `"player"` group, so its flash tween is never played; the important fix is that `_ready()` no longer builds a tween against `null`.

**Deferred to M2:** remove `owner.is_in_group("player")`, the damage-number call, and `get_parent().queue_free()` from health. This patch only makes the visual target safe.

**Verify:** load `actors/test_dummy.tscn`; no null-tween error; player damage flash still works; health/damage numbers unchanged.

---

## 5. P0-6 — Fix the enemy animation guard

**File:** `components/animation/enemy/enemy_animation_component.gd`

### Current

```gdscript
func _process(delta: float) -> void:
	if(state_manager.current_state != "charge end" or
	state_manager.current_state != "hurt"):
		if actor.velocity.x < -20 and not actor.sprite.flip_h:
			sprite.flip_h = true
		elif actor.velocity.x > 20 and actor.sprite.flip_h:
			sprite.flip_h = false
```

`state != A or state != B` is always true.

### Proposed

```gdscript
func _process(_delta: float) -> void:
	if state_manager == null or sprite == null:
		return
	if state_manager.current_state != "charge end" and state_manager.current_state != "hurt":
		if actor.velocity.x < -20 and not sprite.flip_h:
			sprite.flip_h = true
		elif actor.velocity.x > 20 and sprite.flip_h:
			sprite.flip_h = false
```

Use `sprite` consistently instead of checking `actor.sprite` and writing `sprite`; M1 removes `actor.sprite` entirely.

**Verify:** sprite does not flip while hurt/charge-end; flips normally while running.

---

## 6. P0-7 — Fix sword combo finish checks

**File:** `actors/player/sword_state_machine.gd`

### Current

```gdscript
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if(anim_name == "combo 1" or "combo 2"):
		if(anim_name == "combo 1"):
			_animation_player.play("combo 1 end")
		elif(anim_name == "combo 2"):
			_animation_player.play("combo 2 end")
	if(anim_name == "idle entered"):
		_animation_player.play("RESET")

	if(anim_name == "combo 1 end" or "combo 2 end" or "combo 3"):
		if(!_animation_player.is_playing()):
			_state_chart.send_event("combo_finished")
```

### Proposed

```gdscript
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		&"combo 1":
			_animation_player.play("combo 1 end")
		&"combo 2":
			_animation_player.play("combo 2 end")
		&"idle entered":
			_animation_player.play("RESET")

	if anim_name == &"combo 1 end" or anim_name == &"combo 2 end" or anim_name == &"combo 3":
		if not _animation_player.is_playing():
			_state_chart.send_event("combo_finished")
```

**Why:** a non-empty string literal is truthy, so the old conditions fire for every animation. This is why combo transitions feel unreliable.

**Deferred to M4:** the whole combo ownership should move out of the sword's own state machine into the player ability/state layer. This patch only makes the current behavior correct.

**Verify:** combo 1 → combo 2 → combo 3; finish returns to idle; idle/RESET animation does not send `combo_finished`.

---

## 7. P0-8 — Cache hitbox shapes safely and defer toggles

### 7a. `components/combat/hitbox_component.gd` — shape cache

**Current**

```gdscript
var collision_shape : CollisionShape2D

func _ready() -> void:
	collision_shape = get_child(0)
```

**Proposed**

```gdscript
@export var collision_shape: CollisionShape2D

func _ready() -> void:
	if collision_shape == null:
		for child in get_children():
			if child is CollisionShape2D:
				collision_shape = child as CollisionShape2D
				break

	if collision_shape == null:
		push_error("%s: HitboxComponent requires a CollisionShape2D child." % get_path())
```

This supports all current hitbox shapes (`CollisionShape2D`, `combo 1 hitbox shape`, `AttackShape`) without relying on child index.

### 7b. `components/behavior/enemy_behavior_component.gd` — deferred toggles

Add a helper:

```gdscript
func _set_hitbox_active(hitbox: HitboxComponent, active: bool) -> void:
	if hitbox == null:
		push_warning("%s: attack is missing a hitbox reference." % get_path())
		return
	if hitbox.collision_shape == null:
		push_warning("%s: hitbox has no collision shape." % hitbox.get_path())
		return
	hitbox.collision_shape.set_deferred("disabled", not active)
```

Use it in `dash_attack`:

```gdscript
			attack_vfx.rotation = global_position.direction_to(target.global_position).angle()
			attack_vfx.visible = true
			attack_vfx.play("attack")
			_set_hitbox_active(attack_hitbox, true)
			timer.wait_time = duration
			timer.start()
			await timer.timeout
			attack_vfx.visible = false
			attack_vfx.stop()
			_set_hitbox_active(attack_hitbox, false)
```

Use it in `charge`:

```gdscript
			attack_vfx.play("attack")
			_set_hitbox_active(charge_hitbox, true)
```

Use it in `_on_wall_collision`:

```gdscript
func _on_wall_collision(body):
	physics_component.can_be_knocked_back = true
	if attack_vfx:
		attack_vfx.visible = false
	_set_hitbox_active(charge_hitbox, false)
	physics_component.end_dash()
	state_manager.state_chart.send_event("charge end")
	physics_component.calculate_knockback(body.global_position, 40)
```

**Why:** changing `CollisionShape2D.disabled` during the physics flush can produce warnings/errors and makes the active window order-dependent. `set_deferred` applies the change at a safe point.

**Note:** `_on_wall_collision` still reaches `state_manager.state_chart`; M1/M2 will replace this with a state/ability API. Do not expand it now.

**Verify:** attack hitboxes enable/disable at the same moments; no physics-flush warnings; wall charge ends.

---

## 8. Defensive hitbox guards (optional M0, required before M2)

**File:** `components/combat/hitbox_component.gd`

These guards prevent `owner.owner`/`area.owner.health_component`/camera assumptions from throwing on unusual hierarchies. M2 replaces this code with a combat resolver; this is a safety net, not the final design.

### `damage()`

```gdscript
func damage(attack: Attack):
	if dash_component and dash_component.is_dashing():
		return
	if health_component == null:
		return

	health_component.damage(attack)

	if health_component.invincible:
		return

	var physics: PhysicsComponent = null
	if owner:
		physics = owner.get("physics_component") as PhysicsComponent
	if physics:
		physics.calculate_knockback(attack.attack_position, attack.knockback_force)
```

### `_on_area_entered()`

```gdscript
func _on_area_entered(area: Area2D) -> void:
	if not can_deal_damage or not (area is HitboxComponent):
		return

	var target_owner := area.owner
	var target_health: HealthComponent = null
	if target_owner:
		target_health = target_owner.get("health_component") as HealthComponent

	if frame_freeze and target_health and not target_health.invincible:
		FrameFreeze.freeze_frame(frame_freeze_time_scale, frame_freeze_duration)

	var attack := Attack.new()
	attack.attack_damage = attack_damage
	attack.attack_position = global_position
	attack.knockback_force = knockback
	attack.stun_time = stun
	area.damage(attack)

	if knockback_owner_upon_hit:
		var attacker = owner.owner if owner else null
		if attacker and attacker.is_in_group("player"):
			var attacker_physics: PhysicsComponent = attacker.get("physics_component") as PhysicsComponent
			if attacker_physics:
				attacker_physics.calculate_knockback(global_position, knockback_owner_amount)

	if camera_shake:
		var camera := get_viewport().get_camera_2d()
		if camera and camera.has_method("shake_camera"):
			camera.shake_camera()
```

**Why:** `owner`, `owner.owner`, `area.owner`, `health_component`, and the current camera are not guaranteed by the node contract. These guards make the current design fail soft until M2.

**Verify:** player sword still damages enemies; enemy attacks still damage the player/dummy; no null-property errors in the log.

---

## 9. Scene validation tool

**Goal:** catch missing nodes/exports before playtesting. Start with a dev scene, then move it into CI in M7.

Suggested files:

```text
tests/scene_validation.tscn   # Node with the script
tests/scene_validation.gd
```

Skeleton:

```gdscript
extends Node

# scene path -> [node name, exported property] checks
const REQUIRED := {
	"res://actors/player/dog.tscn": [
		[".", "state_manager"],
		[".", "physics_component"],
		[".", "input_component"],
		[".", "health_component"],
		["PhysicsComponent", "actor"],
		["PhysicsComponent", "dash_component"],
		["PhysicsComponent", "input_component"],
	],
	"res://actors/enemies/sword_skeleton_regular.tscn": [
		["EnemyBehaviorComponent", "actor"],
		["EnemyBehaviorComponent", "physics_component"],
		["EnemyBehaviorComponent", "state_manager"],
		["EnemyBehaviorComponent", "input_component"],
		["EnemyBehaviorComponent", "attack_hitbox"],
		["EnemyBehaviorComponent", "attack_range"],
		["EnemyBehaviorComponent", "attack_vfx"],
	],
	"res://actors/enemies/spear_skeleton_regular.tscn": [
		["EnemyBehaviorComponent", "charge_hitbox"],
		["EnemyBehaviorComponent", "attack_range"],
		["EnemyBehaviorComponent", "attack_vfx"],
	],
	"res://actors/test_dummy.tscn": [
		["HealthComponent", "damage_numbers_component"],
		[".", "detection_area"],
	],
}

func _ready() -> void:
	var failures := 0
	for scene_path in REQUIRED:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_error("Cannot load %s" % scene_path)
			failures += 1
			continue

		var entity := packed.instantiate()
		add_child(entity)
		for check in REQUIRED[scene_path]:
			var node_name: String = check[0]
			var property: String = check[1]
			var node: Node = entity if node_name == "." else entity.find_child(node_name, true, false)
			if node == null:
				push_error("%s: missing node '%s'" % [scene_path, node_name])
				failures += 1
				continue
			if node.get(property) == null:
				push_error("%s: %s.%s is null" % [scene_path, node_name, property])
				failures += 1
		entity.queue_free()

	print("Scene validation failures: %d" % failures)
	get_tree().quit(failures)
```

Run headless (use your Godot 4.7 binary; on this machine the check-gd script resolves the Steam install):

```powershell
$godot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godot --headless --path D:\Godot\teste res://tests/scene_validation.tscn
```

**Why:** P0-3, P0-4, and P0-9 are all "the scene says one thing, the code assumes another" bugs. This tool turns them into a failed check instead of a mid-fight null error. In M1, add component `_validate()` methods and let the tool call those instead of this hand-maintained list.

**Note:** instantiating scenes in `_ready` may run their `_ready` code and print unrelated warnings. That is fine for a dev check; in M7 run it in an isolated headless test.

---

## 10. Dead code, autoload, and temp files

### 10a. Dead scripts (confirmed unreferenced by scenes/scripts)

```powershell
git rm `
  archive/legacy/chaserEnemy.gd archive/legacy/chaserEnemy.gd.uid `
  archive/legacy/SkeletonStateMachine.gd archive/legacy/SkeletonStateMachine.gd.uid `
  archive/legacy/spear_skeleton_state_machine.gd archive/legacy/spear_skeleton_state_machine.gd.uid `
  archive/legacy/dog_state_machine.gd archive/legacy/dog_state_machine.gd.uid `
  archive/legacy/room_area_component.gd archive/legacy/room_area_component.gd.uid
```

Keep:
- `world/room_area.gd` — used by `world/rooms/testRoom.tscn` (currently a placeholder).
- `dev/jogo.tscn`, `dev/pathfinding test.tscn`, `dev/coco.tscn`, `dev/new room test.tscn` — dev scenes; decide whether to keep, but do not delete as part of this pass.

### 10b. `PlayerStats` autoload (already removed)

The autoload was removed from `project.godot` and the script was moved to `archive/legacy/playerstats.gd` during the reorganization. If you do not intend to restore it, delete the archived pair:

```powershell
git rm archive/legacy/playerstats.gd archive/legacy/playerstats.gd.uid
```

### 10c. Remove dead API values

Safe now:

- `InputComponent.get_move_input()` — no callers.
- `AnimationComponent.can_transition` — unused (the player state manager has its own flag).

Leave until M2/M4:

- `Attack.stun_time` — set by `HitboxComponent`, never read; M2 decides whether it becomes `AttackData.stun`.
- `NavigationComponent.look_ahead` — exported and set in scenes but unused; remove when the navigation component is rewritten in M5.
- `NavigationComponent.velocity` / `acceleration` — unused; remove in M5.

### 10d. Temp files

There are 33 tracked `.tmp` files now under `archive/tmp/` (they were previously spread across `assets/`, `scenes/`, and the project root). `archive/.gdignore` keeps Godot from scanning them. Review them, then remove in one commit:

```powershell
git rm archive/tmp/*.tmp
```

Do not delete them if any are intentional backups you still want; they are not referenced by scenes or scripts.

**Verify:** `git grep` for each deleted script name returns nothing; project loads; main scene still runs.

---

## 11. Optional — debug overlay

A minimal dev overlay pays for itself immediately. Suggested shape:

```text
CanvasLayer
└─ PanelContainer
   └─ Label
```

Script behavior:

- `_process`: find the player via `get_tree().get_first_node_in_group("player")`.
- Read `health_component.health`, `state_manager.current_state`, `physics_component.last_faced_direction`, `dash_component.is_dashing()`, `actor.velocity`, current animation name.
- Show `state`, `velocity`, `dash`, `hp`, `target` (for enemies).
- Toggle with a debug key (e.g., F3) and keep it out of release builds (`OS.is_debug_build()`).

This is dev tooling, not gameplay. Keep it in `tests/` or `dev/`, not in `scenes/`.

---

## 12. Smoke test matrix for M0

| Test | Expected |
|---|---|
| Load `world/rooms/testRoom.tscn` | No script errors; player moves/dashes/attacks |
| Load `actors/test_dummy.tscn` | No `HealthComponent` null-tween error |
| Sword skeleton scene | Navigation runs; no index error; no missing-method error |
| Spear skeleton scene | Charge dash ends in ~1s; wall collision ends charge once |
| Player combo 1→2→3 | Combo ends cleanly; idle does not send `combo_finished` |
| Hurt enemy during charge end | Sprite does not flip unexpectedly |
| Player takes a hit | Damage flash, damage number, invincibility still work |
| Attack hitboxes | Enable/disable at the intended times; no physics-flush warnings |
| Scene validator | Zero missing/null required references |

---

## What not to do in M0

- Do not split hitbox/hurtbox yet; that is M2.
- Do not remove `owner.is_in_group("player")` from health yet; that is M2.
- Do not move the sword attack into the player ability system yet; that is M4.
- Do not remove animation method/value tracks yet; that is M4.
- Do not move files/folders for organization; do that after the contracts are stable.
- Do not delete `.tmp` files until you have confirmed they are not wanted.

---

*End of M0 proposals. Apply one section per commit; update the checklist in `refactor-plan.md` as each lands.*
