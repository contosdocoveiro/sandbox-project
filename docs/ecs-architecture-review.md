# ECS Architecture Review — `teste` (Godot 4.7)

**Date:** 2026-11-12
**Scope:** Gameplay code under `actors/`, `components/`, `services/`, `world/`, `dev/`, and the entity scenes (`actors/player/dog.tscn`, `actors/player/sword.tscn`, `actors/enemies/sword_skeleton_regular.tscn`, `actors/enemies/spear_skeleton_regular.tscn`, `actors/test_dummy.tscn`, `world/rooms/testRoom.tscn`, `dev/jogo.tscn`). `addons/`, `archive/`, and `godot_state_charts_examples/` are excluded. See `docs/file-organization.md` for the current layout.

**Method:** read-only static review of every gameplay `.gd` file plus the scene wiring. No game code or scenes were changed.

**Branch context:** the review started at `ca75dd8` (`chore/fennara-mcp`). The current `chore/m0-refactor` branch also contains the file-organization move documented in `docs/file-organization.md`. The older `chore/refactor` branch contains an earlier ECS attempt plus unit tests and a few useful fixes (navigation initialization, health event split). `backup/chore-refactor-wip` contains a WIP backup. Treat those branches as reference material, not as a target to merge wholesale.

> **Line numbers** are from `ca75dd8`. If they drift, search for the quoted code/symbol instead.

---

## TL;DR

You have the **composition half** of ECS:

- an entity is a scene root;
- behavior is split into named component nodes;
- `Attack` is already a small plain-data class;
- input and animation already have polymorphic base classes.

You do **not** have the **systems/independence half**:

- components call each other directly and reach through `owner`, `get_parent()`, `find_child()`, and actor-specific fields;
- the actor root scripts are the real "systems";
- gameplay timing is spread across `_physics_process`, StateChart signals, `AnimationPlayer` method/value tracks, `Timer`s, and `await`;
- there is no entity registry, no query model, and no explicit frame order.

That is why the result feels ECS-like but still tightly coupled. The problem is not that you chose component nodes. The problem is that the components are not independent and there is no system layer.

**Recommendation:** do **not** rewrite into a pure data-oriented ECS. The project is small (~1,100 lines of gameplay script). Use an **ECS-lite** model:

1. one entity root with a single wiring/registry point;
2. ordered systems/phases: input → AI → state/ability → movement → combat → presentation → cleanup;
3. combat through hit/hurt events, not `owner` chains;
4. gameplay timing in code/data, not in `AnimationPlayer` tracks;
5. stats/attacks/archetypes as `Resource` data;
6. new archetypes by composition, not by copying root scripts.

Start with the P0 correctness fixes, then contracts, then the combat/input/state seams, then archetypes, then the system scheduler.

---

## 1. Is this ECS?

| ECS concept | What the project currently does | Gap |
|---|---|---|
| **Entity** | The scene root: `Dog`, `SwordSkeletonRegular`, `SpearSkeletonRegular`, `TestDummy` | No identity beyond the node; no registry; every system must know the concrete root type |
| **Component** | Child nodes: `PhysicsComponent`, `HealthComponent`, `HitboxComponent`, `EnemyBehaviorComponent`, ... | Components contain behavior *and* state; they are not data-only |
| **System** | Methods on actor roots (`actors/player/dog.gd::_physics_process`, `SwordSkeleton::_physics_process`, `EnemyBehaviorComponent.dash_attacker_behavior`) plus StateChart signals | No global system layer; each actor orchestrates itself |
| **Query** | `@export` node paths, `find_child()`, `get_parent()`, `owner` | No registry/groups/tags; dependencies are hidden in the scene tree |
| **Schedule** | Godot tree order + StateChart signal order + `AnimationPlayer` tracks + timers/awaits | No explicit phase order; no determinism |

**Classification:** this is a **component-based OOP actor architecture**, not ECS. That is a legitimate Godot architecture — many successful Godot games use it — but it produces exactly the coupling you are seeing unless the component contract and the system layer are made explicit.

### What already works well (keep it)

- Composition is visible in the scenes and components are small and named by role.
- `InputComponent` + `PlayerInputComponent` / `EnemyInputComponent` is a good polymorphic seam.
- `AnimationComponent.animate()` is a usable view seam.
- `Attack` is a plain data class — expand this idea into `AttackData`/`HitEvent`.
- Physics layers are already named in `project.godot:90-100` (`environment`, `player`, `entities`, `hitboxes`, `detection_areas`). That is the foundation for team filtering.
- `godot_state_charts` gives declarative states. Keep it; the problem is who owns transitions and timing, not the addon.
- The codebase is small enough that a staged refactor is realistic.

---

## 2. Current runtime map

### 2.1 Player frame

`Dog._physics_process` (`actors/player/dog.gd:30-38`) does:

```text
input_component.handle_inputs()
velocity = physics_component.calculate_velocity()
if state_manager.current_state == "attacking" and !can_move_during_attack:
    velocity = Vector2.ZERO
physics_component.apply_knockback()
physics_component.move()
```

At the same time:

- `PlayerStateManagerComponent` drives a StateChart (`components/state/player/player_state_manager_component.gd`). On state entry it calls `animation_component.animate()`; during state physics processing it reads `actor.velocity`.
- `PlayerAnimationComponent` reads `state_manager.current_state`, `input_component.input_direction`/`move_input_key`, and the mouse position (`components/animation/player/player_animation_component.gd:9-18, 40-54`).
- `Sword` runs its own `_physics_process` (`actors/player/weapon_behavior.gd:25-29`), moves the weapon toward the mouse, and reads `owner._last_faced_direction` (`:36, :55-56`).
- `SwordStateMachine` runs its own `_physics_process` (`actors/player/sword_state_machine.gd:24-31`), polls `Input` directly, and calls `_sword.owner.send_attack_signal()` (`:36, :66, :88`).
- `Sword`'s `AnimationPlayer` value tracks mutate `SwordStateMachine.can_input_attack`, `/root.combo_finished`, and hitbox `disabled`; method tracks run SFX.

So one player frame is influenced by **six clocks**: Dog physics, the player StateChart, the sword StateChart, weapon physics, sword `AnimationPlayer` tracks, and timers/awaits.

### 2.2 Enemy frame

`SwordSkeleton._physics_process` / `SpearSkeleton._physics_process` (`actors/enemies/sword_skeleton_regular.gd:17-18`, `actors/enemies/spear_skeleton_regular.gd:18-19`) call one behavior method:

- `EnemyBehaviorComponent.dash_attacker_behavior()` (`components/behavior/enemy_behavior_component.gd:20-36`), or
- `EnemyBehaviorComponent.charger_behavior()` (`:60-78`).

That method:

```text
input_component.handle_inputs()          # NavigationComponent.get_direction()
velocity = physics_component.calculate_velocity()
if in attack range and state == "running": stop / request attack
if state == "attacking" / cooldown timer running: velocity = 0
physics_component.apply_knockback()
physics_component.move()
```

At the same time:

- `EnemyStateManagerComponent` drives the enemy StateChart and owns `Timer`/`StunTimer` (`components/state/enemy/enemy_state_manager_component.gd:4-5, 15-23, 70-95`).
- `EnemyAnimationComponent._process` reads `current_state` and `actor.velocity` and flips the sprite (`components/animation/enemy/enemy_animation_component.gd:23-29`).
- Enemy `AnimationPlayer` method tracks call `EnemyBehaviorComponent.dash_attack(0.375)` or `charge()`; value tracks control hitbox `disabled`.
- `HealthComponent.damage_taken` is connected to both `PhysicsComponent` (knockback) and `EnemyStateManagerComponent` (hurt state).
- `HitboxComponent` can call `FrameFreeze`, camera shake, and `owner.owner.physics_component` (`components/combat/hitbox_component.gd:38-65`).

### 2.3 Damage event path (current)

```text
Area2D area_entered
└─ HitboxComponent._on_area_entered()
   ├─ if frame_freeze: area.owner.health_component.invincible check → FrameFreeze.freeze_frame()
   ├─ Attack.new(); fill damage/position/knockback/stun
   ├─ area.damage(attack)
   │  └─ HitboxComponent.damage()
   │     ├─ if dash_component.is_dashing(): return
   │     ├─ health_component.damage(attack)
   │     │  ├─ health -= damage
   │     │  ├─ emit damage_taken
   │     │  │  ├─ PhysicsComponent.process_attack_knockback()  (player/enemy)
   │     │  │  └─ EnemyStateManagerComponent._on_damage_taken() (enemy)
   │     │  ├─ if owner group "player": invincibility + visual flash
   │     │  ├─ damage_numbers_component.display_damage_numbers()
   │     │  └─ if health <= 0: get_parent().queue_free()
   │     └─ if owner.physics_component: calculate_knockback() again
   ├─ if knockback_owner_upon_hit and owner.owner group "player": knockback attacker
   └─ if camera_shake: get_viewport().get_camera_2d().shake_camera()
```

The diagram is the coupling in one picture: the hitbox knows about health, physics, dash, the player group, the viewport camera, and the global `FrameFreeze` service.

### 2.4 Clock inventory

| Clock | Where | What it drives |
|---|---|---|
| `Dog._physics_process` | `actors/player/dog.gd:30` | Input, velocity, state gate, knockback, movement |
| `Dog._process` | `actors/player/dog.gd:40` | Copies `last_faced_direction` for the weapon |
| `SwordSkeleton._physics_process` | `actors/enemies/sword_skeleton_regular.gd:17` | Whole enemy behavior chain |
| `SpearSkeleton._physics_process` | `actors/enemies/spear_skeleton_regular.gd:18` | Whole enemy behavior chain |
| `Weapon._physics_process` | `actors/player/weapon_behavior.gd:25` | Weapon position + idle bob |
| `SwordStateMachine._physics_process` | `actors/player/sword_state_machine.gd:24` | Input polling, state events, combo buffer |
| `EnemyAnimationComponent._process` | `components/animation/enemy/enemy_animation_component.gd:23` | Sprite flip |
| `Camera._process` | `components/presentation/camera_script.gd:16` | Shake, only while active |
| `TestDummy._physics_process` | `actors/test_dummy.gd:7` | `move_and_slide()` only |
| StateChart `state_physics_processing` | Player/enemy state manager scenes | State-specific per-physics checks |
| `AnimationPlayer` value/method tracks | `actors/player/sword.tscn`, `actors/enemies/sword_skeleton_regular.tscn`, `actors/enemies/spear_skeleton_regular.tscn` | Hitbox enable/disable, input windows, behavior invocation, SFX |
| `Timer` / `SceneTreeTimer` / `await` | Dash, enemy state manager, behavior, damage numbers, frame freeze | Cooldowns, stuns, attack sequencing, hitstop |
| `Area2D` signals | Hitboxes, detection, attack range | Damage, target acquisition, range checks |

The important point is not that these clocks exist — every action game has timers and animation events. The point is that **none of them has a declared order or a single owner**. Two clocks can change the same state in the same frame.

---

## 3. Findings

Priority legend: **P0** = current correctness/gameplay blocker; **P1** = tight coupling that blocks safe change; **P2** = scalability/process issue; **P3** = hygiene.

### 3.1 P0 — fix before refactoring

| ID | Finding | Evidence | Impact |
|---|---|---|---|
| **P0-1** | `NavigationComponent` never initializes `ray_directions`, `interest`, or `danger`. | `components/navigation/navigation_component.gd:8-10`; `set_interest()`/`set_danger()` index the empty arrays at `:36-45` | Enemy AI throws an index error on its first navigation tick. The `chore/refactor` branch already has a fix (commit `6499791`). |
| **P0-2** | Spear skeleton `dash_duration = 1000.0`. | `actors/enemies/spear_skeleton_regular.tscn:767` | The charge dash lasts ~16 minutes. Almost certainly meant `1.0` or similar. |
| **P0-3** | Stale signal connection to a method that no longer exists. | `actors/enemies/spear_skeleton_regular.tscn:783` targets `_on_hitbox_component_collided_with_wall`; the code method is `_on_wall_collision` (`components/behavior/enemy_behavior_component.gd:94`) and is connected again in `_ready` at `:18` | Runtime error when the charge hitbox hits a wall. Remove the scene connection; keep one connection. |
| **P0-4** | `HealthComponent` assumes the entity has a direct child named `Body`. | `components/combat/health_component.gd:19-20, 40, 53-55` | `TestDummy` has `Sprite2D`, not `Body` (`actors/test_dummy.tscn`). The tween target is `null`; any non-`Body` entity breaks or logs errors. This is name-based coupling, not a data problem. |
| **P0-5** | Enemy attack behavior is triggered from `AnimationPlayer` method tracks, not code; the player sword's hit windows are animation value tracks. | `actors/enemies/sword_skeleton_regular.tscn:442` calls `EnemyBehaviorComponent.dash_attack(0.375)` at animation times 1 and 1.625; `actors/enemies/spear_skeleton_regular.tscn:547` calls `charge()`; `actors/player/sword.tscn` value tracks set `SwordStateMachine.can_input_attack`, `.:combo_finished`, and hitbox `disabled` | Attack behavior is invisible to code search, impossible to test headlessly, and silently stops if the animation/track is edited. This is the single biggest architectural coupling in the project. |
| **P0-6** | Always-true condition in enemy animation. | `components/animation/enemy/enemy_animation_component.gd:24-25`: `current_state != "charge end" or current_state != "hurt"` | The guard is always true, so the sprite flips during hurt/charge-end. Should be `and`. |
| **P0-7** | Always-true string comparisons in the sword state machine. | `actors/player/sword_state_machine.gd:70-81`: `anim_name == "combo 1" or "combo 2"` and `anim_name == "combo 1 end" or "combo 2 end" or "combo 3"` | Every animation finish is treated as a combo end. Combo transitions are unreliable. The dead `archive/legacy/dog_state_machine.gd:70` has the same bug. |
| **P0-8** | Physics collision shapes are enabled/disabled directly during physics. | `components/behavior/enemy_behavior_component.gd:52, 58, 91, 97`; `components/combat/hitbox_component.gd:29-30` caches `get_child(0)` | Godot can warn/error when collision state changes mid-flush; the cached child-0 assumption is also brittle. Use `set_deferred("disabled", ...)` or an ability phase that runs outside the flush. |
| **P0-9** | Required references are optional at runtime and fail silently. | `EnemyBehaviorComponent` uses `charge_hitbox`/`attack_hitbox`/`attack_vfx` without validation (`:17-18, 42-58, 84-92`); sword scene has no `charge_hitbox`, spear scene has no `attack_hitbox` | Swapping/duplicating a behavior or scene leaves a `null` path that only fails when that attack path is used. A `_validate()` step should assert required exports in debug builds. |
| **P0-10** | The spear charge path never sets its dash duration. | `EnemyBehaviorComponent.charge()` (`:84-92`) does not set `physics_component.dash_duration`; it relies on the scene value, which is `1000.0` | Even after P0-2, the charge duration is a scene value disconnected from the attack data. |
| **P0-11** | Two state machines own the player attack. | `PlayerStateManagerComponent.send_attack_signal()` (`components/state/player/player_state_manager_component.gd:13-18`) and `SwordStateMachine` combos both transition/attack; the sword calls `owner.send_attack_signal()` (`actors/player/sword_state_machine.gd:36, 66, 88`) | One action changes state in two places with different timers/animation lengths. This is the root of many "why did the animation/state not match?" bugs. |

### 3.2 P1 — coupling hotspots

| ID | Hotspot | What is coupled | Why it blocks change |
|---|---|---|---|
| **C1** | Actor roots are the system layer. | `Dog`, `SwordSkeleton`, `SpearSkeleton` each run their own frame pipeline and export 10-15 component references. | Adding an archetype means copying a root script and its wiring; update order and gating are duplicated; no single place to profile or reorder. |
| **C2** | `PhysicsComponent` is a mini-system. | Input (`input_component.input_direction`, `dash_input`), dash start (`:31-33`), velocity/steering, knockback (`:46-52`), health signal connection (`:18-21`), `move_and_slide` (`:24`). | One component has four reasons to change. Movement, dash, and damage reaction cannot be tested or tuned independently. |
| **C3** | `HitboxComponent` is a whole combat system. | Deals damage, receives damage, creates `Attack`, checks dash invulnerability, applies knockback on attacker and defender, triggers `FrameFreeze`, camera shake, wall collision (`components/combat/hitbox_component.gd:29-70`). | It reaches `owner.physics_component`, `owner.owner`, `area.owner.health_component`, and the viewport camera. It cannot be reused by an entity with a different hierarchy. |
| **C4** | `HealthComponent` owns HP, policy, death, and visuals. | `owner.is_in_group("player")` (`components/combat/health_component.gd:29`), `owner.find_child("Body")` (`:19-20, 40, 53-55`), `get_parent().queue_free()` (`:37`), damage numbers (`:33-34`), tween/flash. | Health logic depends on the entity's name, group, parent, and view. It cannot be unit-tested without a scene tree; a non-player entity cannot use the same component without special cases. |
| **C5** | Components read actor-specific fields. | `PhysicsComponent` → `actor.health_component` (`:19`); `EnemyBehavior` → `actor.dash`, `actor.navigation_component` (`:31, 43-48, 85-92`); `NavigationComponent` → `actor.detection_area._player_ref` (`:26-27`); `EnemyAnimation` → `actor.sprite` (`:26-29`); `Hitbox` → `owner.physics_component` (`:38-41`); `Weapon` → `owner._last_faced_direction` (`:55-56`). | Every component is secretly typed to one actor. The composition is not reusable; renaming/moving a field breaks components at runtime. |
| **C6** | Scene-tree discovery instead of contracts. | `find_child("PlayerInputComponent")` (`player_animation_component.gd:9`), `find_child("PlayerStateManagerComponent")` (`:10`), `find_child("EnemyStateManagerComponent")` (`components/animation/enemy/enemy_animation_component.gd:6`), `find_child("HealthComponent")` (`components/state/enemy/enemy_state_manager_component.gd:11`), `find_child("Body")` (`components/movement/dash.gd:13`), `get_parent().get_parent().add_child(ghost)` (`:26`). | Node names become API. Reordering or nesting a component breaks behavior with no compile-time warning. |
| **C7** | State is stringly typed and duplicated. | `current_state` strings in `player_state_manager_component.gd:26, 31, 43`; `components/state/enemy/enemy_state_manager_component.gd:26, 36, 46, 58, 81, 86`; comparisons in `player_animation_component.gd:16-20`, `components/animation/enemy/enemy_animation_component.gd:9-25`, `components/behavior/enemy_behavior_component.gd:26-32, 66-73`, `actors/player/dog.gd:33`. | Renaming a state silently changes behavior. There is no single source of truth for valid state names or transitions. |
| **C8** | State manager and animation are bidirectional. | State managers call `animation_component.animate()`; animation reads `state_manager.current_state`; state managers read `animation_player.current_animation_length`. | A change in either side ripples. Animation becomes a timing authority for gameplay. |
| **C9** | Animation assets contain gameplay. | `actors/player/sword.tscn` value tracks mutate `SwordStateMachine.can_input_attack`, `.:combo_finished`, and hitbox `disabled`; `actors/enemies/sword_skeleton_regular.tscn:442` and `actors/enemies/spear_skeleton_regular.tscn:547` method tracks call behavior methods. | Gameplay cannot be reviewed, tested, or changed without editing animations. Animation length becomes attack duration (P0-5/P0-11). |
| **C10** | `Dash` mixes mechanic and view. | `sprite = get_parent().find_child("Body")` (`components/movement/dash.gd:13`); ghost added to `get_parent().get_parent()` (`:26`); copies `AnimatedSprite2D` fields (`:28-34`); resets `sprite.position` after cooldown (`:44`). | Dash timer/cooldown is coupled to a specific sprite/hierarchy. Headless tests need a fake `Body`; recycling/instancing breaks. |
| **C11** | Navigation and detection share a private variable. | `NavigationComponent.get_direction()` reads `actor.detection_area._player_ref` (`:26-27`); `DetectionArea` owns `_player_ref` (`components/area/detection_area.gd:3, 11-12`). `AttackRangeComponent` separately checks the `"player"` group (`components/area/attack_range_component.gd:7-14`). | Target ownership is split across three components; the "private" `_player_ref` is public API in practice. No signal for target acquired/lost. |
| **C12** | The sword is a second player entity with a second state machine. | `Sword` has its own `CharacterBody2D`, `AnimationPlayer`, StateChart, combo states, input polling, and `owner.send_attack_signal()` calls. | Attack input, combos, aim, and player state are split across two scene trees. The weapon is not an equipment component; it is a parallel actor. |
| **C13** | Global services are called directly. | `DamageNumbers` autoload (`components/combat/damage_numbers_component.gd:5`), `FrameFreeze` autoload (`services/frame_freeze.gd`), `get_viewport().get_camera_2d()` (`components/combat/hitbox_component.gd:64`), `Engine.time_scale` (`services/frame_freeze.gd:4, 7`). | Feedback effects cannot be disabled/replaced for tests or different scenes. `FrameFreeze` has no re-entrancy protection; overlapping freezes can restore `time_scale` early. |
| **C14** | `await`/timers are used as state. | `EnemyBehavior.dash_attack` awaits its `Timer` (`:55`); `EnemyStateManager._on_charge_end_state_entered` awaits a scene timer (`:88`); `Dash.end_dash` awaits cooldown (`:43`); `FrameFreeze` awaits (`:5-6`); `DamageNumbers` awaits tween/resized (`:23, 41`). | Interruptions, death, and scene changes are not handled. Old awaits can send state events after the entity has changed state or been freed. |
| **C15** | No entity lifecycle/death event. | `HealthComponent.damage()` calls `get_parent().queue_free()` (`:37`); no `died` signal, no cleanup, no disabling of hitboxes/AI. | Death is a side effect of a component; other components/timers/awaits may still run for a frame or longer. |
| **C16** | Configuration/data is duplicated. | `actors/player/dog.gd` has `_move_speed`, `life`, `dash_speed`, `dash_duration` (`:9-12`) but `PhysicsComponent`/scene values are used; `PlayerStats` autoload is unused; `look_ahead` is exported but unused (`navigation_component.gd:4`); `Attack.stun_time` is set (`components/combat/hitbox_component.gd:56`) but never read. | Multiple sources of truth; changing a stat in one place has no effect; dead values mislead future work. |
| **C17** | Scene wiring is manual and silent when missing. | `EnemyBehaviorComponent` null-checks `charge_hitbox`, `actor.navigation_component`, `health_component` but does not fail. `.tscn` node paths are hand-edited. | A missing export is discovered only when a branch is exercised. P0-3/P0-9 are symptoms. |
| **C18** | File organization hides ownership. | **Resolved in `chore/m0-refactor`:** component scripts/scenes now live under `components/<domain>/`, actors under `actors/`, services under `services/`, world scenes under `world/`, dev scenes under `dev/`, and retired files under `archive/`. See `docs/file-organization.md`. | Kept as a historical finding. Future files should follow the new layout. |

### 3.3 P2 — scalability / process handling

| ID | Finding | Impact |
|---|---|---|
| **S1** | No entity registry or query layer. Every actor root finds its own components; there is no `get_entities_with(Health, Hurtbox)` style query. | Cross-entity systems (combat, targeting, death cleanup, effects) have no natural home and end up inside components/actor roots. |
| **S2** | No explicit update order. `_physics_process`, `_process`, StateChart signals, `AnimationPlayer` tracks, timers, and `await` can all mutate the same state. | One-frame latencies and races; behavior changes when a node is reordered or a scene is nested. `damage_taken` also fans out to physics and enemy state in listener order, so state can change inside a physics collision callback. Hard to reproduce bugs. |
| **S3** | Every enemy runs navigation/raycasts/animation even when offscreen/idle. | With many enemies, CPU cost scales linearly with all entities. There is no activation/LOD policy. For a small dungeon this may be fine, but it should be a deliberate decision. |
| **S4** | Per-hit allocations: `Attack.new()`, labels, tweens, ghost sprites, `SceneTreeTimer`s. | Garbage/alloc spikes in combat; no pooling for damage numbers or dash ghosts. |
| **S5** | No tests or scene validation. | The `chore/refactor` branch had tests, but the current tree has none. P0-1/P0-3/P0-4 would be caught by a smoke test or a required-export validator. |
| **S6** | Adding an archetype is copy/paste. | `SpearSkeleton` and `SwordSkeleton` are nearly identical root scripts with 11 exports each. A new enemy means another root script, another scene, and 10+ hand-wired paths. |
| **S7** | No team/damage model. | `"player"` group checks and collision layers are the only team filter. Friendly fire, neutral entities, and multiple players are not expressible. |
| **S8** | No ability/stat data model. | Attack damage/knockback/hitstop live in scene exports; timings live in animation tracks; stats are duplicated in root scripts/scenes. Tuning requires editing many files. |
| **S9** | No debug/profiling hooks. | There is no single place to inspect state/intent/timers or measure per-system cost. Fine-grained bugs are found by reading code. |

### 3.4 P3 — hygiene

- Dead/legacy scripts (moved to `archive/legacy/`; verify before deleting): `chaserEnemy.gd` (2 lines), `SkeletonStateMachine.gd`, `spear_skeleton_state_machine.gd`, `dog_state_machine.gd`, `room_area_component.gd`.
- Unused autoload: `PlayerStats` — removed in `chore/m0-refactor`; the script is archived at `archive/legacy/playerstats.gd`.
- Unused values: `look_ahead` (`navigation_component.gd:4`), `Attack.stun_time` (set but never read), `InputComponent.get_move_input()` (no callers), `AnimationComponent.can_transition` (unused), `NavigationComponent.velocity`/`acceleration` (unused).
- `RoomArea` in `world/rooms/testRoom.tscn` has no `CollisionShape2D` and `world/room_area.gd` is empty. It is a placeholder, not a system.
- 33 `.tmp` files now live under `archive/tmp/` (editor/crash backups, excluded from Godot by `archive/.gdignore`). Do not delete blindly; confirm they are not wanted, then remove.
- `dev/coco.tscn`, `dev/new room test.tscn`, `dev/jogo.tscn`, `dev/pathfinding test.tscn` are dev/test scenes. Keep if useful.
- `HealthComponent` now lives at `components/combat/health_component.gd` (moved from `scenes/`).

---

## 4. Coupling matrix

| Component | Reads directly | Writes directly | Should own instead |
|---|---|---|---|
| `PhysicsComponent` | `input_component.input_direction`, `dash_input`; `dash_component.is_dashing()`; `actor.health_component.damage_taken`; `actor.velocity` | `actor.velocity`; `dash_component.start_dash()`; `actor.move_and_slide()` | Velocity integration, steering, `move_and_slide` only. Dash and knockback as separate modifiers. |
| `HealthComponent` | `owner` group, `owner.find_child("Body")`, `get_parent()`; `damage_numbers_component` | `health`, invincibility, parent free, tween/material | HP + invincibility + `damage_taken`/`died`; feedback via listeners; death via entity/system. |
| `HitboxComponent` | `owner.physics_component`, `owner.owner`, `area.owner.health_component`; `Dash`; `FrameFreeze`; viewport camera | target health, knockback, collision shape, frame freeze, camera | Hit detection + attack data only; resolution in `CombatSystem`; feedback as events. |
| `EnemyBehaviorComponent` | `actor.dash`, `actor.navigation_component`; `state_manager.current_state`, `state_manager.timer`, `state_manager.state_chart`; attack VFX/hitboxes | actor velocity, physics dash duration, hitbox shape state, state events, VFX | Behavior strategy/decision only; request abilities through an ability/state API; no direct timers/hitboxes. |
| `PlayerStateManagerComponent` / `EnemyStateManagerComponent` | `actor`, animation component/player; health (enemy) | `current_state`, animation calls, timers, state events | State transitions + timers + `state_changed`; no animation calls; no animation-length authority. |
| `PlayerAnimationComponent` / `EnemyAnimationComponent` | `state_manager.current_state`, input keys, `owner` mouse, `actor.velocity`, `actor.sprite` | `AnimationPlayer`, sprite flip | Presentation only; consume a state/facing/aim snapshot. |
| `NavigationComponent` | `actor.detection_area._player_ref`; raycasts; `NavigationAgent2D` | target, `chosen_dir` | Target/steering data; target acquisition via `DetectionComponent` signals. |
| `Dash` | parent `Body`; grandparent; `AnimatedSprite2D` fields | timer, ghost spawn, sprite position | Dash state/cooldown; VFX in a separate `DashGhostEmitter`. |
| `Sword` / `SwordStateMachine` | `Input`, `owner._last_faced_direction`, `owner.send_attack_signal()`, mouse | weapon transform, combo state, player state event, hitbox tracks | Equipment/aim/ability state; player intent/aim data; no direct owner calls. |
| `DamageNumbersComponent` | `DamageNumbers` autoload | labels | Listener for damage events; pooled presentation. |
| `Camera` / `FrameFreeze` | viewport camera, `Engine.time_scale` | offset, global time scale | Services with request/ref-count APIs. |

---

## 5. Target architecture: ECS-lite

### 5.1 Principles

1. **One entity root; components are children.** Keep the scene-tree composition. Do not switch to ID/array ECS.
2. **One wiring point.** The entity (or a factory) assigns component references once; components never use `find_child`, `owner`, `get_parent().get_parent()`, or actor-specific fields for gameplay.
3. **Components are data + small local operations.** Cross-entity work belongs in systems.
4. **One explicit frame order.** Systems run in a declared phase order; actor roots do not each orchestrate a private pipeline.
5. **State is authoritative and typed.** State names are constants/enums; `state_changed` is a signal; animation follows state, not the other way around.
6. **Gameplay timing lives in code/data.** Animation may *report* events, but it must not be the only owner of attack windows or state durations.
7. **Combat is an event pipeline.** Hitbox detects → emits hit event → combat system resolves → health/death/feedback react.
8. **New archetype = scene + data + strategy.** No new root script per enemy unless the behavior is genuinely unique.

### 5.2 Shape

```text
Gameplay scene
└─ World (Node)                      # owns systems + entity registry
   ├─ InputSystem
   ├─ AISystem
   ├─ AbilitySystem / StateSystem
   ├─ MovementSystem
   ├─ CombatSystem
   ├─ PresentationSystem
   ├─ CleanupSystem
   └─ Entities
      └─ Actor (scene root: CharacterBody2D)
         ├─ StatsComponent            # or ActorStats Resource
         ├─ InputComponent            # player intent
         ├─ AIController              # enemy intent
         ├─ AbilityComponent          # cooldowns, state, hit windows
         ├─ LocomotionComponent       # velocity, dash, knockback
         ├─ HealthComponent           # HP, invincibility, died
         ├─ HurtboxComponent          # receives hits
         ├─ HitboxComponent           # emits hits while active
         ├─ DetectionComponent        # target acquired/lost
         ├─ NavigationComponent       # path/steering
         └─ AnimationComponent        # presentation only
```

This is still Godot-friendly: components are nodes, scenes are editable, `AnimationPlayer`/`Area2D`/`CharacterBody2D` still work. The difference is that **the actor root no longer runs the game**; the `World` does.

### 5.3 Proposed frame order

| Phase | System | Owns | Consumes → produces |
|---|---|---|---|
| 1 | `InputSystem` | Player intent | `Input` → `InputIntent` (move, aim, dash, attack, buffer) |
| 2 | `AISystem` | Enemy intent, targeting | detection/navigation/range → `InputIntent` |
| 3 | `AbilitySystem` / `StateSystem` | State transitions, cooldowns, hit windows | intent + timers → state, ability phase, hitbox activation |
| 4 | `MovementSystem` | Velocity, dash, knockback, `move_and_slide` | intent + stats + state → transform/velocity |
| 5 | `CombatSystem` | Hit queue, damage, knockback, death | hit events + health → health/death events |
| 6 | `PresentationSystem` | Animation, VFX, damage numbers, camera, audio | state/velocity/events → view |
| 7 | `CleanupSystem` | Frees, one-shot resets, signal disconnects | death queue → empty scene |

Notes:

- `Area2D` signals can still emit during physics; have them **queue** hit events and let `CombatSystem` resolve them in its phase. If same-frame response is required, use direct `PhysicsDirectSpaceState2D` queries in `CombatSystem` instead of collision callbacks.
- Do not let systems call each other's concrete methods arbitrarily. Systems can read shared snapshots (intent/state) and emit events.
- Start with a single `World._physics_process(delta)` calling `system.tick(delta)` in order. Do not give each system its own `_physics_process`; that reintroduces implicit order.
- `World` can be a normal scene node, not an autoload. Autoload only truly global services (audio bus, pools, save).
- For a small game, groups (`get_tree().get_nodes_in_group("enemy")`) are enough for queries. Add an `EntityRegistry` only when group traversal becomes measurable or when you need tags/archetypes.

### 5.3.1 What happens to the actor roots?

Before:

```text
Dog._physics_process:
  input.handle_inputs()
  velocity = physics.calculate_velocity()
  if state == "attacking": velocity = 0
  physics.apply_knockback()
  physics.move()
```

After:

```text
Dog / EnemyActor (scene root):
  # no gameplay _physics_process
  # owns component references + ActorStats/EnemyProfile
  # forwards nothing; systems find it through the registry/group

World._physics_process(delta):
  input_system.tick(delta)
  ai_system.tick(delta)
  ability_system.tick(delta)
  movement_system.tick(delta)
  combat_system.tick(delta)
  presentation_system.tick(delta)
  cleanup_system.tick(delta)
```

The actor root remains useful for scene composition, inspector wiring, and local child references. It stops being the place where frame order and gameplay decisions live.

### 5.3.2 Process policy

| Kind of work | Where it runs | Rule |
|---|---|---|
| Simulation (input, AI, state, movement, combat) | `World._physics_process` | Fixed phase order; no per-entity orchestration |
| Presentation (animation selection, sprite flips, camera, VFX) | `PresentationSystem` (usually `_process`) | Reads snapshots/events; never mutates gameplay state |
| One-shot effects (hitstop, damage numbers, dash ghosts) | Services with timers/tweens | Cancellable and pooled where it matters |
| Cooldowns/ability windows | `AbilityComponent`/`StateComponent` timers | Data-driven; not `AnimationPlayer.current_animation_length` |
| Physics callbacks (`area_entered`, `body_entered`) | Godot physics flush | Enqueue only; resolve in the next combat phase |


### 5.4 Component contract

Use a small base class / context rather than a general-purpose framework:

```gdscript
# Shape only — not implementation.
class_name Component extends Node
var entity: Actor          # assigned once by the entity/factory

func bind(actor: Actor) -> void:
    entity = actor

func _validate() -> void:  # debug-only required dependencies
    pass
```

And on the actor:

```gdscript
class_name Actor extends CharacterBody2D
func get_component(type) -> Component
func has_component(type) -> bool
```

Rules:

- `@export` typed references are fine for **required local components** (health needs a hurtbox, etc.) because they are explicit and inspector-friendly.
- `entity.get_component(Type)` is for **optional/generic** lookups (e.g., a presentation listener, a status effect). Do not replace every export with a dictionary lookup; that hides dependencies.
- Components expose **queries** (`is_alive`, `is_dashing`, `is_in_state`) and **signals** (`damage_taken`, `died`, `state_changed`, `dash_started`, `hit_landed`). They do not expose raw mutable internals.
- One-shot intents (`dash_pressed`, `attack_pressed`) are consumed/cleared by the system that handles them. Input polling happens once per frame, in `InputSystem`.
- No component frees another node. Death is a request/event handled by `CleanupSystem` or the actor.
- No component reads `AnimationPlayer.current_animation_length` for gameplay timing. If an ability must match an animation, store the duration in `AbilityData` and validate it against the animation in a tool/test.

### 5.5 Data model

Suggested resources (start small; don't build all at once):

| Resource | Fields | Replaces |
|---|---|---|
| `ActorStats` | `max_health`, `move_speed`, `acceleration`, `dash_speed`, `dash_duration`, `dash_cooldown`, `knockback_resistance`, `team`, `mass` | Root script stats, `PhysicsComponent` exports, `PlayerStats` autoload, `HealthComponent.MAX_HEALTH` |
| `AttackData` | `damage`, `knockback`, `stun`, `hitstop`, `team`, `source`, `critical`, `status_effects` | Scene hitbox stats, `Attack` fields, unused `stun_time` |
| `AbilityData` | `id`, `animation`, `windup`, `active`, `recovery`, `cooldown`, `hitbox_scene`, `cancel_windows` | Animation-length timers, method tracks, `can_input_attack` tracks |
| `EnemyProfile` | `stats`, `behavior`, `detection_range`, `attack_range`, `attack_data` | Per-scene exports, `stop_when_in_attack_range`, `attack_cooldown` in state manager |

`Attack` can remain the runtime hit event (`source`, `target`, `data`, `position`) while `AttackData` is the immutable tuning resource.

### 5.6 What to keep

- **Scenes and nodes.** Do not move to a pure ID/array ECS.
- **`godot_state_charts`.** It is a good declarative state driver. Use it behind a `StateMachineComponent` API; keep animation out of its handlers.
- **`AnimationPlayer`/`AnimatedSprite2D`.** Use them as presentation. A thin `animation_event` bridge is acceptable; arbitrary behavior method tracks are not.
- **`Area2D` collision detection.** Keep broad-phase in Godot; move resolution to `CombatSystem`.
- **Physics layers.** Keep them; add a data-level team filter for final hit validation.

### 5.7 Options compared

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **A. Current: actor roots orchestrate components** | Simple, editor-friendly, no new framework | Coupling, implicit order, copy/paste archetypes | Keep only as a migration starting point |
| **B. ECS-lite: entity + components + World systems** | Keeps Godot ergonomics; explicit order; reusable components; testable; incremental | Requires discipline and some boilerplate; systems need a home | **Recommended** |
| **C. Pure data-oriented ECS** | Best raw performance for thousands of entities; deterministic | Loses scene tree/editor/`AnimationPlayer`/`Area2D` ergonomics; large rewrite; not justified at this scale | Defer unless profiling demands it |
| **D. Third-party ECS addon** | Faster to get ECS primitives | Dependency risk; integration friction with Godot nodes/animations; still requires design work | Not now |

**When to graduate to C:** if you target hundreds/thousands of simultaneous actors, need deterministic lockstep/netcode, or profiling shows the node overhead is the bottleneck. Until then, B gives most of the benefit.

### 5.8 Anti-patterns to avoid in the refactor

- **God actor root.** Moving all logic into `actors/player/dog.gd`/`SwordSkeleton.gd` because "it is easier" recreates the coupling in one file.
- **God system.** A single `System` that does input, AI, movement, combat, and animation is just the old actor root with a new name.
- **Event soup.** Signals for everything make flow tracing harder. Use signals for *events* (damage, death, state changed), queries for *state* (`is_alive`, `is_dashing`), and data for *tuning*.
- **Registry everywhere.** `entity.get_component()` for every dependency hides wiring. Keep typed `@export`s for required local components.
- **Framework before use cases.** Build the second system only after the first two use cases prove the shape.
- **Big-bang ECS rewrite.** The current game is small but the animation/scene data is expensive to recreate. Migrate seam by seam.

---

## 6. Roadmap summary

The detailed checklist is in [`docs/refactor-plan.md`](refactor-plan.md). The order is deliberate:

| Milestone | Outcome | Risk |
|---|---|---|
| **M0 — Baseline + P0 fixes** | Current game is stable; no script errors; attacks work; dead code identified | Low |
| **M1 — Contracts + wiring** | No `find_child`/`owner`/actor-field reach-through in components; state names centralized; fail-fast validation | Medium |
| **M2 — Combat seam** | Hitbox/hurtbox split; damage/death/feedback events; no camera/freeze/owner chains in hitbox | Medium-high |
| **M3 — Input + locomotion** | One intent source; movement/dash/knockback split; no health→physics signal; no input polling outside input system | Medium |
| **M4 — State + animation** | One state authority; animation is a view; no gameplay in animation tracks; explicit ability timing | High |
| **M5 — AI/navigation/archetypes** | New enemy by composition/data; detection/navigation clean; behavior strategies | Medium-high |
| **M6 — World systems + process schedule** | One frame order; entity registry/queries; scalable to many actors; profiling | High |
| **M7 — Data + tests + guardrails** | Stats/attacks/abilities as resources; scene validation; unit/integration tests; CI | Medium, ongoing |

**If you only do three milestones:** M0, M1, M2. They remove the worst coupling and make the rest safe. M4 is the next highest-value. M6 is only worth it when actor count or system complexity justifies it.

---

## 7. Open questions

Answer these before M2/M4/M6; they change the target shape:

1. **Actor count.** Is the target 5-20 actors per room, or hundreds? (M6 is optional below ~50.)
2. **Multiplayer/netcode.** Is deterministic lockstep or rollback planned? (This pushes toward data-oriented ECS and explicit phases.)
3. **State charts.** Do you want to keep `godot_state_charts` long-term? (Recommended: yes, behind a state API.)
4. **Weapon ownership.** Is the sword an equipment component of the player, or a separate entity that can be dropped/swapped? (Recommendation: equipment component with an aim/ability API; not a parallel actor.)
5. **Animation-authored events.** Do you want designers to keep authoring hit windows in `AnimationPlayer`? (If yes, restrict tracks to a thin `AbilityComponent.on_animation_event(name)` API; if no, move windows to `AbilityData`.)
6. **Teams/friendly fire.** Are there allies, neutrals, or multiple players? (Needed for the `team` field and hit filtering.)
7. **Branch base.** Should this refactor start from the current `main`-restored tree, or from `chore/refactor`? (Recommendation: start from the current tree; cherry-pick the small known fixes, not the whole branch.)
8. **Implementation ownership.** You write new feature/behavior code; the agent proposes diffs and can do mechanical refactors (moves, renames, signal wiring, test scaffolding). Confirm this split for the refactor.

---

## 8. Appendix

### 8.1 Known-good references on `chore/refactor`

These commits are useful as references, not as a merge target:

- `6499791` — initialize navigation arrays and guard null references.
- `0016ca6` — remove `PhysicsComponent`'s direct dependency on `HealthComponent`'s damage signal.
- `9853ed9` / `8a4cc55` — damage numbers static call and unit tests.
- `724fc4b`, `1be90c6`, `c80d2d1` — GUT test infrastructure exploration.

Caveats: those tests target the old APIs and the `chore/refactor` health design moved visual logic into `actors/player/dog.gd` (a god-root direction). Read them for the assertions, not as the final architecture.

### 8.2 Suggested file layout (after M1/M2, not before)

```text
src/
  actors/          player.tscn, enemy_base.tscn, actor.gd
  components/      health, hurtbox, hitbox, locomotion, dash, input, ai,
                   ability, state, animation, navigation, detection
  systems/         input, ai, ability, movement, combat, presentation, cleanup
  data/            actor_stats, attack_data, ability_data, enemy_profile
  services/        damage_numbers, hitstop, camera_shake, audio, pools
  world/           world.gd, entity_registry.gd
  ui/debug/        debug_overlay.gd
scenes/            gameplay scenes only
tests/             unit + integration + scene validation
```

Do not batch-move files before the contracts are stable: Godot `.uid` files and `ext_resource` paths make moves noisy, and a large move diff hides behavioral changes.

### 8.3 Validation checklist for every entity scene

Add this as a script/tool and run it in CI:

- [ ] Required components exist exactly once.
- [ ] Required `@export` references are non-null.
- [ ] State names referenced by code exist in the StateChart.
- [ ] Animation names referenced by code/data exist in the `AnimationPlayer`.
- [ ] Animation event names match the thin bridge API.
- [ ] Collision layers/masks match the team/layer table.
- [ ] Hitbox/hurtbox shapes exist and start disabled where intended.
- [ ] No `find_child`/`owner`/`get_parent` gameplay lookups in components.

### 8.4 Glossary

- **Actor / entity:** the scene root that owns components (`Dog`, `SwordSkeletonRegular`, ...).
- **Component:** a child node with data/behavior for one concern.
- **System:** code that operates across entities in a declared phase (combat, movement, AI).
- **Query:** selecting entities by component/tag (e.g., all `Health + Hurtbox`).
- **Intent:** the output of input/AI for one frame (move, aim, dash, attack).
- **Ability:** an action with windup/active/recovery and hit windows.
- **Hitbox/hurtbox:** the area that deals damage vs. the area that receives it.
- **ECS-lite:** Godot nodes as entities/components + a World/system layer, without a data-oriented ECS framework.

---

*End of review. The step-by-step checklist is in `docs/refactor-plan.md`.*
