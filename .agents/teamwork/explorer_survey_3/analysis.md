# Phase 0 Survey: Scene Hierarchy, Resources & Dependency Audit

**Explorer Agent**: `teamwork_explorer` (`explorer_survey_3`)  
**Date**: 2026-11-10  
**Project**: OUT OF TIME — Chronos Shift (`new-game-project`)  
**Godot Engine Version**: `4.7.2.stable.steam.ed1daf0bf`  
**Godot Executable**: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`  
**Working Directory**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_survey_3`  

---

## Executive Summary

A comprehensive read-only survey and audit of all scenes (`.tscn`), resources (`.tres`), shaders (`.gdshader`), materials, tilemaps, fonts, textures, audio assets, and dependency links was executed for `new-game-project`.

### Core Findings
1. **Scene Architecture**: There is exactly **1 scene** in the project (`res://scenes/main.tscn`). It is a lean, declarative root scene (`Node2D` with attached script `res://scripts/game/game_controller.gd`). All child nodes (`GameAudioManager`, `Camera2D`, and 14 `CanvasLayer` HUD controls) are constructed dynamically at runtime in `_ensure_scene_nodes()` and `_build_hud()`.
2. **Headless Loading**: Loading `scenes/main.tscn` headlessly via Godot Engine (`--headless --path ... scenes/main.tscn --quit-after 60`) executed cleanly in **1.21 seconds with exit code 0**. Zero node configuration warnings, zero crashes, zero null reference errors, and zero missing dependency errors were observed.
3. **Asset & Resource Health**:
   - **0 corrupted resources** or broken `ExtResource` / `SubResource` links exist.
   - **0 circular dependencies** detected across the 16 GDScript files and 1 scene.
   - All 7 audio assets (`assets/audio/*.wav`) and 1 texture (`icon.svg`) have matching `.import` files and compiled cache files in `.godot/imported/`.
   - `assets/modular_parts_manifest.json` is well-formed JSON, successfully validated and round-tripped by `ModularAssetSystem`.
4. **Collision & Rendering Architecture**:
   - The project uses **no `CollisionShape2D` or physics collision nodes**. Instead, it implements a pure, deterministic mathematical simulation (`PlayerKinematics`, `CombatMath`, `EnemyAI`, `RagdollPhysics`).
   - The project uses **0 `.gdshader` files and 0 material files**. All visuals (characters, weapons, particles, slashes, warps, shockwaves, seven-segment HUD displays) are rendered through procedural 2D canvas drawing (`_draw()`).
5. **Identified Warnings & Hygiene Discrepancies**:
   - **6 GDScript compiler/runtime warnings** were identified and traced to exact lines in `chrono_shift_model.gd`, `timeline_system.gd`, `game_controller.gd`, and `test_adversarial_disprover.gd`.
   - **1 Scene UID Hygiene Issue**: `scenes/main.tscn` is missing a `uid="..."` attribute in its header and has no `main.tscn.uid` file. Furthermore, its script reference omits `uid="uid://ehegx2l4nndh"`.

---

## 1. Asset & Resource Inventory Catalog

The complete non-engine asset inventory of `new-game-project` was audited:

| Resource Path | Type | On-Disk Size | UID Status | Verification Result |
|---|---|---|---|---|
| `scenes/main.tscn` | `PackedScene` (Scene) | 217 B | None (Missing UID) | **PASS** — Instantiates `GameController` |
| `icon.svg` | `CompressedTexture2D` | 995 B | `uid://4q335xxs2p` | **PASS** — Imported & valid |
| `assets/audio/dash.wav` | `AudioStreamWAV` | 14,156 B | `uid://pm7kjhhuylmx` | **PASS** — Imported & valid |
| `assets/audio/jump.wav` | `AudioStreamWAV` | 12,392 B | `uid://d1wmch8y1kgik` | **PASS** — Imported & valid |
| `assets/audio/slash.wav` | `AudioStreamWAV` | 15,920 B | `uid://c435i5q1lhpi8` | **PASS** — Imported & valid |
| `assets/audio/slice_kill.wav` | `AudioStreamWAV` | 19,448 B | `uid://bbg84mfl7kssc` | **PASS** — Imported & valid |
| `assets/audio/slowmo_enter.wav` | `AudioStreamWAV` | 30,912 B | `uid://dn7d5h0vhbpab` | **PASS** — Imported & valid |
| `assets/audio/slowmo_exit.wav` | `AudioStreamWAV` | 22,094 B | `uid://pw7cjilgu32d` | **PASS** — Imported & valid |
| `assets/audio/warp.wav` | `AudioStreamWAV` | 22,976 B | `uid://gf5br6ho5wig` | **PASS** — Imported & valid |
| `assets/modular_parts_manifest.json` | JSON Data Manifest | 1,458 B | N/A | **PASS** — Validates schema |
| `scripts/chrono_shift/chrono_shift_model.gd` | `GDScript` | 30,867 B | `uid://dpytqcvl1k1re` | **PASS** — Compiles with 2 warnings |
| `scripts/core/combat_math.gd` | `GDScript` | 23,285 B | `uid://ch8ptmqkn30ti` | **PASS** — Compiles clean |
| `scripts/core/enemy_ai.gd` | `GDScript` | 14,845 B | `uid://cmtj1tv1ggmb0` | **PASS** — Compiles clean |
| `scripts/core/player_kinematics.gd` | `GDScript` | 10,241 B | `uid://6u441pbdfear` | **PASS** — Compiles clean |
| `scripts/core/ragdoll_physics.gd` | `GDScript` | 10,871 B | `uid://ccg7qkfurual` | **PASS** — Compiles clean |
| `scripts/core/time_control.gd` | `GDScript` | 3,110 B | `uid://gfu0q0bkgqax` | **PASS** — Compiles clean |
| `scripts/game/audio_manager.gd` | `GDScript` | 3,892 B | `uid://bobapkgj8586p` | **PASS** — Compiles clean |
| `scripts/game/game_controller.gd` | `GDScript` | 82,972 B | `uid://ehegx2l4nndh` | **PASS** — Compiles with 2 warnings |
| `scripts/modular_rig/modular_asset_system.gd` | `GDScript` | 44,792 B | `uid://b7d3nasghwg3j` | **PASS** — Compiles clean |
| `scripts/timeline/timeline_system.gd` | `GDScript` | 20,254 B | `uid://ckxl7jk8g114v` | **PASS** — Compiles with 1 warning |
| `scripts/tools/asset_mcp_bridge.gd` | `GDScript` | 6,087 B | `uid://liv7k71oofsh` | **PASS** — Compiles clean |
| `tests/test_core.gd` | `GDScript` (Test Suite 1) | 26,050 B | `uid://bp5combxaha0r` | **PASS** — 42/42 tests pass |
| `tests/test_chrono_and_timeline.gd` | `GDScript` (Test Suite 2) | 25,607 B | `uid://doiafy0pquh6g` | **PASS** — 35/35 tests pass |
| `tests/test_modular_rig.gd` | `GDScript` (Test Suite 3) | 16,505 B | `uid://wt6ornt6yg62` | **PASS** — 190/190 tests pass |
| `tests/test_game_integration.gd` | `GDScript` (Test Suite 4) | 18,229 B | `uid://nalwi40gf7c6` | **PASS** — 12/12 tests pass |
| `tests/test_adversarial_disprover.gd` | `GDScript` (Test Suite 5) | 41,555 B | `uid://4vxygl03ow0v` | **PASS** — 17/17 tests pass (1 warning) |

---

## 2. Scene Hierarchy & Node Audit

### 2.1 Analysis of `scenes/main.tscn`
The file contents of `scenes/main.tscn` are:
```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/game/game_controller.gd" id="1_game_controller"]

[node name="GameController" type="Node2D"]
script = ExtResource("1_game_controller")
```

### 2.2 Procedural Scene Graph Construction
Instead of storing child nodes in static `.tscn` files, `GameController` constructs the entire runtime node tree procedurally upon instantiation:
- **Audio Subsystem**: `GameAudioManager` node instantiated, assigned name `"GameAudioManager"`, and added as child node (`add_child(audio_mgr)`). Preloads and manages all 7 sound effects.
- **Camera Subsystem**: `Camera2D` node instantiated, assigned name `"MainCamera2D"`, enabled, and added as child node (`add_child(camera)`). Smoothly interpolates camera position to follow player coordinates with lookahead and screen shake.
- **HUD Subsystem**: `CanvasLayer` node instantiated with name `"HUDLayer"`, parenting a rich hierarchy of 14 UI controls:
  - `TopLeftHUD` (`VBoxContainer`): Health bar + label, Chrono energy bar + label, Era indicator label, Modular Rig piece status label.
  - `TopCenterHUD` (`VBoxContainer`): Wave / Campaign Zone banner label, Time Dilation active banner label.
  - `TopRightHUD` (`VBoxContainer`): Score label, Combo multiplier label, DMC-style Style Rank label, 6-speed Shifter status readout.
  - `ControlsLabel` (`Label`): Centered bottom key binding reference guide.

### 2.3 Node Configuration Warnings
Inspection of instantiated `GameController` and all runtime children (`GameAudioManager`, `Camera2D`, `CanvasLayer`, controls) confirmed:
- `node.get_configuration_warnings()` returned **0 configuration warnings**.
- No orphan nodes or missing node references.

### 2.4 Collision Shape Architecture
A dedicated check was conducted for missing `CollisionShape2D` nodes:
- Godot scenes that use `CharacterBody2D`, `RigidBody2D`, or `Area2D` require a `CollisionShape2D` or `CollisionPolygon2D` child to avoid editor warnings.
- However, `OUT OF TIME` does **not** use Godot's built-in physics collision nodes. It implements a pure mathematical, deterministic simulation loop inside `step_simulation(delta, input)`:
  - Horizontal & vertical velocities, coyote time, and jump buffers are computed in `PlayerKinematics`.
  - Katana arc sweeps, bullet reflections, and slice planes are calculated mathematically in `CombatMath`.
  - Platform bounds are stored as lightweight `PhasePlatformData` value objects.
  - Severed limbs are computed via analytical impulse distribution in `RagdollPhysics`.
- **Verdict**: There are no missing collision shapes; the absence of `CollisionShape2D` nodes is by design and results in zero physics server overhead.

---

## 3. Dependency & UID Integrity Audit

### 3.1 ExtResource Reference Verification
- `scenes/main.tscn` contains exactly one `ExtResource`:
  - `id="1_game_controller"` -> `path="res://scripts/game/game_controller.gd"`
  - Target file exists at `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project\scripts\game\game_controller.gd` (82,972 bytes).
  - Target script is syntactically valid and loads cleanly.
- No `SubResource` blocks exist in `main.tscn`.

### 3.2 Script Dependencies & Circular Dependency Audit
All cross-script dependencies use `preload("res://...")` or global class identifiers (`ChronoState`, `PlayerKinematics`, `CombatMath`, `EnemyAI`, `ModularAssetSystem`, `TimelineSystem`).
- The call hierarchy forms a strict Directed Acyclic Graph (DAG):
  - Leaf modules: `time_control.gd`, `player_kinematics.gd`, `ragdoll_physics.gd`
  - Core combat: `combat_math.gd`, `enemy_ai.gd`
  - Timeline & Shifter: `chrono_shift_model.gd`, `timeline_system.gd`
  - Asset Registry: `modular_asset_system.gd`
  - Integration: `game_controller.gd`
  - Bridge & Tests: `asset_mcp_bridge.gd`, `tests/*.gd`
- **Verdict**: Circular dependency check passed with **0 cycles detected**.

### 3.3 UID Consistency Audit
Godot 4.4+ utilizes Unique Resource Identifiers (`uid://...`) to track and remap resources independently of disk paths. An audit across all project files revealed:

1. **Scripts (`scripts/*.gd` & `tests/*.gd`)**:
   - All 16 `.gd` files have corresponding `.gd.uid` companion files.
   - Every on-disk UID exactly matches the Godot cache (`.godot/uid_cache.bin`).
2. **Audio & Textures (`assets/audio/*.wav` & `icon.svg`)**:
   - All 7 `.wav.import` files and `icon.svg.import` contain valid `uid="..."` entries.
   - All imported files match the cache.
3. **Discrepancy in `scenes/main.tscn`**:
   - `scenes/main.tscn` has **no `uid="..."` attribute** in its header line `[gd_scene load_steps=2 format=3]`.
   - `scenes/main.tscn` has **no `.uid` companion file** on disk (`scenes/main.tscn.uid` does not exist).
   - In `scenes/main.tscn`, line 3 `[ext_resource type="Script" path="res://scripts/game/game_controller.gd" id="1_game_controller"]` **omits the script's UID** (`uid="uid://ehegx2l4nndh"`).
   - *Impact*: In Godot 4.4+, if files are moved or renamed, resources lacking UIDs cannot be automatically re-linked. Generating and adding UIDs ensures long-term editor hygiene.

---

## 4. Shaders, Materials, Tilemaps, and Fonts Audit

### 4.1 Shader & Material Audit
- Total `.gdshader` / `.shader` files found: **0**.
- Total `Material` / `ShaderMaterial` resources found: **0**.
- Visuals are drawn directly on the canvas using Godot's immediate-style rendering API inside `GameController._draw()`:
  - `draw_colored_polygon()` for armored body parts, pauldron plates, weapon teeth, and severed ragdoll pieces.
  - `draw_polyline()` / `draw_line()` for bone lines, joints, seven-segment digits, and lasers.
  - `draw_arc()` / `draw_circle()` for gears, shockwaves, knobs, and detents.
- **Verdict**: Zero missing shader uniforms, zero invalid shader compilation errors, and zero unsupported material parameters.

### 4.2 TileMap Audit
- Total `TileMap` / `TileSet` resources found: **0**.
- Platforms and era-specific terrain (Past stone bridge, Present steel catwalk, Future hard-light bridge) are modeled as parametric bounding boxes (`PhasePlatformData`) and rendered via `_draw_platform()` in `GameController`.
- **Verdict**: Zero broken tilemap references or missing tileset atlas textures.

### 4.3 Font Audit
- Total custom font files (`.ttf`, `.otf`) found: **0**.
- All HUD labels (`HealthLabel`, `EnergyLabel`, `EraLabel`, `RigLabel`, `WaveLabel`, `ScoreLabel`, `ComboLabel`, `StyleRankLabel`, `ShifterReadoutLabel`, `ControlsLabel`) utilize the Godot default system font with `add_theme_color_override("font_color", ...)`.
- **Verdict**: Zero font file lookup errors.

---

## 5. Headless Godot CLI Execution & Scene Loading Verification

### 5.1 Verification Commands and Output

#### Test 1: Headless Scene Loading Benchmark (60 frames)
Command:
```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project" scenes/main.tscn --quit-after 60 2>&1 | Out-String
```
Output:
```text
Godot Engine v4.7.2.stable.steam.ed1daf0bf - https://godotengine.org
```
- Exit code: `0`
- Duration: ~1.2 seconds.
- Result: Clean execution, 0 crashes, 0 errors.

#### Test 2: Verbose Dependency Loading Verification
Command:
```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --verbose --path "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project" scenes/main.tscn --quit-after 60 2>&1 | Out-String
```
Output Snippet:
```text
Loaded system CA certificates
Loading resource: res://scenes/main.tscn remapped: res://scenes/main.tscn
Loading resource: res://scripts/game/game_controller.gd remapped: res://scripts/game/game_controller.gd
Completed load for: 'res://scripts/game/game_controller.gd' remapped 'res://scripts/game/game_controller.gd' at thread -1
Completed load for: 'res://scenes/main.tscn' remapped 'res://scenes/main.tscn' at thread -1
Loading resource: res://assets/audio/slash.wav remapped: res://assets/audio/slash.wav
Loading resource: res://.godot/imported/slash.wav-c23cb59b0ceabbfe38a50714459d5291.sample remapped: res://.godot/imported/slash.wav-c23cb59b0ceabbfe38a50714459d5291.sample
Completed load for: 'res://assets/audio/slash.wav' remapped 'res://assets/audio/slash.wav' at thread -1
Loading resource: res://assets/audio/warp.wav remapped: res://assets/audio/warp.wav
...
Completed load for: 'res://assets/audio/jump.wav' remapped 'res://assets/audio/jump.wav' at thread -1
```
- Result: All 7 audio assets and scripts loaded and remapped without failure.

#### Test 3: Full Automated Test Suite Regression
Command:
```bat
cmd /c "run_tests.bat"
```
Results:
- **Suite 1: Core Kinematics & Combat**: 42/42 tests passed.
- **Suite 2: Chronos Shift & Timeline**: 35/35 tests passed.
- **Suite 3: Modular Rig & Asset System**: 190/190 tests passed.
- **Suite 4: End-to-End Game Integration**: 12/12 tests passed.
- **Suite 5: Disprover Adversarial Red-Team**: 17/17 tests passed.
- **Overall Total**: **296 / 296 tests passed (0 failures)**.

---

## 6. Detailed Issue Registry & Remediation Proposals

While the engine and test suites run with 100% test clearance, the survey identified **6 GDScript compiler warnings** logged during script compilation/reloading, plus **1 UID metadata hygiene issue**:

### Issue 1: Built-in Function Shadowing (`len`)
- **File**: `res://scripts/chrono_shift/chrono_shift_model.gd`
- **Line**: 210
- **Verbatim Warning**: `WARNING: The variable "len" has the same name as a built-in function. at: GDScript::reload (res://scripts/chrono_shift/chrono_shift_model.gd:210)`
- **Root Cause**: The local variable `len` in `constrain_step()` shares its name with the built-in GDScript function `len(var)`.
- **Proposed Fix**:
```gdscript
# Before:
var len: float = d.length()
if len <= 0.0:
    return curr

# After:
var d_len: float = d.length()
if d_len <= 0.0:
    return curr
```

### Issue 2: Incompatible Ternary Operator Return Types
- **File**: `res://scripts/chrono_shift/chrono_shift_model.gd`
- **Line**: 940
- **Verbatim Warning**: `WARNING: Values of the ternary operator are not mutually compatible. at: GDScript::reload (res://scripts/chrono_shift/chrono_shift_model.gd:940)`
- **Root Cause**: In `dilation_edge = is_dilating if is_dilating != was else null`, the true branch evaluates to `bool` while the false branch evaluates to `null` (`Nil`). The GDScript type checker warns on mismatched ternary branch types.
- **Proposed Fix**:
```gdscript
# Before:
dilation_edge = is_dilating if is_dilating != was else null

# After:
if is_dilating != was:
    dilation_edge = is_dilating
else:
    dilation_edge = null
```

### Issue 3: Local Parameter Shadowing Member Function (`center_x`)
- **File**: `res://scripts/timeline/timeline_system.gd`
- **Line**: 49
- **Verbatim Warning**: `WARNING: The local function parameter "center_x" is shadowing an already-declared function at line 76 in the current class. at: GDScript::reload (res://scripts/timeline/timeline_system.gd:49)`
- **Root Cause**: In class `PhasePlatformData`, `_init(center_x: float = 0.0, ...)` declares parameter `center_x`, which shadows the member function `func center_x() -> float:` declared on line 76.
- **Proposed Fix**:
```gdscript
# Before:
func _init(
    center_x: float = 0.0,
    p_y: float = 0.0,
    p_width: float = 200.0,
    p_era: int = -1,
    p_thickness: float = 12.0
) -> void:
    min_x = center_x - p_width * 0.5
    max_x = center_x + p_width * 0.5

# After:
func _init(
    p_center_x: float = 0.0,
    p_y: float = 0.0,
    p_width: float = 200.0,
    p_era: int = -1,
    p_thickness: float = 12.0
) -> void:
    min_x = p_center_x - p_width * 0.5
    max_x = p_center_x + p_width * 0.5
```

### Issue 4: Unused Local Variable (`world_dt`)
- **File**: `res://scripts/game/game_controller.gd`
- **Line**: 857
- **Verbatim Warning**: `WARNING: The local variable "world_dt" is declared but never used in the block. If this is intended, prefix it with an underscore: "_world_dt". at: GDScript::reload (res://scripts/game/game_controller.gd:857)`
- **Root Cause**: `var world_dt: float = chrono.get_world_dt(dt)` is declared at line 857, but never referenced. Later at line 939, `var updated_world_dt: float = chrono.get_world_dt(dt)` is declared and passed to `_step_world_entities()`.
- **Proposed Fix**: Remove the redundant declaration on line 857.

### Issue 5: Local Variable Shadowing Object Base Method (`tr`)
- **File**: `res://scripts/game/game_controller.gd`
- **Line**: 2255
- **Verbatim Warning**: `WARNING: The local variable "tr" is shadowing an already-declared method in the base class "Object". at: GDScript::reload (res://scripts/game/game_controller.gd:2255)`
- **Root Cause**: In `_draw_seven_segment_glyph()`, `var tr := center_scr + Vector2(w, -h)` (top-right corner) shadows the built-in translation method `Object.tr(message)`.
- **Proposed Fix**:
```gdscript
# Before:
var tl := center_scr + Vector2(-w, -h)
var tr := center_scr + Vector2(w, -h)
...
if segs[0]:
    _d_line(tl, tr, col, 1.8) # a (top)
if segs[1]:
    _d_line(tr, mr, col, 1.8) # b (top-right)

# After:
var tl := center_scr + Vector2(-w, -h)
var pt_tr := center_scr + Vector2(w, -h)
...
if segs[0]:
    _d_line(tl, pt_tr, col, 1.8) # a (top)
if segs[1]:
    _d_line(pt_tr, mr, col, 1.8) # b (top-right)
```

### Issue 6: Unused Local Variable (`reg`) in Adversarial Attack Test
- **File**: `res://tests/test_adversarial_disprover.gd`
- **Line**: 698
- **Verbatim Warning**: `WARNING: The local variable "reg" is declared but never used in the block. If this is intended, prefix it with an underscore: "_reg". at: GDScript::reload (res://tests/test_adversarial_disprover.gd:698)`
- **Root Cause**: In `attack_3b_invalid_slot_names_and_numbers_and_missing_textures()`, `var reg := ModularAssetScript.ModularAssetRegistry.new()` is allocated but never used.
- **Proposed Fix**: Prefix with underscore: `var _reg := ModularAssetScript.ModularAssetRegistry.new()` or remove the unused line.

### Issue 7: Missing UID Attributes on `scenes/main.tscn`
- **File**: `res://scenes/main.tscn`
- **Lines**: 1, 3
- **Root Cause**: Scene file lacks a top-level UID and lacks the explicit `uid="uid://ehegx2l4nndh"` attribute on its ExtResource script binding.
- **Proposed Fix**:
```ini
# Before:
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/game/game_controller.gd" id="1_game_controller"]

# After (generated by Godot ResourceSaver / MCP resave_resources):
[gd_scene load_steps=2 format=3 uid="uid://df6g8a01k2main"]

[ext_resource type="Script" uid="uid://ehegx2l4nndh" path="res://scripts/game/game_controller.gd" id="1_game_controller"]
```

---

## 7. Downstream Implementation Recommendations

1. **Clean Compiler Warnings**: In the subsequent Implementation Phase, apply the 6 localized patches identified above. Because all 6 are variable renamings or formatting adjustments, they carry zero functional risk and will eliminate 100% of the warnings logged to `godot.log`.
2. **Resave Scene UIDs**: Run `godot-mcp`'s `update_project_uids` (or invoke `godot_operations.gd resave_resources`) during the write phase to stamp `main.tscn` and its ExtResource with official Godot 4.7 UIDs.
3. **Automated Verification Gate**: Ensure that any future edits continue to pass all 5 test suites (`run_tests.bat`) with zero regression.
