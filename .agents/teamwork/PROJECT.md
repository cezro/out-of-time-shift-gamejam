# Project: Out of Time - Procedural Stickman Animation System Integration

## Architecture
- **Animation System**: Hybrid procedural 2D stickman animation combining the skeletal CCDIK and kinematics from `procedural-animation-test-scene` with the mathematical piece-by-piece solver `ModularAssetSystem.StickmanPoseSolver` in `out-of-time-shift-gamejam`.
- **Motion Principles**: Informs procedural curves with skills.sh motion design (damped second-order springs $\zeta \approx 0.70\text{--}0.85$, piecewise stance-lock & Hermite smoothstep foot swing, cadence saturation $f(v) = 1.8 + 2.0 \cdot \tanh(|v| / 180)$, volume-conserving squash/stretch, and 3-phase combat sweep curves).
- **Entities Covered**:
  - Player Character (`PlayerKinematics` / `GameController`)
  - Timeline Clones / Chrono-Echoes / Ghost Trails / Afterimages
  - 6 Enemy Archetypes (`enemy_runner`, `enemy_ninja`, `enemy_heavy`, `enemy_gunner_semi`, `enemy_gunner_auto`, `enemy_sniper`) and severed ragdoll halves
- **Verification Harness**: Automated regression suite (`run_tests.bat`, headless Godot) + dedicated showcase test scene (`procedural_stickman_showcase.tscn`).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Rig & Scene Import | Import `stickmanprocedural.gd`, `stickmanprocedural.tscn`, and sprite assets from reference repo | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Reference Rig Bug Fixes | Fix script attachment on root Player, fix `facing - signf(direction)` typo, fix unassigned 6th CCDIK modifier | M1 | Explorer 2 Survey |
| 3 | PackedScene Backend Registration | Register procedural stickman scene in `ModularAssetSystem` for `AssetRenderBackend.PACKED_SCENE` | M1 | Explorer 1 & 2 Survey |
| 4 | Motion Dynamics & Easing Curves | Implement second-order harmonic oscillator springs and snappy easing curves | M2 | ORIGINAL_REQUEST §R1 & Explorer 3 |
| 5 | Procedural Gait & Swing Upgrade | Implement piecewise stance-lock, Hermite smoothstep swing, cadence curve, and dual-frequency head bob | M2 | ORIGINAL_REQUEST §R1, Explorer 2 & 3 |
| 6 | Dynamic Squash/Stretch & Attack Tuning | Implement volume-conserving jump/land squash & stretch and 3-phase non-linear combat swing arc | M2 | ORIGINAL_REQUEST §R1 & Explorer 3 |
| 7 | Player Rig & Animation Integration | Connect player velocity, state, and actions to the procedural stickman rig | M3 | ORIGINAL_REQUEST §R2 |
| 8 | Timeline Clones Procedural Coverage | Animate Chrono-Echoes, afterimages, and ghost trails with the procedural stickman rig | M3 | ORIGINAL_REQUEST §R2 |
| 9 | Enemy / NPC Procedural Coverage | Animate all 6 enemy stickmen archetypes and severed ragdolls with the procedural stickman rig | M3 | ORIGINAL_REQUEST §R2 |
| 10 | Scene Rig Reference Replacement | Replace existing stickman rig references across game scenes without breaking scene instantiation | M3 | ORIGINAL_REQUEST §R2 |
| 11 | Dedicated Showcase Test Scene | Create dedicated Godot scene (`res://scenes/procedural_stickman_showcase.tscn`) demonstrating all entities with snappy motion | M4 | ORIGINAL_REQUEST §R3 |
| 12 | Automated Verification & Regression Suite | Ensure `run_tests.bat` passes with 100% success (all test suites pass, 0 regressions) | M4 | ORIGINAL_REQUEST §R3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Procedural Rig & Scene Asset Integration | Import procedural rig scenes, scripts, and textures; fix reference bugs; register PackedScene backend | none | DONE |
| M2 | Snappy Motion Dynamics & Procedural Solver Upgrade | Implement skills-informed mathematical gait, springs, squash/stretch, and combat sweeps in pose solver | M1 | IN_PROGRESS |
| M3 | Global Coverage Across All Stickman Entities | Wire player, timeline clones/ghosts, and 6 enemy types to procedural stickman rig; replace legacy references | M2 | PLANNED |
| M4 | Dedicated Test Scene & Automated Regression Suite | Create dedicated test scene and verify 100% pass rate in `run_tests.bat` | M3 | PLANNED |

## Interface Contracts
### `stickmanprocedural.gd` ↔ `ModularAssetSystem` / Game Entities
- `update_procedural_animation(velocity: Vector2, is_on_ground: bool, facing_direction: float, current_state: String, delta: float) -> void`
- `get_bone_positions() -> Dictionary[String, Vector2]` (maps bone/joint names to 2D local space)
- Properties:
  - `stride_length: float`
  - `foot_lift: float`
  - `arm_swing: float`
  - `head_bounce: float`
  - `snappiness: float` (spring response multiplier)

### `ModularAssetSystem.StickmanPoseSolver` ↔ Renderers
- `generate_stickman_pose(stance: String, progress: float, vel: Vector2, on_ground: bool, facing: float, anim_time: float, ...) -> StickmanPose`
- Joint invariants:
  - $+Y$ is UP in simulation coordinates (`head_center.y > neck.y > pelvis.y`)
  - Running forward lean: `run_pose.neck.x * facing > idle_pose.neck.x * facing`
  - Jumping leg tuck: `jump_pose.left_knee.y > idle_pose.left_knee.y`

## Code Layout
- `new-game-project/scenes/stickman/`: Procedural stickman scene (`stickmanprocedural.tscn`)
- `new-game-project/scripts/stickman/`: Procedural stickman controller script (`stickmanprocedural.gd`)
- `new-game-project/assets/stickman/`: Stickman body part textures/sprites
- `new-game-project/scripts/modular_rig/modular_asset_system.gd`: Procedural pose solver and asset system
- `new-game-project/scripts/game/game_controller.gd`: Game controller rendering and entity management
- `new-game-project/scenes/procedural_stickman_showcase.tscn`: Dedicated visual demonstration test scene
- `new-game-project/tests/`: Automated unit and integration test scripts (`test_modular_rig.gd`, etc.)
