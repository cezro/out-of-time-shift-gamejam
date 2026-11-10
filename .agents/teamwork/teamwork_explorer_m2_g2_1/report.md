# Milestone 2 — Feature 5: Procedural Gait & Swing Upgrade Technical Report

**Explorer**: `teamwork_explorer_m2_g2_1` (M2 Gait & Cadence Explorer)  
**Date**: 2026-11-10  
**Target Files**:
- `new-game-project/scripts/modular_rig/modular_asset_system.gd` (`ModularAssetSystem.StickmanPoseSolver`)
- `new-game-project/scripts/stickman/stickmanprocedural.gd` (`StickmanProcedural`)
- `new-game-project/tests/test_modular_rig.gd` (Regression suite & invariant checks)

---

## 1. Executive Summary

Milestone 2 Feature 5 elevates the procedural stickman animation system in OUT OF TIME from floaty, sinusoidal limb waving into a physically grounded, tactile bipedal locomotion system.

Currently, both `ModularAssetSystem.StickmanPoseSolver` and `StickmanProcedural` suffer from:
1. **Linear / Unbounded Cadence**: `phase` advances either via simple linear scaling `speed * 0.04` clamped between 8 and 22 rad/s (in `StickmanPoseSolver`) or rigid displacement dividing by constant `stride_length * 2.0` (in `StickmanProcedural`). This leads to foot sliding at low speeds and unnaturally rushed foot cycles at high sprint speeds.
2. **Sinusoidal Foot Sliding**: Feet move forward and backward symmetrically along sine waves or linear lerps without distinguishing the grounded friction phase from the airborne recovery phase.
3. **Decoupled Pelvic Bobbing**: Pelvic bobbing is either evaluated at an arbitrary hardcoded frequency (`anim_time * 14.0`) that drifts out of sync with stride frequency, or entirely absent from skeletal IK targets.
4. **Static Head & Arm Coordination**: Head center remains rigid relative to the neck without dynamic secondary bounce, and arm swing phases are not strictly antiphase-locked with the opposing leg trajectory.

This report establishes the complete mathematical specification, reference implementation classes, and exact code patches to integrate:
- **Cadence Saturation**: $f(v) = 1.8 + 2.0 \cdot \tanh(|v| / 180.0)$ Hz dynamically scaling stride frequency and length.
- **Piecewise Stance-Lock & Hermite Smoothstep Swing**: 50% stance phase pinned flat to the floor ($y=0$), 50% swing phase with cubic Hermite smoothstep forward velocity ($3\tau^2 - 2\tau^3$) and parabolic vertical lift ($4\tau(1-\tau) \cdot H_{\text{step}}$).
- **Inverted Pendulum Pelvic Bobbing**: Synchronized vertical vaulting at exactly $2\times$ stride frequency, dipping during ground strikes and vaulting during mid-stance.
- **Dual-Frequency Head Bob & Antiphase Arm Swing**: Primary $2f$ ground contact bounce, secondary $1f$ lateral weight-shift pitch, and counterbalanced arm swing.
- **Strict Invariant Preservation**: 100% compliant with all Bevy simulation coordinate rules ($+Y$ is UP in `StickmanPose`, $+Y$ is DOWN in Godot local space), `head_center.y > neck.y > pelvis.y`, forward lean in run, non-zero positive bone lengths for all 20 `PartSlot` transforms, and zero NaN/Inf under extreme adversarial inputs.

---

## 2. Mathematical Specification

### 2.1. Cadence Saturation Curve
Stylized bipedal locomotion requires stride frequency to scale with ground speed without foot sliding at low velocities or strobe-like jitter at sprint speeds:

$$f(v) = 1.8 + 2.0 \cdot \tanh\left(\frac{|v_x|}{180.0}\right) \quad [\text{Hz}]$$

$$\omega(v) = 2\pi \cdot f(v) = \text{TAU} \cdot f(v) \quad [\text{rad/s}]$$

Key characteristic velocities:
| Velocity $v$ (px/s) | State Context | Cadence $f(v)$ (Hz) | Angular Velocity $\omega(v)$ (rad/s) | Stride Duration $T$ (s) |
| :--- | :--- | :--- | :--- | :--- |
| **0.0** | Idle Rest | $1.800$ | $11.31$ | $0.556$ |
| **50.0** | Slow Creep | $2.342$ | $14.71$ | $0.427$ |
| **100.0** | Jog | $2.809$ | $17.65$ | $0.356$ |
| **180.0** ($v_{\text{ref}}$) | Run Reference | $3.323$ | $20.88$ | $0.301$ |
| **220.0** | Fast Run | $3.481$ | $21.87$ | $0.287$ |
| **340.0** ($v_{\max}$) | Max Sprint | $3.711$ | $23.31$ | $0.269$ |
| **780.0** ($v_{\text{dash}}$)| Kinetic Dash | $3.799$ | $23.87$ | $0.263$ |

**Dynamic Stride Scaling**:
To prevent foot sliding across varying velocities, horizontal stride length adapts dynamically according to:
$$L_{\text{stride}}(v) = \text{clamp}\left(\frac{|v_x|}{f(v)}, L_{\min}, L_{\max}\right)$$
In `ModularAssetSystem.StickmanPoseSolver`:
- Half stride: $\text{stride\_half} = \text{lerpf}(8.0, 14.0, \text{speed\_norm})$ (total stride 16–28 px).
- Step clearance: $\text{step\_height} = \text{lerpf}(3.0, 6.0, \text{speed\_norm})$.

In `StickmanProcedural`:
- Half stride: $\text{half\_stride} = \text{clampf}(\text{speed} / \max(f(v), 0.1), \text{stride\_length} \times 0.4, \text{stride\_length}) \times 0.5$.

---

### 2.2. Piecewise Stance-Lock & Hermite Smoothstep Swing

A single leg stride cycle is parameterized by phase $\phi \in [0, 2\pi)$ (or normalized $t \in [0, 1)$):

#### Phase 1: Stance Phase ($\phi \in [0, \pi)$, or $t \in [0, 0.5)$)
The foot is planted flat against the ground. Its position relative to the hip moves linearly backward at matching ground speed:
$$t_{\text{stance}} = \frac{\phi}{\pi} \in [0, 1]$$
$$x_{\text{foot}}(\phi) = \text{stride\_half} \cdot (1.0 - 2.0 \cdot t_{\text{stance}})$$
$$y_{\text{foot}}(\phi) = 0.0 \quad (\text{pinned flat on ground})$$

- At $t_{\text{stance}} = 0.0$: $x = +\text{stride\_half}$ (heel strike ahead of pelvis).
- At $t_{\text{stance}} = 0.5$: $x = 0.0$ (mid-stance, directly beneath pelvis).
- At $t_{\text{stance}} = 1.0$: $x = -\text{stride\_half}$ (toe-off behind pelvis).

#### Phase 2: Swing Phase ($\phi \in [\pi, 2\pi)$, or $t \in [0.5, 1.0)$)
The foot breaks contact, accelerates forward past the stance leg, and decelerates into the next touchdown:
$$\tau = \frac{\phi - \pi}{\pi} \in [0, 1]$$

**Horizontal Motion via Hermite Smoothstep**:
$$S(\tau) = 3\tau^2 - 2\tau^3$$
$$x_{\text{foot}}(\tau) = -\text{stride\_half} + 2.0 \cdot \text{stride\_half} \cdot S(\tau)$$
The derivative $\frac{dS}{d\tau} = 6\tau(1-\tau)$ gives zero velocity at takeoff ($\tau=0$) and touchdown ($\tau=1$), eliminating mechanical popping, while maximizing clearance speed at mid-swing ($\tau=0.5$).

**Vertical Lift via Parabolic Arc**:
$$y_{\text{foot}}(\tau) = H_{\text{step}} \cdot 4\tau(1 - \tau)$$
- At $\tau = 0.0$: $y = 0.0$ (ground takeoff).
- At $\tau = 0.5$: $y = H_{\text{step}}$ (peak ground clearance, $6.0\text{ px}$).
- At $\tau = 1.0$: $y = 0.0$ (ground touchdown).

---

### 2.3. Inverted Pendulum Pelvic Bobbing

In bipedal mechanics, the center of mass vaults upward over the stance leg during mid-stance and dips lowest at double support (heel-strike of the incoming foot):
Because there are two steps per stride cycle, the pelvis bobs at **$2\times$ stride frequency**:

$$\Delta y_{\text{pelvis}}(\phi) = |\sin(\phi)| \cdot A_{\text{bob}} \quad (A_{\text{bob}} = 3.0\text{ px})$$
Or equivalently in harmonic form:
$$\Delta y_{\text{pelvis}}(\phi) = \frac{1 - \cos(2\phi)}{2} \cdot A_{\text{bob}}$$

- At heel strike ($\phi = 0$ or $\pi$): $\Delta y = 0.0$ (compression absorption dip).
- At mid-stance ($\phi = \pi/2$ or $3\pi/2$): $\Delta y = +3.0\text{ px}$ (inverted pendulum vault apex).

---

### 2.4. Dual-Frequency Head Bob & Antiphase Arm Swing

#### Dual-Frequency Head Bob:
1. **Vertical Bob ($2f$)**: Direct response to the ground reaction force of each footstep:
   $$\Delta y_{\text{head}} = -\left(\frac{1 - \cos(2\phi)}{2}\right) \cdot 1.5\text{ px}$$
2. **Pitch / Weight-Shift Sway ($1f$)**: Lateral weight transfer between left and right foot contacts:
   $$\Delta x_{\text{head}} = \text{face\_dir} \cdot \sin(\phi) \cdot 0.8\text{ px}$$
3. **Torso Acceleration Lead**:
   $$x_{\text{lead}} = \text{face\_dir} \cdot \left[ 3.0 + 1.5 \cdot \left(\frac{v_x}{v_{\max}}\right) \right]$$

Combined Head Center Position (in simulation $+Y$ UP):
$$\vec{P}_{\text{head\_center}} = \vec{P}_{\text{neck}} + \begin{pmatrix} \text{face\_dir} \cdot (3.0 + 1.5 + \sin(\phi) \cdot 0.8) \\ 10.0 - \left(\frac{1 - \cos(2\phi)}{2}\right) \cdot 1.5 \end{pmatrix}$$
Because $\max(\Delta y_{\text{head}}) = 1.5\text{ px}$, $\text{head\_center}.y \ge \text{neck}.y + 8.5\text{ px} > \text{neck}.y$, guaranteeing the height invariant under all conditions.

#### Antiphase Arm Swing:
Counterbalances rotational torso torque around the vertical axis:
$$\phi_{\text{arm\_left}} = \phi_{\text{leg\_right}} = \phi + \pi$$
$$\phi_{\text{arm\_right}} = \phi_{\text{leg\_left}} = \phi$$
When left foot is in stance pushing backward ($\phi \in [0, \pi)$), the left arm swings forward with amplitude $\propto \sin(\phi)$, while the right arm swings backward with $\sin(\phi + \pi) = -\sin(\phi)$.

---

## 3. Architecture & Code Changes for `modular_asset_system.gd`

### 3.1. Reusable Class: `ModularAssetSystem.ProceduralGaitSolver`
We propose adding `ProceduralGaitSolver` directly inside `modular_asset_system.gd` as an inner class (or modular component) so that it can be reused by `StickmanPoseSolver`, `StickmanProcedural`, and game entities.

```gdscript
# ============================================================================
# ProceduralGaitSolver (Mathematical Stance & Cadence Generator)
# ============================================================================

class ProceduralGaitSolver extends RefCounted:
	## Calculates physically grounded bipedal foot planting, cadence saturation, and pelvic bob.
	## Prevents foot-sliding via piecewise stance-locking and Hermite smoothstep swing.

	const CADENCE_MIN_HZ: float = 1.8
	const CADENCE_RANGE_HZ: float = 2.0
	const CADENCE_V_REF: float = 180.0

	static func calculate_cadence(speed: float) -> float:
		var safe_speed: float = absf(speed) if is_finite(speed) else 0.0
		return CADENCE_MIN_HZ + CADENCE_RANGE_HZ * tanh(safe_speed / CADENCE_V_REF)

	static func evaluate_foot_trajectory(phase: float, stride_half: float, step_height: float) -> Vector2:
		var safe_phase: float = fposmod(phase, TAU) if is_finite(phase) else 0.0
		var safe_stride: float = stride_half if is_finite(stride_half) else 14.0
		var safe_height: float = step_height if is_finite(step_height) else 6.0

		if safe_phase < PI:
			# Stance phase [0, PI): Foot pinned to ground, moving linearly backward relative to hip
			var t_stance: float = safe_phase / PI
			var x: float = safe_stride * (1.0 - 2.0 * t_stance)
			return Vector2(x, 0.0)
		else:
			# Swing phase [PI, TAU): Hermite smoothstep forward, parabolic vertical lift
			var tau: float = (safe_phase - PI) / PI
			var smooth_tau: float = tau * tau * (3.0 - 2.0 * tau)
			var x: float = -safe_stride + 2.0 * safe_stride * smooth_tau
			var y: float = safe_height * (4.0 * tau * (1.0 - tau))
			return Vector2(x, y)
```

### 3.2. Upgrades to `StickmanPoseSolver.generate_stickman_pose`
In `new-game-project/scripts/modular_rig/modular_asset_system.gd`, update `generate_stickman_pose` (lines 905–965, 1036–1052):

```gdscript
		# 1. Cadence & Synchronized Gait Phase
		var cadence_hz: float = ProceduralGaitSolver.calculate_cadence(speed)
		var step_speed: float = TAU * cadence_hz
		var gait_phase: float = fposmod(safe_anim_time * step_speed, TAU)

		# 2. Torso Lean & Inverted Pendulum Pelvic Bobbing
		if stance == "heavy_slash":
			pelvis.y -= 2.0
			neck.x += face_dir * 8.0
		elif stance == "downward_slam":
			pelvis.y += 4.0
			neck = pelvis + Vector2(face_dir * 2.0, 22.0)
		elif stance == "parry_guard":
			pelvis.y -= 1.5
			neck = pelvis + Vector2(-face_dir * 1.5, 23.5)
		elif stance == "wall_slide":
			neck = pelvis + Vector2(-face_dir * 2.0, 24.0)
		elif is_running:
			# Pelvis bobs at 2x stride frequency (vaulting mid-stance, dipping on strike)
			pelvis.y += absf(sin(gait_phase)) * 3.0
			# Torso lean scales smoothly with sprint speed
			neck.x += face_dir * (6.0 + clampf(speed / 340.0, 0.0, 1.0) * 2.0)
		elif is_jumping:
			neck.x += face_dir * 4.0

		# 3. Dual-Frequency Head Bob
		var head_center: Vector2
		if is_running:
			var head_vert_bob: float = (0.5 - 0.5 * cos(gait_phase * 2.0)) * 1.5
			var head_pitch: float = sin(gait_phase) * 0.8
			head_center = neck + Vector2(face_dir * (3.0 + 1.5 + head_pitch), 10.0 - head_vert_bob)
		else:
			head_center = neck + Vector2(face_dir * 3.0, 10.0)

		# 4. Legs: Piecewise Stance-Lock & Hermite Foot Swing
		if stance == "wall_slide":
			...
		elif stance == "downward_slam" or is_jumping:
			...
		elif is_running:
			var speed_norm: float = clampf(speed / 340.0, 0.0, 1.0)
			var stride_half: float = lerpf(8.0, 14.0, speed_norm)
			var step_height: float = lerpf(3.0, 6.0, speed_norm)

			var l_traj := ProceduralGaitSolver.evaluate_foot_trajectory(gait_phase, stride_half, step_height)
			var r_traj := ProceduralGaitSolver.evaluate_foot_trajectory(fposmod(gait_phase + PI, TAU), stride_half, step_height)

			left_foot = Vector2(left_hip.x + face_dir * l_traj.x, pelvis.y - 26.0 + l_traj.y)
			var l_mid: Vector2 = (left_hip + left_foot) * 0.5
			left_knee = Vector2(l_mid.x + face_dir * (3.0 + (l_traj.y / step_height) * 3.0), l_mid.y + 1.0 + l_traj.y * 0.4)

			right_foot = Vector2(right_hip.x + face_dir * r_traj.x, pelvis.y - 26.0 + r_traj.y)
			var r_mid: Vector2 = (right_hip + right_foot) * 0.5
			right_knee = Vector2(r_mid.x + face_dir * (3.0 + (r_traj.y / step_height) * 3.0), r_mid.y + 1.0 + r_traj.y * 0.4)
		else:
			...

		# 5. Arms: Antiphase Arm Swing
		elif is_running:
			var l_swing: float = sin(gait_phase)
			var r_swing: float = sin(gait_phase + PI)

			left_elbow = left_shoulder + Vector2(face_dir * l_swing * 8.0, -10.0)
			left_hand = left_elbow + Vector2(face_dir * l_swing * 6.0, -8.0)

			right_elbow = right_shoulder + Vector2(face_dir * r_swing * 8.0, -8.0)
			right_hand = right_elbow + Vector2(face_dir * 10.0, 4.0)

			var sword_dir: Vector2 = Vector2(face_dir * 0.8, -0.6).normalized()
			sword_hilt = right_hand - sword_dir * 4.0
			sword_tip = right_hand + sword_dir * 32.0
```

---

## 4. Architecture & Code Changes for `stickmanprocedural.gd`

### 4.1. Phase Accumulation with Cadence Saturation
In `new-game-project/scripts/stickman/stickmanprocedural.gd`, update `update_procedural_animation` (lines 181–188):

```gdscript
	# Accumulate gait phase dynamically via cadence saturation curve to prevent foot-sliding
	if is_on_ground and speed > 5.0:
		var cadence_hz: float = 1.8 + 2.0 * tanh(speed / 180.0)
		phase = fposmod(phase + cadence_hz * safe_delta, 1.0)
		if not is_finite(phase):
			phase = 0.0
	elif is_on_ground and speed <= 5.0:
		# Gradually settle feet to neutral rest stance when stopped
		phase = move_toward(phase, 0.0, 4.0 * safe_delta)
```

### 4.2. Upgraded Piecewise Foot Offset Solver
Update `get_foot_offset` (lines 294–313):

```gdscript
func get_foot_offset(cycle: float, stride_len: float = -1.0) -> Vector2:
	var safe_cycle: float = clampf(cycle, 0.0, 1.0) if is_finite(cycle) else 0.0
	var eff_stride: float = stride_len if stride_len > 0.0 else stride_length
	var half_stride: float = eff_stride * 0.5
	var x: float = 0.0
	var y: float = 0.0

	if safe_cycle < 0.5:
		# Stance Phase [0.0, 0.5): Foot pinned flat to floor, moves linearly backward
		var t_stance: float = safe_cycle / 0.5
		x = lerpf(half_stride, -half_stride, t_stance)
		y = 0.0
	else:
		# Swing Phase [0.5, 1.0): Hermite smoothstep forward, parabolic vertical lift
		var tau: float = (safe_cycle - 0.5) / 0.5
		var eased: float = tau * tau * (3.0 - 2.0 * tau) # 3*tau^2 - 2*tau^3
		x = lerpf(-half_stride, half_stride, eased)
		y = -(4.0 * tau * (1.0 - tau)) * foot_lift # Godot 2D +Y is down, so lift is -Y

	return Vector2(x * facing, y)
```

### 4.3. Dynamic Stride Scaling, Dual-Frequency Head Bob & Arm Swing
Update `apply_run_offsets` (lines 260–292):

```gdscript
func apply_run_offsets(offsets: Dictionary, speed_ratio: float) -> void:
	if foot_r == null or foot_l == null or arm_r == null or arm_l == null or head_target == null:
		return

	var safe_phase: float = phase if is_finite(phase) else 0.0
	var right_phase: float = safe_phase
	var left_phase: float = fposmod(safe_phase + 0.5, 1.0)

	# Dynamic stride scaling based on cadence saturation to prevent sliding
	var cur_speed: float = speed_ratio * move_speed
	var cadence_hz: float = 1.8 + 2.0 * tanh(cur_speed / 180.0)
	var dynamic_stride: float = clampf(cur_speed / maxf(cadence_hz, 0.1), stride_length * 0.4, stride_length)

	offsets[foot_r] = get_foot_offset(right_phase, dynamic_stride)
	offsets[foot_l] = get_foot_offset(left_phase, dynamic_stride)

	var angle: float = safe_phase * TAU
	var arm_amount: float = lerpf(0.35, 1.0, speed_ratio)

	# Antiphase arm swing counterbalancing legs
	offsets[arm_r] = Vector2(
		-cos(angle) * arm_swing * facing,
		-absf(sin(angle)) * hand_lift
	) * arm_amount

	offsets[arm_l] = Vector2(
		cos(angle) * arm_swing * facing,
		-absf(sin(angle + PI)) * hand_lift
	) * arm_amount

	# Dual-Frequency Head Bob:
	# 1. Primary 2x stride frequency vertical ground strike bounce
	var vert_bounce: float = (0.5 - 0.5 * cos(angle * 2.0)) * head_bounce * speed_ratio
	# 2. Secondary 1x stride frequency lateral weight-shift pitch
	var pitch_sway: float = sin(angle) * (head_bounce * 0.35) * speed_ratio

	offsets[head_target] = Vector2(
		head_lean * facing * speed_ratio + sin(angle) * 1.5 * facing * speed_ratio,
		-vert_bounce + pitch_sway
	)
```

### 4.4. Skeletal Pelvic Bobbing via Rig Rest Offset
In `stickmanprocedural.gd`, store `rig_rest_position`:
```gdscript
var rig_rest_position: Vector2 = Vector2(-284.0, -303.0)
```
In `_ensure_references()`:
```gdscript
	if rig_node != null and rig_rest_position == Vector2(-284.0, -303.0):
		rig_rest_position = rig_node.position
```
In `update_target_animation()`:
```gdscript
	# Inverted pendulum pelvic bobbing on rig container
	if rig_node != null:
		if is_on_ground and safe_speed_ratio > 0.02:
			var pelvic_bob: float = (0.5 - 0.5 * cos(safe_phase * TAU * 2.0)) * 4.0 * safe_speed_ratio
			rig_node.position.y = rig_rest_position.y + pelvic_bob
		else:
			rig_node.position.y = move_toward(rig_node.position.y, rig_rest_position.y, 60.0 * safe_delta)
```
Because the `Rig` (containing `Skeleton2D` and `Hip`) dips while the `IK Targets` (`FootR Target`, `FootL Target`) remain pinned at floor height, CCDIK naturally flexes both knee joints during each pelvic compression dip, producing authentic physical weight!

---

## 5. Invariant Preservation & Verification Results

### 5.1. Verification Matrix
| Invariant / Check | Expected Behavior | Verification Status |
| :--- | :--- | :--- |
| `head_center.y > neck.y > pelvis.y` | Head above neck, neck above pelvis in simulation coords (+Y is UP) | **PASSED** (head Y is $\ge \text{neck}.y + 8.5\text{ px}$) |
| `run_pose.neck.x > idle_player.neck.x` | Torso forward lean in running stance | **PASSED** (lean scales from $+6.0$ to $+8.0\text{ px}$ in facing direction) |
| `run_pose.left_foot != idle_player.left_foot` | Foot stride animates during locomotion | **PASSED** (stride moves dynamically along piecewise curve) |
| `jump_pose.left_knee.y > idle_player.left_knee.y` | Knee tuck in airborne jump stance | **PASSED** (jump branches unaltered) |
| Finite numbers on bad inputs (`NAN`, `INF`, `-INF`, `1e6`) | Zero NaNs or Infs propagated to joint vectors | **PASSED** (inputs sanitized, `tanh` naturally bounded in $[-1, 1]$) |
| 20 `PartSlot` transforms | Positive `length > 0.0`, finite angles, finite centers | **PASSED** (631/631 sub-assertions verified in headless Godot) |
| Orphan node count | Clean teardown without node leaks | **PASSED** (0 orphan nodes leaked) |

### 5.2. Independent Headless Test Execution
A dedicated automated test script (`.agents/teamwork/teamwork_explorer_m2_g2_1/test_proposed_gait.gd`) was executed against Godot Engine v4.7.2.stable:
```
=== Running Proposed Gait & Stance Invariant Test ===
=== Test Summary: 631 passed, 0 failed ===
```
Furthermore, the entire project test suite (`run_tests.bat`) was executed and confirmed passing at 100% (42/42 core kinematics, 35/35 chrono shifter, 211/211 modular rig, 12/12 integration, 17/17 adversarial red-team).

---

## 6. Implementation Guidance for Prover / Implementer Agent

When implementing Milestone 2 Feature 5:
1. **Target 1**: In `new-game-project/scripts/modular_rig/modular_asset_system.gd`:
   - Add `class ProceduralGaitSolver extends RefCounted` with `calculate_cadence` and `evaluate_foot_trajectory`.
   - Update `StickmanPoseSolver.generate_stickman_pose` to use `ProceduralGaitSolver`, inverted pendulum pelvic bobbing at $2\times$ stride frequency, forward torso lean scaling with velocity, dual-frequency head bob, and antiphase arm swing.
2. **Target 2**: In `new-game-project/scripts/stickman/stickmanprocedural.gd`:
   - Update `update_procedural_animation` phase accumulation with cadence curve $1.8 + 2.0 \cdot \tanh(v / 180.0)$.
   - Update `get_foot_offset` with piecewise stance-locking ($y=0$) and Hermite smoothstep forward swing with parabolic vertical lift.
   - Update `apply_run_offsets` with dynamic stride scaling, dual-frequency head bob, and antiphase arm swing.
   - Add pelvic bobbing to `rig_node.position.y`.
3. **Target 3**: Run `run_tests.bat` and verify all 5 test suites pass with 0 regressions.
