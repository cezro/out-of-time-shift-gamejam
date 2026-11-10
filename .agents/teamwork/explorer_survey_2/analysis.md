# Phase 0 Survey: Godot MCP Tooling & Runtime Engine Diagnostics

**Explorer Agent**: `explorer_survey_2`  
**Date**: 2026-11-10  
**Project**: OUT OF TIME — Chronos Shift (`new-game-project`)  
**Godot Version**: `4.7.2.stable.steam.ed1daf0bf`  
**Godot Executable**: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`  
**Godot MCP Directory**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\tools\godot-mcp`  

---

## 1. Executive Summary

A comprehensive, read-only diagnostic survey was conducted across the Godot engine runtime, editor loading pipeline, test suites, and the Godot MCP tooling.

### Key Conclusions:
1. **Engine & Project Health**: The project is exceptionally stable at runtime. There are **0 crashes**, **0 null pointer exceptions**, **0 unhandled exceptions**, **0 `get_node` lookup failures**, and **0 missing signal connections**. All 5 unit and integration test suites pass 100% (296/296 total test assertions across the repository).
2. **Godot MCP Tooling**: The server located in `tools/godot-mcp` is fully functional and built. It communicates over stdio JSON-RPC using `@modelcontextprotocol/sdk: 0.6.0`. It successfully drives Godot operations (version queries, project info, project execution, debug output retrieval, UID lookups).
   - *Critical Discovery*: The Windows path auto-detection in `tools/godot-mcp/src/index.ts` does not include Steam's library directory. To operate correctly, `GODOT_PATH="D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"` must be set in the environment or passed in configuration.
3. **Warnings Identified**: Exactly **6 GDScript compiler/runtime warnings** were emitted to `stderr` and captured via Godot MCP's `get_debug_output`. Resolving these 6 isolated code patterns will satisfy the project's requirement of zero console/editor warnings.

---

## 2. Godot MCP Tooling Deep Dive

### 2.1 Architecture and Implementation
The Godot MCP server (`tools/godot-mcp`) provides AI assistants with a bridge to Godot Engine 4.x via Model Context Protocol:
- **Core Files**:
  - `tools/godot-mcp/package.json`: Configured with `"type": "module"`, dependencies `@modelcontextprotocol/sdk: 0.6.0`, `axios: ^1.7.9`, `fs-extra: ^11.2.0`.
  - `tools/godot-mcp/src/index.ts` & `build/index.js`: Main MCP server implementing stdio JSON-RPC transport and handlers.
  - `tools/godot-mcp/build/scripts/godot_operations.gd`: Headless GDScript runner invoked via `godot --headless --path <project> --script godot_operations.gd <op> <params>`.
  - `new-game-project/scripts/tools/asset_mcp_bridge.gd`: In-project companion script mirroring modular part/weapon registration into `assets/modular_parts_manifest.json`.

### 2.2 Available MCP Tools
| Tool Name | Type | Mechanism | Verified Status |
|---|---|---|---|
| `get_godot_version` | Query | `execFile(godotPath, ['--version'])` | **PASS** — Returns `4.7.2.stable.steam.ed1daf0bf` |
| `list_projects` | Discovery | Scans directory for `project.godot` files | **PASS** — Finds `new-game-project` |
| `get_project_info` | Inspection | Scans scenes, scripts, assets, parses `project.godot` | **PASS** — Reports 1 scene, 16 scripts, 8 assets |
| `run_project` | Execution | `spawn(godotPath, ['-d', '--path', projectPath, ...scene])` | **PASS** — Starts project, captures stdout & stderr |
| `get_debug_output` | Inspection | Returns accumulated stdout and stderr lines from running process | **PASS** — Captures realtime output & warnings |
| `stop_project` | Control | Kills active Godot child process | **PASS** — Clean termination |
| `get_uid` | UID Management | Invokes `godot_operations.gd get_uid` | **PASS** — Returns UID status JSON |
| `update_project_uids` | UID Management | Invokes `godot_operations.gd resave_resources` | Available |
| `launch_editor` | GUI Launch | Spawns `godot -e --path <projectPath>` | Available |
| `create_scene` / `add_node` / `load_sprite` / `save_scene` / `export_mesh_library` | Scene Ops | Headless SceneTree operations via `godot_operations.gd` | Available |

### 2.3 Auto-Detection Caveat on Windows
In `tools/godot-mcp/src/index.ts` (lines 317-324):
```typescript
} else if (osPlatform === 'win32') {
  possiblePaths.push(
    'C:\\Program Files\\Godot\\Godot.exe',
    'C:\\Program Files (x86)\\Godot\\Godot.exe',
    'C:\\Program Files\\Godot_4\\Godot.exe',
    'C:\\Program Files (x86)\\Godot_4\\Godot.exe',
    `${process.env.USERPROFILE}\\Godot\\Godot.exe`
  );
}
```
Steam installs Godot to user-selected library paths (e.g. `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`). While macOS checks Steam paths, the win32 section does not.  
**Resolution**: Set `process.env.GODOT_PATH = "D:\\SteamLibrary\\steamapps\\common\\Godot Engine\\godot.windows.opt.tools.64.exe"`.

---

## 3. Runtime Engine Execution & Diagnostics

### 3.1 Editor Import Scan (`--headless --editor --import -v`)
Executing the editor scan:
```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --editor --import --path "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project" -v
```
**Results**:
- File scanning: 100% complete.
- Global class loading: OK.
- GDExtensions: OK.
- Scene loading: `res://scenes/main.tscn` loaded successfully.
- Script compilation: `res://scripts/game/game_controller.gd` loaded successfully.
- Parse errors: **0**.
- Invalid resource warnings: **0**.
- Exit code: **0**.

### 3.2 GDScript Syntax Validation (`--check-only`)
All 16 GDScript files were parsed using `godot --headless --path <project> --check-only -s <file>`:
1. `res://scripts/chrono_shift/chrono_shift_model.gd` — **OK (exit 0)**
2. `res://scripts/core/combat_math.gd` — **OK (exit 0)**
3. `res://scripts/core/enemy_ai.gd` — **OK (exit 0)**
4. `res://scripts/core/player_kinematics.gd` — **OK (exit 0)**
5. `res://scripts/core/ragdoll_physics.gd` — **OK (exit 0)**
6. `res://scripts/core/time_control.gd` — **OK (exit 0)**
7. `res://scripts/game/audio_manager.gd` — **OK (exit 0)**
8. `res://scripts/game/game_controller.gd` — **OK (exit 0)**
9. `res://scripts/modular_rig/modular_asset_system.gd` — **OK (exit 0)**
10. `res://scripts/timeline/timeline_system.gd` — **OK (exit 0)**
11. `res://scripts/tools/asset_mcp_bridge.gd` — **OK (exit 0)**
12. `res://tests/test_adversarial_disprover.gd` — **OK (exit 0)**
13. `res://tests/test_chrono_and_timeline.gd` — **OK (exit 0)**
14. `res://tests/test_core.gd` — **OK (exit 0)**
15. `res://tests/test_game_integration.gd` — **OK (exit 0)**
16. `res://tests/test_modular_rig.gd` — **OK (exit 0)**

### 3.3 Test Suite Execution Diagnostics
All 5 test suites were executed in headless mode with `-d` (debug enabled):
| Suite | Executed Command | Result | Warnings Emitted |
|---|---|---|---|
| `test_core.gd` | `godot -d --headless -s res://tests/test_core.gd` | **42/42 PASSED** | None |
| `test_modular_rig.gd` | `godot -d --headless -s res://tests/test_modular_rig.gd` | **190/190 PASSED** | None |
| `test_chrono_and_timeline.gd` | `godot -d --headless -s res://tests/test_chrono_and_timeline.gd` | **35/35 PASSED** | 3 warnings (`chrono_shift_model.gd:210, 940`, `timeline_system.gd:49`) |
| `test_game_integration.gd` | `godot -d --headless -s res://tests/test_game_integration.gd` | **12/12 PASSED** | 5 warnings (same 3 + `game_controller.gd:857, 2255`) |
| `test_adversarial_disprover.gd` | `godot -d --headless -s res://tests/test_adversarial_disprover.gd` | **17/17 PASSED** | 6 warnings (same 5 + `test_adversarial_disprover.gd:698`) |

### 3.4 Main Scene Runtime Execution
Running `scenes/main.tscn` directly with Godot Engine and via Godot MCP `run_project`:
- **Display Driver**: D3D12 Forward+ on NVIDIA GeForce RTX 5070 GPU.
- **Simulation**: Game controller, HUD, stickman animations, canvas rendering, timeline effects, audio pool all run without error.
- **Node Path Lookups**: `get_node()` lookups — 0 failures.
- **Signal Connections**: 0 errors.
- **Runtime Errors**: 0 errors.
- **Exit Code**: 0.
- **Standard Error**: Exactly 5 warnings emitted on initial script compile pass (`GDScript::reload`).

---

## 4. Comprehensive Warning Inventory & Proposed Remediation

### Warning 1: Variable Name Shadows Built-in Function
- **File**: `new-game-project/scripts/chrono_shift/chrono_shift_model.gd`
- **Line**: 210
- **Verbatim Warning**:
  ```text
  WARNING: The variable "len" has the same name as a built-in function.
     at: GDScript::reload (res://scripts/chrono_shift/chrono_shift_model.gd:210)
  ```
- **Context**:
  ```gdscript
  209: 		var d := Vector2(dx, dy)
  210: 		var len: float = d.length()
  211: 		if len <= 0.0:
  212: 			return curr
  213: 		var n: int = maxi(1, int(ceilf(len / MAX_SUBSTEP)))
  ```
- **Root Cause**: `len` is a built-in GDScript global function (`len(Variant)`). Declaring a local variable `len` shadows this global function.
- **Proposed Fix**: Rename `len` to `d_len` or `delta_len`:
  ```gdscript
  		var d := Vector2(dx, dy)
  		var d_len: float = d.length()
  		if d_len <= 0.0:
  			return curr
  		var n: int = maxi(1, int(ceilf(d_len / MAX_SUBSTEP)))
  ```

---

### Warning 2: Ternary Operator Incompatible Types
- **File**: `new-game-project/scripts/chrono_shift/chrono_shift_model.gd`
- **Line**: 940
- **Verbatim Warning**:
  ```text
  WARNING: Values of the ternary operator are not mutually compatible.
     at: GDScript::reload (res://scripts/chrono_shift/chrono_shift_model.gd:940)
  ```
- **Context**:
  ```gdscript
  937: 		var was: bool = is_dilating
  938: 		slowmo_factor = dilation
  939: 		is_dilating = dilation < DILATING_THRESHOLD
  940: 		dilation_edge = is_dilating if is_dilating != was else null
  ```
- **Root Cause**: In GDScript 4.x, the ternary operator `A if C else B` performs static type checking on branches A (`bool`) and B (`null` / Nil). Since `bool` and `Nil` do not share a specific common type other than `Variant`, the compiler warns about incompatible types.
- **Proposed Fix**: Use standard `if-else` statement:
  ```gdscript
  		var was: bool = is_dilating
  		slowmo_factor = dilation
  		is_dilating = dilation < DILATING_THRESHOLD
  		if is_dilating != was:
  			dilation_edge = is_dilating
  		else:
  			dilation_edge = null
  ```

---

### Warning 3: Function Parameter Shadows Class Method
- **File**: `new-game-project/scripts/timeline/timeline_system.gd`
- **Line**: 49
- **Verbatim Warning**:
  ```text
  WARNING: The local function parameter "center_x" is shadowing an already-declared function at line 76 in the current class.
     at: GDScript::reload (res://scripts/timeline/timeline_system.gd:49)
  ```
- **Context**:
  ```gdscript
  48: 	func _init(
  49: 		center_x: float = 0.0,
  50: 		p_y: float = 0.0,
  51: 		p_width: float = 200.0,
  52: 		p_era: int = -1,
  53: 		p_thickness: float = 12.0
  54: 	) -> void:
  55: 		min_x = center_x - p_width * 0.5
  56: 		max_x = center_x + p_width * 0.5
  ...
  76: 	func center_x() -> float:
  77: 		return (min_x + max_x) * 0.5
  ```
- **Root Cause**: In `PhasePlatformData`, the constructor parameter `center_x` shadows the method `func center_x() -> float` defined at line 76. Note that all other constructor parameters use the `p_` prefix convention (`p_y`, `p_width`, `p_era`, `p_thickness`).
- **Proposed Fix**: Rename `center_x` parameter to `p_center_x`:
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
  		y = p_y
  		era = p_era
  		thickness = p_thickness
  ```

---

### Warning 4: Unused Local Variable
- **File**: `new-game-project/scripts/game/game_controller.gd`
- **Line**: 857
- **Verbatim Warning**:
  ```text
  WARNING: The local variable "world_dt" is declared but never used in the block. If this is intended, prefix it with an underscore: "_world_dt".
     at: GDScript::reload (res://scripts/game/game_controller.gd:857)
  ```
- **Context**:
  ```gdscript
  853: 	# 3. Timeline Shift (Tab / C)
  854: 	if timeline_shift_pressed:
  855: 		perform_timeline_shift(target_era_input)
  856: 
  857: 	var world_dt: float = chrono.get_world_dt(dt)
  858: 	var player_dt: float = chrono.get_player_dt(dt)
  ...
  939: 	var updated_world_dt: float = chrono.get_world_dt(dt)
  940: 	_step_world_entities(dt, updated_world_dt, effective_aim)
  ```
- **Root Cause**: `world_dt` is calculated at line 857, but is never accessed. Later at line 939, `updated_world_dt` is calculated and passed to `_step_world_entities`.
- **Proposed Fix**: Remove line 857 entirely (or prefix with `_world_dt` if retained for clarity):
  ```gdscript
  	# 3. Timeline Shift (Tab / C)
  	if timeline_shift_pressed:
  		perform_timeline_shift(target_era_input)

  	var player_dt: float = chrono.get_player_dt(dt)
  ```

---

### Warning 5: Local Variable Shadows Base Object Method
- **File**: `new-game-project/scripts/game/game_controller.gd`
- **Line**: 2255
- **Verbatim Warning**:
  ```text
  WARNING: The local variable "tr" is shadowing an already-declared method in the base class "Object".
     at: GDScript::reload (res://scripts/game/game_controller.gd:2255)
  ```
- **Context**:
  ```gdscript
  2248: func _draw_seven_segment_glyph(center_scr: Vector2, ch: String, half_size: float, col: Color) -> void:
  ...
  2254: 	var tl := center_scr + Vector2(-w, -h)
  2255: 	var tr := center_scr + Vector2(w, -h)
  2256: 	var ml := center_scr + Vector2(-w, 0.0)
  2257: 	var mr := center_scr + Vector2(w, 0.0)
  2258: 	var bl := center_scr + Vector2(-w, h)
  2259: 	var br := center_scr + Vector2(w, h)
  ```
- **Root Cause**: In Godot, `Object.tr(message, context)` is the built-in localization/translation helper method available on all objects inheriting from `Object`. Local variable `tr` (top-right vertex) shadows this method.
- **Proposed Fix**: Rename the bounding box point variables to avoid shadowing `tr` (e.g. `pt_tl`, `pt_tr`, `pt_ml`, `pt_mr`, `pt_bl`, `pt_br`):
  ```gdscript
  	var pt_tl := center_scr + Vector2(-w, -h)
  	var pt_tr := center_scr + Vector2(w, -h)
  	var pt_ml := center_scr + Vector2(-w, 0.0)
  	var pt_mr := center_scr + Vector2(w, 0.0)
  	var pt_bl := center_scr + Vector2(-w, h)
  	var pt_br := center_scr + Vector2(w, h)

  	if segs[0]:
  		_d_line(pt_tl, pt_tr, col, 1.8) # a (top)
  	if segs[1]:
  		_d_line(pt_tr, pt_mr, col, 1.8) # b (top-right)
  	if segs[2]:
  		_d_line(pt_mr, pt_br, col, 1.8) # c (bottom-right)
  	if segs[3]:
  		_d_line(pt_bl, pt_br, col, 1.8) # d (bottom)
  	if segs[4]:
  		_d_line(pt_ml, pt_bl, col, 1.8) # e (bottom-left)
  	if segs[5]:
  		_d_line(pt_tl, pt_ml, col, 1.8) # f (top-left)
  	if segs[6]:
  		_d_line(pt_ml, pt_mr, col, 1.8) # g (middle)
  ```

---

### Warning 6: Unused Local Variable in Test Suite
- **File**: `new-game-project/tests/test_adversarial_disprover.gd`
- **Line**: 698
- **Verbatim Warning**:
  ```text
  WARNING: The local variable "reg" is declared but never used in the block. If this is intended, prefix it with an underscore: "_reg".
     at: GDScript::reload (res://tests/test_adversarial_disprover.gd:698)
  ```
- **Context**:
  ```gdscript
  696: func attack_3b_invalid_slot_names_and_numbers_and_missing_textures() -> bool:
  697: 	var ok: bool = true
  698: 	var reg := ModularAssetScript.ModularAssetRegistry.new()
  699: 
  700: 	# Pass invalid slot names, out-of-range negative/huge slot numbers...
  ```
- **Root Cause**: `reg` is instantiated in `attack_3b_invalid_slot_names_and_numbers_and_missing_textures()` but is never referenced.
- **Proposed Fix**: Prefix with underscore `_reg` or remove line 698.

---

## 5. Verification Protocol for Implementer

Following application of the above fixes, independent verification can be achieved through two complementary pathways:

### Pathway A: Direct Godot CLI Verification
Run Godot in headless debug mode on the main scene and the test suites:
```powershell
$godot = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$proj = "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project"

# 1. Verify main scene loads with ZERO stderr output
node -e "
const { execFile } = require('child_process');
execFile('$($godot.Replace('\', '\\'))', ['-d', '--headless', '--path', '$($proj.Replace('\', '\\'))', '--scene', 'res://scenes/main.tscn', '--quit-after', '100'], (err, stdout, stderr) => {
  if (stderr.trim()) console.error('FAIL - Warnings logged:\n', stderr);
  else console.log('PASS - Zero warnings, zero errors!');
});
"

# 2. Run all test suites
& $godot -d --headless --path $proj -s res://tests/test_core.gd
& $godot -d --headless --path $proj -s res://tests/test_chrono_and_timeline.gd
& $godot -d --headless --path $proj -s res://tests/test_modular_rig.gd
& $godot -d --headless --path $proj -s res://tests/test_game_integration.gd
& $godot -d --headless --path $proj -s res://tests/test_adversarial_disprover.gd
```

### Pathway B: Godot MCP Tooling Verification
Start `tools/godot-mcp` with `GODOT_PATH` set, issue `run_project`, wait 2-3 seconds, call `get_debug_output`, and inspect the `errors` array:
```javascript
// Expected result in get_debug_output response:
{
  "output": [
    "Godot Engine v4.7.2.stable.steam.ed1daf0bf...",
    "D3D12 12_0 - Forward+..."
  ],
  "errors": []  // Must be strictly empty!
}
```
This directly confirms acceptance criterion R2 (clean console output and verification via Godot MCP tooling).
