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
| 8 | Godot MCP Tooling Integration | Verify Godot MCP server inspection, project info, run_project, debug output | M1 | Survey | VERIFIED (0 errors) |
| 9 | Verification & Zero-Warning Gate M1 | Verify clean console, 0 parse errors, 0 runtime errors, 0 warnings across all core scripts | M1 | Acceptance Criteria | DONE |
| 10 | `stickmanprocedural.gd:132` warning | Unused local variable `previous_position` in `_step_simulation` | M2 | Victory Audit | IN_PROGRESS |
| 11 | `stickmanprocedural.gd:373` warning | Unused parameter `loadout_facing` in `to_stickman_pose()` | M2 | Victory Audit | IN_PROGRESS |
| 12 | `test_challenger_m1_2_adversarial.gd` warnings | Narrowing float-to-int conversions and ternary return warnings on `--check-only` | M2 | Victory Audit | IN_PROGRESS |
| 13 | Global Zero-Warning Verification | All scripts, scenes (`stickmanprocedural.tscn`, `main.tscn`), and test suites run with 0 warnings | M2 | Victory Audit | IN_PROGRESS |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Core Simulation & Scene Warnings | Resolve 6 core compiler warnings & scene UID | none | DONE |
| M2 | Procedural Stickman & Test Suite Warnings | Resolve 2 warnings in `stickmanprocedural.gd`, clean up challenger test script warnings, verify 0 warnings across `test_modular_rig.gd` and `stickmanprocedural.tscn` | M1 | IN_PROGRESS |

### Key Outputs & Verification Artifacts:
- **Files Touched in M1**: `scripts/chrono_shift/chrono_shift_model.gd`, `scripts/timeline/timeline_system.gd`, `scripts/game/game_controller.gd`, `tests/test_adversarial_disprover.gd`, `scenes/main.tscn`.
- **Files Assigned in M2**: `scripts/stickman/stickmanprocedural.gd`, `tests/test_challenger_m1_2_adversarial.gd`, `scenes/stickman/stickmanprocedural.tscn`.

## Interface Contracts
- All method signatures and return types remain 100% backward-compatible.
- `to_stickman_pose(loadout_facing: int)` must retain parameter position and type signature, but prefix unused argument with underscore (`_loadout_facing: int`).
- `instantiate_rig()` and `stickmanprocedural.tscn` instantiation behavior and node hierarchy remain intact.

## Code Layout
- `scripts/stickman/stickmanprocedural.gd`: Owned by Worker M2
- `tests/test_challenger_m1_2_adversarial.gd`: Owned by Worker M2
- `scenes/stickman/stickmanprocedural.tscn`: Owned by Worker M2
