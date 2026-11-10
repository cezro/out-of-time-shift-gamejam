# Comprehensive Survey Report: OUT OF TIME Game Codebase & Stickman Architecture

**Surveyor**: Explorer 1 (`teamwork_explorer`)  
**Target Codebase**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam`  
**Engine**: Godot Engine 4.7 (`4.7.2.stable.steam.ed1daf0bf`)  
**Date**: 2026-11-10  

---

## 1. Executive Summary

The `out-of-time-shift-gamejam` project implements **OUT OF TIME**, a 2D fast-paced stickman combat and time-shifting platformer ported from `bevy-game-test` into Godot 4.7. The core architecture combines:
1. **Procedural Vector Stickman Skeleton**: A mathematical stickman pose solver (`ModularAssetSystem.StickmanPoseSolver`) calculating 2D joint positions across 6 martial stances and 20 anatomical slots.
2. **Piece-by-Piece Modular Equipment & Weapon Rig**: An interchangeable asset system supporting 4 render backends (procedural vectors, external textures, custom local-space polygons, and packed scenes) and an 11-piece interlocking weapon assembly (the Shift Staff / Chronos Key).
3. **Pure Kinematic Simulation with Inverted Y Coordinate Conversion**: All gameplay logic operates deterministically in simulation space (+Y = UP) and converts to Godot's canvas space (+Y = DOWN) at the draw boundary.
4. **Time Dilator & 3-Era Timeline Shift**: An interactive H-gate stick-shift model (Gears 1–6, N, R) coupled with 3 parallel timeline eras (Past, Present, Future), Chronos Wells, phase platforms, and Chrono-Echo detonations.
5. **Headless Test Suite**: 5 test suites comprising 296 unit, integration, and adversarial tests running via `run_tests.bat`, currently passing 100% (296/296).
6. **Godot MCP Tooling**: Located in `tools/godot-mcp`, interfacing with Godot via Node.js CLI/JSON-RPC and `godot_operations.gd`. Two distinct bugs were identified in `godot-mcp` (an ES module `require('fs')` crash and a falsy `{}` check bug in `godot_operations.gd`).

---

## 2. Inventory of Stickman Usages, Models, and Scenes

The stickman rig and character models are utilized across three distinct gameplay entities:

| Entity Category | Scene / Script Path | Primary Class / Data Model | Loadout Preset ID | Visual Presentation |
| :--- | :--- | :--- | :--- | :--- |
| **Player Character** | `new-game-project/scenes/main.tscn`<br>`new-game-project/scripts/game/game_controller.gd:73`<br>`new-game-project/scripts/core/player_kinematics.gd:84` | `PlayerKinematics.PlayerState` | `"player_shift_staff"` | Pure white stickman skeleton, electric cyan eyes and 3-node scarf, brass-and-cyan Shift Staff (Mechanical Cane / Chronos Key). |
| **Time-Shift Clones & Ghost Trails** | `new-game-project/scripts/game/game_controller.gd:16-54`<br>`new-game-project/scripts/timeline/timeline_system.gd:145-177` | `GameController.GhostTrailData`<br>`TimelineSystem.ChronoEchoData` | Inherited from active player loadout | Fading translucent neon afterimages rendered with alpha fade; Chrono-Echoes display aiming vectors and shockwave detonator circles. |
| **Enemies / NPCs (6 Types)** | `new-game-project/scripts/core/enemy_ai.gd:35-126`<br>`new-game-project/scripts/modular_rig/modular_asset_system.gd:1544-1806` | `EnemyAI.EnemyData` | `"enemy_runner"`<br>`"enemy_ninja"`<br>`"enemy_heavy"`<br>`"enemy_gunner_semi"`<br>`"enemy_gunner_auto"`<br>`"enemy_sniper"` | Procedural stickman skeleton with custom equipment: crimson slasher, violet ninja with polygon cowl, orange stone guardian with polygon chestplate and cleaver, green rifle marksman, amber dual SMG suppressor, cyan sniper with cyber visor. |
| **Severed Ragdoll Halves** | `new-game-project/scripts/core/ragdoll_physics.gd:13-50`<br>`new-game-project/scripts/game/game_controller.gd:2148-2181` | `RagdollPhysics.RagdollPieceData` | Dynamically split: `<loadout>_upper`<br>`<loadout>_lower` | Decapitated/bisected upper torso and lower legs tumbling with angular velocity; loadout pieces automatically route to appropriate half. |

---

## 3. Stickman Rig Structure & Anatomical Breakdown

### 3.1 Skeleton Nodes & Joint Hierarchy
The stickman rig is not bound to a conventional Godot `Skeleton2D` / `Bone2D` node tree. Instead, it is computed in pure memory by `ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose()` (`new-game-project/scripts/modular_rig/modular_asset_system.gd:849-1070`).

The resulting `StickmanPose` holds 17 distinct joint/node positions:
- **Head & Torso**: `head_center: Vector2` (radius 8.5 for player, 7.5 for enemy), `neck: Vector2`, `pelvis: Vector2`.
- **Upper Limbs**: `left_shoulder`, `left_elbow`, `left_hand`, `right_shoulder`, `right_elbow`, `right_hand`.
- **Lower Limbs**: `left_hip`, `left_knee`, `left_foot`, `right_hip`, `right_knee`, `right_foot`.
- **Weapon Anchor**: `sword_hilt: Vector2`, `sword_tip: Vector2`.
- **Dynamic Physics Ribbon**: `scarf_nodes: Array[Vector2]` (3 trail points fluttering with `anim_time` and vertical velocity `clampf(safe_vel.y, -2000.0, 2000.0)`).

### 3.2 The 20 Anatomical Equipment Slots (`PartSlot`)
`ModularAssetSystem.PartSlot` (`modular_asset_system.gd:12-33`):
- Upper Body (11 slots):
  - `HEAD = 0`, `EYES = 1`, `HAT_HELMET = 2`, `SCARF_CAPE = 3`, `TORSO = 4`
  - `UPPER_ARM_L = 6`, `FOREARM_L = 7`, `HAND_L = 8`
  - `UPPER_ARM_R = 9`, `FOREARM_R = 10`, `HAND_R = 11`
- Lower Body (7 slots):
  - `PELVIS = 5`
  - `THIGH_L = 12`, `SHIN_L = 13`, `FOOT_L = 14`
  - `THIGH_R = 15`, `SHIN_R = 16`, `FOOT_R = 17`
- Weapon Anchors (2 slots):
  - `WEAPON_MAIN = 18`, `WEAPON_OFFHAND = 19`

### 3.3 The 11 Modular Weapon Piece Slots (`WeaponPieceSlot`)
`ModularAssetSystem.WeaponPieceSlot` (`modular_asset_system.gd:35-47`):
- `POMMEL = 0`: Counterweight brass sphere.
- `GRIP = 1`: Wrapped leather / textured grip.
- `GUARD = 2`: Curved cane crook or katana tsuba guard.
- `SHAFT_LOWER = 3`: Lower cane shaft segment.
- `GEARWORK_CORE = 4`: Rotating brass clockwork cog (spins with `rotation_offset + anim_time * 4.0`).
- `SHAFT_UPPER = 5`: Upper extension sleeve.
- `BLADE_EDGE = 6`: Concealed high-frequency edge extending along cane line.
- `KEY_TEETH = 7`: Ornate brass Chronos Key notches that rotate into alignment as gears engage or when near a Chronos Well.
- `MUZZLE_BARREL = 8`: Firearm barrel for gunners/snipers.
- `OPTIC_SCOPE = 9`: Optical or laser sight module.
- `MAGAZINE = 10`: Drum or box magazine.

### 3.4 The 4 Render Backends (`AssetRenderBackend`)
`ModularAssetSystem.AssetRenderBackend` (`modular_asset_system.gd:49-54`):
1. `PROCEDURAL_VECTOR`: Vector lines, arcs, circles, rotating gear teeth rendered via custom drawing primitives (`_d_line`, `_d_arc`, `_d_circle`).
2. `TEXTURE_SPRITE`: `Texture2D` instances scaled, rotated, and positioned to match the bone's computed local transform.
3. `CUSTOM_POLYGON`: Data-driven `PackedVector2Array` geometry rendered in bone local space (e.g. Golem stone chestplate, heavy cleaver, ninja cowl hood).
4. `PACKED_SCENE`: Sub-scene instantiation linked to bone slot transforms.

---

## 4. Character Movement, State Machines, and Interactions

### 4.1 Kinematic Configuration
Located in `new-game-project/scripts/core/player_kinematics.gd:8-24`:
- Horizontal Speed: `max_speed = 340.0 px/s`
- Acceleration / Deceleration: `accel = 2200.0 px/s²`, `decel = 2800.0 px/s²`
- Jump Force: `jump_force = 580.0 px/s` (+Y)
- Gravity: `gravity = 1400.0 px/s²`, `fall_gravity_mult = 1.6` (when `vy < 0`), `short_hop_mult = 2.2` (when jump released early while `vy > 0`)
- Responsiveness: `coyote_time_max = 0.12s`, `jump_buffer_max = 0.12s`
- Kinetic Dash: `dash_speed = 780.0 px/s`, `dash_duration = 0.14s`, `dash_cooldown_max = 0.40s`. Crucial mechanic: `start_dash()` immediately zeroes `slash_cooldown`, enabling light slash recovery cancellation!
- Wall Mechanics: Vertical slide capped at `wall_slide_speed = -110.0 px/s`; diagonal rebound jump launches with `Vector2(420.0 * normal_x, 560.0)`.
- Downward Slam: Fast vertical plunge at `slam_speed = -950.0 px/s`, triggering a `160px` AOE shockwave on impact with floor/platforms.

### 4.2 Combat Hit Detection and Arc Mathematics
Located in `new-game-project/scripts/core/combat_math.gd:25-78`:
- `point_to_segment_distance_sq(p, a, b)`: Calculates minimum squared distance from enemy center to line segment.
- `katana_arc_intersects()`: Evaluates 135° (`PI * 0.75`) sweep within `80px` range, checking dot product angle difference between player aim direction and target vector.
- Deflect / Parry: 0.22s defensive window that intercepts enemy bullets, reflects them at `1.6x` bullet speed with reversed team identity, and neutralizes incoming melee damage.

### 4.3 Chronos Shift H-Gate Mechanics
Located in `new-game-project/scripts/chrono_shift/chrono_shift_model.gd`:
- H-gate layout with columns at $x \in \{-1.0, 0.0, 1.0\}$ and central neutral rail $y=0$.
- Gears: G1 (-1, 1), G2 (-1, -1), G3 (0, 1), G4 (0, -1), G5 (1, 1), G6 (1, -1), Neutral (0, 0), Reverse (-1, 0 / override).
- Dilation mapping:
  - Neutral: $1.00\times$ (0 drain)
  - Gear 1: $0.75\times$ (12 energy/s)
  - Gear 2: $0.55\times$ (25 energy/s)
  - Gear 3: $0.38\times$ (40 energy/s)
  - Gear 4: $0.24\times$ (55 energy/s)
  - Gear 5: $0.12\times$ (68 energy/s)
  - Gear 6: $0.04\times$ (75 energy/s)
  - Reverse (R): $0.90\times$ (turbo overdrive & parry counter-knockdown)
- Detent spring stiffness: `DETENT_K = 16.0/s`; knob seats into gear slots when $|y| > 0.45$.

### 4.4 Timeline Shifting and Parallel Eras
Located in `new-game-project/scripts/timeline/timeline_system.gd`:
- 3 Eras: `PAST (0)` (Ancient Overgrown Ruins), `PRESENT (1)` (Industrial Clockwork Compound), `FUTURE (2)` (Cybernetic Neon Void).
- Phase platforms activate only in their corresponding era (`era == -1` for all eras).
- Laser hazards activate in Future era.
- Vine climb surfaces activate in Past era.
- Chronos Wells serve as era transition portals in Campaign mode; arena-wide shift available in Horde mode.
- Momentum Invariant: Horizontal and vertical velocities are strictly conserved during era shifts.
- Chrono-Echo Detonation: Any `ChronoEchoData` left behind in an era detonates when the player shifts into that era, executing cross-era AOE slices.

---

## 5. Automated Test Runner Setup & Analysis

### 5.1 Test Execution Script (`run_tests.bat`)
`run_tests.bat` executes the 5 Godot test suites sequentially using the Godot Engine executable in `--headless` mode:
```bat
@echo off
set "GODOT_PATH=D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
set "PROJ=%~dp0new-game-project"

"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_core.gd 2>&1
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_chrono_and_timeline.gd 2>&1
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_modular_rig.gd 2>&1
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_game_integration.gd 2>&1
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_adversarial_disprover.gd 2>&1
```

### 5.2 Test Suites Breakdown
1. **Suite 1: Core Kinematics & Combat Suite (`res://tests/test_core.gd`)**:
   - 42 tests covering kinematics, acceleration, jumps, coyote time, jump buffer, chrono energy, dilation math, katana arc, combo multipliers, enemy AI, wave manager, ragdolls, gunner AI, bullets, slow-mo dilation, kinetic dash recovery cancel, wall slide/rebound, heavy launcher, downward slam, and DMC style ranks.
   - Result: **42 / 42 PASSED**.
2. **Suite 2: Chronos Shift & Timeline Suite (`res://tests/test_chrono_and_timeline.gd`)**:
   - 35 tests covering H-gate geometry, anti-tunneling fuzzing, detents, engagement, energy drain, gear persistence on release, stall recovery, fuzz input, camera shake, acclimatization, Reverse Gear, timeline switching at Chronos Wells, phase traversal, and Chrono-Echoes.
   - Result: **35 / 35 PASSED**.
3. **Suite 3: Modular Piece-by-Piece Rig Suite (`res://tests/test_modular_rig.gd`)**:
   - 190 test assertions covering `StickmanPoseSolver` across all 6 stances, bone transform calculations for all 20 PartSlots, Shift Staff 7-piece weapon assembly & Chronos Key alignment, runtime injection of sprites and polygons, ragdoll loadout splitting, JSON manifest export/import roundtrip, and AssetMcpBridge CLI.
   - Result: **190 / 190 PASSED**.
4. **Suite 4: End-to-End Game Scene Integration Suite (`res://tests/test_game_integration.gd`)**:
   - 12 end-to-end integration tests instantiating `GameController`, simulating player input, testing HUD updates, running, jumping, wall rebound, kinetic dash slash recovery cancellation, light slash kills with split ragdolls, heavy launcher juggles, downward slam shockwaves, parry sniper ricochet reflection & reverse gear kills, chrono warp beams, timeline shift & echo detonations, campaign traversal mode toggle, and live piece-by-piece modular customization cycling.
   - Result: **12 / 12 PASSED**.
5. **Suite 5: Disprover Adversarial Red-Team Suite (`res://tests/test_adversarial_disprover.gd`)**:
   - 17 adversarial attack scenarios testing extreme dt, NaN/Inf inputs across kinematics, combat math, enemy AI, ragdolls, H-gate, timeline system, pose solver, simultaneous bullet deflection + player contact, duplicate slice deduplication, rapid timeline cycling, reverse gear priority, turbo shifter boundary, malformed JSON manifests, invalid slot names, missing textures, ragdoll split preservation, and audio stress.
   - Result: **17 / 17 PASSED**.

**Total Test Count**: **296 / 296 PASSED (0 FAILED)**.

---

## 6. Godot Engine & Godot MCP Tooling Survey

### 6.1 Project Load & Engine Health Check
- Executed:
  ```powershell
  cmd.exe /c '"D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "new-game-project" --check-only --quit 2>&1'
  ```
  Result: Clean exit code 0, zero errors, zero warnings.
- Executed Editor initialization:
  ```powershell
  cmd.exe /c '"D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "new-game-project" --editor --quit 2>&1'
  ```
  Result: All 5 initialization steps completed cleanly (`first_scan_filesystem`, `loading_editor_layout`), exit code 0, zero errors, zero warnings.

### 6.2 Identified Issues in `tools/godot-mcp`

During examination of `tools/godot-mcp`, two bugs were identified in the MCP tooling:

#### Bug 1: GDScript Boolean Falsy Trap in `godot_operations.gd`
- **Location**: `tools/godot-mcp/src/scripts/godot_operations.gd:53-55` and `tools/godot-mcp/build/scripts/godot_operations.gd:53-55`
- **Code**:
  ```gdscript
  if error == OK:
      params = json.get_data()
  else:
      log_error("Failed to parse JSON parameters: " + params_json)
      log_error("JSON Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
      quit(1)

  if not params:
      log_error("Failed to parse JSON parameters: " + params_json)
      quit(1)
  ```
- **Issue**: In GDScript 4, an empty Dictionary `{}` evaluates to `false` in a boolean context (`if not {}:` is `true`). When operations that take no arguments (e.g. `resave_resources "{}"`) are invoked, `json.get_data()` returns `{}`, triggering `if not params:`, which logs `[ERROR] Failed to parse JSON parameters: {}` and calls `quit(1)`.
- **Secondary Issue**: Neither line 51 nor line 55 contains a `return` statement after `quit(1)`. In GDScript, `quit(1)` schedules an exit on the main loop but does not abort execution of `_init()`, causing execution to fall through into `match operation:` and execute operations with invalid state.
- **Proposed Fix**:
  ```gdscript
  if error != OK:
      log_error("Failed to parse JSON parameters: " + params_json)
      log_error("JSON Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
      quit(1)
      return

  params = json.get_data()
  if params == null or not (params is Dictionary):
      log_error("Failed to parse JSON parameters (must be a JSON object): " + params_json)
      quit(1)
      return
  ```

#### Bug 2: ES Module Scope `require('fs')` Crash in `index.ts`
- **Location**: `tools/godot-mcp/src/index.ts:1438` and `tools/godot-mcp/build/index.js:1209`
- **Code**:
  ```typescript
  // Extract project name from project.godot file
  let projectName = basename(args.projectPath);
  try {
    const fs = require('fs');
    const projectFileContent = fs.readFileSync(projectFile, 'utf8');
  ...
  ```
- **Issue**: `tools/godot-mcp` is configured as an ES module (`"type": "module"` in `package.json`). In standard ES module environments, CommonJS `require` is not defined. Calling `require('fs')` throws a `ReferenceError: require is not defined in ES module scope`. In `handleGetProjectInfo`, this causes the `try...catch` block to catch the error and fail to read `project.godot`, silently defaulting the project name to the folder name.
- **Proposed Fix**: Use the already-imported `fs` methods or import `readFileSync` directly from `'fs'` at module top-level.

#### Configuration Note: `GODOT_PATH` Auto-Detection
- When running `tools/godot-mcp/build/index.js` on Windows, if the `GODOT_PATH` environment variable is not explicitly set, the server logs a warning that Godot cannot be found in common locations and falls back to `C:\Program Files\Godot\Godot.exe`. Setting `$env:GODOT_PATH="D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"` allows `godot-mcp` to start cleanly with zero warnings.

---

## 7. Conclusions and Next Steps for Implementer / Verifier
1. The game codebase (`new-game-project`) is fully operational, mathematically robust, and structurally clean with zero compilation or editor load errors.
2. The stickman rig, procedural pose solver, 20-slot modular equipment architecture, and 11-slot weapon assembly are cleanly decoupled from Godot's scene tree, enabling high-performance canvas drawing and headless testing.
3. Fixing Bug 1 and Bug 2 in `tools/godot-mcp` will ensure seamless Godot MCP operations when inspecting project metadata and executing CLI operations.
