# Dispatch: Milestone 1 Worker (Procedural Rig & Scene Asset Integration)

You are `teamwork_worker` (Milestone 1 Worker).
Working directory: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_worker_m1_1`
Original Request: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md`
Project Document: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\PROJECT.md`

## Files You Own Exclusively
- `new-game-project/assets/stickman/*`
- `new-game-project/scripts/stickman/stickmanprocedural.gd`
- `new-game-project/scenes/stickman/stickmanprocedural.tscn`
- `new-game-project/scripts/modular_rig/modular_asset_system.gd`
- `new-game-project/assets/modular_parts_manifest.json`
- `new-game-project/tests/test_modular_rig.gd`

## Explorer Inputs (Read These Carefully First!)
1. M1 Explorer 1 Report & Handoff: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_1\handoff.md`
2. M1 Explorer 2 Report, Patch & Proposed Script:
   - Handoff: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_2\handoff.md`
   - Patch: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_2\remediation.patch`
   - Ready-to-use Script: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_2\proposed_stickmanprocedural.gd`
3. M1 Explorer 3 Report & Handoff: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_3\handoff.md`

## Implementation Tasks
1. **Asset Import**:
   - Copy all 16 `.png` textures and their corresponding 16 `.png.import` files from `c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene\assets\stickman\` into `new-game-project\assets\stickman\`.
   - Create directories `new-game-project\scripts\stickman\` and `new-game-project\scenes\stickman\`.
   - Install `stickmanprocedural.gd` using the remediated implementation from `.agents/teamwork/teamwork_explorer_m1_2/proposed_stickmanprocedural.gd` into `new-game-project\scripts\stickman\stickmanprocedural.gd`.
   - Install `stickmanprocedural.tscn` from `c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene\stickmanprocedural.tscn` into `new-game-project\scenes\stickman\stickmanprocedural.tscn`, applying the fixes from M1 Explorer 2 (attaching script ext_resource to root Player, removing dangling 6th CCDIK modifier, setting modification_count = 5).
2. **ModularAssetSystem Registration**:
   - In `new-game-project/scripts/modular_rig/modular_asset_system.gd`:
     - Add `instantiate_scene() -> Node` to `PartPieceSpec`.
     - Add `var rig_scene_path: String = ""` and `instantiate_rig() -> Node` to `CharacterLoadout`.
     - Add `const PROCEDURAL_STICKMAN_SCENE_PATH = "res://scenes/stickman/stickmanprocedural.tscn"`.
     - Register preset `"player_procedural_stickman"` in `ModularAssetRegistry._init_builtin_presets()`.
     - Add `instantiate_rig(loadout_id)` and `get_rig_scene_path(loadout_id)` to `ModularAssetRegistry`.
   - Update `new-game-project/assets/modular_parts_manifest.json` to include the new part piece and loadout.
3. **Automated Testing & Verification**:
   - In `new-game-project/tests/test_modular_rig.gd`:
     - Add Test 7 (`_test_packed_scene_backend_and_procedural_stickman()`) as detailed in M1 Explorer 3 handoff.
   - Run the headless test command and `run_tests.bat`.
   - Verify all 5 test suites pass (100% pass rate, 0 failures, 0 regressions).

## Verification Commands
Run in PowerShell:
```powershell
cmd.exe /c "run_tests.bat"
```
and
```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "new-game-project" --check-only
```

Write your completion report to `report.md` and `handoff.md` in your working directory, then message the orchestrator.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.


## 2026-11-10T13:30:01Z
You are Milestone 1 Worker (teamwork_worker).
Working directory: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_worker_m1_1
Original Request: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md
Project Document: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\PROJECT.md
Dispatch Instructions: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_worker_m1_1\DISPATCH.md

Explorer handoffs to read before starting:
- c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_1\handoff.md
- c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_2\handoff.md (plus proposed_stickmanprocedural.gd and remediation.patch in that directory)
- c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_3\handoff.md

Tasks:
1. Import 16 stickman textures & .import files to new-game-project/assets/stickman/.
2. Import and fix stickmanprocedural.gd in new-game-project/scripts/stickman/ using proposed_stickmanprocedural.gd from explorer 2.
3. Import and fix stickmanprocedural.tscn in new-game-project/scenes/stickman/ (attaching script ext_resource, removing dangling 6th CCDIK modifier).
4. Register PACKED_SCENE backend and preset in new-game-project/scripts/modular_rig/modular_asset_system.gd and modular_parts_manifest.json.
5. Add automated Test 7 in new-game-project/tests/test_modular_rig.gd.
6. Run run_tests.bat and Godot check-only to verify 100% pass rate.
Write report.md and handoff.md in your working directory, then notify the orchestrator.
