# File organization

This is the working layout after the `chore/m0-refactor` reorganization. Paths in the architecture docs and refactor plan point here.

## Top level

```text
actors/            entities and their root scripts
components/        reusable component scripts and scenes, grouped by domain
services/          autoloaded/global services
world/             room, prop, and lighting scenes
dev/               scratch/test scenes that are not part of the game flow
archive/           retired files and editor temp backups (ignored by Godot)
assets/            textures, audio, tilesets, and other imported assets
shaders/           shader source + shader materials
docs/              architecture review and refactor plan
tests/             dev validation tools
addons/            third-party addons (do not reorganize)
godot_state_charts_examples/  addon examples (do not reorganize)
```

Root stays intentionally small: `project.godot`, `export_presets.cfg`, `icon.svg`, `icon.svg.import`, `version.txt`, `VERSIONING.md`, `AGENTS.md`, `.gitignore`, `.gitattributes`.

## Entity layout

```text
actors/
  player/
    dog.gd
    dog.tscn
    dog_with_camera_setup.tscn
    sword.tscn
    sword_state_machine.gd
    weapon_behavior.gd
  enemies/
    spear_skeleton_regular.gd
    spear_skeleton_regular.tscn
    sword_skeleton_regular.gd
    sword_skeleton_regular.tscn
  test_dummy.gd
  test_dummy.tscn
```

Rule: entity roots live under `actors/`. A new enemy should be a new folder/file under `actors/enemies/`; do not put entity roots in `components/` or at the repository root.

## Component layout

```text
components/
  animation/
    animation_component.gd / .tscn
    enemy/
      enemy_animation_component.gd / .tscn
    player/
      player_animation_component.gd / .tscn
  area/
    attack_range_component.gd / .tscn
    detection_area.gd
  behavior/
    enemy_behavior_component.gd / .tscn
  combat/
    attack.gd
    damage_numbers_component.gd / .tscn
    health_component.gd / .tscn
    hitbox_component.gd / .tscn
  input/
    input_component.gd / .tscn
    enemy/
      enemy_input_component.gd / .tscn
    player/
      player_input_component.gd / .tscn
  movement/
    dash.gd / .tscn
    dash_ghost.gd / .tscn
    physics_component.gd / .tscn
  navigation/
    context_map.tscn
    navigation_component.gd / .tscn
  presentation/
    camera_script.gd
  state/
    state_manager_component.gd
    enemy/
      enemy_state_manager_component.gd / .tscn
    player/
      player_state_manager_component.gd / .tscn
```

Rules:

- A component script and its scene live together, in the same domain folder.
- Domain folders are `animation`, `area`, `behavior`, `combat`, `input`, `movement`, `navigation`, `presentation`, `state`.
- New domains should only be added when there is more than one component to justify them.
- Entity-specific variants stay in a subfolder (`animation/enemy`, `input/player`, `state/player`).
- Do not use spaces in new folder names. The old `components/enemy behavior/` folder was renamed to `components/behavior/`.

## Services, world, dev

```text
services/
  damage_numbers.gd       # autoload DamageNumbers
  frame_freeze.gd         # autoload FrameFreeze

world/
  room_area.gd
  lighting/
    canvas_modulate_green_dungeon.tscn
  props/
    door.gd
    door front.tscn
    door side.tscn
    green light torches.tscn
    torch front.tscn
    torch left.tscn
    torch right.tscn
  rooms/
    first room.tscn
    testRoom.tscn

dev/
  coco.tscn
  jogo.tscn
  new room test.tscn
  pathfinding test.tscn
```

Rules:

- `services/` is for things that are intentionally global/autoloaded, not for behavior that belongs to one entity.
- `world/` is for scenes placed into rooms and environments.
- `dev/` is for throwaway test scenes. If a scene becomes part of the game flow, move it to `world/` or `actors/`.

## Archive

```text
archive/
  .gdignore                 # Godot ignores this whole folder
  legacy/
    chaserEnemy.gd / .uid
    dog_state_machine.gd / .uid
    hitbox_component_duplicate.tscn
    playerstats.gd / .uid
    room_area_component.gd / .uid
    SkeletonStateMachine.gd / .uid
    spear_skeleton_state_machine.gd / .uid
  tmp/
    ... 33 tracked .tmp files
```

The `archive/.gdignore` file is important: it keeps Godot from scanning archived scripts/scenes and registering their `class_name`s. Delete archived files only after confirming they are not wanted; they remain recoverable from git history.

## Tilesets

```text
assets/tilesets/
  tileset dungeon cinza.tres
  tileset dungeon cinza dois de altura.tres
```

The three room scenes that reference them were updated to the new paths.

## Validation

`tests/resource_load_check.gd` + `.tscn` load every `.gd`, `.tscn`, and `.tres` under `actors/`, `components/`, `services/`, `world/`, `dev/`, `tests/`, and `shaders/`. Run:

```powershell
$godot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godot --headless --path D:\Godot\teste res://tests/resource_load_check.tscn
```

Expected result:

```text
RESOURCE LOAD CHECK: 71 resources, 0 failures
```

The main scene (`world/rooms/testRoom.tscn`) also runs headless with no new path errors. The only persistent shader-compiler message is pre-existing (`!actions.custom_samplers.has(...)`), not a resource-path failure.

## Special cases from the move

- **`hitbox_component.tscn` duplicate:** the canonical scene is `components/combat/hitbox_component.tscn` (UID `uid://crvcpbc56v03n`). The old root `hitbox_component.tscn` duplicate is archived. The spear scene was updated to the canonical UID/path.
- **`PlayerStats`:** the autoload was removed. The script is archived under `archive/legacy/`.
- **`HealthComponent`:** moved from `scenes/HealthComponent.gd` to `components/combat/health_component.gd`; its scene is `components/combat/health_component.tscn`.
- **Godot UIDs:** `.tscn` header UIDs and `.gd.uid` sidecars were preserved; all `ext_resource` paths and autoload paths were updated. Do not move these files manually without updating paths (use the editor or a mapping like this one).

## Rules for adding files

1. New entity root → `actors/<kind>/`.
2. New reusable component → `components/<domain>/` with its scene beside it.
3. New global/autoload service → `services/`.
4. New room/prop/lighting scene → `world/`.
5. New scratch/test scene → `dev/`.
6. Retired/legacy file → `archive/legacy/` (keep `.gdignore`).
7. Never put a component script at the repository root.
8. Never use spaces in new folder names.
9. After moving any resource, run `tests/resource_load_check` and the main scene.
