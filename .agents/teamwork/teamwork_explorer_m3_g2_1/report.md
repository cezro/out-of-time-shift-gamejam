# Milestone 3 — Feature 7: Player Rig & Animation Integration Analysis Report

**Agent**: `teamwork_explorer_m3_g2_1` (M3 Player Rig Explorer)  
**Date**: 2026-11-10T15:28:00Z  
**Working Directory**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\teamwork_explorer_m3_g2_1`  
**Target Subsystem**: Player character construction, kinematics, procedural animation, and modular asset rendering  

---

## 1. Executive Summary

This investigation examines how the player character is currently constructed, simulated, rendered, and controlled in `new-game-project/scripts/game/game_controller.gd`, `new-game-project/scripts/core/player_kinematics.gd`, `new-game-project/scripts/modular_rig/modular_asset_system.gd`, and `new-game-project/scripts/stickman/stickmanprocedural.gd`.

### Core Discoveries:
1. **Decoupled Data Architecture**: In `game_controller.gd`, the player is **not** an instantiated scene node or `CharacterBody2D`. Instead, the player is stored as a pure `RefCounted` data model (`player: PlayerKinematics.PlayerState`) initialized at `game_controller.gd:73, 149-158`.
2. **Current Rendering Mechanism**: Rendering is completely driven on each frame by `_draw()` at `game_controller.gd:1964-1975`. It calls `ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose()` to generate a `StickmanPose` in simulation coordinates (+Y UP), then renders immediate 2D canvas draw primitives via `_draw_modular_character()` using the active loadout (`player.loadout_id = "player_shift_staff"`) registered in `ModularAssetRegistry`.
3. **Dormant M2 Spring Dynamics in Live Player**: While Milestone 2 implemented damped harmonic oscillators (`PoseDynamicsContext`, `ProceduralSpring`, `ProceduralSpring2D`), dynamic torso lean, and acceleration recoil in `StickmanPoseSolver`, `game_controller.gd` currently invokes `generate_stickman_pose()` with default parameters (omitting `dynamics_ctx`, `accel_x`, and `dt`). As a result, live gameplay currently falls back to static pose evaluations.
4. **CCDIK Scene Rig Readiness**: The procedural stickman scene rig (`res://scenes/stickman/stickmanprocedural.tscn` / `stickmanprocedural.gd`) is fully implemented with external driving support (`autonomous_physics = false`), CCDIK bone solvers, cadence-saturated gait, and `to_stickman_pose()`.
5. **Scale and Coordinate Bridge Requirement**:
   - `PlayerKinematics` simulation operates with **+Y UP** (floor $y = -260$, jump $v_y = +580$, player height $\approx 58\text{ px}$).
   - `stickmanprocedural.gd` operates with **+Y DOWN** (Godot screen space, native capsule height $732\text{ px}$).
   - Feeding velocity and position to `StickmanProcedural` requires inverting vertical velocity ($v_{y,\text{godot}} = -v_{y,\text{sim}}$).

---

## 2. Census & Exact Code Locations

### 2.1 Player Construction & Lifecycle
| Component | File Path | Line Range | Description |
|---|---|---|---|
| `PlayerState` | `scripts/core/player_kinematics.gd` | 84–131 | Pure RefCounted data structure storing position, velocity, facing, timers, health, and loadout ID |
| `MovementConfig` | `scripts/core/player_kinematics.gd` | 8–25 | Pure movement parameters (accel: 2200, decel: 2800, max_speed: 340, jump_force: 580, gravity: 1400) |
| Player Instantiation | `scripts/game/game_controller.gd` | 73 | `var player: PlayerKinematics.PlayerState = PlayerKinematics.PlayerState.new()` |
| Player Config Initialization | `scripts/game/game_controller.gd` | 152–154 | `player.loadout_id = "player_shift_staff"`, `player.position = Vector2(0.0, FLOOR_Y)`, `player.is_grounded = true` |
| Scene Tree Census | `scenes/main.tscn` | 1–7 | Root `GameController` Node2D only. **Zero player child nodes** exist in `main.tscn` |
| Scene Nodes Setup | `scripts/game/game_controller.gd` | 184–200 | `_ensure_scene_nodes()` creates `audio_mgr`, `camera`, and `hud_layer`. No player node added |

### 2.2 Player Simulation & Kinematics
| Routine | File Path | Line Range | Operation |
|---|---|---|---|
| Simulation Tick | `scripts/game/game_controller.gd` | 749–946 | `step_simulation()` polls input, steps shifter, runs combat triggers, steps player kinematics |
| Attack Action Triggers | `scripts/game/game_controller.gd` | 880–932 | Triggers slam, light slash (`_execute_light_slash`), dash, heavy launcher (`_execute_heavy_launcher`), parry (`_process_active_parry_window`), warp |
| Movement & Collision Step | `scripts/game/game_controller.gd` | 1207–1360 | `_step_player_movement_and_environment()` handles horizontal velocity, wall slide/rebound, vertical velocity, platform landing, jump pads, hazard collisions |
| Horizontal Kinematics | `scripts/core/player_kinematics.gd` | 133–152 | `step_horizontal_velocity()`: acceleration toward target speed, deceleration to stop |
| Vertical Kinematics | `scripts/core/player_kinematics.gd` | 154–193 | `step_vertical_velocity()`: coyote time (0.12s), jump buffer (0.12s), gravity scaling (fall 1.6x, short hop 2.2x) |
| Wall Slide & Rebound | `scripts/core/player_kinematics.gd` | 234–279 | `step_wall_slide_and_rebound()`: caps descent at -110 px/s, diagonal wall launch (420, 560) |
| Kinetic Dash | `scripts/core/player_kinematics.gd` | 196–230 | `start_dash()`: 780 px/s for 0.14s, cancels light slash recovery cooldown (`slash_cooldown = 0.0`) |
| Downward Slam | `scripts/core/player_kinematics.gd` | 282–297 | `start_downward_slam()`: airborne vertical drop at -950 px/s |

### 2.3 Player Rendering Pipeline
| Step | File Path | Line Range | Operation |
|---|---|---|---|
| Redraw Request | `scripts/game/game_controller.gd` | 944 | `queue_redraw()` queued at the end of each simulation step |
| Canvas Draw Entry | `scripts/game/game_controller.gd` | 1764–2035 | `_draw()` iterates background, platforms, wells, echoes, ghosts, enemies, player, ragdolls, visuals |
| Player Pose Generation | `scripts/game/game_controller.gd` | 1951–1975 | Invokes `ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(...)` |
| Modular Character Draw | `scripts/game/game_controller.gd` | 2050–2146 | `_draw_modular_character()` draws head circle, scarf lines, body segments, polygon armor, and shift staff |
| Shift Staff Weapon Draw | `scripts/game/game_controller.gd` | 2110–2145 | `loadout.weapon_assembly.compute_piece_transforms()` renders interlocking cogs and key teeth aligned with active Chronos gear |
| Parry Ward Arc | `scripts/game/game_controller.gd` | 1977–1980 | Draws golden deflection ward arc (`_d_arc`, radius 34 px) in front of player when `player.parry_timer > 0.0` |

---

## 3. Detailed Answers to Investigation Questions

### Question 1: Exactly where and how the player stickman is instantiated and rendered in `game_controller.gd`

1. **Instantiation**:
   - The player character is **not instantiated as a Node or PackedScene** in `game_controller.gd`.
   - `player` is an instance of `PlayerKinematics.PlayerState` (a pure `RefCounted` data class) created at line 73:
     ```gdscript
     var player: PlayerKinematics.PlayerState = PlayerKinematics.PlayerState.new()
     ```
   - In `_init()` (lines 152–154):
     ```gdscript
     player.loadout_id = "player_shift_staff"
     player.position = Vector2(0.0, FLOOR_Y)
     player.is_grounded = true
     ```
   - `main.tscn` contains only `[node name="GameController" type="Node2D"]`. There are no player subnodes.

2. **Rendering**:
   - The player is rendered inside `GameController._draw()` (lines 1951–1976) via immediate CanvasItem drawing:
     ```gdscript
     var near_well: bool = (timeline.is_near_chronos_well(player.position) != null)
     var active_gear: int = shifter.model.get_active_gear()
     var gear_alignment: float = 1.0 if near_well else clampf(float(active_gear) / 6.0, 0.0, 1.0)
     var p_attacking: bool = (attack_anim_timer > 0.0)
     var p_atk_prog: float = (
         clampf(attack_anim_timer / maxf(0.001, attack_anim_duration), 0.0, 1.0)
         if p_attacking
         else 0.0
     )
     var p_stance: String = last_stance
     if near_well and not p_attacking and absf(player.velocity.x) < 15.0 and player.is_grounded:
         p_stance = "well_unlock"

     var player_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
         player.position,
         player.facing,
         player.velocity,
         player.is_grounded,
         anim_time,
         p_attacking,
         p_atk_prog,
         false,
         p_stance
     )
     _draw_modular_character(player_pose, player.loadout_id, player.facing, gear_alignment, 1.0)
     ```
3. **Subsystems Used**:
   - Uses `ModularAssetSystem.StickmanPoseSolver` for mathematical joint positions.
   - Uses `ModularAssetSystem.ModularAssetRegistry` (`asset_registry.get_loadout("player_shift_staff")`) for visual piece definitions.
   - Does **not** use scene nodes for rendering.
   - The registered preset `"player_procedural_stickman"` (pointing to `res://scenes/stickman/stickmanprocedural.tscn`) is in `asset_registry`, but is not currently instantiated by `game_controller.gd`.

---

### Question 2: How live velocity, grounded status, facing, actions, wall slides, and parries should be passed into the procedural stickman rig

#### Coordinate System Harmonization
There is a fundamental sign difference between the simulation space and Godot's scene/engine space:
- **Simulation Space** (`player_kinematics.gd` / `game_controller.gd`): $+Y$ is **UP**.
  - Jump: $v_y = +580.0$
  - Downward Slam / Fall: $v_y = -950.0$
  - Gravity: subtracted each step
- **Godot 2D / Rig Space** (`stickmanprocedural.gd`): $+Y$ is **DOWN**.
  - Upward jump stretch: `safe_vel.y < -50.0` (line 352)
  - Downward fall plunge: `safe_vel.y > 150.0` (line 357)
  - Landing impact speed: `maxf(_last_vy, 0.0)` (line 329)

**Conversion Invariant**:
When passing velocity to `StickmanProcedural.update_procedural_animation()`, the vector must be inverted on $Y$:
$$\vec{v}_{\text{godot}} = \begin{pmatrix} v_x \\ -v_y \end{pmatrix} = \text{to\_screen}(\vec{v}_{\text{sim}})$$

#### State Mapping Matrix
The table below specifies the priority and exact string mapping from `GameController`'s kinematic state to both `StickmanProcedural` and `StickmanPoseSolver`:

| Priority | Kinematic Condition | Rig Animation State (`current_state`) | Solver Stance (`stance`) | Solver Parameters |
|---|---|---|---|---|
| 1 | `player.parry_timer > 0.0` | `"parry_guard"` | `"parry_guard"` | `is_attacking = false` |
| 2 | `attack_anim_timer > 0.0` and `last_stance == "heavy_slash"` | `"heavy_slash"` | `"heavy_slash"` | `is_attacking = true`, `p_atk_prog` in $[0, 1]$ |
| 3 | `attack_anim_timer > 0.0` and `last_stance != "heavy_slash"` | `"slash"` | `"normal"` | `is_attacking = true`, `p_atk_prog` in $[0, 1]$ |
| 4 | `player.is_slamming` | `"downward_slam"` | `"downward_slam"` | `is_grounded = false` |
| 5 | `player.is_wall_sliding` | `"wall_slide"` | `"wall_slide"` | `is_grounded = false` |
| 6 | `player.is_climbing_vine` | `"air"` | `"normal"` | `is_grounded = false` |
| 7 | `not player.is_grounded` and $v_y > 0.0$ | `"jump"` | `"normal"` | `is_grounded = false` |
| 8 | `not player.is_grounded` and $v_y \le 0.0$ | `"fall"` | `"normal"` | `is_grounded = false` |
| 9 | `player.is_grounded` and `player.dash_timer > 0.0` | `"run"` | `"normal"` | High speed horizontal dash |
| 10 | `player.is_grounded` and $|v_x| > 15.0$ | `"run"` | `"normal"` | Cadence saturation curve ($1.8\text{--}3.71\text{ Hz}$) |
| 11 | `player.is_grounded` and `near_well` and $|v_x| \le 15.0$ | `"idle"` | `"well_unlock"` | Shift staff extended horizontally |
| 12 | `player.is_grounded` and $|v_x| \le 15.0$ | `"idle"` | `"normal"` | Idle breathing oscillation |

#### Connecting to `StickmanProcedural` Scene Rig
When an instance of `StickmanProcedural` (`player_rig`) is maintained on `GameController`:
```gdscript
if player_rig != null:
    var godot_vel := Vector2(player.velocity.x, -player.velocity.y)
    player_rig.global_position = to_screen(player.position)
    player_rig.update_procedural_animation(
        godot_vel,
        player.is_grounded,
        player.facing,
        current_state_str,
        player_dt
    )
```

#### Connecting to `ModularAssetSystem.StickmanPoseSolver`
To activate the M2 damped harmonic oscillator springs and dynamic acceleration lean in live gameplay:
1. Store a persistent `player_dynamics_ctx: ModularAssetSystem.PoseDynamicsContext` on `GameController`.
2. Compute horizontal acceleration:
   $$a_x = \text{clampf}\left(\frac{v_x - v_{x,\text{prev}}}{\Delta t}, -3500.0, 3500.0\right)$$
3. Pass `player_dynamics_ctx`, `accel_x`, and `player_dt` into `generate_stickman_pose()`:
   ```gdscript
   var player_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
       player.position,
       player.facing,
       player.velocity,
       player.is_grounded,
       anim_time,
       p_attacking,
       p_atk_prog,
       false,
       p_stance,
       player_accel_x,
       player_dynamics_ctx,
       player_dt
   )
   ```

---

### Question 3: How visual properties (colors, loadout pieces, scarf, blade trail) are applied to the player's procedural stickman

1. **Color Palette Application**:
   - `CharacterLoadout` specifies `body_color` (`Color(1.0, 1.0, 1.0, 1.0)` crisp white) and `accent_color` (`Color(0.0, 0.85, 1.0, 0.95)` electric cyan).
   - In `_draw_modular_character()`, each equipped `PartPieceSpec` modulates its draw color:
     $$p_{\text{col}} = \text{Color}(p.r, p.g, p.b, p.a \cdot \alpha_{\text{mult}})$$
   - In `StickmanProcedural`, if scene sprite nodes are used, the visual sprites under `Rig/Body` (`ArmTopB`, `Torso`, `Head`, etc.) receive tinting by assigning `modulate = loadout.body_color`.

2. **Loadout Pieces & Armor Attachment**:
   - Equipment is organized into 20 anatomical `PartSlot` enums (`HAT_HELMET`, `TORSO`, `UPPER_ARM_L`, `SHIN_L`, etc.).
   - `ModularAssetSystem.StickmanPoseSolver.compute_slot_transform(pose, slot, facing)` computes the exact start point, end point, center point, and bone angle for every slot based on the live pose.
   - Multiple render backends are supported:
     - `PROCEDURAL_VECTOR`: vector lines and arcs with custom line width.
     - `CUSTOM_POLYGON`: scaled polygon points rotated to `bone_angle` (used by crown helmet, pauldrons, breastplate, greaves).
     - `TEXTURE_SPRITE`: centered sprite textures with custom scale and region (used by runtime badge helmet).
     - `PACKED_SCENE`: references instantiated procedural subscenes.
   - Customization cycling (`cycle_player_modular_customization()`, lines 550–666) mutates `player_shift_staff` across 4 tiers without modifying kinematics.

3. **Scarf Ribbon Dynamics**:
   - Attached to `PartSlot.SCARF_CAPE` (`player_chronos_scarf`).
   - Rooted at `head_back = pose.head_center + Vector2(-facing * pose.head_radius, 0.0)`.
   - Has 3 trailing segments (`scarf_nodes[0]`, `scarf_nodes[1]`, `scarf_nodes[2]`).
   - Simulated with damped harmonic oscillator springs (`PoseDynamicsContext.scarf_springs`) counteracted by vertical velocity ($v_y \cdot 0.02$).
   - Inter-node distances are strictly clamped in $[6.0, 14.0]\text{ px}$ to prevent elastic tearing or collapse.
   - Trailing invariant strictly enforced: nodes are always positioned behind `head_center` in the opposite direction of `player.facing`.
   - Rendered as dual-segment gradient: primary cyan on root-to-mid, secondary glow on mid-to-tail.

4. **Shift Staff & Blade Trail Visuals**:
   - Rendered via `loadout.weapon_assembly.compute_piece_transforms(pose.sword_hilt, pose.sword_tip, facing, gear_alignment, anim_time)`.
   - Gearwork core rotates dynamically with animation time.
   - Chronos Key teeth rotate in alignment with the active Chronos gear ratio (`gear_alignment`).
   - Dynamic combat visuals:
     - **Light Slash Arc**: `CombatMath.SlashArcVisualData` with radius 80 px, span $0.75\pi$, duration 0.14s, cyan color.
     - **Heavy Launcher Arc**: `SlashArcVisualData` with radius 105 px, span $0.95\pi$, duration 0.20s, golden orange color.
     - **Parry Ward**: Hemispherical arc with radius 34 px in front of player when `player.parry_timer > 0.0`.
     - **Downward Slam Shockwave**: Expanding concentric ring (`CombatMath.ShockwaveVisualData`) up to radius 160 px on landing.
     - **Dash Ghost Trails**: `GhostTrailData` capturing live pose snapshots, rendered as fading cyan skeletons.

---

### Question 4: How to ensure zero breaking changes to gameplay logic, combat hitboxes, or input responsiveness

1. **Strict Decoupling of Kinematics from Presentation**:
   - All gameplay logic (movement, platform snaps, wall rebound, coyote time, jump buffers, katana slash sweeps, bullet deflections, slam shockwaves) operates purely on `player: PlayerKinematics.PlayerState` in simulation space (+Y UP).
   - Under no circumstances should game physics or combat collision checks be bound to bone node positions or scene Sprite2D colliders.
   - This ensures all 42 core kinematics tests (`test_core.gd`) and 35 chronos shift tests (`test_chrono_and_timeline.gd`) remain 100% immune to rendering modifications.

2. **Autonomous Physics Lockout on Procedural Rig**:
   - In `StickmanProcedural`, `autonomous_physics` MUST be `false` (the default).
   - In `_ready()`, `set_physics_process(false)` prevents the rig from reading Godot input actions or executing `move_and_slide()`.
   - The rig must be updated exclusively via deterministic calls from `GameController.step_simulation()` or `_draw()`.

3. **Preserving Modular Loadout Preset Compatibility**:
   - `test_game_integration.gd` (Test 12) strictly tests `player.loadout_id = "player_shift_staff"` and live part cycling via `cycle_player_modular_customization()`.
   - `player.loadout_id` must remain `"player_shift_staff"` by default.
   - `_draw()` must continue executing `_draw_modular_character()`, guaranteeing `draw_call_count >= 1` and `last_draw_primitive_count > 100` to satisfy Test 1 and Test 12.

4. **Numerical Sanitization on State Bridge**:
   - Apply guards to all variables passed to procedural rigs:
     - Delta time: `clampf(player_dt, 0.0, 0.033)` prevents spring explosion during debugger stalls or frame drops.
     - Facing direction: guard against 0.0, NaN, and Inf; enforce strict $+1.0$ or $-1.0$.
     - Velocity: replace NaN/Inf components with `Vector2.ZERO`.
     - Animation time: `fmod(anim_time, 10000.0)` prevents floating-point precision degradation.

---

## 4. Proposed Architecture Blueprint for Implementers

### 4.1 State Bridge in `GameController`

To implement Feature 7 cleanly without breaking any existing tests:

```gdscript
# In GameController declarations:
var player_dynamics_ctx: ModularAssetSystem.PoseDynamicsContext = ModularAssetSystem.PoseDynamicsContext.new()
var player_prev_vx: float = 0.0
var player_accel_x: float = 0.0
var player_rig: StickmanProcedural = null

# In GameController._ensure_scene_nodes():
func _ensure_player_rig() -> void:
    if player_rig == null:
        var rig_node = asset_registry.instantiate_rig("player_procedural_stickman")
        if rig_node is StickmanProcedural:
            player_rig = rig_node as StickmanProcedural
            player_rig.autonomous_physics = false
            player_rig.visible = false # Offscreen/hidden solver so it doesn't duplicate _draw primitives
            add_child(player_rig)

# In GameController._step_player_movement_and_environment():
if player_dt > 0.0001:
    player_accel_x = clampf((player.velocity.x - player_prev_vx) / player_dt, -3500.0, 3500.0)
else:
    player_accel_x = 0.0
player_prev_vx = player.velocity.x

# Step procedural rig if present
if player_rig != null:
    var godot_vel := Vector2(player.velocity.x, -player.velocity.y)
    var anim_state: String = _resolve_player_anim_state()
    player_rig.update_procedural_animation(godot_vel, player.is_grounded, player.facing, anim_state, player_dt)

# In GameController._draw():
var player_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
    player.position,
    player.facing,
    player.velocity,
    player.is_grounded,
    anim_time,
    p_attacking,
    p_atk_prog,
    false,
    p_stance,
    player_accel_x,
    player_dynamics_ctx,
    player_dt
)
_draw_modular_character(player_pose, player.loadout_id, player.facing, gear_alignment, 1.0)
```

This blueprint delivers full procedural motion dynamics (acceleration lean, harmonic oscillator springs, squash/stretch, cadence saturation) to the player while maintaining 100% test compatibility and zero breaking changes.
