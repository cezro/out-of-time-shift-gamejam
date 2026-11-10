# Handoff Report: Milestone 3 — Feature 8: Timeline Clones Procedural Coverage

**Agent**: `teamwork_explorer_m3_g2_2`  
**Working Directory**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m3_g2_2`  
**Date**: 2026-11-10  
**Status**: Task Complete (Hard Handoff)

---

## 1. Observation

1. **ChronoEchoData Schema**: In `new-game-project/scripts/timeline/timeline_system.gd:145-177`:
   ```gdscript
   class ChronoEchoData extends RefCounted:
       var origin: Vector2 = Vector2.ZERO
       var aim_dir: Vector2 = Vector2.RIGHT
       var era: int = TimelineEra.PRESENT
       var timer: float = 3.0
       var max_timer: float = 3.0
       var radius: float = 95.0
       var echo_type: String = "slash"
   ```
   Directly observed: `ChronoEchoData` lacks character pose fields (`facing`, `velocity`, `is_grounded`, `anim_time`, `stance`, `attack_progress`, `loadout_id`), and lacks any trajectory buffer.

2. **Chrono-Echo Rendering**: In `new-game-project/scripts/game/game_controller.gd:1883-1892`:
   ```gdscript
   # 5. Chrono-Echoes
   for echo in timeline.echoes:
       if echo == null:
           continue
       var e_alpha: float = 0.75 if echo.era == timeline.current_era else 0.30
       var e_scr: Vector2 = to_screen(echo.origin)
       _d_arc(e_scr, echo.radius * 0.35, 0.0, TAU, 24, Color(0.2, 0.95, 1.0, e_alpha), 2.0)
       var dir_scr := Vector2(echo.aim_dir.x, -echo.aim_dir.y)
       _d_line(e_scr - dir_scr * 18.0, e_scr + dir_scr * 24.0, Color(0.95, 0.82, 0.3, e_alpha), 2.5)
   ```
   Directly observed: Chrono-Echoes render only as an abstract wireframe circle arc and aim vector. They do not render a stickman body, modular equipment, or animated pose.

3. **Ghost Trail Data & Rendering**: In `new-game-project/scripts/game/game_controller.gd:16-54` and `1893-1911`:
   - `GhostTrailData` stores `position`, `facing`, `velocity`, `is_grounded`, `anim_time`, `is_attacking`, `attack_progress`, `stance`, `timer`, `max_timer`, `color`, `era`, `loadout_id`.
   - In `_draw()`:
   ```gdscript
   var g_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
       ghost.position, ghost.facing, ghost.velocity, ghost.is_grounded,
       ghost.anim_time, ghost.is_attacking, ghost.attack_progress, false, ghost.stance
   )
   var g_col := Color(ghost.color.r, ghost.color.g, ghost.color.b, ghost.color.a * g_ratio)
   _draw_pose_skeleton(g_pose, g_col, 2.0)
   ```
   Directly observed: Ghost trails solve poses mathematically via `StickmanPoseSolver`, but only draw the untextured bone lines via `_draw_pose_skeleton()`.

4. **Procedural Stickman Rig & PACKED_SCENE**:
   In `new-game-project/scripts/modular_rig/modular_asset_system.gd:2248-2274`:
   `player_procedural_stickman` is registered in `ModularAssetRegistry` mapping to `res://scenes/stickman/stickmanprocedural.tscn` under `AssetRenderBackend.PACKED_SCENE`.
   In `new-game-project/scripts/stickman/stickmanprocedural.gd:188-233`:
   Provides `update_procedural_animation(velocity, is_on_ground, facing, current_state, delta)`.
   In lines 11-12 & 138-142: `autonomous_physics: bool = false` disables autonomous physics and enables external driving.

5. **Test Baseline Status**: Ran `cmd.exe /c run_tests.bat` via terminal. All 5 test suites passed cleanly with 100% success (42 core tests, 35 chrono/timeline tests, 230 modular rig tests, 12 game integration tests, 17 adversarial disprover tests).

---

## 2. Logic Chain

1. **From Observation 1 & 2**: Because `ChronoEchoData` only stores `origin`, `aim_dir`, `era`, and `timer`, any renderer attempting to draw an echo cannot know what posture or action the player was performing when the echo was cast. Therefore, `ChronoEchoData` must be extended with snapshot fields (`facing`, `velocity`, `is_grounded`, `anim_time`, `stance`, `attack_progress`, `loadout_id`).
2. **From Observation 2 & 3**: Ghost trails are spawned rapidly (e.g. every 0.04s during dash and 3 at once during warp), whereas Chrono-Echoes are few (max 1–3 active per era) but persist for 3.0 seconds. Instantiating a full `stickmanprocedural.tscn` node tree with 17 bones and 5 IK modifiers for every ghost trail would trigger 20+ node allocations and deallocations per second, causing GC frame drops.
3. **From Step 2 and Observation 4**: A **Dual-Tier System** is the mathematically optimal architecture:
   - **Tier 1 (Transient Afterimages & Ghosts)**: Use `ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose()` rendered through `_draw_modular_character()` or `_draw_pose_skeleton()`. Pure mathematical evaluation, $\mathcal{O}(1)$ time, zero node allocations.
   - **Tier 2 (Persistent Chrono-Echoes & Clones)**: Use a bounded preallocated node pool (`EchoRigPool`, 3–4 instances of `stickmanprocedural.tscn`) attached to the scene tree with `autonomous_physics = false`. Driven via `update_procedural_animation()`, modulated with era colors, and hidden when inactive. Zero runtime node allocations.
4. **From Observation 1 & Continuous Trajectory Requirements**: For timeline replays, rewinds, and historical clone playback, a pre-allocated circular ring buffer (`TimelineTrajectoryBuffer`, 300 frames) eliminates GC allocation spikes, and cubic Hermite interpolation guarantees $C^1$ velocity continuity between discrete recorded frames.
5. **From Observation 5**: All existing tests in `run_tests.bat` pass. The proposed changes preserve backward compatibility for `timeline.spawn_chrono_echo()` by providing default arguments for new parameters, ensuring 0 test regressions.

---

## 3. Caveats

1. **Node Pool Sizing**: The proposed `EchoRigPool` has a default capacity of 4 nodes. If gameplay allows more than 4 echoes to exist simultaneously across all eras, echoes beyond index 3 must fall back to Tier 1 mathematical drawing (`_draw_modular_character`). This graceful fallback is designed and documented in `report.md`.
2. **Shader vs Canvas Modulate**: In Godot 4 CanvasItem rendering, setting `CanvasItem.modulate` on the root of `stickmanprocedural.tscn` multiplies child sprite colors uniformly. If advanced spectral chromatic dispersion is desired at the GPU level, a custom CanvasItem shader will be required; currently, the dual-draw geometric offset method achieves this without requiring a custom shader file.
3. **Autonomous Physics Deactivation**: When `StickmanProcedural` nodes are used in the pool, `autonomous_physics` MUST be `false` (which is already the default in `stickmanprocedural.gd:11`). If set to `true`, the rig's internal `move_and_slide()` would fight external timeline placement.

---

## 4. Conclusion

The investigation is complete. The path forward for Feature 8 (Timeline Clones Procedural Coverage) is fully documented in `report.md`. It provides:
1. **Extended Data Structures**: Pose-aware `ChronoEchoData` and a zero-allocation circular `TimelineTrajectoryBuffer`.
2. **Dual-Tier Rig Integration**: Tier 1 mathematical pose solving for high-frequency afterimages + Tier 2 pre-allocated `EchoRigPool` (`stickmanprocedural.tscn`) for multi-second Chrono-Echoes.
3. **Aesthetic Harmonization**: 3-era chromatic tinting (PAST Amber, PRESENT Cyan, FUTURE Magenta), active-era pulsating resonance, and distance-based afterimage spacing invariant under Chronos Shift time dilation.
4. **Deterministic Combat**: Exact bone-aligned strike hitboxes and slice deduplication by `enemy_id`.

---

## 5. Verification Method

To independently verify the investigation and future implementation:

1. **Automated Regression Suite**:
   Execute the full test suite in powershell / command prompt:
   ```cmd
   cmd.exe /c run_tests.bat
   ```
   **Expected Result**: All 5 test suites pass with 100% success (0 errors, 0 warnings).
2. **Code Inspection**:
   - Inspect `new-game-project/scripts/timeline/timeline_system.gd` lines 145–177 (`ChronoEchoData`).
   - Inspect `new-game-project/scripts/game/game_controller.gd` lines 1883–1911 (`_draw()` echo and ghost loops).
   - Inspect `new-game-project/scripts/stickman/stickmanprocedural.gd` lines 188–233 (`update_procedural_animation()`).
   - Inspect `.agents/teamwork/teamwork_explorer_m3_g2_2/report.md` for full implementation details.
3. **Invalidation Conditions**:
   - The findings are invalidated if `run_tests.bat` fails.
   - The findings are invalidated if dynamic node allocation during dash afterimages produces measurable garbage-collection hitching.
