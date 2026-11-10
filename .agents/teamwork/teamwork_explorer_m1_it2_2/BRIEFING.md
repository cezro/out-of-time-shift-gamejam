# BRIEFING — 2026-11-10T14:12:15Z

## Mission
Design precise fix strategy for coordinate parity (+Y UP vs +Y DOWN) in to_stickman_pose() in stickmanprocedural.gd.

## 🔒 My Identity
- Archetype: explorer
- Roles: explorer, coordinate parity remediation
- Working directory: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m1_it2_2
- Original parent: 0fd925e9-f058-4fd8-8532-3aab95b2a4f6
- Milestone: Milestone 1 Iteration 2

## 🔒 Key Constraints
- Read-only investigation — do NOT implement directly in source code
- Design precise fix strategy for coordinate parity (+Y UP vs +Y DOWN) in to_stickman_pose() in stickmanprocedural.gd
- Write report.md and handoff.md, then notify orchestrator

## Current Parent
- Conversation ID: 0fd925e9-f058-4fd8-8532-3aab95b2a4f6
- Updated: 2026-11-10T14:12:15Z

## Investigation State
- **Explored paths**:
  - `new-game-project/scripts/stickman/stickmanprocedural.gd` (lines 320–400)
  - `new-game-project/scenes/stickman/stickmanprocedural.tscn` (rig hierarchy, bone transforms)
  - `new-game-project/scripts/modular_rig/modular_asset_system.gd` (`StickmanPose`, `StickmanPoseSolver`, `compute_slot_transform`)
  - `new-game-project/scripts/game/game_controller.gd` (`to_screen()`, `to_sim()`, `_draw_pose_skeleton`, `_draw_modular_character`)
  - `new-game-project/scripts/core/player_kinematics.gd` (simulation coordinate conventions)
  - `new-game-project/tests/` (`test_challenger_m1_2_adversarial.gd`, `test_stickman_procedural_stress.gd`, `test_modular_rig.gd`)
  - Reviewer 2 Report (`.agents/teamwork/teamwork_reviewer_m1_2/report.md`, Finding 1)
- **Key findings**:
  - Confirmed empirical bone values in Godot 2D character-local space: head_center.y ≈ -184.0, neck.y ≈ -161.0, pelvis.y ≈ -2.0, feet.y ≈ +320 to +325.
  - In Godot 2D, +Y is DOWN. In simulation space, +Y is UP (`head_center.y > neck.y > pelvis.y`).
  - Currently `to_stickman_pose()` directly copies Godot 2D coordinates into `pose`, violating `head_center.y > neck.y > pelvis.y` and rendering the stickman inverted when passed through `to_screen(sim_pos)`.
  - The correct mapping is a pure reflection across the horizontal axis: $X_{sim} = X_{local}, Y_{sim} = -Y_{local}$.
  - This preserves horizontal offsets, facing direction (+X right, -X left), and yields a lossless round-trip isometry: `to_screen(_to_sim_coord(P)) == P`.
  - Secondary elements (`sword_hilt`, `sword_tip`, `scarf_nodes`) should be cleanly populated using effective facing to prevent zero-vector artifacts in `compute_slot_transform`.
- **Unexplored areas**:
  - None within task boundary.

## Key Decisions Made
- Formulate static helper `_to_sim_coord(local_pos: Vector2) -> Vector2` with `is_finite` guards.
- Formulate replacement `to_stickman_pose(loadout_facing: float = 1.0) -> RefCounted` mapping all 14 bone endpoints through `_to_sim_coord`.
- Preserve method signature and backwards compatibility across all callers in test suites.

## Artifact Index
- DISPATCH.md — Task instructions and dispatch messages
- BRIEFING.md — Persistent context & state
- progress.md — Liveness heartbeat
- report.md — Comprehensive technical analysis & recommendation
- handoff.md — 5-component handoff report
