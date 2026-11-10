# Rig Defect Remediation & Interface Strategy Report

**Explorer**: M1 Explorer 2 (`teamwork_explorer_m1_2`)  
**Mission**: Analyze defects in `stickmanprocedural.gd` and `stickmanprocedural.tscn`, formulate exact line-by-line remediation for the Worker, and specify the interface additions required for `new-game-project`.  
**Reference Repository**: `c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene`  
**Target Project**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project`  
**Date**: 2026-11-10  

---

## 1. Executive Summary

The reference character rig in `procedural-animation-test-scene` implements an inverse-kinematics stickman using Godot 4's 2D Skeletal system (`Skeleton2D`, `SkeletonModificationStack2D`, `SkeletonModification2DCCDIK`, `SkeletonModification2DLookAt`). While its analytical distance-driven gait logic is sound, five critical defects prevent it from working properly or integrating into `new-game-project`:

1. **Unattached Root Script**: `stickmanprocedural.tscn` root node `Player` has no `script` property. When instantiated, none of the procedural animation methods or exports exist.
2. **Facing Assignment Typo**: Line 63 in `stickmanprocedural.gd` uses subtraction (`facing - signf(direction)`) instead of assignment (`facing = signf(direction)`), rendering it impossible for the character to turn left.
3. **Dangling 6th CCDIK Modifier**: `SkeletonModification2DCCDIK_gavct` in `stickmanprocedural.tscn` lacks a `target_nodepath` and joint data, triggering Godot engine warnings and evaluation errors.
4. **Hardcoded Input & Physics Coupling**: `_physics_process` directly polls `Input.get_axis` and executes `move_and_slide()`, causing conflicts when instantiated as an NPC, clone, or under `PACKED_SCENE`.
5. **Facing Asymmetry in Target Rest Positions**: Because `Rig.scale.x` is not inverted (to protect chiral CCDIK constraints), the asymmetric resting positions of the feet and arms cause unnatural postures when facing left.

All five defects have been diagnosed with complete remediation steps, exact line-by-line diffs, and verified against Godot 4.7.2.

---

## 2. Cataloged Defect Diagnosis & Remediation

### Defect 1: Root Node Missing Script Attachment
- **Location**: `stickmanprocedural.tscn`, Line 125.
- **Observation**:
  ```ini
  [node name="Player" type="CharacterBody2D" unique_id=562865352]
  ```
  The scene does not declare an `ext_resource` for `stickmanprocedural.gd`, and the root `CharacterBody2D` lacks a `script` property.
- **Root Cause**: The developer prototyped the script in `main.tscn` or detached the script before committing `stickmanprocedural.tscn`.
- **Impact**: Any attempt to call `update_procedural_animation()` or inspect `@export` variables after `instantiate()` causes a script error (`Invalid call: Non-existent function`).
- **Remediation**:
  1. Add external script resource declaration in scene header:
     ```ini
     [ext_resource type="Script" uid="uid://vawx2quhkhg3" path="res://scripts/stickman/stickmanprocedural.gd" id="1_script"]
     ```
  2. Attach `script = ExtResource("1_script")` to root node:
     ```ini
     [node name="Player" type="CharacterBody2D" unique_id=562865352]
     script = ExtResource("1_script")
     ```

---

### Defect 2: Gait Direction Expression Typo
- **Location**: `stickmanprocedural.gd`, Line 63.
- **Observation**:
  ```gdscript
  if direction != 0.0:
      facing - signf(direction)
  ```
- **Root Cause**: A typographical error where `-` (minus) was typed instead of `=` (assignment operator).
- **Impact**: The expression `facing - signf(direction)` is evaluated and discarded as a no-op. Godot emits a compiler warning (*"Standalone expression has no effect"*). The variable `facing` remains permanently at `1.0`, preventing the rig from ever facing left during gameplay or locomotion.
- **Remediation**:
  Replace line 63 with:
  ```gdscript
  if direction != 0.0:
      facing = signf(direction)
  ```

---

### Defect 3: Dangling 6th CCDIK Modifier Lacking Target Path
- **Location**: `stickmanprocedural.tscn`, Lines 112–123.
- **Observation**:
  ```ini
  [sub_resource type="SkeletonModification2DCCDIK" id="SkeletonModification2DCCDIK_gavct"]
  tip_nodepath = NodePath("Hip/Waist/Torso/Neck")

  [sub_resource type="SkeletonModificationStack2D" id="SkeletonModificationStack2D_y3uf6"]
  enabled = true
  modification_count = 6
  modifications/0 = SubResource("SkeletonModification2DCCDIK_aqggk")
  modifications/1 = SubResource("SkeletonModification2DCCDIK_kt8o7")
  modifications/2 = SubResource("SkeletonModification2DCCDIK_e4tth")
  modifications/3 = SubResource("SkeletonModification2DCCDIK_w7c4t")
  modifications/4 = SubResource("SkeletonModification2DLookAt_ymdls")
  modifications/5 = SubResource("SkeletonModification2DCCDIK_gavct")
  ```
- **Root Cause**: In `animation.tscn`, the author experimented with a `Body Target` (Node2D at `Vector2(266, 142)`), but abandoned it. In `stickmanprocedural.tscn`, `modifications/5` was left in the stack pointing to `SkeletonModification2DCCDIK_gavct` without `target_nodepath`, without `ccdik_data_chain_length`, and with no corresponding target node in `IK Targets`.
- **Impact**: When Godot evaluates the modification stack, `SkeletonModification2DCCDIK` complains about an invalid target node path.
- **Remediation**:
  Remove `SkeletonModification2DCCDIK_gavct`, set `modification_count = 5`, and remove `modifications/5`. This results in exactly 5 valid, active modifiers:
  - Mod 0: Right Leg CCDIK -> `FootR Target`
  - Mod 1: Left Leg CCDIK -> `FootL Target`
  - Mod 2: Right Arm CCDIK -> `ArmR Target`
  - Mod 3: Left Arm CCDIK -> `ArmL Target`
  - Mod 4: Head LookAt -> `Head Target`
  This aligns 1:1 with the 5 target nodes in `IK Targets` and the 5 target variables in `stickmanprocedural.gd`.

---

### Defect 4: Rigid Rest Position Asymmetry & CCDIK Chiral Protection
- **Location**: `stickmanprocedural.gd`, lines 146–150 & 204.
- **Observation**:
  `Rig.scale.x` is never inverted. Instead, the author multiplied target offsets by `facing` (`return Vector2(x * facing, y)`). However, `rest_positions` are hardcoded:
  - `FootR Target` rest: `X = 160` (behind hip center `284.51`)
  - `FootL Target` rest: `X = 307` (in front of hip center `284.51`)
  When `facing = -1.0`, FootR offset points left (-X) and FootL offset points left (-X), but their resting base positions are still offset to the right!
- **Root Cause & Engine Invariant**:
  If one attempts to fix this by flipping `Rig.scale.x = -1.0`, Godot's 2D CCDIK angle constraints (which have min/max angles defined in local joint space with clockwise/counter-clockwise flags) invert chirality, causing knees and elbows to hyperextend backwards.
- **Remediation**:
  Maintain `Rig.scale.x = 1.0` so CCDIK constraints remain mathematically stable, and dynamically mirror the base resting positions across the hip center (`HIP_REST_X = 284.51`) whenever `facing < 0.0`:
  ```gdscript
  const HIP_REST_X: float = 284.51

  func get_mirrored_rest_position(target: Node2D, cur_facing: float) -> Vector2:
      var base_rest: Vector2 = rest_positions.get(target, target.position)
      if cur_facing >= 0.0:
          return base_rest
      var dx: float = base_rest.x - HIP_REST_X
      return Vector2(HIP_REST_X - dx, base_rest.y)
  ```
  This creates symmetrical locomotion and idle stances facing both left and right with zero CCDIK distortion.

---

### Defect 5: Coupling to Input and Self-Contained Physics
- **Location**: `stickmanprocedural.gd`, lines 59–92.
- **Observation**:
  `_physics_process` directly calls `Input.get_axis("ui_left", "ui_right")` and `move_and_slide()`.
- **Root Cause**: The script was written as a standalone prototype character rather than a reusable visual rig component.
- **Impact**: In `new-game-project`, player kinematics are solved by `PlayerKinematics`, enemies by `EnemyAI`, and Chrono-Echoes by `TimelineSystem`. If `stickmanprocedural` executes its own physics, it double-steps physics, listens to player keyboard inputs on enemies, and fights external positioning.
- **Remediation**:
  Add an `@export var autonomous_physics: bool = false` control flag:
  - Default `false`: `_physics_process` is disabled via `set_physics_process(false)` in `_ready()`.
  - Animation is driven cleanly from the outside via `update_procedural_animation()`.
  - When set to `true` (e.g. in the showcase test scene), `_physics_process` activates for standalone play.

---

## 3. Interface Method Specifications

To fulfill the requirements of `PROJECT.md` and seamlessly interface with `ModularAssetSystem`, `GameController`, and AI entities, `stickmanprocedural.gd` provides the following contract:

### 1. `update_procedural_animation`
```gdscript
func update_procedural_animation(
    p_velocity: Vector2,
    is_on_ground: bool,
    facing_direction: float,
    current_state: String,
    delta: float
) -> void
```
- **Parameters**:
  - `p_velocity`: Current 2D velocity vector in pixels/sec.
  - `is_on_ground`: True if feet have contact with ground.
  - `facing_direction`: $+1.0$ for right, $-1.0$ for left.
  - `current_state`: Entity animation state (`"idle"`, `"run"`, `"jump"`, `"fall"`, `"wall_slide"`, `"slash"`, `"heavy_slash"`, `"parry_guard"`).
  - `delta`: Frame delta time in seconds.
- **Behavior**:
  - Updates `facing`.
  - Accumulates gait phase $\Delta\Phi = \frac{|v_x| \cdot \Delta t}{2 \cdot \text{stride\_length}}$.
  - Selects offset solver matching `current_state`.
  - Exponentially lerps IK targets: $\text{weight} = 1.0 - e^{-\text{snappiness} \cdot \Delta t}$.

### 2. `get_bone_positions`
```gdscript
func get_bone_positions() -> Dictionary[String, Vector2]
```
- **Returns**: Dictionary mapping joint names to 2D coordinates in character-local space (`to_local(bone.global_position)`).
- **Supported Joint Keys**:
  `pelvis`, `neck`, `head`, `head_center`, `torso`, `waist`, `left_shoulder`, `left_elbow`, `left_hand`, `right_shoulder`, `right_elbow`, `right_hand`, `left_hip`, `left_knee`, `left_foot`, `right_hip`, `right_knee`, `right_foot`.

### 3. `get_ik_targets`
```gdscript
func get_ik_targets() -> Dictionary[String, Node2D]
```
- **Returns**: Dictionary with direct references to the 5 IK target nodes (`"foot_r"`, `"foot_l"`, `"arm_r"`, `"arm_l"`, `"head"`).

### 4. `to_stickman_pose`
```gdscript
func to_stickman_pose(loadout_facing: float = 1.0) -> RefCounted
```
- **Returns**: A populated `ModularAssetSystem.StickmanPose` instance reflecting the live bone positions. Enables `GameController._draw_modular_character()` to render equipment, modular weapons, and pauldrons directly aligned with the procedural rig.

---

## 4. Parameter Exports Specification

In accordance with `PROJECT.md §Interface Contracts`, the exported variables are structured as follows:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `autonomous_physics` | `bool` | `false` | Standalone movement mode toggle |
| `stride_length` | `float` | `52.0` | Horizontal ground distance per half-stride |
| `foot_lift` | `float` | `6.0` | Maximum vertical lift during swing phase |
| `arm_swing` | `float` | `24.0` | Horizontal reach of arm counter-swing |
| `hand_lift` | `float` | `6.0` | Vertical lift of hands during swing |
| `head_bounce` | `float` | `2.5` | Amplitude of dual-frequency head bob |
| `head_lean` | `float` | `9.0` | Forward lean of head target during locomotion |
| `snappiness` | `float` | `18.0` | Spring response rate ($1 - e^{-\text{snappiness} \cdot \Delta t}$) |
| `air_foot_spread` | `float` | `14.0` | Leg spread separation while airborne |
| `air_foot_lift` | `float` | `12.0` | Leg tuck retraction during jump ascent |
| `air_hand_lift` | `float` | `18.0` | Hand elevation while airborne |

**Backward Compatibility Aliases**:
To avoid breaking any code that refers to original reference property names:
- `hand_swing` is a property getter/setter alias for `arm_swing`.
- `pose_response` is a property getter/setter alias for `snappiness`.

---

## 5. Exact Line-by-Line Fix Instructions for Worker

The Worker should apply the following precise edits upon importing the files into `new-game-project`:

### Target File 1: `scenes/stickman/stickmanprocedural.tscn`

1. **Insert Script External Resource at Scene Header** (after line 1):
   ```ini
   [ext_resource type="Script" uid="uid://vawx2quhkhg3" path="res://scripts/stickman/stickmanprocedural.gd" id="1_script"]
   ```
2. **Remove Defective 6th CCDIK Modifier** (lines 112–114):
   Delete lines:
   ```ini
   [sub_resource type="SkeletonModification2DCCDIK" id="SkeletonModification2DCCDIK_gavct"]
   tip_nodepath = NodePath("Hip/Waist/Torso/Neck")
   ```
3. **Update SkeletonModificationStack2D** (lines 115–123):
   Change:
   ```ini
   [sub_resource type="SkeletonModificationStack2D" id="SkeletonModificationStack2D_y3uf6"]
   enabled = true
   modification_count = 6
   modifications/0 = SubResource("SkeletonModification2DCCDIK_aqggk")
   modifications/1 = SubResource("SkeletonModification2DCCDIK_kt8o7")
   modifications/2 = SubResource("SkeletonModification2DCCDIK_e4tth")
   modifications/3 = SubResource("SkeletonModification2DCCDIK_w7c4t")
   modifications/4 = SubResource("SkeletonModification2DLookAt_ymdls")
   modifications/5 = SubResource("SkeletonModification2DCCDIK_gavct")
   ```
   To:
   ```ini
   [sub_resource type="SkeletonModificationStack2D" id="SkeletonModificationStack2D_y3uf6"]
   enabled = true
   modification_count = 5
   modifications/0 = SubResource("SkeletonModification2DCCDIK_aqggk")
   modifications/1 = SubResource("SkeletonModification2DCCDIK_kt8o7")
   modifications/2 = SubResource("SkeletonModification2DCCDIK_e4tth")
   modifications/3 = SubResource("SkeletonModification2DCCDIK_w7c4t")
   modifications/4 = SubResource("SkeletonModification2DLookAt_ymdls")
   ```
4. **Attach Script to Root Node** (line 125):
   Change:
   ```ini
   [node name="Player" type="CharacterBody2D" unique_id=562865352]
   ```
   To:
   ```ini
   [node name="Player" type="CharacterBody2D" unique_id=562865352]
   script = ExtResource("1_script")
   ```

### Target File 2: `scripts/stickman/stickmanprocedural.gd`

The Worker can directly deploy the fully prepared, lint-free implementation from:
`.agents/teamwork/teamwork_explorer_m1_2/proposed_stickmanprocedural.gd`  
Or apply the unified diff from:
`.agents/teamwork/teamwork_explorer_m1_2/remediation.patch`

---

## 6. Verification Method

To verify the remediations independently:
1. **Script Syntax & Compilation Check**:
   ```powershell
   & "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "new-game-project" --check-only
   ```
   Must exit with code 0 and 0 errors.
2. **Full Regression Test Suite**:
   ```cmd
   cmd /c "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\run_tests.bat"
   ```
   Must produce `ALL 5 TEST SUITES PASSED!`.
3. **Rig Instantiation Unit Test**:
   Instantiate `res://scenes/stickman/stickmanprocedural.tscn` in a unit test:
   - Confirm `rig.get_script() != null`.
   - Confirm `rig.has_method("update_procedural_animation") == true`.
   - Confirm `rig.get_bone_positions().size() == 17`.
   - Confirm `rig.to_stickman_pose() is ModularAssetSystem.StickmanPose`.
