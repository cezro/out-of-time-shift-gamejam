# Empirical Challenge & Stress-Test Report: Procedural Stickman Rig (Milestone 1)

**Agent**: Challenger 1 (`teamwork_challenger_m1_1`)  
**Target Recipient**: Orchestrator (`0fd925e9-f058-4fd8-8532-3aab95b2a4f6`) / Milestone 1 Worker (`teamwork_worker_m1_1`)  
**Date**: 2026-11-10  
**Test Suite**: `res://tests/test_stickman_procedural_stress.gd`  
**Verdict**: **REQUEST_CHANGES**

---

## 1. Executive Summary

Challenger 1 conducted comprehensive, adversarial empirical stress tests on the imported procedural stickman scene (`res://scenes/stickman/stickmanprocedural.tscn`) and script (`res://scripts/stickman/stickmanprocedural.gd`) using a dedicated 10-phase automated test harness (`new-game-project/tests/test_stickman_procedural_stress.gd`) executed in headless Godot 4.7.

While the rig demonstrated exceptional kinematic stability across finite velocities up to 100,000 px/s, rapid state transitions, and high-frequency facing flips, **an empirical vulnerability was discovered**:
Passing non-finite inputs (`NAN` or `INF`) in `p_velocity` or `delta` causes **irreversible NaN latching** in `phase` and all 5 IK targets (`foot_r`, `foot_l`, `arm_r`, `arm_l`, `head`). Because `Vector2.lerp(valid, weight)` from a NaN position evaluates to NaN under IEEE 754, the rig permanently freezes and cannot recover even when subsequent inputs are completely valid.

Therefore, the verdict is **REQUEST_CHANGES** pending the addition of defensive input sanitization and target self-healing in `stickmanprocedural.gd`.

---

## 2. Test Execution Matrix

| # | Test Case | Target Dimension | Assertions / Iterations | Status |
|---|---|---|---|---|
| 1 | `test_01_scene_instantiation_and_node_integrity` | Scene loading, node structure, bone hierarchy, 5 IK targets, property aliases | 14 assertions | **PASS** |
| 2 | `test_02_extreme_velocities_stress` | Zero, subnormal (1e-18), massive (5000 px/s), plunge (-10000 px/s), astronomical (100,000 px/s) | 12 velocities, 100+ checks | **PASS** |
| 3 | `test_03_high_frequency_direction_and_ground_flips` | 200 alternating direction/ground flips, symmetry check around `HIP_REST_X` (284.51) | 200 cycles, mirrored math | **PASS** |
| 4 | `test_04_rapid_state_transitions_and_malformed_states` | 10 canonical stances + 8 malformed/empty/overflow strings (`__proto__`, `ultra_instinct`) | 36 transitions, pose checks | **PASS** |
| 5 | `test_05_boundary_delta_times` | `dt = 0.0`, `1e-12`, `0.001`, `0.016`, `1.0`, `100.0`, `-0.016`, `-1.0` | 11 boundary values | **PASS** |
| 6 | `test_06_nan_and_inf_resilience` | Facing direction NaN/Inf, velocity NaN/Inf injection, post-recovery finite convergence | 8 bad inputs + 10 recovery steps | **FAIL (DEFECT)** |
| 7 | `test_07_bone_positions_and_stickman_pose_completeness` | 18 joints present, finite coordinates, spatial hierarchy (`head.y < neck.y < pelvis.y`), `to_stickman_pose()` | 19 joints + 16 pose members | **PASS** |
| 8 | `test_08_property_tampering_and_extremes` | `stride_length <= 0`, `move_speed <= 0`, `snappiness = 0.0`, `snappiness = 1000.0` | Division by zero stress | **PASS** |
| 9 | `test_09_continuous_long_run_simulation` | 10,000 continuous frames of randomized gameplay (vel, jump, attack, fall) | 10,000 frames | **PASS** |
| 10 | `test_10_multi_instance_isolation_and_lifecycle` | 10 concurrent stickman rigs with opposing facings and independent lifecycles | 10 instances, clean teardown | **PASS** |

**Summary**: 9 / 10 test phases passed. Phase 6 failed due to the unhandled NaN/Inf latching defect.

---

## 3. Detailed Vulnerability Analysis

### [High] Defect 1: Irreversible NaN Latching on Non-Finite Velocity or Delta

- **Challenged Component**: `StickmanProcedural.update_procedural_animation()` in `new-game-project/scripts/stickman/stickmanprocedural.gd:154-210`.
- **Verbatim Error**:
  ```
  -> ASSERTION FAILED: Target 'foot_r' position must be finite after recovery (got (nan, nan))
  -> ASSERTION FAILED: Target 'foot_l' position must be finite after recovery (got (nan, nan))
  -> ASSERTION FAILED: Target 'arm_r' position must be finite after recovery (got (nan, nan))
  -> ASSERTION FAILED: Target 'arm_l' position must be finite after recovery (got (nan, nan))
  -> ASSERTION FAILED: Target 'head' position must be finite after recovery (got (nan, nan))
  ```

#### Reproduction Steps
1. Instantiate `StickmanProcedural` from `res://scenes/stickman/stickmanprocedural.tscn`.
2. Call `update_procedural_animation(Vector2(INF, 0.0), true, 1.0, "run", 0.016)` (or `Vector2(NAN, 0.0)` or `delta = NAN`) for a single frame.
3. Call `update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)` with completely valid parameters for 10 subsequent frames.
4. Inspect `phase` and `get_ik_targets()` positions.

#### Root Cause Mechanism
1. At line 168: `speed = absf(p_velocity.x)` becomes `NAN` (or `INF`).
2. At line 174: `phase = fposmod(phase + distance_moved / ..., 1.0)`. In IEEE 754 arithmetic, `fposmod(INF, 1.0)` is `NAN`. Thus, `phase` latches to `NAN`.
3. In `apply_run_offsets()`: `angle = phase * TAU = NAN`. Arm, foot, and head offsets evaluate to `Vector2(NAN, NAN)`.
4. In `update_target_animation()`:
   ```gdscript
   target.position = target.position.lerp(base_rest + offset, weight)
   ```
   `target.position` is assigned `Vector2(NAN, NAN)`.
5. On subsequent frames with valid `p_velocity`:
   - `phase` remains `NAN` because `fposmod(NAN + valid, 1.0) = NAN`.
   - `target.position.lerp(valid_target, weight)` evaluates `NAN + (valid_target - NAN) * weight = NAN`.
   - The rig cannot escape `(nan, nan)` without being destroyed and reinstantiated.

#### Blast Radius
- All 5 IK targets (`FootR`, `FootL`, `ArmR`, `ArmL`, `Head`) permanently freeze at `(nan, nan)`.
- CCDIK solver fails to update limb rotations.
- Stickman visuals freeze in place permanently for the rest of the game session.

#### Recommended Mitigation
In `new-game-project/scripts/stickman/stickmanprocedural.gd`:
1. Sanitize `p_velocity` and `delta` at the entry point of `update_procedural_animation()`, matching the defensive design already used in `ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose` (`modular_asset_system.gd:890-896`):
   ```gdscript
   var safe_vel: Vector2 = p_velocity if (is_finite(p_velocity.x) and is_finite(p_velocity.y)) else Vector2.ZERO
   var safe_delta: float = delta if (is_finite(delta) and delta >= 0.0) else 0.0
   ```
2. Reset corrupted phase:
   ```gdscript
   if not is_finite(phase):
       phase = 0.0
   ```
3. Add self-healing before target interpolation in `update_target_animation()`:
   ```gdscript
   for target in targets:
       var base_rest: Vector2 = get_mirrored_rest_position(target, facing)
       var offset: Vector2 = offsets.get(target, Vector2.ZERO)
       if not is_finite(target.position.x) or not is_finite(target.position.y):
           target.position = base_rest
       target.position = target.position.lerp(base_rest + offset, weight)
   ```

---

## 4. Confirmed Strengths of the Implementation

Despite Defect 1, the implementation demonstrated significant architectural rigor:
1. **Finite Kinematic Stability**: Handled velocities up to 100,000 px/s with clean phase boundedness in `[0.0, 1.0)`.
2. **Mirroring Precision**: `get_mirrored_rest_position` accurately mirrors targets across `HIP_REST_X` (284.51) down to floating-point epsilon.
3. **Headless Hierarchy Safety**: `_ensure_references()` successfully initializes IK targets and skeleton without requiring tree notifications.
4. **Clean Concurrency & Lifecycle**: 10 simultaneous instances ran with zero cross-instance pollution and freed with 0 orphaned nodes.
5. **Full Regression Health**: All 5 existing regression suites in `run_tests.bat` (210 modular rig tests, 42 kinematics tests, 35 chronos shift tests, 12 integration tests, 17 disprover tests) pass with 100% success.

---

## 5. Invalidation & Re-test Criteria

To resolve this challenge and achieve **APPROVE**:
1. Worker must apply the defensive sanitization and self-healing to `stickmanprocedural.gd`.
2. Execute the challenger stress suite:
   ```powershell
   python -c "import subprocess; res = subprocess.run([r'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', '--headless', '--path', r'c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project', '--script', 'res://tests/test_stickman_procedural_stress.gd'], capture_output=True, text=True); print(res.stdout); print(res.stderr); assert res.returncode == 0"
   ```
   **Expected**: `=== STICKMAN PROCEDURAL STRESS SUMMARY: 10 / 10 PASSED (0 FAILED) ===` with exit code 0.
3. Verify that `cmd.exe /c run_tests.bat` continues to pass with 100% success.
