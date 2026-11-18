# Refactor Plan — ECS-lite migration

Companion to [`ecs-architecture-review.md`](ecs-architecture-review.md). Findings IDs (`P0-*`, `C*`, `S*`) refer to that document.

## How to use this plan

- Work top to bottom. Do not start a milestone before the previous milestone's acceptance criteria pass.
- Keep the current game playable. One branch per milestone; merge only when the smoke check passes.
- Every task has a checkbox. Add the date/PR when done.
- **Implementation ownership:** you write new feature/behavior code. The agent can do mechanical refactors (file moves, renames, signal wiring, test scaffolding, scene validation) and propose diffs; it should not write feature logic you want to understand yourself.
- Prefer **strangler migration**: add the new path, validate it side by side, then delete the old path. Avoid big-bang rewrites.
- Re-run the scene validator and smoke scene after every milestone.

**Smoke check (use from M0 onward):**

- [ ] Main scene (`world/rooms/testRoom.tscn`) runs 60 seconds with no script errors.
- [ ] Player moves, dashes, attacks; at least one combo hits a dummy.
- [ ] Sword skeleton and spear skeleton take damage and die.
- [ ] At least one enemy attack damages the player/dummy.
- [ ] No `null`/missing-method/`find_child` errors in the log.

---

## M0 — Baseline and P0 fixes

**Goal:** make the current build stable enough to refactor against. No architecture change yet.

**Branch:** `chore/m0-refactor`

**Detailed proposed patches:** [`m0-fixes.md`](m0-fixes.md).

### Tasks

- [x] Tag/branch the current HEAD as the baseline. `chore/m0-refactor` now exists; do not refactor on top of uncommitted playtest changes.
- [x] Reorganize project files into `actors/`, `components/<domain>/`, `services/`, `world/`, `dev/`, `archive/` (see `docs/file-organization.md`, plus `tests/resource_load_check`).
- [ ] Add a small debug overlay (dev tooling) showing for the followed actor: state, input intent, velocity, dash timer/cooldown, health/invincible, active hitboxes, current target. This is the observation tool for every later milestone.
- [ ] Fix **P0-1**: initialize `NavigationComponent` arrays (`ray_directions`, `interest`, `danger`) from the `ContextMap` rays in `_ready`; guard `actor`/`agent` nulls. Reference: `chore/refactor` commit `6499791`.
- [ ] Fix **P0-2 / P0-10**: replace spear `dash_duration = 1000.0` with the intended value, and make `charge()` set `physics_component.dash_duration` explicitly from a named charge-duration value (move it into ability data later, in M4/M7).
- [ ] Fix **P0-3**: remove the stale `collided_with_wall` connection in `actors/enemies/spear_skeleton_regular.tscn`; keep the single connection made in `EnemyBehaviorComponent._ready`.
- [ ] Fix **P0-4**: make `HealthComponent` resolve its visual target by an exported/optional `NodePath` or a `damage_flash` listener, not `owner.find_child("Body")`. At minimum, support `TestDummy`'s `Sprite2D` and fail loudly if no target is configured.
- [ ] Fix **P0-6**: change the enemy animation guard to `and`.
- [ ] Fix **P0-7**: rewrite the sword combo finish checks with explicit `and`/`or` grouping (or, better, move them to `match`).
- [ ] Fix **P0-8**: use `set_deferred("disabled", ...)` for collision shapes toggled during physics; validate the shape reference instead of `get_child(0)`.
- [ ] Add a **scene validation** script (tool or runtime debug) that checks required exports/nodes for `actors/player/dog.tscn`, `actors/player/sword.tscn`, `actors/enemies/sword_skeleton_regular.tscn`, `actors/enemies/spear_skeleton_regular.tscn`, `actors/test_dummy.tscn`.
- [ ] Confirm and remove dead files (listed in review §3.4); they currently live under `archive/legacy/`: `chaserEnemy.gd`, `SkeletonStateMachine.gd`, `spear_skeleton_state_machine.gd`, `dog_state_machine.gd`, `room_area_component.gd`.
- [x] Remove the `PlayerStats` autoload (done in the reorganization; the script is archived at `archive/legacy/playerstats.gd`). Remove or annotate dead API values (`look_ahead`, `get_move_input`, `AnimationComponent.can_transition`); decide in M2 whether `Attack.stun_time` becomes `AttackData.stun` or is removed.
- [ ] Review the 33 `.tmp` files now under `archive/tmp/` and delete only after confirming they are editor/crash backups. Do not delete user scenes.
- [ ] Capture baseline logs and a short recording/gif of player + enemy attacks for before/after comparison.

### Acceptance

- [ ] Smoke check passes.
- [ ] Scene validator returns zero missing required references.
- [ ] No `find_child("Body")` null error on `actors/test_dummy.tscn`.
- [ ] Enemy navigation runs without index errors.
- [ ] Spear charge dash ends in a sane time.
- [ ] Combo end/sprite flip bugs are gone.

**Risk:** low. This is mostly bug fixing and cleanup.

---

## M1 — Component contracts and wiring

**Goal:** components stop discovering each other through the scene tree and actor-specific fields. Composition becomes real.

**Branch:** `refactor/m1-contracts`

### Tasks

- [ ] Define the entity contract: `Actor`/`Entity` base with `get_component(type)` / `has_component(type)` (or an explicit `ComponentContext`). Decide whether the actor root is the entity or a child `Entity` node; write it down.
- [ ] Define a `Component` base (optional but useful): `entity`, `bind(actor)`, `_validate()`. Keep it small; no update loop.
- [ ] Replace every gameplay `find_child` with an exported reference or `entity.get_component`:
  - [ ] `PlayerAnimationComponent`: `PlayerInputComponent`, `PlayerStateManagerComponent`.
  - [ ] `EnemyAnimationComponent`: `EnemyStateManagerComponent`.
  - [ ] `EnemyStateManagerComponent`: `HealthComponent`.
  - [ ] `Dash`: `Body` sprite.
  - [ ] `HealthComponent`: `Body` visual target.
  - [ ] `EnemyBehaviorComponent`: `actor.dash`, `actor.navigation_component`.
  - [ ] `NavigationComponent`: `actor.detection_area._player_ref`.
  - [ ] `HitboxComponent`: `owner.physics_component`, `owner.owner`, `area.owner.health_component`.
  - [ ] `Weapon`: `owner._last_faced_direction`.
- [ ] Remove `get_parent().get_parent()` from `Dash`; the ghost emitter receives a spawn parent or a world service.
- [ ] Add `_validate()` to components with required references; assert in debug builds with a clear entity name and missing path. Replace silent `if x:` fallbacks where the dependency is mandatory.
- [ ] Centralize state names: one file of `StringName` constants or an enum, used by state managers, animation, behavior, and tests. Keep the StateChart event strings in sync (a validator can compare).
- [ ] Add `StateManagerComponent.is_in_state(name)` and a `state_changed(old, new)` signal; make `current_state` read-only from outside (getter or `state` property).
- [x] Move `HealthComponent` from `scenes/` to `components/combat/health_component.gd` (done in the reorganization).
- [ ] Add a test scene with an actor whose component nodes are renamed/nested; it must still work. This proves the contract.

### Acceptance

- [ ] No gameplay `find_child`, `owner.<gameplay field>`, or `get_parent().get_parent()` remains in `components/` (local child lookups are allowed).
- [ ] Renaming a component node does not break behavior if it is wired via exports.
- [ ] Missing required reference fails fast in debug with a useful message.
- [ ] Smoke check still passes; behavior is unchanged.

**Risk:** medium. Mostly mechanical, but touches every scene. Do it in small commits per component.

---

## M2 — Combat seam: hitbox, hurtbox, health, feedback

**Goal:** one combat pipeline. A hit is detected once, resolved once, and feedback is a listener.

**Branch:** `refactor/m2-combat`

### Tasks

- [ ] Split `HitboxComponent` into:
  - [ ] `HurtboxComponent` (receives hits; holds `HealthComponent`/team; no attack stats).
  - [ ] `HitboxComponent` (deals hits; holds `AttackData`; active window only; no health).
  - If a split is too much at once, keep one class but separate the two code paths and scenes; do not keep the union forever.
- [ ] Create `HitEvent` (runtime: source, target, `AttackData`, position) and `AttackData` (Resource: damage, knockback, stun, hitstop, team, critical, status effects). Rename the old `Attack` or keep it as the event.
- [ ] Create a `CombatSystem`/`CombatResolver` (World node or autoload) that:
  - [ ] receives queued hit events (or queries overlaps);
  - [ ] applies team/friendly-fire filtering;
  - [ ] applies damage, knockback, stun, hitstop, death;
  - [ ] emits `damage_dealt`, `entity_died`, `hit_landed` events.
- [ ] `HealthComponent`: remove visuals, group checks, and `get_parent().queue_free()`. Emit `damage_taken`, `health_changed`, `died`; let the actor/`CleanupSystem` handle death.
- [ ] `HitboxComponent`: remove `FrameFreeze`, camera shake, knockback-owner logic, and `owner` chains. Emit a hit event; do not apply damage directly.
- [ ] Move damage numbers, camera shake, hitstop, and VFX into listeners/services:
  - [ ] `DamageNumbersComponent` listens to `damage_dealt`.
  - [ ] `CameraShakeService` listens to `hit_landed` with intensity/duration from `AttackData`.
  - [ ] `HitStopService` owns `Engine.time_scale` with request tokens/ref count (or per-entity pause), not a bare global.
  - [ ] VFX listener plays the attack animation/flash.
- [ ] Add team/`target_mask` to hurtboxes; replace `"player"` group checks with data. Keep collision layers as broad-phase.
- [ ] Death flow: `HealthComponent` emits `died`; actor/system disables collision, hitboxes, AI, animation; queue free after death animation; guard timers/awaits with `is_instance_valid`/generation tokens.
- [ ] Fix the double knockback path: only `CombatSystem` applies knockback (or only the damage signal, not both).
- [ ] Add tests for: damage, invincibility, death, friendly fire, knockback direction, hitstop re-entrancy.

### Acceptance

- [ ] One hit produces exactly one damage event and one knockback impulse.
- [ ] `HitboxComponent` contains no viewport/camera/`FrameFreeze`/`owner.physics_component` references.
- [ ] `HealthComponent` contains no `find_child`, no group check, no parent free.
- [ ] Player can damage enemies; enemies can damage player/dummy; death cleans up.
- [ ] Damage numbers/camera shake can be disabled without touching combat.
- [ ] Smoke check passes.

**Risk:** medium-high. Keep the old damage path behind a flag until the new one is validated.

---

## M3 — Input intent and locomotion

**Goal:** one input source and one movement operation. Dash and knockback become modifiers, not hidden side effects.

**Branch:** `refactor/m3-locomotion`

### Tasks

- [ ] Define `InputIntent` (move direction, aim direction, dash pressed, attack pressed, buffer window). One-shot fields are cleared after consumption.
- [ ] `InputSystem`: poll `Input` once per frame for players; write `InputIntent`.
- [ ] `AIController`/`AISystem`: write `InputIntent` for enemies; no `EnemyInputComponent` polling navigation inside `handle_inputs()`.
- [ ] Remove direct `Input` polling from `SwordStateMachine`; consume `attack_pressed`/buffer from the player intent. The weapon no longer owns input.
- [ ] Split `PhysicsComponent`:
  - [ ] `LocomotionComponent`: stats, velocity, steering, `move_and_slide`.
  - [ ] `DashComponent`: dash state, cooldown, duration, invulnerability policy; events `dash_started`/`dash_ended`.
  - [ ] `KnockbackComponent` or a locomotion modifier: applied impulse with delta-based decay.
- [ ] Remove the `HealthComponent.damage_taken → PhysicsComponent` signal connection; combat applies impulses.
- [ ] Make movement delta-based (steering, knockback decay); remove per-frame constant decay. Use a fixed physics step.
- [ ] Dash VFX: move ghost spawning into a `DashGhostEmitter` that listens to dash events; no `get_parent().get_parent()`, no sprite field copying outside presentation.
- [ ] Remove `Dog._process` copying `last_faced_direction`; the aim/facing value is produced by input/state and read by presentation/weapon in the same phase.
- [ ] Remove unused root stats (`_move_speed`, `life`, `dash_speed`, `dash_duration`) or move them into `ActorStats`.

### Acceptance

- [ ] Only `InputSystem`/player input component calls `Input`.
- [ ] `PhysicsComponent` no longer references health or input.
- [ ] `HealthComponent` no longer connects to physics.
- [ ] Dash cooldown/invulnerability works without a `Body` sprite present (headless test).
- [ ] Knockback is frame-rate independent in a test.
- [ ] Player/enemy movement feels the same or better; smoke check passes.

**Risk:** medium. Movement feel is easy to regress; test before/after at 60/120 FPS.

---

## M4 — State and animation discipline

**Goal:** one state authority; animation is a view; attack timing is explicit and testable.

**Branch:** `refactor/m4-state-animation`

### Tasks

- [ ] Unify player/enemy state managers behind one `StateMachineComponent` API:
  - [ ] `request(event)` / `send(event)`;
  - [ ] `is_in_state(name)`;
  - [ ] `state_changed(old, new)` signal;
  - [ ] timers/cooldowns owned by the state/ability component, not read from `AnimationPlayer`.
- [ ] Remove `animation_component.animate()` calls from state handlers. `AnimationComponent`/`PresentationSystem` subscribes to `state_changed`, intent, and velocity, and chooses the animation.
- [ ] Remove `state_manager.current_state` reads from animation/behavior; use `is_in_state()` or a state snapshot.
- [ ] Replace gameplay in `AnimationPlayer` tracks:
  - [ ] `EnemyBehaviorComponent.dash_attack`/`charge` method tracks → `AbilityComponent` phases (windup/active/recovery) or a thin `on_animation_event("hit_start")` bridge.
  - [ ] `SwordStateMachine.can_input_attack`, `.:combo_finished`, and hitbox `disabled` value tracks → `AbilityData` cancel windows / hit windows controlled by code.
  - [ ] Keep only cosmetic method tracks (SFX/VFX) if desired.
- [ ] Introduce `AbilityData`/`AbilityComponent` for attacks (windup, active, recovery, cooldown, cancel windows, hitbox scene). The sword combo becomes a sequence of abilities, not a second actor state machine.
- [ ] Decide the single owner of the player attack:
  - [ ] Recommended: player `StateMachineComponent`/`AbilityComponent` owns attack state and timing; the sword is equipment that supplies animation/hitboxes and aim.
  - [ ] Remove `owner.send_attack_signal()`; use an ability/event.
- [ ] Fix combo state logic (P0-7) as part of the new ability sequence; add tests for combo 1→2→3, buffer, cancel, and finish.
- [ ] Remove `await`-based state events (`EnemyStateManager._on_charge_end...`, `EnemyBehavior.dash_attack`); use timers/ability phases with cancellation.
- [ ] Add a headless test: change an animation's length; state/attack windows must not change (timing comes from `AbilityData`).

### Acceptance

- [ ] No gameplay logic in `.tscn` animation method/value tracks (only cosmetic events, if any).
- [ ] No state handler reads `current_animation_length`.
- [ ] `AnimationComponent` has no references to input, mouse, or `state_manager.current_state`.
- [ ] Changing an attack animation does not change state duration, cancel windows, or damage windows.
- [ ] Combo/buffer tests pass; smoke check passes.

**Risk:** high. Do this after M2/M3; keep the old StateChart scenes as data, but route transitions through the new API. Use a feature flag if needed.

---

## M5 — AI, navigation, and archetypes

**Goal:** a new enemy is a scene + data + behavior strategy, not a copied root script.

**Branch:** `refactor/m5-archetypes`

### Tasks

- [ ] Split targeting:
  - [ ] `DetectionComponent` emits `target_acquired(target)` / `target_lost(target)`.
  - [ ] `AttackRangeComponent` emits `entered_range(target)` / `exited_range(target)`; no `"player"` group hardcode; use a target filter/team.
  - [ ] `NavigationComponent` owns `set_target`/`clear_target`, ray initialization, `get_steering_direction`; no `actor.detection_area._player_ref`.
- [ ] Split `EnemyBehaviorComponent` into strategies:
  - [ ] `ChaseBehavior` (move toward target, stop at range).
  - [ ] `DashAttackBehavior` (request dash attack ability).
  - [ ] `ChargeBehavior` (request charge ability, wall collision end).
  - Use `Resource` strategies or child nodes; no `actor.dash`/`state_manager.timer` reach-through.
- [ ] Generic `EnemyActor`/`Actor` root with `@export var profile: EnemyProfile` and `@export var behavior: BehaviorStrategy`; `SpearSkeleton`/`SwordSkeleton` scripts become presets/data or are deleted.
- [ ] Add an `EnemyTemplate` scene + factory/spawner. New enemy = duplicate template, swap `EnemyProfile`/behavior/stats.
- [ ] Fix required exports: validate `attack_hitbox`/`charge_hitbox` per behavior; remove the stale spear connection (already M0).
- [ ] Move `attack_cooldown`, `stop_when_in_attack_range`, `dash_duration`, `attack_damage` into `EnemyProfile`/`AttackData`.
- [ ] Add three test archetypes (e.g., chaser, dasher, charger) from data; prove no new root script.
- [ ] Add a navigation test: target acquired → path direction → target lost → idle.

### Acceptance

- [ ] A new enemy can be added without editing a root script or copying 11 exports.
- [ ] No component reads a private `_player_ref` or a state manager's internal `timer`.
- [ ] Each behavior can be tested with a fake intent/target.
- [ ] All enemy attacks deal damage; wall collision ends charge.
- [ ] Smoke check passes.

**Risk:** medium-high. The behavior strategies are where gameplay feel lives; keep the existing tuning and compare.

---

## M6 — World systems and process schedule

**Goal:** one frame pipeline, scalable to many actors and easy to profile.

**Branch:** `refactor/m6-world`

### Tasks

- [ ] Add a `World` node to gameplay scenes (or a `World` scene) with `_physics_process(delta)` calling systems in order:
  1. `InputSystem`
  2. `AISystem`
  3. `AbilitySystem`/`StateSystem`
  4. `MovementSystem`
  5. `CombatSystem`
  6. `PresentationSystem`
  7. `CleanupSystem`
- [ ] Remove per-actor orchestration from `actors/player/dog.gd`, `SwordSkeleton.gd`, `SpearSkeleton.gd`; they become thin data/component containers.
- [ ] Add entity registration:
  - [ ] Start with groups/tags (`player`, `enemy`, `damageable`, `ai`), cached per frame.
  - [ ] Add `EntityRegistry` only if group traversal is measurable; keep the API small.
- [ ] Convert hit detection to a queue resolved by `CombatSystem`; no gameplay mutation inside `area_entered` beyond enqueueing. If same-frame response is needed, use direct space queries in `CombatSystem`.
- [ ] Add activation/LOD policy (optional, after profiling): disable AI/animation for offscreen/distant actors; keep physics/health as needed. Do not optimize blindly.
- [ ] Add profiling counters per system (entity count, microseconds) and a debug overlay page.
- [ ] Benchmark 10/50/100 enemies before/after; record numbers.
- [ ] Document the frame order in `docs/runtime-order.md` and make it a review checklist item.

### Acceptance

- [ ] Exactly one place defines update order.
- [ ] Reordering actor nodes does not change behavior.
- [ ] Adding a system does not require editing actor roots.
- [ ] 50 enemies at target FPS with no per-frame allocation spikes from timers/tweens (measure first).
- [ ] Smoke check passes.

**Risk:** high. This is only worth doing when actor count/complexity justifies it. M0-M5 deliver most of the design benefit without it.

---

## M7 — Data, tests, and guardrails

**Goal:** tuning and archetypes are data; regressions are caught automatically.

**Branch:** `refactor/m7-data-tests`

### Tasks

- [ ] `ActorStats` Resource; replace `HealthComponent.MAX_HEALTH`, `PhysicsComponent` stats, root stats, and `PlayerStats`.
- [ ] `AttackData`/`AbilityData` Resources; replace hitbox exports and ability constants.
- [ ] `EnemyProfile` Resource; replace per-scene enemy tuning.
- [ ] Unit tests:
  - [ ] `AttackData`/team filtering;
  - [ ] `HealthComponent` damage/invincibility/death;
  - [ ] `CombatResolver` one-hit-one-damage;
  - [ ] state transitions/cooldowns;
  - [ ] movement/dash/knockback delta behavior;
  - [ ] navigation steering with fake rays/target.
- [ ] Integration tests:
  - [ ] instantiate one of each actor, run N physics ticks, assert no null exports and expected state;
  - [ ] simulate a hit and assert health/death/feedback events.
- [ ] Scene validator in CI: required components/exports, state names, animation names/events, collision layers.
- [ ] Headless smoke scene in CI (Godot `--headless`), with a timeout and log assertion.
- [ ] Add a `docs/component-contracts.md` with the rules from the review and a "new enemy/new attack" cookbook.
- [ ] Review the `chore/refactor` tests for reusable assertions; do not restore obsolete API tests.

### Acceptance

- [ ] CI catches a missing export, a renamed state, and a broken animation event.
- [ ] New enemy/attack can be added by data + scene changes, with tests.
- [ ] No duplicated stat source remains.
- [ ] Smoke + unit + integration tests pass.

**Risk:** medium, ongoing. Add tests incrementally with each milestone rather than saving them all for the end.

---

## Dependency order

```text
M0 (stability)
 └─ M1 (contracts)
     ├─ M2 (combat)
     │   └─ M4 (state/animation)
     ├─ M3 (input/locomotion)
     │   └─ M4
     └─ M5 (AI/archetypes)
         └─ M6 (world systems)  [optional until scale demands]
             └─ M7 (data/tests)
```

M2 and M3 can run in parallel after M1 if the same person is not doing both. M4 depends on both because attack timing touches state/combat. M6 should not start until the components are independent; otherwise the systems become a new god object.

## Stop points

- **After M0:** the game is stable; use this as the baseline for every comparison.
- **After M2:** combat is decoupled; this is the highest-value architectural change.
- **After M4:** animation no longer controls gameplay; this is the second-highest-value change.
- **After M5:** new content scales by composition.
- **After M6:** the project scales to many actors with an explicit frame order.

## Definition of done for the refactor

- [ ] A new enemy is a scene + `EnemyProfile` + behavior strategy; no new root script.
- [ ] A new attack is `AbilityData` + hitbox scene + animation; no gameplay method/value tracks.
- [ ] No gameplay component uses `find_child`, `owner`, `get_parent().get_parent()`, or actor-specific fields.
- [ ] Exactly one update-order definition exists and is documented.
- [ ] A hit is resolved once, through one combat pipeline.
- [ ] Death is an event; no component frees its parent.
- [ ] Scene validation, unit tests, and a headless smoke test run in CI.
- [ ] The debug overlay shows state/intent/velocity/timers/target for any actor.
