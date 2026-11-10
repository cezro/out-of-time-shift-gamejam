# Remediation & Architecture Analysis Report: Procedural Stickman NaN/Inf Defect

**Agent**: M1 Iteration 2 Explorer 1 (`teamwork_explorer_m1_it2_1`)  
**Target Recipient**: Orchestrator (`0fd925e9-f058-4fd8-8532-3aab95b2a4f6`) / M1 Iteration 2 Worker  
**Date**: 2026-11-10  
**Target Script**: `res://scripts/stickman/stickmanprocedural.gd`  
**Challenger Stress Suite**: `res://tests/test_stickman_procedural_stress.gd`  

---

## 1. Executive Summary

Empirical investigation confirmed the defect reported by Challenger 1 in `test_06_nan_and_inf_resilience` of `res://tests/test_stickman_procedural_stress.gd`:
When `StickmanProcedural.update_procedural_animation()` receives non-finite velocities (`NAN`, `INF`, `-INF`) or deltas, the rig undergoes **irreversible IEEE 754 NaN latching**. Specifically:
1. Gait accumulation evaluates `fposmod(phase + distance_moved / ..., 1.0) = NAN`, latching `phase` to `NAN`.
2. Offset solvers evaluate `phase * TAU = NAN`, producing `Vector2(NAN, NAN)` offsets for all IK targets.
3. Target interpolation executes `target.position = target.position.lerp(base_rest + offset, weight)`. Under IEEE 754 arithmetic, `lerp(from, to, weight) = from + (to - from) * weight` evaluates to `NAN` when `from` is `NAN`. Thus, once `target.position` is set to `(NAN, NAN)`, the node is permanently corrupted and cannot recover even when completely valid physics inputs resume.

This investigation designed and empirically validated a **5-layer Defense-in-Depth Remediation**:
1. **Entry Point Input Sanitization**: Defensive finite guards on `p_velocity` (`safe_vel`), `delta` (`safe_delta >= 0.0`), and `facing_direction`.
2. **Gait Phase Self-Healing**: Boundary guard `if not is_finite(phase): phase = 0.0` before and after accumulation.
3. **IK Target Self-Healing Pre-Lerp**: If `target.position` is non-finite, it is immediately reset to `base_rest` before `lerp()` executes, breaking the IEEE 754 NaN latch.
4. **Snappiness & Weight Clamping**: Exponential smoothing factor `weight` is clamped in `[0.0, 1.0]`.
5. **Bone Coordinate Sanitization**: `get_bone_positions()` sanitizes bone local transforms, preventing corrupted bone data from entering `to_stickman_pose()`.

**Empirical Validation**:
- **Before Remediation**: 9 / 10 stress tests passed (test 6 failed with 5 target NaN assertions).
- **With Remediation**: **10 / 10 stress tests passed (0 failed)**; all 5 project regression suites passed with 100% success (0 regressions).

---

## 2. Root Cause & Propagation Analysis

### 2.1 Call Graph & Contamination Path

```
update_procedural_animation(p_velocity, is_on_ground, facing_direction, current_state, delta)
 │
 ├── 1. speed = absf(p_velocity.x) ────────────► [NAN / INF]
 │
 ├── 2. distance_moved = speed * delta ────────► [NAN / INF]
 │
 ├── 3. phase = fposmod(phase + ..., 1.0) ─────► [NAN] (Latches!)
 │
 └── 4. update_target_animation(delta, speed_ratio, is_on_ground, p_velocity, current_state)
      │
      ├── apply_run_offsets():
      │    angle = phase * TAU ────────────────► [NAN]
      │    offsets[target] = Vector2(...) ─────► [Vector2(NAN, NAN)]
      │
      └── target.position.lerp(base_rest + offset, weight):
           target.position = (NAN, NAN) ───────► [PERMANENT NODE LATCH]
```

### 2.2 Why Subsequent Clean Inputs Fail to Recover (The Latch)

In `update_target_animation()` line 209:
```gdscript
target.position = target.position.lerp(base_rest + offset, weight)
```
When `target.position` is already `(NAN, NAN)` from a previous bad frame:
$$\text{lerp}(a, b, w) = a + (b - a) \cdot w$$
Substituting $a = \text{NAN}$:
$$\text{NAN} + (b - \text{NAN}) \cdot w = \text{NAN} + \text{NAN} = \text{NAN}$$
No matter what valid destination $b = \text{base\_rest} + \text{offset}$ or valid weight $w \in [0.0, 1.0]$ is provided, `target.position` **remains `(NAN, NAN)` permanently**. The node can never recover without explicit self-healing.

---

## 3. Defense-in-Depth Remediation Architecture

To make `StickmanProcedural` resilient against all adversarial numerical inputs, the following 5 defensive layers must be implemented:

### Layer 1: External Input Sanitization
Matching the pattern in `ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose` (`modular_asset_system.gd:890-896`):
```gdscript
var safe_vel: Vector2 = p_velocity if (is_finite(p_velocity.x) and is_finite(p_velocity.y)) else Vector2.ZERO
var safe_delta: float = delta if (is_finite(delta) and delta >= 0.0) else 0.0

if not is_nan(facing_direction) and facing_direction != 0.0:
    facing = 1.0 if facing_direction > 0.0 else -1.0
elif not is_finite(facing) or absf(facing) != 1.0:
    facing = 1.0
```
- Non-finite velocities immediately fall back to `Vector2.ZERO`.
- Non-finite or negative deltas fall back to `0.0`.
- Facing is strictly validated to preserve the $\pm 1.0$ invariant.

### Layer 2: Phase Self-Healing & Bounded Modulo
```gdscript
if not is_finite(phase):
    phase = 0.0

var speed: float = absf(safe_vel.x)
var speed_ratio: float = clampf(speed / maxf(move_speed, 1.0), 0.0, 1.0)

if is_on_ground and stride_length > 0.01:
    var distance_moved: float = speed * safe_delta
    phase = fposmod(phase + distance_moved / (stride_length * 2.0), 1.0)
    if not is_finite(phase):
        phase = 0.0
```
- If `phase` is ever corrupted by external tampering or numerical overflow, it instantly resets to `0.0`.

### Layer 3: IK Target Self-Healing Pre-Lerp
In `update_target_animation()`:
```gdscript
for target in targets:
    if target == null:
        continue
    var base_rest: Vector2 = get_mirrored_rest_position(target, facing)
    var offset: Vector2 = offsets.get(target, Vector2.ZERO)
    if not is_finite(offset.x) or not is_finite(offset.y):
        offset = Vector2.ZERO

    # Self-heal corrupted target position before lerp to break irreversible NaN latching
    if not is_finite(target.position.x) or not is_finite(target.position.y):
        target.position = base_rest

    target.position = target.position.lerp(base_rest + offset, weight)
```
- **Key Invariant**: If `target.position` has any non-finite component, it is snapped to `base_rest` *before* the lerp calculation.
- This breaks the IEEE 754 latch and guarantees that all 5 IK targets (`foot_r`, `foot_l`, `arm_r`, `arm_l`, `head`) return to valid finite space on the very next frame.

### Layer 4: Snappiness & Weight Sanitization
```gdscript
var safe_snappiness: float = snappiness if (is_finite(snappiness) and snappiness >= 0.0) else 18.0
var weight: float = clampf(1.0 - exp(-safe_snappiness * safe_delta), 0.0, 1.0) if safe_delta > 0.0 else 1.0
if not is_finite(weight):
    weight = 1.0
```
- Protects against negative or infinite snappiness values, guaranteeing $weight \in [0.0, 1.0]$.

### Layer 5: Bone Transformation Guard
In `get_bone_positions()`:
```gdscript
var local_pos: Vector2 = to_local(b_node.global_position)
if is_finite(local_pos.x) and is_finite(local_pos.y):
    result[key] = local_pos
else:
    result[key] = Vector2.ZERO
```
- Prevents uninitialized or corrupted skeletal bones from propagating NaNs into `to_stickman_pose()`.

---

## 4. Proposed Code Changes & Unified Diff

The unified patch file has been generated in this workspace at:
`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_1\stickmanprocedural_nan_inf_remediation.patch`

And the complete proposed replacement script is available at:
`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_1\proposed_stickmanprocedural.gd`

### Key Diffs Summary

#### A. Entry point `update_procedural_animation()` (`stickmanprocedural.gd:161-177`)
```diff
@@ -161,19 +161,31 @@
 	_ensure_references()
 	current_anim_state = current_state
 
-	# Update facing direction if non-zero
-	if facing_direction != 0.0:
-		facing = 1.0 if facing_direction >= 0.0 else -1.0
-
-	var speed: float = absf(p_velocity.x)
+	# Sanitize velocity and delta inputs against NaN/Inf
+	var safe_vel: Vector2 = p_velocity if (is_finite(p_velocity.x) and is_finite(p_velocity.y)) else Vector2.ZERO
+	var safe_delta: float = delta if (is_finite(delta) and delta >= 0.0) else 0.0
+
+	# Update facing direction if valid and non-zero; preserve valid +/-1.0 invariant
+	if not is_nan(facing_direction) and facing_direction != 0.0:
+		facing = 1.0 if facing_direction > 0.0 else -1.0
+	elif not is_finite(facing) or absf(facing) != 1.0:
+		facing = 1.0
+
+	# Guard against non-finite phase latching
+	if not is_finite(phase):
+		phase = 0.0
+
+	var speed: float = absf(safe_vel.x)
 	var speed_ratio: float = clampf(speed / maxf(move_speed, 1.0), 0.0, 1.0)
 
 	# Accumulate gait phase based on horizontal ground displacement
 	if is_on_ground and stride_length > 0.01:
-		var distance_moved: float = speed * delta
+		var distance_moved: float = speed * safe_delta
 		phase = fposmod(phase + distance_moved / (stride_length * 2.0), 1.0)
-
-	update_target_animation(delta, speed_ratio, is_on_ground, p_velocity, current_state)
+		if not is_finite(phase):
+			phase = 0.0
+
+	update_target_animation(safe_delta, speed_ratio, is_on_ground, safe_vel, current_state)
```

#### B. Target Animation & Self-Healing Loop (`stickmanprocedural.gd:180-210`)
```diff
@@ -184,6 +196,10 @@
 	p_velocity: Vector2 = Vector2.ZERO,
 	current_state: String = "idle"
 ) -> void:
+	var safe_delta: float = delta if (is_finite(delta) and delta >= 0.0) else 0.0
+	var safe_speed_ratio: float = clampf(speed_ratio, 0.0, 1.0) if is_finite(speed_ratio) else 0.0
+	var safe_vel: Vector2 = p_velocity if (is_finite(p_velocity.x) and is_finite(p_velocity.y)) else Vector2.ZERO
+
 	var offsets: Dictionary = {}
 
 	# Default standing / resting pose
@@ -191,28 +207,47 @@
 		offsets[target] = Vector2.ZERO
 
 	if not is_on_ground or current_state in ["jump", "fall", "air"]:
-		apply_air_offsets(offsets, p_velocity)
+		apply_air_offsets(offsets, safe_vel)
 	elif current_state == "wall_slide":
 		apply_wall_slide_offsets(offsets)
 	elif current_state in ["slash", "heavy_slash"]:
 		apply_attack_offsets(offsets, current_state)
 	elif current_state == "parry_guard":
 		apply_parry_offsets(offsets)
-	elif speed_ratio > 0.02 or current_state in ["run", "walk"]:
-		apply_run_offsets(offsets, speed_ratio)
-
-	var weight: float = 1.0 - exp(-snappiness * delta) if delta > 0.0 else 1.0
+	elif safe_speed_ratio > 0.02 or current_state in ["run", "walk"]:
+		apply_run_offsets(offsets, safe_speed_ratio)
+
+	var safe_snappiness: float = snappiness if (is_finite(snappiness) and snappiness >= 0.0) else 18.0
+	var weight: float = clampf(1.0 - exp(-safe_snappiness * safe_delta), 0.0, 1.0) if safe_delta > 0.0 else 1.0
+	if not is_finite(weight):
+		weight = 1.0
 
 	for target in targets:
+		if target == null:
+			continue
 		var base_rest: Vector2 = get_mirrored_rest_position(target, facing)
 		var offset: Vector2 = offsets.get(target, Vector2.ZERO)
+		if not is_finite(offset.x) or not is_finite(offset.y):
+			offset = Vector2.ZERO
+
+		# Self-heal corrupted target position before lerp to break irreversible NaN latching
+		if not is_finite(target.position.x) or not is_finite(target.position.y):
+			target.position = base_rest
+
 		target.position = target.position.lerp(base_rest + offset, weight)
```

---

## 5. Verification Matrix & Validation Results

| Test Target | Command | Result Before | Result With Fix |
|---|---|---|---|
| Challenger Stress Suite (`test_stickman_procedural_stress.gd`) | `godot --headless --path new-game-project --script res://tests/test_stickman_procedural_stress.gd` | 9 / 10 passed (`test_06` FAILED) | **10 / 10 PASSED (0 FAILED)** |
| Core Kinematics & Combat Suite | `godot --headless --path new-game-project --script res://tests/test_core.gd` | 42 / 42 passed | **42 / 42 PASSED** |
| Chronos Shift & Timeline Suite | `godot --headless --path new-game-project --script res://tests/test_chrono_and_timeline.gd` | 35 / 35 passed | **35 / 35 PASSED** |
| Modular Piece-by-Piece Rig Suite | `godot --headless --path new-game-project --script res://tests/test_modular_rig.gd` | 210 / 210 passed | **210 / 210 PASSED** |
| End-to-End Game Integration Suite | `godot --headless --path new-game-project --script res://tests/test_game_integration.gd` | 12 / 12 passed | **12 / 12 PASSED** |
| Adversarial Red-Team Disprover Suite | `godot --headless --path new-game-project --script res://tests/test_adversarial_disprover.gd` | 17 / 17 passed | **17 / 17 PASSED** |

---

## 6. Actionable Recommendation for Milestone 1 Worker

The Milestone 1 Worker should apply the unified patch `stickmanprocedural_nan_inf_remediation.patch` to `new-game-project/scripts/stickman/stickmanprocedural.gd`:

```powershell
# Either apply via git patch or copy the proposed file:
Copy-Item ".agents\teamwork\teamwork_explorer_m1_it2_1\proposed_stickmanprocedural.gd" "new-game-project\scripts\stickman\stickmanprocedural.gd" -Force
```

Then execute:
```powershell
python -c "import subprocess; res = subprocess.run([r'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', '--headless', '--path', r'c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project', '--script', 'res://tests/test_stickman_procedural_stress.gd'], capture_output=True, text=True); print(res.stdout); print(res.stderr); assert res.returncode == 0"
cmd.exe /c run_tests.bat
```

Both commands will exit with code 0 and confirm full remediation.
