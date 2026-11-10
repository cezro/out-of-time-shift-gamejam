# Handoff Report — Milestone 3 Challenger 1: Adversarial Stress Testing & Global Stickman Coverage

**Verdict**: `REQUEST_CHANGES`

## 1. Observation
1. Baseline test suite execution via `cmd /c run_tests.bat`:
   - Suite 1 (`test_core.gd`): 42 / 42 passed
   - Suite 2 (`test_chrono_and_timeline.gd`): 35 / 35 passed
   - Suite 3 (`test_modular_rig.gd`): 287 / 287 passed
   - Suite 4 (`test_game_integration.gd`): 12 / 12 passed
   - Suite 5 (`test_adversarial_disprover.gd`): 17 / 17 passed
   - Status: All 5 suites (393 total assertions) pass 100%.

2. Empirical adversarial stress harness implemented in `new-game-project/tests/test_adversarial_m3_stress.gd` executed headlessly (`godot.windows.opt.tools.64.exe --headless --path new-game-project --script res://tests/test_adversarial_m3_stress.gd`):
   - **Test 1 — 100+ Enemies Across All 6 Archetypes & AI State Cycling**:
     - 120 enemies spawned simultaneously (20 RUNNER, 20 NINJA, 20 HEAVY, 20 GUNNER_SEMI, 20 GUNNER_AUTO, 20 SNIPER) across PAST, PRESENT, FUTURE.
     - Cycled AI states through `CHASE` -> `WINDUP` -> `ATTACK` -> `HITSTUN` -> `JUGGLED` over 60 simulation frames.
     - Observation: `ctrl._enemy_rig_pool` scaled dynamically to 120 nodes, all rigs updated with finite positions, positive scale, and archetype color modulation; `ctrl.last_draw_primitive_count` exceeded 250 primitives per frame without crash, NaN, or slowdown.
     - **Result: PASS**.
   - **Test 2 — 50+ Enemies (100+ Pieces) Sliced Simultaneously with Custom Armor Tumbling**:
     - 60 enemies across all 6 archetypes simultaneously sliced into 120 ragdoll pieces (60 `UPPER_TORSO` + 60 `LOWER_LEGS`).
     - Tumbled over 60 physics frames with angular velocities $\pm 14.0\text{ rad/s}$ and ground bounce.
     - Observation: Split loadouts (`enemy_runner_upper`, `enemy_heavy_lower`, etc.) were dynamically registered in `ModularAssetRegistry`. `compute_slot_transform()` calculated finite poses tracking tumbling pieces (helmets on head, boots on feet, weapons on arms).
     - **Result: PASS**.
   - **Test 3 — 50+ Chrono-Echoes Across All 3 Eras with Rapid Era Shifting & Detonations**:
     - 60 Chrono-Echoes spawned (20 PAST, 20 PRESENT, 20 FUTURE) across varied combat stances.
     - 30 rapid sequential era shifts executed via `ctrl.timeline.try_shift_timeline()`.
     - Observation: Echoes in target eras detonated correctly, remaining echoes faded with bounded `fade_ratio()` in $[0.0, 1.0]$. The 4 pooled echo rigs in `_echo_rig_pool` and canvas fallback rendered cleanly with 0 out-of-bounds errors. Full decay reached 0 echoes after 5.0s.
     - **Result: PASS**.
   - **Test 5 — Memory Leak & Orphan Node Monitoring (`Performance.OBJECT_ORPHAN_NODE_COUNT`)**:
     - 3 heavy lifecycle iterations of spawning 60 enemies, 40 ragdolls, 30 echoes, running simulation/draw, and freeing scenes.
     - Observation: `[ORPHAN MONITOR] Initial: 0 | Final: 0 | Delta: 0`.
     - **Result: PASS (0 orphan node leak)**.
   - **Test 4 — Rapid Player Directional Flipping ($+1.0 \leftrightarrow -1.0$) and High-Speed Launch/Slam**:
     - Tested 120 frames with directional flips every frame ($+1.0 \leftrightarrow -1.0$) and vertical velocity transitions between $+1400.0\text{ px/s}$ (launch) and $-2800.0\text{ px/s}$ (downward slam).
     - Observation: Player position and velocity remained strictly finite. However, the procedural scarf distance constraint invariant was violated:
       ```
       ADVERSARIAL STRESS FAILURE: Frame 1: Scarf segment 0-1 distance clamped in [6, 14] px (got 14.558606)
       ADVERSARIAL STRESS FAILURE: Frame 1: Scarf segment 1-2 distance clamped in [6, 14] px (got 14.511223)
       ...
       ADVERSARIAL STRESS FAILURE: Frame 90: Scarf segment 0-1 distance clamped in [6, 14] px (got 18.677620)
       ADVERSARIAL STRESS FAILURE: Frame 90: Scarf segment 1-2 distance clamped in [6, 14] px (got 17.494371)
       ...
       ADVERSARIAL STRESS FAILURE: Frame 114: Scarf segment 0-1 distance clamped in [6, 14] px (got 4.445323)
       ```
     - **Result: FAIL (Scarf distance constraint violated; expands up to $18.79\text{ px}$ and compresses to $4.44\text{ px}$)**.

## 2. Logic Chain
1. In `new-game-project/scripts/modular_rig/modular_asset_system.gd:1431-1439`, distance constraints are computed:
   ```gdscript
   var d01: float = scarf_0.distance_to(scarf_1)
   if d01 > 0.001:
       var dir01: Vector2 = (scarf_1 - scarf_0) / d01
       scarf_1 = scarf_0 + dir01 * clampf(d01, 6.0, 14.0)
   var d12: float = scarf_1.distance_to(scarf_2)
   if d12 > 0.001:
       var dir12: Vector2 = (scarf_2 - scarf_1) / d12
       scarf_2 = scarf_1 + dir12 * clampf(d12, 6.0, 14.0)
   ```
2. However, immediately after clamping in lines 1441–1449, the X coordinates are unconditionally overridden to enforce directional trailing:
   ```gdscript
   if face_dir > 0.0:
       scarf_0.x = minf(scarf_0.x, head_back.x - 4.0)
       scarf_1.x = minf(scarf_1.x, scarf_0.x - 4.0)
       scarf_2.x = minf(scarf_2.x, scarf_1.x - 4.0)
   else:
       scarf_0.x = maxf(scarf_0.x, head_back.x + 4.0)
       scarf_1.x = maxf(scarf_1.x, scarf_0.x + 4.0)
       scarf_2.x = maxf(scarf_2.x, scarf_1.x + 4.0)
   ```
3. Because Euclidean distance $d = \sqrt{(x_{i+1} - x_i)^2 + (y_{i+1} - y_i)^2}$ depends directly on the X separation, modifying the X coordinates post-clamp invalidates the previous distance clamping. Under rapid directional turns and high vertical speed ($v_y = \pm 2800$), $(y_{i+1} - y_i)$ is large while $(x_{i+1} - x_i)$ is altered, causing the distance to stretch to $18.79\text{ px}$ ($>134\%$ of the 14.0px maximum) or compress to $4.44\text{ px}$ ($<75\%$ of the 6.0px minimum).
4. In steady-state running (`test_modular_rig.gd:521`), $v_y = 0$ and facing is constant $+1.0$, which masked the defect during Worker unit testing.
5. Mitigation: In `StickmanPoseSolver.generate_stickman_pose()`, directional trailing must be evaluated prior to distance clamping, or distance clamping must project the node along the constrained trailing link so both the trailing invariant AND the $[6.0, 14.0]\text{ px}$ distance constraint are simultaneously satisfied.

## 3. Caveats
- The core simulation, kinematic physics, combat math, enemy AI, time dilation, and audio systems are stable, finite, and free of memory leaks.
- Zero orphan nodes were leaked across all tests (delta == 0).
- The existing 5 test suites pass 100% because existing tests only sampled steady-state forward running.

## 4. Conclusion
**Verdict: `REQUEST_CHANGES`**

While 4 out of 5 stress scenarios passed with flying colors (120 enemy archetype state cycles, 120 tumbling ragdoll halves, 60 multi-era echoes, and 0 orphan node leaks), an adversarial edge case was uncovered in `modular_asset_system.gd`:
- **Defect**: Scarf segment distances violate the $[6.0, 14.0]\text{ px}$ constraint during rapid player directional flipping and high vertical velocity transitions, expanding up to $18.79\text{ px}$ and compressing down to $4.44\text{ px}$.
- **Resolution Required**: In `StickmanPoseSolver.generate_stickman_pose()`, re-order or project the distance constraint solver so that scarf segment lengths strictly respect $[6.0, 14.0]\text{ px}$ while trailing behind the head during rapid turns and vertical slams.

## 5. Verification Method
1. Run full project test suites:
   ```cmd
   cmd /c run_tests.bat
   ```
   *Expected outcome*: All 5 test suites pass (393 / 393 assertions).
2. Run empirical adversarial stress harness:
   ```powershell
   & "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path new-game-project --script res://tests/test_adversarial_m3_stress.gd
   ```
   *Current outcome*: 4 / 5 pass, with `test_stress_04` surfacing the scarf distance violation defect.
   *Resolution criteria*: After worker fixes constraint ordering, all 5 stress tests must pass 100%.
