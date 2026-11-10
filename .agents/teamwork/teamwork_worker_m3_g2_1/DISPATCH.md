## 2026-11-10T15:30:17Z
You are teamwork_worker_m3_g2_1 (Worker for Milestone 3: Global Coverage Across All Stickman Entities).
Your working directory is: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_worker_m3_g2_1
Workspace root: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY FIRST STEPS:
1. Read ORIGINAL_REQUEST.md: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md
2. Read PROJECT.md: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\PROJECT.md
3. Read the Explorer Reports from Milestone 3:
   - Explorer 1 (Player Rig Integration): c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m3_g2_1\report.md
   - Explorer 2 (Timeline Clones & Echoes): c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m3_g2_2\report.md
   - Explorer 3 (Enemies & Scene Rig Replacement): c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m3_g2_3\report.md

FILE WRITE OWNERSHIP:
You exclusively own and may edit:
- `new-game-project/scripts/game/game_controller.gd`
- `new-game-project/scripts/core/player_kinematics.gd`
- `new-game-project/scripts/timeline/timeline_system.gd`
- `new-game-project/scripts/modular_rig/modular_asset_system.gd`
- `new-game-project/scripts/stickman/stickmanprocedural.gd`
- Tests under `new-game-project/tests/`

IMPLEMENTATION TASKS (Milestone 3: Features 7, 8, 9, 10):
1. **Feature 7: Player Rig & Animation Integration**:
   - In `game_controller.gd`: Maintain a persistent `PoseDynamicsContext` for the player (`player_dynamics_ctx`). Pass horizontal acceleration ($a_x = dv_x / dt$), `player_dynamics_ctx`, and `dt` into `StickmanPoseSolver.generate_stickman_pose` so the player exhibits live acceleration lean, head lag, and dynamic scarf trailing.
   - Support `player_procedural_stickman` loadout. When passing simulation coordinates (+Y UP) to engine nodes (+Y DOWN), properly invert vertical velocity.
2. **Feature 8: Timeline Clones Procedural Coverage**:
   - In `timeline_system.gd`: Add `facing`, `velocity`, `is_grounded`, `stance`, `anim_time` to timeline recording / echo data.
   - In `game_controller.gd`: Render Chrono-Echoes and timeline clones using full modular stickman poses (`StickmanPoseSolver.generate_stickman_pose`) rather than bare circles, applying era-specific color tinting (PAST Amber, PRESENT Cyan, FUTURE Magenta) and alpha transparency.
   - Maintain distance-based afterimage spacing invariant under Chronos Shift time dilation.
3. **Feature 9 & 10: Enemy / NPC Coverage & Scene Rig Replacement**:
   - In `modular_asset_system.gd`: Register `"player_default"` as an alias to `"player_shift_staff"` in `ModularAssetRegistry`.
   - Wire all 6 enemy archetypes (`enemy_runner`, `enemy_ninja`, `enemy_heavy`, `enemy_gunner_semi`, `enemy_gunner_auto`, `enemy_sniper`) to reference `PROCEDURAL_STICKMAN_SCENE_PATH`.
   - In `game_controller.gd:1923`: replace hardcoded `"normal"` enemy stance with dynamic stance mapped from enemy AI state and archetype (e.g., windup -> `"parry_guard"` or charge, attack -> `"heavy_slash"`, airborne -> `"jump"`).
   - In `game_controller.gd`: Upgrade `_draw_ragdoll_piece()` so severed upper and lower stickman halves render custom helmets, cowls, chestplates, and weapons as they tumble.

VERIFICATION REQUIREMENTS:
- Run Godot `--check-only` headless on all modified scripts. Ensure zero compiler warnings and zero errors.
- Run `run_tests.bat` (all 5 test suites). All tests must pass 100%.
- Run `test_modular_rig.gd`, `test_m2_motion_dynamics.gd`, and all existing tests. Ensure zero regressions.
- Verify that `test_01_scene_instantiation_hud_and_draw` passes (`last_draw_primitive_count > 100`).
