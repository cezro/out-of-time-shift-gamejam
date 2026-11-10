# Handoff Report: Coordinate Parity Remediation in `to_stickman_pose()`

**Agent**: Milestone 1 Iteration 2 Explorer 2 (`teamwork_explorer_m1_it2_2`)  
**Target Recipient**: Orchestrator (`0fd925e9-f058-4fd8-8532-3aab95b2a4f6`)  
**Date**: 2026-11-10  
**Type**: Hard Handoff (Investigation & Strategy Complete)  

---

## 1. Observation

1. **Contract Invariant (`PROJECT.md:50`)**:
   > `Joint invariants: +Y is UP in simulation coordinates (head_center.y > neck.y > pelvis.y)`
2. **Screen Projection Transform (`new-game-project/scripts/game/game_controller.gd:60–66`)**:
   ```gdscript
   static func to_screen(sim_pos: Vector2) -> Vector2:
       return Vector2(sim_pos.x, -sim_pos.y)

   static func to_sim(screen_pos: Vector2) -> Vector2:
       return Vector2(screen_pos.x, -screen_pos.y)
   ```
3. **Unconverted Raw Coordinates in `to_stickman_pose()` (`new-game-project/scripts/stickman/stickmanprocedural.gd:372–399`)**:
   ```gdscript
   func to_stickman_pose(loadout_facing: float = 1.0) -> RefCounted:
       var bones := get_bone_positions()
       ...
       pose.head_center = bones.get("head_center", Vector2.ZERO)
       pose.neck = bones.get("neck", Vector2.ZERO)
       pose.pelvis = bones.get("pelvis", Vector2.ZERO)
       ...
   ```
   `get_bone_positions()` evaluates `to_local(b_node.global_position)` on each `Bone2D`, returning coordinates in Godot 2D local space ($+Y$ DOWN).
4. **Empirical Measurements on Live Rig**:
   Execution of `stickmanprocedural.tscn` in headless Godot yields live bone coordinates:
   - `head_center`: `Vector2(-20.0, -184.0)`
   - `neck`: `Vector2(-18.0, -161.0)`
   - `pelvis`: `Vector2(1.0, -2.0)`
   - `left_foot`: `Vector2(23.0, 325.0)`
   - `right_foot`: `Vector2(-123.8, 320.3)`
   In character-local Godot 2D space:
   $$y_{head\_center} (-184.0) < y_{neck} (-161.0) < y_{pelvis} (-2.0) < y_{feet} (+325.0)$$
   When un-inverted coordinates are copied into `pose`, `pose.head_center.y < pose.neck.y < pose.pelvis.y`, directly violating `PROJECT.md:50`.
5. **Slot Transforms and Rendering Projections (`new-game-project/scripts/modular_rig/modular_asset_system.gd:1115–1117`)**:
   ```gdscript
   PartSlot.HEAD:
       start_pt = pose.neck
       end_pt = pose.head_center + Vector2(0.0, pose.head_radius)
   ```
   `compute_slot_transform()` assumes $+Y$ UP, adding $+8.5$ in Y for the head crown. With $y_{head} = -184.0$, $+8.5$ points downward towards the neck instead of upward.

---

## 2. Logic Chain

1. From **Observation 1 & 4**, Godot 2D coordinates have $+Y$ DOWN, whereas simulation space (`StickmanPose`) requires $+Y$ UP.
2. From **Observation 3**, copying raw Godot 2D coordinates directly into `StickmanPose` results in an upside-down vertical orientation ($y_{head} < y_{neck} < y_{pelvis}$).
3. From **Observation 2**, `game_controller.gd:to_screen()` negates the Y coordinate to project simulation points onto the screen: $\text{to\_screen}(x, y) = (x, -y)$.
4. Applying `to_screen()` to the un-inverted pose maps the head to screen $y = +184.0$ (down near ground) and feet to screen $y = -325.0$ (up in air), visually flipping the stickman upside down.
5. In both Godot 2D and simulation space, $+X$ points RIGHT and $-X$ points LEFT. Therefore, the transformation from Godot 2D space to simulation space is a reflection across the horizontal X-axis:
   $$M = \begin{pmatrix} 1 & 0 \\ 0 & -1 \end{pmatrix}, \quad \vec{v}_{sim} = (x_{local}, -y_{local})$$
6. Under this transformation:
   - $y_{sim} = -y_{local}$ inverts vertical coordinates: $y_{sim, head} = +184.0 > y_{sim, neck} = +161.0 > y_{sim, pelvis} = +2.0 > y_{sim, feet} = -325.0$. The contract $\text{head\_center}.y > \text{neck}.y > \text{pelvis}.y$ is satisfied.
   - $x_{sim} = x_{local}$ preserves all horizontal coordinates, offsets, and forward leans ($x \cdot \text{facing} > 0$) identically.
   - The round-trip $\text{to\_screen}(\vec{v}_{sim}) = (x_{local}, -(-y_{local})) = (x_{local}, y_{local})$ is a lossless mathematical involution.
7. Adding a static helper `_to_sim_coord(local_pos: Vector2) -> Vector2` with `is_finite` guards sanitizes incoming vectors and transforms all 14 skeletal bone endpoints cleanly.

---

## 3. Caveats

1. **Scope Boundary**: This analysis designs the coordinate remediation strategy and provides the exact code diff. Per the explorer archetype constraints, source code edits in `new-game-project/scripts/stickman/stickmanprocedural.gd` are left to the implementation agent (Worker / Prover).
2. **Scale Consideration**: `StickmanProcedural` bone positions use scene-pixel units (~500px height), whereas `StickmanPoseSolver` generates poses in ~60-unit simulation space. Because `ModularAssetSystem.compute_slot_transform()` derives limb vectors directly from joint differences without hardcoded length clamping, pixel-scale poses work consistently when rendered via `to_screen()`. Normalization or scaling factors (if desired for unified physics ragdolls) can be applied if Milestone 3 requires identical unit scales.

---

## 4. Conclusion

1. **Root Cause**: `stickmanprocedural.gd:to_stickman_pose()` copied raw Godot 2D character-local coordinates ($+Y$ DOWN) directly into `StickmanPose` ($+Y$ UP) without negating the Y axis.
2. **Remediation Strategy**:
   - Implement `static func _to_sim_coord(local_pos: Vector2) -> Vector2: return Vector2(local_pos.x if is_finite(local_pos.x) else 0.0, -local_pos.y if is_finite(local_pos.y) else 0.0)`.
   - In `to_stickman_pose()`, map all 14 bone vectors through `_to_sim_coord()`.
   - Populate secondary anchors (`sword_hilt`, `sword_tip`, and 3-node `scarf_nodes`) using resolved facing direction to ensure full compatibility with `ModularAssetSystem.compute_slot_transform()`.
3. **Artifacts Delivered**:
   - Technical analysis: `.agents/teamwork/teamwork_explorer_m1_it2_2/report.md`
   - Unified machine patch: `.agents/teamwork/teamwork_explorer_m1_it2_2/stickmanprocedural_coord_parity.patch`
   - Test assertion recommendation: `.agents/teamwork/teamwork_explorer_m1_it2_2/report.md` §6

---

## 5. Verification Method

1. **Apply the Patch**:
   Apply `.agents/teamwork/teamwork_explorer_m1_it2_2/stickmanprocedural_coord_parity.patch` to `new-game-project/scripts/stickman/stickmanprocedural.gd`.
2. **Headless Compilation**:
   ```powershell
   & "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "new-game-project" --check-only
   ```
   Must exit with code 0 and 0 errors/warnings.
3. **Automated Test Suite**:
   ```powershell
   cmd.exe /c "run_tests.bat"
   ```
   Must pass all 5 test suites (100% pass rate).
4. **Adversarial & Coordinate Invariant Verification**:
   ```powershell
   & "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "new-game-project" --script "res://tests/test_challenger_m1_2_adversarial.gd"
   ```
   Verify that `test_14_live_rig_to_stickman_pose_simulation` confirms:
   - `pose.head_center.y > pose.neck.y` (e.g., $184.0 > 161.0$)
   - `pose.neck.y > pose.pelvis.y` (e.g., $161.0 > 2.0$)
   - `pose.pelvis.y > pose.left_foot.y` (e.g., $2.0 > -325.0$)
