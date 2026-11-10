# Dispatch: Milestone 1 Iteration 2 Worker (Remediation Implementation)

You are `teamwork_worker` (Milestone 1 Iteration 2 Worker).
Working directory: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_worker_m1_2`
Original Request: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md`
Project Document: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\PROJECT.md`

## Files You Own Exclusively
- `new-game-project/scripts/stickman/stickmanprocedural.gd`
- `new-game-project/tests/test_modular_rig.gd`
- `new-game-project/tests/test_stickman_procedural_stress.gd`

## Explorer Inputs (Read These Carefully First!)
1. M1 It2 Explorer 1 Report & Patch:
   - Report: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_1\report.md`
   - Patch: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_1\stickmanprocedural_nan_inf_remediation.patch`
   - Script: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_1\proposed_stickmanprocedural.gd`
2. M1 It2 Explorer 2 Report & Patch:
   - Report: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_2\report.md`
   - Patch: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_2\stickmanprocedural_coord_parity.patch`
3. M1 It2 Explorer 3 Report & Patches:
   - Report: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_3\report.md`
   - Teardown Patch: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_3\proposed_test_modular_rig_teardown.patch`
   - Stress Hardening Patch: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_3\proposed_stress_hardening.patch`

## Tasks
1. Apply the 5-layer NaN/Inf defect remediation to `new-game-project/scripts/stickman/stickmanprocedural.gd` (sanitizing `p_velocity` and `delta`, resetting NaN phase, self-healing non-finite targets before `lerp`).
2. Apply coordinate parity to `to_stickman_pose()` in `new-game-project/scripts/stickman/stickmanprocedural.gd` (inverting Y coordinates via `_to_sim_coord()` so that $+Y$ is UP simulation space and `head_center.y > neck.y > pelvis.y` holds).
3. Apply teardown active assertion to `new-game-project/tests/test_modular_rig.gd` line 443 (replacing `_assert(true, ...)` with active verification of `not is_instance_valid(rig_node)`).
4. Apply stress hardening to `new-game-project/tests/test_stickman_procedural_stress.gd` (replacing tautological line 556 and adding active coordinate hierarchy checks to Test 7).
5. Run the verification commands:
   - `python -c "import subprocess; res = subprocess.run([r'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', '--headless', '--path', r'c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project', '--script', 'res://tests/test_stickman_procedural_stress.gd'], capture_output=True, text=True); print(res.stdout); assert res.returncode == 0"`
   - `& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "new-game-project" --check-only`
   - `cmd.exe /c "run_tests.bat"`
   Verify that all tests pass 100% with zero failures.
6. Write your report to `report.md` and `handoff.md`, then notify the orchestrator.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.


## 2026-11-10T14:14:33Z
You are Milestone 1 Iteration 2 Worker (teamwork_worker).
Working directory: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_worker_m1_2
Original Request: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md
Project Document: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\PROJECT.md
Dispatch Instructions: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_worker_m1_2\DISPATCH.md

Please read the dispatch instructions and the three Explorer reports/patches:
- c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_1\report.md
- c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_2\report.md
- c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_3\report.md

Tasks:
1. Apply 5-layer NaN/Inf defect remediation in stickmanprocedural.gd.
2. Apply coordinate parity (+Y UP) in to_stickman_pose() in stickmanprocedural.gd.
3. Update test_modular_rig.gd line 443 with active teardown assertions.
4. Update test_stickman_procedural_stress.gd line 556 and add coordinate parity checks.
5. Verify with test_stickman_procedural_stress.gd (10/10 PASS), Godot check-only, and run_tests.bat (100% pass).
Write report.md and handoff.md, then notify the orchestrator.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
