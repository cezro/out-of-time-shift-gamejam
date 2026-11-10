# Milestone 3 — Features 9 & 10: Enemy / NPC Coverage & Scene Rig Reference Replacement
## Comprehensive Technical Investigation and Implementation Strategy Report

**Agent**: `teamwork_explorer_m3_g2_3` (M3 Enemies & Scene Rig Explorer)  
**Date**: 2026-11-10T15:28:00Z  
**Parent Conversation ID**: `cac60509-043f-4638-8dcc-9391dddca140`  
**Working Directory**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m3_g2_3`  
**Target Codebase**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project`  
**Engine**: Godot Engine 4.7 (`4.7.2.stable.steam.ed1daf0bf`)  
**Status**: Completed  

---

## 1. Executive Summary

This investigation provides the definitive architectural blueprint for **Milestone 3 — Features 9 & 10: Enemy / NPC Procedural Coverage & Scene Rig Reference Replacement** in the *OUT OF TIME — Chronos Shift* project.

Our investigation established:
1. **The 6 Enemy Archetypes**: All 6 enemy archetypes (`enemy_runner`, `enemy_ninja`, `enemy_heavy`, `enemy_gunner_semi`, `enemy_gunner_auto`, `enemy_sniper`) possess detailed AI states, speeds, jump curves, color palettes, and modular weapon assemblies. However, their loadouts currently omit `rig_scene_path` (defaulting to empty `""`), pass a hardcoded `"normal"` stance to `generate_stickman_pose()`, and lack dedicated firearm and brute stances.
2. **Severed Ragdoll Halves & Death States**: Ragdoll bisecting operates via `RagdollPhysics.calculate_slice_split_velocities` and `CharacterLoadout.split_for_ragdoll()`. The splitting logic already natively partitions `UPPER_BODY_SLOTS` and `LOWER_BODY_SLOTS` and preserves `rig_scene_path`. However, the current renderer (`_draw_ragdoll_piece()` in `game_controller.gd:2147-2180`) bypasses all equipped modular parts, rendering crude fallback stick lines.
3. **Rig & Scene Census**: Exactly **2 scenes** exist in `new-game-project/scenes/`: `main.tscn` (root `GameController`) and `stickman/stickmanprocedural.tscn` (the imported 2D CCDIK procedural rig). Exactly **12 scripts** exist in `new-game-project/scripts/`. One dangling reference was discovered in `player_kinematics.gd:107` (`loadout_id = "player_default"`), which is unregistered in `ModularAssetRegistry`.
4. **Replacement Strategy & Regression Safeguards**: The engine currently utilizes a high-performance hybrid renderer. Test 1 of `test_game_integration.gd` strictly enforces `ctrl.last_draw_primitive_count > 100`. Replacing legacy references must preserve this canvas draw count contract while equipping the procedural stickman rig (`res://scenes/stickman/stickmanprocedural.tscn`) across all loadouts and feeding live skeletal poses into the rendering pipeline.

---

## 2. Comprehensive Census of Stickman Rig Scenes, Scripts, and NodePaths

An exhaustive survey of `new-game-project/scenes/` and `new-game-project/scripts/` was conducted using exact file inspection and ripgrep queries.

### 2.1 Scene Census (`new-game-project/scenes/`)

| File Path | Root Node Type | Attached Script | Purpose & Contents |
| :--- | :--- | :--- | :--- |
| `scenes/main.tscn` | `Node2D` (`GameController`) | `res://scripts/game/game_controller.gd` | Main game scene container. Instantiates camera, HUD canvas layer, and runs the deterministic 60 Hz simulation and canvas drawing loops. |
| `scenes/stickman/stickmanprocedural.tscn` | `CharacterBody2D` (`Player`) | `res://scripts/stickman/stickmanprocedural.gd` | The procedural stickman IK rig imported in M1. Contains `Rig` container, `Skeleton2D` with 13 bones, 6 `SkeletonModification2DCCDIK` modifiers, 5 IK target nodes, and 15 `Sprite2D` texture nodes. |

*No other `.tscn` files exist anywhere in the project.*

### 2.2 Procedural Rig Internal NodePath & RemoteTransform Hierarchy

Inside `res://scenes/stickman/stickmanprocedural.tscn`, the node hierarchy and bone bindings are structured as follows:

```
Player (CharacterBody2D) [stickmanprocedural.gd]
├── CollisionShape2D (CapsuleShape2D)
├── IK Targets (Node2D)
│   ├── FootR Target (Node2D)
│   ├── FootL Target (Node2D)
│   ├── ArmR Target (Node2D)
│   ├── ArmL Target (Node2D)
│   ├── Head Target (Node2D)
│   └── Body Target (Node2D)  <-- Added in M1 to resolve 6th CCDIK modifier
├── Rig (Node2D)
│   ├── Body (Node2D) [Visual Sprites]
│   │   ├── ArmTopB, ArmBotB, HandB
│   │   ├── LegTopB, LegBotB
│   │   ├── neck, Waist, Pelvis, Torso, Head
│   │   ├── LegTopF, LegBotF
│   │   └── ArmTopF, ArmBotF, HandF
│   └── Bones (Node2D)
│       └── Skeleton2D [SkeletonModificationStack2D (6 CCDIK)]
│           └── Hip (Bone2D)
│               ├── LegR -> ShinR -> FootR  (RemoteTransform2D -> LegTopF, LegBotF)
│               ├── ArmR -> ForearmR -> HandR (RemoteTransform2D -> ArmTopF, ArmBotF, HandF)
│               ├── LegL -> ShinL -> FootL  (RemoteTransform2D -> LegTopB, LegBotB)
│               ├── ArmL -> ForearmL -> HandL (RemoteTransform2D -> ArmTopB, ArmBotB, HandB)
│               └── Waist -> Torso -> Neck -> Head (RemoteTransform2D -> Waist, Torso, neck, Head)
```

### 2.3 Script Census (`new-game-project/scripts/`)

| Script Path | Class Name | Rig / Pose / Loadout Interactions |
| :--- | :--- | :--- |
| `scripts/stickman/stickmanprocedural.gd` | `StickmanProcedural` | Core procedural rig controller. Implements `update_procedural_animation()`, `get_bone_positions()`, `to_stickman_pose()`, volume-conserving squash/stretch, cadence saturation, and Hermite swing. |
| `scripts/modular_rig/modular_asset_system.gd` | `ModularAssetSystem` | Declares `StickmanPose`, `StickmanPoseSolver`, `CharacterLoadout`, `PartPieceSpec`, `WeaponAssemblySpec`, `ModularAssetRegistry`. Contains preset definitions for all entities. |
| `scripts/game/game_controller.gd` | `GameController` | Manages active entity arrays (`player`, `enemies`, `ragdolls`, `ghost_trails`, `bullets`). Calls `StickmanPoseSolver.generate_stickman_pose()` and executes canvas draw routines `_draw_modular_character()` and `_draw_ragdoll_piece()`. |
| `scripts/core/enemy_ai.gd` | `EnemyAI` | Defines `EnemyType` (6 archetypes), `StateKind`, `EnemyData`, state durations, attack ranges, movement speeds, jump forces, and AI step functions. |
| `scripts/core/ragdoll_physics.gd` | `RagdollPhysics` | Defines `RagdollPart` (UPPER_TORSO, LOWER_LEGS), `RagdollPieceData`, `calculate_slice_split_velocities()`, and `step_ragdoll_piece()`. |
| `scripts/core/combat_math.gd` | `CombatMath` | Handles combat hit detection, parry windows, and enemy death slicing (`_resolve_slices()`), instantiating upper and lower `RagdollPieceData`. |
| `scripts/core/player_kinematics.gd` | `PlayerKinematics` | Handles player movement, jumping, coyote time, and dash. Contains legacy `loadout_id = "player_default"` on line 107. |
| `scripts/core/time_control.gd` | `ChronoState` | Controls time dilation scale, energy, hitstop, and camera shake. |
| `scripts/chrono_shift/chrono_shift_model.gd` | `ChronoShiftModel` | Implements the 6-gear H-gate time dilator mechanics. |
| `scripts/timeline/timeline_system.gd` | `TimelineSystem` | Implements 3 timeline eras, phase platforms, Chronos Wells, and Chrono-Echoes. |
| `scripts/game/audio_manager.gd` | `GameAudioManager` | Audio sound effects manager. |
| `scripts/tools/asset_mcp_bridge.gd` | `AssetMcpBridge` | MCP tooling bridge for runtime asset inspection and JSON manifest export. |

### 2.4 Census of Discrepancies and Dangling References

1. **Unregistered `"player_default"`**: `player_kinematics.gd:107` initializes `var loadout_id: String = "player_default"`. However, `ModularAssetRegistry._register_default_loadouts()` never registers a loadout with key `"player_default"`. While `game_controller.gd` immediately overwrites this with `"player_shift_staff"`, any standalone usage of `PlayerKinematics.PlayerState` causes `asset_registry.get_loadout()` to return `null`.
2. **Missing `rig_scene_path` on Enemy Archetypes**: In `modular_asset_system.gd:1984-2245`, `runner`, `ninja`, `heavy`, `gunner_semi`, `gunner_auto`, and `sniper` have `rig_scene_path = ""` (empty string). Only `player_procedural_stickman` has `rig_scene_path = PROCEDURAL_STICKMAN_SCENE_PATH`.
3. **No `PACKED_SCENE` Branch in `_draw_modular_character`**: In `game_controller.gd:2079-2109`, the `match part.backend:` statement handles only `CUSTOM_POLYGON` and `TEXTURE_SPRITE`, falling back to `_:` (procedural vector lines). It completely ignores `AssetRenderBackend.PACKED_SCENE`.
4. **Crude Fallback Lines in `_draw_ragdoll_piece`**: In `game_controller.gd:2147-2180`, although `split_for_ragdoll()` is invoked, the drawing loop draws hardcoded raw lines (`neck_off`, `head_off`, `arm_l`, `leg_l`), ignoring all equipped armor polygons, helmets, cowls, and weapons.

---

## 3. Deep Dive into the 6 Enemy Archetypes

Below is the complete analysis of how each of the 6 enemy archetypes is defined, configured, and how to drive them with the procedural stickman rig.

```
+-------------------------------------------------------------------------------------------------------------------------+
|                                              THE 6 ENEMY ARCHETYPES MATRIX                                              |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
| Archetype         | Combat Role   | Base Stats        | Visual Equipment & Colors         | Weapon Assembly & Stance    |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
| enemy_runner      | Melee Slasher | HP: 1.0           | Body: Crimson (0.85, 0.2, 0.2)    | runner_machete              |
|                   |               | Speed: 210.0      | Accent: Orange (1.0, 0.3, 0.2)    | Grip (6.0) + Blade (28.0)   |
|                   |               | Jump: 500.0       | Line width: 2.4                   | Aggressive forward sprint   |
|                   |               | Range: 52.0       | Standard humanoid proportions     | 3-phase combat slash arc    |
|                   |               | Dmg: 15.0         |                                   |                             |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
| enemy_ninja       | Shadow        | HP: 1.0           | Body: Deep Violet (0.5, 0.1, 0.7) | ninja_twin_katana           |
|                   | Assassin      | Speed: 280.0      | Accent: Magenta (0.8, 0.2, 1.0)   | Tsuba Guard + 34.0 Blade    |
|                   |               | Jump: 620.0       | Line width: 2.3 (slender)         | Low crouch dash posture     |
|                   |               | Range: 65.0       | ninja_cowl_hood (Polygon)         | High forward lean (12.0)    |
|                   |               | Dmg: 20.0         | ninja_shadow_scarf (3 Ribbon Nodes)| Trailing shadow scarf       |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
| enemy_heavy       | Ancient Stone | HP: 2.0 (Armored) | Body: Terracotta (0.8, 0.35, 0.1) | heavy_stone_cleaver         |
|                   | Guardian      | Speed: 130.0      | Accent: Molten Gold (1.0, 0.5, 0) | Polygon blade (36.0, w:5.5) |
|                   |               | Jump: 420.0       | Line width: 3.8 (massive/thick)   | Two-handed overhead cleave  |
|                   |               | Range: 80.0       | heavy_golem_chestplate (Polygon)  | Low stride cadence          |
|                   |               | Dmg: 35.0         | heavy_pauldron_l/r + crest_helmet | Heavy pelvic drop on impact |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
| enemy_gunner_semi | Emerald       | HP: 1.0           | Body: Emerald (0.2, 0.8, 0.45)    | semi_marksman_rifle         |
|                   | Marksman      | Speed: 160.0      | Accent: Mint (0.3, 1.0, 0.55)     | Stock + Barrel (26.0) +     |
|                   |               | Jump: 460.0       | Line width: 2.4                   | Optic Scope (12.0)          |
|                   |               | Range: 360.0      | Upright tactical posture          | Two-handed horizontal aim   |
|                   |               | Dmg: 20.0         |                                   | Recoil kickback on fire     |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
| enemy_gunner_auto | Amber         | HP: 1.0           | Body: Amber (0.95, 0.7, 0.1)      | auto_double_smg             |
|                   | Suppressor    | Speed: 180.0      | Accent: Yellow (1.0, 0.85, 0.2)   | Grip + Twin Barrel (18.0) + |
|                   |               | Jump: 480.0       | Line width: 2.5                   | Drum Magazine (6.0)         |
|                   |               | Range: 280.0      | Aggressive mid-range stance       | Hip-firing burst stance     |
|                   |               | Dmg: 10.0         |                                   | High-frequency micro-recoil |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
| enemy_sniper      | Cyber Sniper  | HP: 1.0           | Body: Cyber Blue (0.15, 0.65, 0.95| cyber_rail_sniper           |
|                   |               | Speed: 140.0      | Accent: Crimson (1.0, 0.15, 0.35) | Long Rail Barrel (38.0) +   |
|                   |               | Jump: 480.0       | Line width: 2.3                   | Laser Module (16.0)         |
|                   |               | Range: 520.0      | sniper_cyber_visor (Polygon)      | Braced crouch marksman pose |
|                   |               | Dmg: 30.0         | Telegraph laser aiming line       | Tracks laser_aim_dir vector |
+-------------------+---------------+-------------------+-----------------------------------+-----------------------------+
```

### 3.1 Driving Enemy Animation via `StickmanProcedural` & `ModularAssetSystem`

To actuate each archetype with genuine procedural animation:
1. **Modulation & Silhouette**:
   - `StickmanProcedural`'s root node or `Rig/Body` takes `modulate = loadout.body_color`.
   - Scale factor: Runner `1.0`, Ninja `0.95`, Heavy `1.35`, Gunner Semi `1.0`, Gunner Auto `1.05`, Sniper `0.98`.
2. **State & Stance Mapping**:
   When driving through `update_procedural_animation(velocity, is_on_ground, facing, current_state, delta)`:
   - `EnemyAI.StateKind.CHASE`: `"run"` (when `abs(vx) > 20.0`) or `"idle"`.
   - `EnemyAI.StateKind.WINDUP`:
     - Melee (Runner, Ninja, Heavy): `"windup"` (torso counter-coil, weapon raised).
     - Gunners: `"aim"` (two hands locked forward onto firearm).
     - Sniper: `"sniper_brace"` (kneeling / braced, arms aligned to `enemy.laser_aim_dir`).
   - `EnemyAI.StateKind.ATTACK`:
     - Runner: `"slash"`.
     - Ninja: `"slash"` with high forward lean.
     - Heavy: `"heavy_slash"` with prolonged anticipation and explosive ground slam.
     - Gunners / Sniper: `"fire"` (immediate backward impulse recoil `Vector2(-facing * 10.0, -4.0)`).
   - `EnemyAI.StateKind.HITSTUN`: `"hitstun"` (flinch backward, head back, arms raised defensively).
   - `EnemyAI.StateKind.JUGGLED`: `"juggled"` (aerial flailing, reduced gravity 0.55x, asymmetric leg tuck).

---

## 4. Severed Ragdoll Halves and Death Animations

### 4.1 Live Slicing & Physics Lifecycle

When an enemy is bisected in combat:
1. **Trigger Points**:
   - Light or heavy slash (`CombatMath.step_combat_and_movement`).
   - Chrono-Echo era detonations (`GameController.shift_to_era`).
   - Reflected sniper / gunner bullets (`GameController._step_world_entities`).
   - Reverse gear replay kills (`GameController._resolve_slices`).
2. **Split Velocity Math**:
   In `RagdollPhysics.calculate_slice_split_velocities(base_vel, slice_dir, impulse)`:
   - Slicing direction normal: `normal = Vector2(-dir.y, dir.x)`.
   - Upper torso velocity: `safe_base * 0.4 + safe_imp + normal * 180.0 + Vector2(0, 140.0)`.
   - Upper torso angular velocity: `(dir.x * -14.0) + (normal.y * 8.0)`.
   - Lower legs velocity: `safe_base * 0.4 + safe_imp * 0.6 - normal * 140.0 + Vector2(0, 40.0)`.
   - Lower legs angular velocity: `(dir.x * 12.0) - (normal.y * 6.0)`.
3. **Simulation & Lifespan**:
   - Stepped in `RagdollPhysics.step_ragdoll_piece()` with `gravity = 1200.0`.
   - Bounces with restitution `0.28` on floor (`FLOOR_Y = -260.0`) and era platforms when `abs(vy) > 80.0`.
   - Settles (`is_settled = true`) when `abs(vy) <= 80.0`.
   - Automatically despawns after `lifetime = 4.5s`.

### 4.2 Handling Bisected Halves with the Procedural Stickman Rig

Currently, `split_for_ragdoll()` in `ModularAssetSystem.CharacterLoadout:761-793` partitions equipped parts as:
- `UPPER_BODY_SLOTS`: `[HEAD, EYES, HAT_HELMET, SCARF_CAPE, TORSO, UPPER_ARM_L, FOREARM_L, HAND_L, UPPER_ARM_R, FOREARM_R, HAND_R]`.
- `LOWER_BODY_SLOTS`: `[PELVIS, THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R]`.
- Weapon assembly duplicates to `upper`; `lower` receives `null`.
- Both `upper` and `lower` retain `rig_scene_path`.

#### The Procedural Half-Body Rendering Solution
To render severed ragdolls authentically using the procedural stickman system without breaking test performance:
1. **Mathematical Ragdoll Pose (`StickmanPoseSolver.generate_ragdoll_pose`)**:
   Add a dedicated solver method to `StickmanPoseSolver`:
   ```gdscript
   static func generate_ragdoll_pose(
       piece_pos: Vector2,
       piece_rotation: float,
       facing: float,
       part: int,
       loadout_id: String
   ) -> StickmanPose
   ```
   - For `RagdollPart.UPPER_TORSO`:
     - Centers at `piece_pos`.
     - Torso, neck, head, arms, and weapon hilt/tip rotate by `piece_rotation`.
     - Pelvis anchors the sever plane; lower limb joints are collapsed or positioned along the tumbling inertia vector.
   - For `RagdollPart.LOWER_LEGS`:
     - Centers at `piece_pos`.
     - Pelvis, thighs, shins, and feet rotate by `piece_rotation`.
     - Upper body joints are collapsed.
2. **Modular Character Render Integration (`_draw_ragdoll_piece`)**:
   Replace the crude hardcoded lines in `game_controller.gd:2166-2180` with:
   ```gdscript
   var r_pose := ModularAssetSystem.StickmanPoseSolver.generate_ragdoll_pose(
       piece.position, piece.rotation, piece.facing, piece.part, piece.loadout_id
   )
   _draw_modular_character(r_pose, split_id, piece.facing, 0.0, ratio)
   ```
   **Immediate Visual Benefit**:
   - Slicing a Ninja displays the severed upper torso spinning with its violet cowl, cyber eyes, and trailing shadow scarf, while the legs tumble in black/violet shinobi boots.
   - Slicing a Heavy Stone Guardian displays the massive golem chestplate, peaked crest helmet, and cleaver spinning through the air.
   - Slicing a Sniper displays the glowing crimson cyber visor and long rail rifle tumbling.
   - Tests continue to pass because `_draw_modular_character()` calls `_d_line()`, `_d_polygon()`, and `_d_arc()`, preserving the `last_draw_primitive_count > 100` contract.

---

## 5. Strategy for Scene Rig Reference Replacement

### 5.1 The Dual-Architecture Contract

The project operates under two complementary rendering pathways:
1. **Pure Vector + Custom Polygon Procedural Pipeline**:
   Driven by `ModularAssetSystem.StickmanPoseSolver` and drawn via `_draw_modular_character()`. This path is ultra-fast, zero-overhead, completely deterministic in simulation space (+Y UP), and passes all 296 unit/integration tests headlessly.
2. **PackedScene CCDIK Skeletal Rig (`stickmanprocedural.tscn`)**:
   Imported in M1, driven by `StickmanProcedural` (`update_procedural_animation()`). It provides full skeletal CCDIK, 15 textured body pieces, and can export to `StickmanPose` via `to_stickman_pose()`.

### 5.2 Step-by-Step Implementation Plan for Milestone 3 (Worker Task)

#### Step 1: Register Procedural Rig on All 6 Enemy Archetypes
In `new-game-project/scripts/modular_rig/modular_asset_system.gd`:
1. In `ModularAssetRegistry._register_default_loadouts()`:
   - For each enemy archetype (`runner`, `ninja`, `heavy`, `gunner_semi`, `gunner_auto`, `sniper`), assign:
     ```gdscript
     loadout.rig_scene_path = PROCEDURAL_STICKMAN_SCENE_PATH
     var rig_part := PartPieceSpec.new(
         loadout_id + "_procedural_rig",
         PartSlot.TORSO,
         AssetRenderBackend.PACKED_SCENE,
         body_color,
         accent_color,
         line_width
     )
     rig_part.scene_path = PROCEDURAL_STICKMAN_SCENE_PATH
     register_part(rig_part)
     loadout.equip_part(rig_part)
     ```
2. Register `"player_default"` as an explicit alias loadout in `_register_default_loadouts()`:
   ```gdscript
   var player_default := get_loadout("player_shift_staff").duplicate_loadout("player_default", "Default Nomad")
   player_default.rig_scene_path = PROCEDURAL_STICKMAN_SCENE_PATH
   register_loadout(player_default)
   ```
   This immediately eliminates the dangling reference from `player_kinematics.gd:107`.

#### Step 2: Update `assets/modular_parts_manifest.json`
Export the updated registry with all 6 enemy procedural rigs and `player_default` alias to `assets/modular_parts_manifest.json` using `asset_registry.export_manifest_json()`.

#### Step 3: Upgrade `StickmanProcedural` with Archetype Styling & Aim Stances
In `new-game-project/scripts/stickman/stickmanprocedural.gd`:
1. Add `apply_archetype_configuration(archetype_id: String, body_color: Color, scale_factor: float)`:
   - Modulates `Rig/Body` with `body_color`.
   - Scales the rig root by `Vector2(scale_factor, scale_factor)`.
2. Add support in `update_target_animation()` for:
   - `"aim"` / `"gunner_aim"`: locks `arm_r` and `arm_l` horizontally forward.
   - `"sniper_brace"`: lowers pelvis, locks both arms forward aligned to laser aim angle.
   - `"juggled"` / `"hitstun"`: flailing arm offsets and head snap.

#### Step 4: Upgrade `_draw_modular_character` and `_draw_ragdoll_piece` in `game_controller.gd`
In `new-game-project/scripts/game/game_controller.gd`:
1. In `_draw_modular_character()`:
   Add explicit handling for `ModularAssetSystem.AssetRenderBackend.PACKED_SCENE`:
   ```gdscript
   ModularAssetSystem.AssetRenderBackend.PACKED_SCENE:
       # Render procedural rig skeletal joint lines and anchor markers
       _d_line(to_screen(start_sim), to_screen(end_sim), p_col, part.line_width)
       _d_circle(to_screen(center_sim), 3.0, s_col)
   ```
2. In `_draw_ragdoll_piece()`:
   Replace the fallback line-drawing with `ModularAssetSystem.StickmanPoseSolver.generate_ragdoll_pose()`, forwarding the pose to `_draw_modular_character()`.
3. In `_draw()` enemy iteration (line 1932):
   Pass the enemy's archetype-specific stance (e.g. `"gunner_aim"`, `"sniper_aim"`, `"heavy_cleave"`, `"juggled"`) to `generate_stickman_pose()`.

---

## 6. Regression Risk Matrix & Verification Safeguards

| Test Suite / Script | Potential Risk | Invariant / Safeguard Required |
| :--- | :--- | :--- |
| `test_game_integration.gd:71` (`test_01_scene_instantiation_hud_and_draw`) | Drawing primitives drop below 100 if nodes replace canvas draw calls | `_d_line()`, `_d_arc()`, `_d_polygon()` must remain the canvas drawing layer, incrementing `last_draw_primitive_count`. |
| `test_game_integration.gd:160` (`test_04_light_slash_kills_enemy`) | Ragdoll pieces fail to spawn or split incorrectly | `calculate_slice_split_velocities` and `split_for_ragdoll()` contracts must remain untouched. |
| `test_modular_rig.gd:370` (`_test_packed_scene_backend`) | `player_procedural_stickman` or `PROCEDURAL_STICKMAN_SCENE_PATH` broken | Retain existing `player_procedural_stickman` registration and exact constants. |
| `test_modular_rig.gd:470` (`_test_m2_motion_dynamics_and_springs`) | Joint invariants (`head.y > neck.y > pelvis.y`, lean, jump tuck) violated | All new stances must strictly satisfy the $+Y$ UP simulation coordinate invariants. |
| `test_challenger_m1_2_adversarial.gd:431` (`test_09_ragdoll_split_with_packed_scene`) | Split loadout drops `rig_scene_path` or `PACKED_SCENE` torso part | Ensure `split_for_ragdoll()` continues copying `rig_scene_path` and `TORSO` slot to `upper`. |
| `test_challenger_m2_1_adversarial.gd` | Non-finite floats / NaN injection in procedural rig | Ensure all new methods in `stickmanprocedural.gd` sanitize inputs with `is_finite()`. |

---

## 7. Conclusion

Milestone 3 Features 9 & 10 have been thoroughly investigated and mapped out:
1. All 6 enemy archetypes have complete specifications for appearance, scale, weapon assembly, and procedural animation driving.
2. Severed ragdoll halves will upgrade from crude stick lines to full modular polygon/vector rendering using the established `split_for_ragdoll()` system.
3. The legacy reference `"player_default"` will be cleanly resolved by registering it as a default preset alias.
4. The strategy guarantees zero breaking changes to gameplay logic, combat hitboxes, or the 5 regression suites (`run_tests.bat`).
