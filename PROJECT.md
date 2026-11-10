# Project: OUT OF TIME — Godot Project Health & Error Remediation

## Architecture
- **Engine**: Godot Engine 4.7.2.stable.steam.ed1daf0bf (`D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`)
- **Tooling**: Godot MCP Tooling (`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\tools\godot-mcp`)
- **Simulation**: Mathematical kinematic simulation, pure GDScript simulation models (ChronoShiftModel, TimelineSystem, CombatMath, EnemyAI, RagdollPhysics, ModularAssetSystem, StickmanProcedural).
- **Presentation**: Single main scene `scenes/main.tscn`, modular procedural scene `scenes/stickman/stickmanprocedural.tscn`, procedural 2D canvas drawing (`_draw()`), 14 dynamic HUD controls.

## Feature / Issue Inventory
| # | Feature / Issue | Description | Milestone | Source | Status |
|---|-----------------|-------------|-----------|--------|--------|
| 1 | `chrono_shift_model.gd:210` warning | Shadowed built-in identifier `len` in `_compute_drift_vector` | M1 | Survey | RESOLVED (`d_len`) |
| 2 | `chrono_shift_model.gd:940` warning | Incompatible ternary operator return types (`bool` vs `null`) | M1 | Survey | RESOLVED (explicit if-else) |
| 3 | `timeline_system.gd:49` warning | Local parameter `center_x` in `_init` shadows method `center_x()` | M1 | Survey | RESOLVED (`p_center_x`) |
| 4 | `game_controller.gd:857` warning | Unused local variable `world_dt` in `_step_simulation` | M1 | Survey | RESOLVED (removed) |
| 5 | `game_controller.gd:2255` warning | Local variable `tr` in `_draw_seven_segment_glyph` shadows base class `Object.tr()` | M1 | Survey | RESOLVED (`pt_tr`) |
| 6 | `test_adversarial_disprover.gd:698` warning | Unused local variable `reg` in test method | M1 | Survey | RESOLVED (`_reg`) |
| 7 | `scenes/main.tscn` UID hygiene | Missing UID header in `main.tscn` and missing script UID on `ExtResource` | M1 | Survey | RESOLVED (`uid://cq6bj1igfs42f`) |
| 8 | Godot MCP Tooling Integration | Verify Godot MCP server inspection, project info, run_project, debug output | M1 | Survey | VERIFIED (0 errors, 17/17 passed) |
| 9 | Verification & Zero-Warning Gate M1 | Verify clean console, 0 parse errors, 0 runtime errors, 0 warnings across all core scripts | M1 | Acceptance Criteria | DONE |
| 10 | `stickmanprocedural.gd:132` warning | Unused local variable `previous_position` in `_step_simulation` | M2 | Victory Audit | RESOLVED (`_previous_position`) |
| 11 | `stickmanprocedural.gd:373` warning | Unused parameter `loadout_facing` in `to_stickman_pose()` | M2 | Victory Audit | RESOLVED (`_loadout_facing`) |
| 12 | `test_challenger_m1_2_adversarial.gd` warnings | Narrowing float-to-int conversions and ternary return warnings on `--check-only` | M2 | Victory Audit | RESOLVED |
| 13 | Global Zero-Warning Verification | All scripts, scenes (`stickmanprocedural.tscn`, `main.tscn`), and test suites run with 0 warnings | M2 | Victory Audit | DONE (29/29 scripts, 15/15 test suites pass) |
| 14 | Scarf Cloth Distance & Trailing Invariant | Clamped cloth distance $[7.0, 13.0] \subset [5.9, 14.1]$ and backward trailing invariant under extreme vertical velocity | M3 | Adversarial Stress | RESOLVED |
| 15 | Live Render Overhead Optimization | Replaced `get_stack()` in `_draw()` with `NOTIFICATION_DRAW` pass flag & added active rig limb skip path ($0.55\text{ms} \to 0.23\text{ms}$) | M3 | Performance Audit | RESOLVED |
| 16 | Audio Server Teardown & Dummy Playback Leaks | Guarded headless dummy audio driver playback and added `stop_all()` to prevent ObjectDB leaks | M3 | Leak Audit | RESOLVED |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Core Simulation & Scene Warnings | Resolve 6 core compiler warnings & scene UID | none | DONE |
| M2 | Procedural Stickman & Test Suite Warnings | Resolve 2 warnings in `stickmanprocedural.gd`, clean up challenger test script warnings, verify 0 warnings across `test_modular_rig.gd` and `stickmanprocedural.tscn` | M1 | DONE |
| M3 | Global Coverage, Cloth Invariants & Performance | Resolve scarf cloth constraints, optimize render loop, fix audio leaks, 15/15 test suites passing | M2 | DONE |

### Key Outputs & Verification Artifacts:
- **Files Touched**: `scripts/chrono_shift/chrono_shift_model.gd`, `scripts/timeline/timeline_system.gd`, `scripts/game/game_controller.gd`, `scripts/game/audio_manager.gd`, `scripts/modular_rig/modular_asset_system.gd`, `scripts/stickman/stickmanprocedural.gd`, `scenes/main.tscn`, `scenes/stickman/stickmanprocedural.tscn`, `run_tests.bat`.
- **Test Suites (100% Passing)**: All 15 suites in `run_tests.bat` pass headlessly with 0 errors, 0 warnings, 0 leaks.
- **Godot MCP Server**: 17/17 stress tests passed.
