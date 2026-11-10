# Comprehensive Survey Report: Procedural Animation Rig Source & Integration

**Target Reference Repository**: `c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene`  
**Target Destination Project**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project`  
**Explorer**: Explorer 2 (`explorer_procedural_source_1`)  
**Date**: 2026-11-10  

---

## 1. Executive Summary

This report delivers a thorough architectural, kinematic, and programmatic survey of the `procedural-animation-test-scene` repository. The reference repository implements a 2D procedural humanoid stickman character using Godot 4's built-in 2D Skeletal and Inverse Kinematics (`Skeleton2D`, `SkeletonModificationStack2D`, `SkeletonModification2DCCDIK`, and `SkeletonModification2DLookAt`), coupled with a distance-driven mathematical gait algorithm and decoupled modular 2D sprites.

### Key Discoveries & Health Assessment:
1. **Elegant Visual-Skeletal Decoupling**: The rig cleanly separates bone transforms from visual renderables using `RemoteTransform2D` nodes, driving external `Sprite2D` nodes from the bone tree.
2. **Analytic Distance-Driven Gait**: Gait cycle phase accumulates strictly from actual horizontal ground displacement (`distance_moved / (stride_length * 2.0)`), eliminating foot sliding regardless of acceleration or speed changes.
3. **Critical Source Bugs Identified**:
   - **Bug #1 (Gait Direction Typo)**: Line 63 in `stickmanprocedural.gd` contains `facing - signf(direction)` instead of `facing = signf(direction)`. This standalone expression has no effect, preventing the character from ever turning left.
   - **Bug #2 (Unattached Script)**: The scene file `stickmanprocedural.tscn` lacks a `script` property on root node `Player`. When instantiated into `main.tscn`, `stickmanprocedural.gd` is never executed unless re-attached.
   - **Bug #3 (Dangling IK Modification)**: The 6th entry in `SkeletonModificationStack2D` (`SkeletonModification2DCCDIK_gavct`) has an unassigned `target_nodepath`, leaving an unconfigured modifier in the active stack.
   - **Bug #4 (Missing Rig Flip)**: The script scales offsets by `facing` but never inverts `Rig.scale.x`, causing limbs to cross over awkwardly rather than mirroring.
4. **Integration Viability**: The rig can be integrated into `new-game-project` either as a `PACKED_SCENE` component matching `ModularAssetSystem.PartSlot` bindings, or by distilling its mathematical swing/bobbing formulas directly into `StickmanPoseSolver`.

---

## 2. Repository File Inventory & Configuration

| File Path | Size | Description |
|---|---|---|
| `project.godot` | 722 B | Godot 4.7 project configuration (`GL Compatibility`, `D3D12`, canvas_items stretch mode). |
| `main.tscn` | 1,068 B | Test harness scene containing `Player` instance, `Ground` StaticBody2D, and backdrop. |
| `main.gd` | 1,470 B | Test environment controller: establishes 4000x80 floor, clear color, and fall-reset at `y > 1200`. |
| `stickmanprocedural.tscn` | 18,128 B | Core character scene: `CharacterBody2D`, `CapsuleShape2D`, 15-part `Body`, 17-bone `Skeleton2D`, 5 `IK Targets`. |
| `stickmanprocedural.gd` | 5,285 B | Procedural locomotion script (movement, gait phase, CCDIK target positioning, air offsets). |
| `animation.tscn` | 17,383 B | Isolated skeletal rig prototype with 6 targets (including extra `Body Target`). |
| `assets/stickman/*.png` | 32 files | 15 modular body part textures (ArmTop/Bot, LegTop/Bot, Hand, Foot, Head, Neck, Torso, Waist, Pelvis for Front and Back). |

---

## 3. Node Hierarchy & Architectural Topology

The character rig in `stickmanprocedural.tscn` utilizes a three-tier decoupled structure:

```
Player (CharacterBody2D)
│   # Collision & Physics
├── CollisionShape2D (CapsuleShape2D, radius: 118, height: 732, pos: Vector2(-17, -12))
│
│   # Tier 1: Visual Renderables
├── Rig (Node2D, pos: Vector2(-284, -303))
│   ├── Body (Node2D)
│   │   ├── ArmTopB, ArmBotB, HandB (Sprite2D) [Back arm pieces]
│   │   ├── LegTopB, LegBotB (Sprite2D)        [Back leg pieces]
│   │   ├── Neck, Waist, Pelvis, Torso, Head   [Core torso & head]
│   │   ├── LegTopF, LegBotF (Sprite2D)        [Front leg pieces]
│   │   └── ArmTopF, ArmBotF, HandF (Sprite2D) [Front arm pieces]
│   │
│   │   # Tier 2: Skeletal Kinematic Chains
│   └── Bones (Node2D)
│       └── Skeleton2D (modification_stack: SkeletonModificationStack2D)
│           └── Hip (Bone2D, pos: (284.51, 301.46))
│               ├── RemoteTransform2D -> Body/Pelvis
│               │
│               ├── LegR (Bone2D, pos: (-36.05, 27.94)) [Front leg chain]
│               │   ├── RemoteTransform2D -> Body/LegTopF
│               │   └── ShinR (Bone2D, length: 178.5)
│               │       ├── RemoteTransform2D -> Body/LegBotF
│               │       └── FootR (Bone2D)
│               │
│               ├── ArmR (Bone2D, pos: (-42.77, -148.07)) [Front arm chain]
│               │   ├── RemoteTransform2D -> Body/ArmTopF
│               │   └── ForearmR (Bone2D, pos: (-30.15, 95.95))
│               │       ├── RemoteTransform2D -> Body/ArmBotF
│               │       └── HandR (Bone2D)
│               │           └── RemoteTransform2D -> Body/HandF
│               │
│               ├── LegL (Bone2D, pos: (26.96, 22.04)) [Back leg chain]
│               │   ├── RemoteTransform2D -> Body/LegTopB
│               │   └── ShinL (Bone2D, length: 178.5)
│               │       ├── RemoteTransform2D -> Body/LegBotB
│               │       └── FootL (Bone2D)
│               │
│               ├── ArmL (Bone2D, pos: (1.24, -149.00)) [Back arm chain]
│               │   ├── RemoteTransform2D -> Body/ArmTopB
│               │   └── ForearmL (Bone2D, pos: (-1.15, 90.00))
│               │       ├── RemoteTransform2D -> Body/ArmBotB
│               │       └── HandL (Bone2D)
│               │           └── RemoteTransform2D -> Body/HandB
│               │
│               └── Waist (Bone2D, pos: (-5.95, -30.01)) [Spine chain]
│                   ├── RemoteTransform2D -> Body/Waist
│                   └── Torso (Bone2D, pos: (-2.95, -28.00))
│                       ├── RemoteTransform2D -> Body/Torso
│                       └── Neck (Bone2D, pos: (-9.84, -101.02))
│                           ├── RemoteTransform2D -> Body/Neck
│                           └── Head (Bone2D, length: 95.25)
│                               └── RemoteTransform2D -> Body/Head
│
│   # Tier 3: Inverse Kinematic Target Points
└── IK Targets (Node2D, pos: Vector2(-284, -303))
    ├── FootR Target (Node2D, default rest: (160, 624))
    ├── FootL Target (Node2D, default rest: (307, 628))
    ├── ArmR Target  (Node2D, default rest: (253, 329))
    ├── ArmL Target  (Node2D, default rest: (347, 308))
    └── Head Target  (Node2D, default rest: (262, 26))
```

### Inverse Kinematics Stack Configuration:
`Skeleton2D.modification_stack` contains 6 modifications:
1. `SkeletonModification2DCCDIK` (Right/Front Leg):
   - Chain length: 2 (`Hip/LegR`, `Hip/LegR/ShinR`)
   - Target: `IK Targets/FootR Target`
   - Constraints: Angle limits active on thigh [69.3°, -106.5° inverted] and shin [-208.0°, 360.0° inverted] in local space.
2. `SkeletonModification2DCCDIK` (Left/Back Leg):
   - Chain length: 2 (`Hip/LegL`, `Hip/LegL/ShinL`)
   - Target: `IK Targets/FootL Target`
   - Constraints: Thigh [84.3°, 275.1° inverted], shin [152.6°, 360.0° inverted].
3. `SkeletonModification2DCCDIK` (Right/Front Arm):
   - Chain length: 2 (`Hip/ArmR`, `Hip/ArmR/ForearmR`)
   - Target: `IK Targets/ArmR Target`
   - Constraints: Forearm constrained to [246.9°, 2.5° inverted].
4. `SkeletonModification2DCCDIK` (Left/Back Arm):
   - Chain length: 2 (`Hip/ArmL`, `Hip/ArmL/ForearmL`)
   - Target: `IK Targets/ArmL Target`
   - Constraints: Forearm constrained to [-115.2°, -0.95°].
5. `SkeletonModification2DLookAt` (Head):
   - Bone: `Hip/Waist/Torso/Neck/Head`
   - Target: `IK Targets/Head Target`
6. `SkeletonModification2DCCDIK` (Torso - Incomplete):
   - Tip: `Hip/Waist/Torso/Neck`
   - Target: *None* (Unassigned, historical leftover from `animation.tscn`).

---

## 4. Procedural Gait & Kinematics Algorithms

`stickmanprocedural.gd` computes target positions mathematically in script space, delegating joint-angle solving to the engine's CCDIK modifiers.

### 4.1. Phase Accumulation & Stride Synchronization
Rather than relying on continuous clock time, gait phase increments proportional to true horizontal displacement:
$$\Delta x = |x_t - x_{t-1}|$$
$$\text{speed}_{\text{actual}} = \frac{\Delta x}{\max(\Delta t, 0.0001)}$$
$$\text{speed\_ratio} = \text{clamp}\left(\frac{\text{speed}_{\text{actual}}}{\text{move\_speed}}, 0.0, 1.0\right)$$
$$\text{phase} = \left(\text{phase} + \frac{\Delta x}{2 \times \text{stride\_length}}\right) \bmod 1.0$$
*Advantage*: Foot velocity relative to the ground matches character velocity, eliminating foot slippage.

### 4.2. Leg Kinematics: Stance vs. Swing Formulation
The two legs operate at a half-cycle ($0.5$) phase offset:
$$\phi_R = \text{phase}, \quad \phi_L = (\text{phase} + 0.5) \bmod 1.0$$

For each cycle value $\phi \in [0, 1)$:
1. **Stance Phase ($\phi < 0.5$)**: Foot planted on the ground, sliding backward relative to character hip:
   $$t = \frac{\phi}{0.5}$$
   $$x = \text{lerp}\left(\frac{L_{\text{stride}}}{2}, -\frac{L_{\text{stride}}}{2}, t\right), \quad y = 0$$
2. **Swing Phase ($\phi \ge 0.5$)**: Foot lifts off, swinging forward along an eased parabolic trajectory:
   $$t = \frac{\phi - 0.5}{0.5}$$
   $$\text{eased} = t^2 \times (3 - 2t) \quad \text{(Hermite Smoothstep)}$$
   $$x = \text{lerp}\left(-\frac{L_{\text{stride}}}{2}, \frac{L_{\text{stride}}}{2}, \text{eased}\right)$$
   $$y = -\sin(t \times \pi) \times H_{\text{lift}}$$
3. Final foot target offset:
   $$\vec{O}_{\text{foot}} = (x \times \text{facing}, y)$$

### 4.3. Upper Body Kinematics: Arm Swing & Dual Head Bounce
1. **Arm Counter-Swing**:
   Hands swing in antiphase to their corresponding feet to conserve angular momentum:
   $$\theta = \text{phase} \times 2\pi$$
   $$A_{\text{arm}} = \text{lerp}(0.35, 1.0, \text{speed\_ratio})$$
   $$\vec{O}_{\text{arm\_r}} = \left(-\cos(\theta) \times W_{\text{swing}} \times \text{facing}, -\left|\sin(\theta)\right| \times H_{\text{hand\_lift}}\right) \times A_{\text{arm}}$$
   $$\vec{O}_{\text{arm\_l}} = \left(\cos(\theta) \times W_{\text{swing}} \times \text{facing}, -\left|\sin(\theta + \pi)\right| \times H_{\text{hand\_lift}}\right) \times A_{\text{arm}}$$
2. **Head Dynamics (Lean + 2x Bobbing Frequency)**:
   Because the body bobs once per step (twice per full two-step stride cycle), the bounce frequency is $2\theta$:
   $$\text{bounce} = \left(0.5 - 0.5\cos(2\theta)\right) \times H_{\text{head\_bounce}} \times \text{speed\_ratio}$$
   $$\vec{O}_{\text{head}} = (\text{head\_lean} \times \text{facing} \times \text{speed\_ratio}, -\text{bounce})$$

### 4.4. Air / Jump / Fall Blending
When `not is_on_floor()`:
$$\text{rising} = (v_y < 0.0), \quad \text{tuck} = \begin{cases} 1.0 & \text{if rising} \\ 0.45 & \text{if falling} \end{cases}$$
$$\vec{O}_{\text{foot\_r}} = (W_{\text{spread}} \times \text{facing}, -H_{\text{foot\_lift}} \times \text{tuck})$$
$$\vec{O}_{\text{foot\_l}} = (-W_{\text{spread}} \times \text{facing}, -H_{\text{foot\_lift}} \times \text{tuck} \times 0.5)$$
$$\vec{O}_{\text{arm\_r}} = (-W_{\text{swing}} \times \text{facing} \times 0.3, -H_{\text{air\_hand\_lift}})$$
$$\vec{O}_{\text{arm\_l}} = (W_{\text{swing}} \times \text{facing} \times 0.3, -H_{\text{air\_hand\_lift}} \times 0.8)$$
$$\vec{O}_{\text{head}} = (\text{head\_lean} \times \text{facing} \times 0.4, -2.0)$$

### 4.5. Exponential Pose Response Smoothing
Transitions between idle, running, and aerial states are filtered via exponential decay:
$$w = 1.0 - \exp(-\text{pose\_response} \times \Delta t)$$
$$\vec{P}_{\text{target}}(t) = \text{lerp}(\vec{P}_{\text{target}}(t - 1), \vec{P}_{\text{rest}} + \vec{O}, w)$$
Default `pose_response = 18.0` yields snappy yet artifact-free damping (~55ms convergence).

---

## 5. Source Code Defect & Bug Audit

During the inspection of `procedural-animation-test-scene`, several bugs were identified:

| Bug ID | Location | Observation & Impact | Recommended Fix |
|---|---|---|---|
| **BUG-01** | `stickmanprocedural.gd:63` | `facing - signf(direction)`: Subtraction operator used instead of assignment `=`. Standalone expression warning; `facing` never changes, so character cannot turn left. | Change to: `facing = signf(direction)` |
| **BUG-02** | `stickmanprocedural.tscn:125` | `[node name="Player" type="CharacterBody2D"]`: Missing `script = ExtResource(...)`. Instantiating the scene creates a dummy body with no movement or animation. | Add script link to `stickmanprocedural.gd` on root node. |
| **BUG-03** | `stickmanprocedural.tscn:112` | Modification 5 `SkeletonModification2DCCDIK_gavct` has `tip_nodepath = NodePath("Hip/Waist/Torso/Neck")` without a target or chain. Logs editor warnings. | Remove modification 5 or assign valid target and joint chain. |
| **BUG-04** | `stickmanprocedural.tscn:128` | Giant base dimensions: Capsule collider height is 732px, radius 118px. In `main.tscn`, an arbitrary scale of `0.41346` was applied to compensate. | Normalize rig scale to unit size (~100-120px) matching standard platformer metrics. |
| **BUG-05** | `stickmanprocedural.gd:63, 146` | Visual node `Rig` does not flip `scale.x`. Limb targets flip in X, causing bones to stretch backwards and contort instead of turning. | Set `Rig.scale.x = facing` on directional change. |

---

## 6. Integration Architecture with `new-game-project`

### 6.1. Comparison with Existing `new-game-project` Rig Systems

| Feature | `procedural-animation-test-scene` | `new-game-project` (`ModularAssetSystem`) |
|---|---|---|
| **Primary Architecture** | Scene-based (`Skeleton2D` + `Bone2D` + `CCDIK`) | Code-based Analytical Solver (`StickmanPoseSolver`) |
| **Render Backend** | Godot Scene Tree (`Sprite2D` nodes) | 4 Backends (`PROCEDURAL_VECTOR`, `TEXTURE_SPRITE`, `CUSTOM_POLYGON`, `PACKED_SCENE`) |
| **Coordinate System** | Godot Canvas Item (+Y is DOWN) | Pure Sim (+Y is UP, converted via `to_screen()`) |
| **Collision Size** | Height ~732px (scaled by 0.413) | Standard Player Height ~48px (feet at $y=-260$, head at $y=-212$) |
| **Performance Overhead** | Node traversal + CCDIK solver per frame | Zero allocation, pure vector math in RefCounted |
| **Customization** | Fixed 15 textures mapped via `RemoteTransform2D` | 20 PartSlots, 11 WeaponSlots, JSON manifests, runtime piece injection |

### 6.2. Two Integration Approaches

#### Strategy A: Direct PackedScene Backend (`PACKED_SCENE` in ModularAssetSystem)
`ModularAssetSystem.AssetRenderBackend.PACKED_SCENE` already exists in `new-game-project`.
- Export/instantiate `stickmanprocedural.tscn` as a child of the player entity.
- The player controller calls `rig.update_gait(velocity, is_grounded, facing, delta)`.
- Coordinate mapping required:
  - Negate Y: $v_{y, \text{rig}} = -v_{y, \text{sim}}$.
  - Scale factor: Scale rig down by approximately $48.0 / 732.0 \approx 0.0655$ (or normalize the source scene).
  - Slot mapping: Individual modular pieces can be injected as child sprites of the respective `Bone2D` nodes instead of the static `Body` sprites.

#### Strategy B: Algorithm Porting into `StickmanPoseSolver` (Recommended)
`new-game-project` relies on `ModularAssetSystem.StickmanPoseSolver` for its high-performance vector rendering, ghost trails, slice ragdolls, and headless test suites.
- Integrate the two-phase Hermite smoothstep foot swing:
  $$t_{\text{eased}} = t^2 (3 - 2t)$$
  $$\Delta y_{\text{foot}} = -\sin(t \pi) \times H_{\text{lift}}$$
- Integrate the double-frequency head bounce:
  $$\text{bounce} = (0.5 - 0.5\cos(2\theta)) \times H_{\text{bounce}} \times \text{speed\_ratio}$$
- Integrate vertical velocity-dependent aerial tucking (`rising` vs `falling`).
- *Benefits*: 100% headless CI compatibility, zero scene dependencies, perfect ghost trail support, and preservation of all 296 existing automated tests.

---

## 7. Runbook & Verification Guidelines

To independently verify the reference source behavior:
1. **Source Project Headless Verification**:
   ```powershell
   & "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene" --quit
   ```
2. **Target Project Test Suite Verification**:
   ```powershell
   python -c "
   import subprocess
   res = subprocess.run([
       r'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
       '--headless',
       '--path', r'c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project',
       '--script', 'res://tests/test_modular_rig.gd'
   ], capture_output=True, text=True)
   print(res.stdout)
   assert res.returncode == 0
   "
   ```
3. **Bug Verification**: Inspect line 63 of `stickmanprocedural.gd` and line 125 of `stickmanprocedural.tscn` to confirm the syntax and script attachment issues documented in Section 5.
