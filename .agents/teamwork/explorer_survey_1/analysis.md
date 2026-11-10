# GDScript Static Analysis & Phase 0 Survey Report

**Project**: `new-game-project` (Godot Engine v4.7.2.stable.steam.ed1daf0bf)  
**Survey Agent**: `teamwork_explorer` (`explorer_survey_1`)  
**Date**: 2026-11-10  
**Status**: Survey Complete — 6 Engine Warnings & 23 Dynamic Typing / Discarded Return Items Identified  

---

## 1. Executive Summary

A comprehensive static analysis, compilation check, scene execution, and Godot MCP inspection was conducted across all 16 GDScript files, 1 scene file (`scenes/main.tscn`), asset manifests, and project settings in `new-game-project`.

### Key Conclusions:
1. **0 Script Parse / Syntax Errors**: All 16 GDScript files compile cleanly in Godot 4.7.2 without syntax errors.
2. **0 Runtime Crash / Missing Resource Errors**: `scenes/main.tscn` loads and runs headlessly without missing dependencies, audio loading failures, or runtime crashes. All 5 unit and adversarial test suites (296 total test cases) pass with 100% clearance.
3. **6 Verbatim Godot 4.7 Engine Compiler Warnings**: When compiled in debug mode (`-d`) or loaded via the Godot MCP tooling, Godot Engine logs exactly 6 compiler warnings to `stderr` across 4 files.
4. **23 Static Typing / Discarded Return Code Quality Items**: 20 untyped dynamic variable declarations and 3 discarded return values from `Dictionary.erase()` exist across `combat_math.gd`, `game_controller.gd`, `modular_asset_system.gd`, and `asset_mcp_bridge.gd`.

---

## 2. Methodology & Inspection Environment

The survey employed a multi-vector verification strategy:
- **Godot 4.7.2 Headless Engine Compilation**: Executed `godot.windows.opt.tools.64.exe --headless --path <project> --check-only -s <file>` for all 16 scripts.
- **Engine Debug-Mode Static Reload Inspection**: Executed `godot.windows.opt.tools.64.exe -d --headless --path <project>` scanning every script with `ResourceLoader.load(..., CACHE_MODE_IGNORE)` to capture compiler output on `stderr`.
- **Godot MCP Tooling Live Inspection**: Ran the MCP server at `tools/godot-mcp/build/index.js` over stdio via JSON-RPC, executing `get_project_info`, `get_godot_version`, `run_project`, and `get_debug_output`.
- **AST / Token-Based Static Code Analysis**: Developed a custom multi-line tokenizer in Python analyzing all 10,500+ lines for type safety, shadowing, deprecations, and unused parameters.

---

## 3. Verbatim Godot Engine 4.7 Compiler Warnings

When running the project under debug mode (`-d`) or running via Godot MCP `run_project`, Godot Engine 4.7.2 emits the following 6 warnings to `stderr`:

### Warning 1: Built-in Identifier Shadowing (`len`)
- **Location**: `res://scripts/chrono_shift/chrono_shift_model.gd:210`
- **Engine Message**:
  ```text
  WARNING: The variable "len" has the same name as a built-in function.
     at: GDScript::reload (res://scripts/chrono_shift/chrono_shift_model.gd:210)
  ```
- **Code Context**:
  ```gdscript
  209: 		var d := Vector2(dx, dy)
  210: 		var len: float = d.length()
  211: 		if len <= 0.0:
  ```
- **Root Cause**: `len()` is a built-in function in GDScript. Declaring `var len` shadows this identifier.
- **Proposed Fix**:
  ```gdscript
  var d_len: float = d.length()
  if d_len <= 0.0:
  ```

---

### Warning 2: Incompatible Ternary Operator Return Types
- **Location**: `res://scripts/chrono_shift/chrono_shift_model.gd:940`
- **Engine Message**:
  ```text
  WARNING: Values of the ternary operator are not mutually compatible.
     at: GDScript::reload (res://scripts/chrono_shift/chrono_shift_model.gd:940)
  ```
- **Code Context**:
  ```gdscript
  939: 		is_dilating = dilation < DILATING_THRESHOLD
  940: 		dilation_edge = is_dilating if is_dilating != was else null
  ```
- **Root Cause**: The ternary operator `A if cond else B` requires compatible types. Branch `A` evaluates to `bool`, while branch `B` evaluates to `null` (`TYPE_NIL`). In GDScript static typing, mixing primitive `bool` with `null` without explicit Variant cast triggers a type incompatibility warning.
- **Proposed Fix**:
  ```gdscript
  if is_dilating != was:
  	dilation_edge = is_dilating
  else:
  	dilation_edge = null
  ```

---

### Warning 3: Method Shadowing by Function Parameter (`center_x`)
- **Location**: `res://scripts/timeline/timeline_system.gd:49`
- **Engine Message**:
  ```text
  WARNING: The local function parameter "center_x" is shadowing an already-declared function at line 76 in the current class.
     at: GDScript::reload (res://scripts/timeline/timeline_system.gd:49)
  ```
- **Code Context**:
  ```gdscript
  48: 	func _init(
  49: 		center_x: float = 0.0,
  50: 		p_y: float = 0.0,
  51: 		p_width: float = 200.0,
  ...
  76: 	func center_x() -> float:
  77: 		return (min_x + max_x) * 0.5
  ```
- **Root Cause**: The parameter `center_x` in `PhasePlatformData._init()` has the exact same name as the instance method `center_x()`. Notice other parameters in `_init()` use the `p_` convention (`p_y`, `p_width`, `p_era`).
- **Proposed Fix**:
  ```gdscript
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

---

### Warning 4: Unused Local Variable (`world_dt`)
- **Location**: `res://scripts/game/game_controller.gd:857`
- **Engine Message**:
  ```text
  WARNING: The local variable "world_dt" is declared but never used in the block. If this is intended, prefix it with an underscore: "_world_dt".
     at: GDScript::reload (res://scripts/game/game_controller.gd:857)
  ```
- **Code Context**:
  ```gdscript
  857: 	var world_dt: float = chrono.get_world_dt(dt)
  858: 	var player_dt: float = chrono.get_player_dt(dt)
  ```
- **Root Cause**: Inside `_step_simulation()`, `world_dt` is calculated but never referenced; player cooldowns and physics utilize `player_dt` or `dt`.
- **Proposed Fix**:
  ```gdscript
  var _world_dt: float = chrono.get_world_dt(dt)
  ```

---

### Warning 5: Base Class Method Shadowing (`tr`)
- **Location**: `res://scripts/game/game_controller.gd:2255`
- **Engine Message**:
  ```text
  WARNING: The local variable "tr" is shadowing an already-declared method in the base class "Object".
     at: GDScript::reload (res://scripts/game/game_controller.gd:2255)
  ```
- **Code Context**:
  ```gdscript
  2254: 	var tl := center_scr + Vector2(-w, -h)
  2255: 	var tr := center_scr + Vector2(w, -h)
  2256: 	var ml := center_scr + Vector2(-w, 0.0)
  ```
- **Root Cause**: `Object.tr()` is Godot's built-in translation method inherited by all Nodes. Declaring local variable `var tr` for "top-right" in `_draw_seven_segment_glyph()` shadows `Object.tr()`.
- **Proposed Fix**:
  ```gdscript
  var pt_tl := center_scr + Vector2(-w, -h)
  var pt_tr := center_scr + Vector2(w, -h)
  var pt_ml := center_scr + Vector2(-w, 0.0)
  var pt_mr := center_scr + Vector2(w, 0.0)
  var pt_bl := center_scr + Vector2(-w, h)
  var pt_br := center_scr + Vector2(w, h)
  ```

---

### Warning 6: Unused Local Variable in Test (`reg`)
- **Location**: `res://tests/test_adversarial_disprover.gd:698`
- **Engine Message**:
  ```text
  WARNING: The local variable "reg" is declared but never used in the block. If this is intended, prefix it with an underscore: "_reg".
     at: GDScript::reload (res://tests/test_adversarial_disprover.gd:698)
  ```
- **Code Context**:
  ```gdscript
  696: func attack_3b_invalid_slot_names_and_numbers_and_missing_textures() -> bool:
  697: 	var ok: bool = true
  698: 	var reg := ModularAssetScript.ModularAssetRegistry.new()
  ```
- **Root Cause**: In test `attack_3b_invalid_slot_names_and_numbers_and_missing_textures`, `reg` is allocated but only static method calls and direct struct inspections are performed.
- **Proposed Fix**:
  ```gdscript
  var _reg := ModularAssetScript.ModularAssetRegistry.new()
  ```

---

## 4. Static Typing & Code Quality Analysis

Beyond active engine warnings, static analysis flagged 23 locations where dynamic typing or unhandled return values can trigger warnings under strict GDScript warning presets:

### 4.1 Discarded Return Values (`RETURN_VALUE_DISCARDED`)
`Dictionary.erase()` returns a `bool` indicating whether the key existed. In Godot 4, discarding this without assignment can trigger `RETURN_VALUE_DISCARDED`:
1. `scripts/core/combat_math.gd:371`: `enemies_by_id.erase(eid)`
2. `scripts/modular_rig/modular_asset_system.gd:476`: `pieces.erase(slot)`
3. `scripts/modular_rig/modular_asset_system.gd:713`: `parts.erase(slot)`

*Remedy*: Explicitly silence or handle:
```gdscript
var _did_erase: bool = enemies_by_id.erase(eid)
```

### 4.2 Untyped Dynamic Variables (`UNTYPED_DECLARATION`)
In several locations, `var foo = ...` is used instead of static type hints or `:=`, resulting in unsafe member/method accesses on `Variant`:
1. `scripts/core/combat_math.gd:370, 500, 598`:
   ```gdscript
   var enemy = enemies_by_id[eid]
   # Recommendation:
   var enemy: EnemyAI.EnemyData = enemies_by_id.get(eid, null)
   ```
2. `scripts/game/game_controller.gd:1179`:
   ```gdscript
   var e = enemies[i]
   # Recommendation:
   var e: Variant = enemies[i]
   ```
3. `scripts/tools/asset_mcp_bridge.gd:33, 61, 112, 147`:
   Untyped `var parsed = JSON.parse_string(...)` and `var spec = ...`.
   *Recommendation*: `var parsed: Variant = ...` and `var spec: ModularAssetSystem.PartPieceSpec = ...`.
4. `scripts/modular_rig/modular_asset_system.gd` (15 locations):
   JSON dictionary parsing lines using `var raw_pieces = d.get(...)`.
   *Recommendation*: Add explicit `: Variant` or `: Dictionary` annotations.

---

## 5. Autoload & Project Setting Audit

### 5.1 Autoloads
- **Status**: Clean. No autoloads are declared in `project.godot`.
- **Architecture**: The project adopts a clean, deterministic object lifecycle where `GameController` acts as the root orchestrator and instantiates its sub-systems (`chrono`, `player`, `energy`, `combo`, `wave_mgr`, `shifter`, `timeline`, `asset_registry`, `audio_mgr`) in `_init()` and `_ensure_scene_nodes()`. All subsystem scripts register global classes via `class_name`. There are zero circular autoload dependencies or singleton race conditions.

### 5.2 Project Settings (`project.godot`)
- **Godot Version Compatibility**: `config/features=PackedStringArray("4.7", "Forward Plus")` — Fully matches Godot Engine 4.7.
- **Rendering Driver**: `rendering_device/driver.windows="d3d12"` — Successfully initializes Direct3D 12 on Windows with NVIDIA RTX 5070.
- **Physics Engine**: `3d/physics_engine="Jolt Physics"` — Present in configuration. The project is 2D and does not instantiate 3D physics nodes; no errors are generated.
- **Scene UIDs**: `main.tscn` is defined with `[gd_scene format=3]` without an embedded `uid="uid://..."` tag. Godot MCP's `get_uid` reports that no `.uid` file exists. Adding a UID or resaving via Godot MCP is optional but adheres to Godot 4.4+ best practices.

---

## 6. Deprecated / Obsolete Godot 3 / 4.x Methods

A comprehensive scan against Godot 3/4 deprecation patterns (`instance()`, `yield()`, `rand_range()`, `export(...)`, `onready var`, `File.new()`, `Directory.new()`, string-based signals) yielded **zero instances**. The codebase adheres strictly to modern Godot 4 syntax:
- Uses `instantiate()`
- Uses `await`
- Uses `randf_range()`
- Uses `@export` and `@onready`
- Uses `Callable`-based signals (`signal.connect(...)`)
- Uses `FileAccess` and `DirAccess` static APIs.

---

## 7. Inventory of Analyzed Files

| File Path | Lines | Compile Status | Warnings / Issues Found |
|---|---|---|---|
| `scripts/chrono_shift/chrono_shift_model.gd` | 958 | Pass | 2 Warnings (shadowed `len`, incompatible ternary) |
| `scripts/timeline/timeline_system.gd` | 588 | Pass | 1 Warning (parameter `center_x` shadows method) |
| `scripts/game/game_controller.gd` | 2275 | Pass | 2 Warnings (unused `world_dt`, shadowed `tr`), 1 untyped var |
| `scripts/core/combat_math.gd` | 640 | Pass | 0 Warnings, 1 discarded return, 3 untyped vars |
| `scripts/modular_rig/modular_asset_system.gd` | 1806 | Pass | 0 Warnings, 2 discarded returns, 15 untyped vars |
| `scripts/tools/asset_mcp_bridge.gd` | 174 | Pass | 0 Warnings, 4 untyped vars |
| `scripts/core/enemy_ai.gd` | 588 | Pass | Clean (0 issues) |
| `scripts/core/player_kinematics.gd` | 296 | Pass | Clean (0 issues) |
| `scripts/core/ragdoll_physics.gd` | 209 | Pass | Clean (0 issues) |
| `scripts/core/time_control.gd` | 94 | Pass | Clean (0 issues) |
| `scripts/game/audio_manager.gd` | 86 | Pass | Clean (0 issues) |
| `tests/test_adversarial_disprover.gd` | 872 | Pass | 1 Warning (unused `reg`), 1 untyped var |
| `tests/test_chrono_and_timeline.gd` | 1029 | Pass | Clean (0 issues) |
| `tests/test_core.gd` | 988 | Pass | Clean (0 issues) |
| `tests/test_game_integration.gd` | 438 | Pass | Clean (0 issues) |
| `tests/test_modular_rig.gd` | 365 | Pass | Clean (0 issues) |
| `scenes/main.tscn` | 7 | Pass | Valid 2D scene, missing UID tag |
| `project.godot` | 32 | Pass | Valid Godot 4.7 configuration |
