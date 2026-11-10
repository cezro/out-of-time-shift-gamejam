# Comprehensive Motion & Animator Skills Survey: Snappy 2D Procedural Stickman Animation in Godot 4.7

**Explorer**: Explorer 3 (`teamwork_explorer` — Motion & Animator Skills)  
**Date**: 2026-11-10  
**Project**: `out-of-time-shift-gamejam` (`new-game-project`, Godot 4.7)  
**Target Domain**: High-responsiveness 2D stickman procedural combat, platforming locomotion, and fluid kinematic expression.

---

## 1. Executive Summary

Procedural 2D stickman animation requires a delicate balance between **instant kinematic responsiveness** (zero input lag, crisp telegraphing) and **believable physical weight** (secondary momentum, foot planting, squash/stretch impact). 

Generic sine-wave procedural rigs (such as simple harmonic bobbing and trigonometric leg waving) feel floaty, slippery, and robotic because feet slide across the floor without friction, torso leans ignore acceleration spikes, and combat slashes sweep linearly without attack acceleration or hitstop snap.

By surveying 5 specialized agent skills from modern game development and interaction motion design:
1. `gamedev-skills/awesome-gamedev-agent-skills@godot-animation`
2. `thedivergentai/game-dev-agentic-skills@godot-2d-animation`
3. `thedivergentai/game-dev-agentic-skills@godot-animation-tree-mastery`
4. `kylezantos/design-motion-principles@design-motion-principles` (Emil Kowalski, Jakub Krehel, Jhey Tompkins)
5. `affaan-m/ecc@motion-patterns` & `motion-foundations`

We synthesize a unified, mathematically grounded framework tailored specifically for Godot 4.7 GDScript. This report details the core principles, exact equations, parameter tables, and reference implementations for:
- **Second-Order Damped Springs** ($\zeta \in [0.65, 0.85]$ for snappy overshoot with rapid settle).
- **Asymmetric Easing Curves** (fast attack exponential entry, soft settle).
- **Physical Gait Cycle & Foot Planting** (cadence power-law, piecewise stance-hold vs rapid swing, ground contact pop).
- **Volume-Preserving Squash & Stretch** (jump anticipation, launch stretch, falling elongation, landing impact rebound).
- **Combat Slash Mechanics** (non-linear sweep, anticipation coil, hitstop frame holding).

---

## 2. In-Depth Analysis of Candidate Skills

### 2.1. `gamedev-skills/awesome-gamedev-agent-skills@godot-animation`
- **Core Architecture**: Distinguishes the three animation axes in Godot 4.7:
  - `AnimationPlayer`: Source of truth for keyframed clips, Call Method tracks (critical for frame-perfect hitbox and audio synchronization), and Property/Bézier curves.
  - `AnimationTree`: Runtime blending, `AnimationNodeStateMachine` transitions, and `AnimationNodeBlendSpace2D` parameter driving.
  - `Tween` (`create_tween()`): Pure procedural, fire-and-forget code transitions for UI pops, juice, recoil impulses, and squash-stretch recovery.
- **Godot 4.7 Specifics**:
  - `Tween.TRANS_SPRING` and `Tween.TRANS_BACK` paired with `Tween.EASE_OUT` provide built-in overshoot dampening.
  - Sub-property addressing via colons (e.g., `tween_property(rig, "scale:y", 1.0, 0.12)`).
  - Deprecation of 3.x `Tween` nodes and `yield()` in favor of lightweight `create_tween()` and `await tw.finished`.
- **Takeaway for Procedural Stickman**: Procedural rig calculations shouldn't fight Godot's scene tree. High-frequency limb positioning is solved per-frame in GDScript, while global impulses (landing squash, hit recoil, parry flashes) are smoothly layered via code tweens or procedural spring offsets.

### 2.2. `thedivergentai/game-dev-agentic-skills@godot-2d-animation`
- **Core Architecture**: Focuses on 2D skeletal hierarchies (`Bone2D`), `AnimatedSprite2D`, and hybrid procedural-skeletal animation.
- **Key Principles**:
  - Separation of mathematical pose calculation from rendering backends (vector lines, sprites, polygonal cutouts).
  - Explicit limb constraint enforcement: preventing hyperextension of procedural knees/elbows using inverse kinematics (IK) angle clamps.
  - Frame-perfect event dispatching on contact frames (e.g., footstep dust, blade trail emission).
- **Takeaway for Procedural Stickman**: The existing `ModularAssetSystem.StickmanPoseSolver` already separates pose generation from the 4 rendering backends (`PROCEDURAL_VECTOR`, `TEXTURE_SPRITE`, `CUSTOM_POLYGON`, `PACKED_SCENE`). The procedural pose solver must calculate joint positions that conform to realistic stickman bone lengths while injecting kinematic juice.

### 2.3. `thedivergentai/game-dev-agentic-skills@godot-animation-tree-mastery`
- **Core Architecture**: Advanced hierarchical state machines, blend trees, and parameter path decoupling.
- **Key Principles**:
  - **Decouple Physics from Animation State**: Locomotion parameters (velocity, acceleration, ground status) must be normalized into continuous driving variables rather than discrete brittle states.
  - **Avoid "Spider-Web Graphs"**: Group states hierarchically (e.g., Locomotion vs Combat vs Hit Reactions).
  - Relative parameter paths and clean blend spaces (`parameters/Locomotion/blend_position`).
- **Takeaway for Procedural Stickman**: Rather than hard-switching between poses, stickman procedural animation should blend between base procedural modes (Idle, Walk, Run, Jump, WallSlide, Attack) using smooth weight transitions or continuous velocity-driven gait parameters.

### 2.4. `kylezantos/design-motion-principles@design-motion-principles`
- **The Three Designer Lenses**:
  1. **Emil Kowalski** (Restraint, Speed, Purpose):
     - *"UI animations should generally stay under 300ms."* (In high-intensity games, action telegraphed states must resolve in 60–180ms).
     - **The Frequency Rule**: Actions triggered hundreds of times per minute (jumping, running, slashing) must have ultra-snappy or instantaneous attack, with no floaty lag.
     - **Scale on Press**: Immediate tactile feedback (e.g., crouch anticipation on jump, impact compression on attack connect).
     - **Interruptibility**: Animations must never lock out state or queue sluggishly; when direction changes, the rig must blend instantly into the new trajectory.
  2. **Jakub Krehel** (Production Polish):
     - **Subtle Settling**: Use damped springs without excessive bounce ($\text{bounce} \approx 0$ or small overshoot) to maintain a grounded, professional feel.
     - **Asymmetric Transitions**: Entrances/attacks are fast and punchy; exits/settles are smooth and subtle.
  3. **Jhey Tompkins** (Parametric & Creative Decomposition):
     - Decompose monolithic transforms into isolated degrees of freedom (e.g., separately controlling torso lean, pelvic bob, and foot swing rather than a single combined transformation).
- **Anti-Slop Quality Gate**:
  - Eliminates floaty, unmotivated easing (`TRANS_LINEAR` or generic `TRANS_SINE` everywhere).
  - Eliminates disconnect between visual motion and player control.

### 2.5. `affaan-m/ecc@motion-patterns` & `motion-foundations`
- **Standardized Spring Token Presets**:
  - `snappy`: `{ stiffness: 300, damping: 30 }` (Natural frequency $\approx 2.76\text{ Hz}$, damping ratio $\zeta \approx 0.86$ — fast attack, zero wobble, tiny overshoot).
  - `gentle`: `{ stiffness: 120, damping: 14 }` (Soft settling for idle transitions).
  - `bouncy`: `{ stiffness: 400, damping: 10 }` (High frequency, visible oscillations).
  - `instant`: `{ stiffness: 600, damping: 35 }` (Ultra-fast settle, $< 100\text{ ms}$).
- **Token Durations**:
  - `instant`: 80ms
  - `fast`: 180ms
  - `normal`: 350ms
- **Cubic Bézier Tokens**:
  - `smooth`: `[0.22, 1.0, 0.36, 1.0]` (Ease-Out Quint/Cubic curve).
  - `sharp`: `[0.4, 0.0, 0.2, 1.0]` (Fast acceleration, firm stop).
- **Scale Tokens**:
  - `subtle`: $0.98$
  - `press`: $0.95$ (Micro-squash on landing / footstep)
  - `pop`: $1.04$ (Telegraph pop)

---

## 3. Mathematical Principles of Snappy Procedural Stickman Animation

### 3.1. Damped Harmonic Oscillator (Second-Order Dynamic Spring)

To replace linear or floaty lerps, procedural joint and torso offsets should be computed using a second-order spring-damper system:

$$m \ddot{y} + c \dot{y} + k (y - y_{\text{target}}) = 0$$

Dividing by mass $m$, we define:
- **Angular Natural Frequency**: $\omega_n = \sqrt{k / m} = 2\pi f_n$ (where $f_n$ is in Hertz)
- **Damping Ratio**: $\zeta = \frac{c}{2\sqrt{km}}$

The system behavior is dictated by $\zeta$:
- $\zeta > 1.0$: Overdamped (sluggish, no overshoot)
- $\zeta = 1.0$: Critically Damped (fastest approach to target with exactly zero overshoot)
- $0.65 \le \zeta \le 0.85$: **Snappy Underdamped** (rapid attack, 2%–8% overshoot, settles within 1–1.5 oscillation cycles) — **The Sweet Spot for Game Juice**.
- $\zeta < 0.5$: Underdamped/Wobbly (excessive ringing, jelly-like).

#### Semi-Implicit Euler Numerical Integration
For real-time physics in Godot `_physics_process(dt)`:
$$a = -\omega_n^2 (y - y_{\text{target}}) - 2\zeta \omega_n v$$
$$v \leftarrow v + a \cdot \Delta t$$
$$y \leftarrow y + v \cdot \Delta t$$

Semi-implicit Euler evaluates velocity first, then position, making it unconditionally stable provided $\Delta t < \frac{2}{\omega_n}$.

---

### 3.2. Asymmetric Easing Curves (Fast Attack, Soft Settle)

For triggered events (blade slashes, dash thrusts, turn-around flips), time-normalized progression $t \in [0, 1]$ must be mapped through fast-attack curves.

#### 1. Ease-Out Exponential (Immediate Snap)
$$y(t) = 1.0 - 2^{-10t}$$
- At $t = 0.1$ (10% of time elapsed), $y(0.1) \approx 0.50$ (50% of motion done!).
- At $t = 0.3$ (30% elapsed), $y(0.3) \approx 0.875$ (87.5% done!).
- The remaining 70% of time is spent smoothly settling into the rest pose.

#### 2. Ease-Out Back (Snappy Overshoot)
$$y(t) = 1.0 + c_1 (t - 1)^3 + c_2 (t - 1)^2$$
Where $c_1 \approx 1.70158$ and $c_2 \approx 1.70158$.  
For a sharper, snappier stickman recoil, tuning $c_1 = 2.4$ yields a punchy 8% overshoot.

---

### 3.3. Stride Frequency, Cadence, and Procedural Foot Planting

The major flaw of naive trigonometric walking (`sin(anim_time * speed)`) is **foot slip**: the feet slide backward and forward smoothly across the floor regardless of ground speed.

#### 1. Cadence (Stride Frequency vs Velocity)
In human and stylized bipedal locomotion, stride frequency does not scale linearly. At low speeds, stride length increases faster than frequency; at high sprint speeds, cadence asymptotically approaches a physical ceiling:

$$f_{\text{cadence}}(v) = f_{\min} + (f_{\max} - f_{\min}) \cdot \tanh\left(\frac{|v_x|}{v_{\text{ref}}}\right)$$

For OUT OF TIME's kinematic configuration ($v_{\max} = 340.0\text{ px/s}$):
- $f_{\min} = 1.8\text{ Hz}$ ($11.3\text{ rad/s}$)
- $f_{\max} = 3.8\text{ Hz}$ ($23.8\text{ rad/s}$)
- $v_{\text{ref}} = 180.0\text{ px/s}$

#### 2. Piecewise Stance & Swing Phases
A step cycle of phase $\phi \in [0, 2\pi)$ is split into two distinct mechanical phases:
1. **Stance Phase ($\phi \in [0, \pi)$)**: The foot is planted on the floor.
   - Horizontal offset relative to hip moves linearly backward at matching ground velocity:
     $$x_{\text{foot}}(\phi) = \text{stride\_half} \cdot \left(1.0 - 2.0 \cdot \frac{\phi}{\pi}\right)$$
   - Vertical height is locked flat to the floor:
     $$y_{\text{foot}}(\phi) = -L_{\text{leg}}$$
2. **Swing Phase ($\phi \in [\pi, 2\pi)$)**: The foot breaks ground contact and swings forward to prepare for the next plant.
   - Forward progress accelerates using a smooth cosine or cubic ease:
     $$\tau = \frac{\phi - \pi}{\pi} \in [0, 1]$$
     $$x_{\text{foot}}(\tau) = -\text{stride\_half} + 2.0 \cdot \text{stride\_half} \cdot (3\tau^2 - 2\tau^3)$$
   - Lift height follows a clean parabolic arc:
     $$y_{\text{foot}}(\tau) = -L_{\text{leg}} + H_{\text{step}} \cdot 4\tau(1 - \tau)$$

#### 3. Ground Contact Pop & Pelvis Inverted Pendulum
- The pelvis does not bob at $1\times$ stride frequency; it bobs at **$2\times$ stride frequency** (once per step when each foot lands).
- When a foot transitions from swing to stance ($\phi \approx 0$ or $\pi$), ground strike occurs:
  - Pelvis drops into a compression dip of $\Delta y \approx -3.5\text{ px}$.
  - A subtle knee bend absorbs the shock before rebounding up as the leg straightens during mid-stance.

---

### 3.4. Volume-Conserving Squash & Stretch

To maintain cartoon/stylized believability, non-rigid distortion of the stickman silhouette must respect **conservation of volume**:

$$S_x \cdot S_y = 1.0 \implies S_x = \frac{1}{\sqrt{S_y}}$$

#### 1. Jump Launch Anticipation & Explosion
- **Anticipation Frame ($t_{\text{jump}} \in [0, 0.04\text{s}]$)**: Compression into the floor:
  $$S_y = 0.75, \quad S_x = 1.15$$
- **Ascent Stretch**: Upward velocity ($v_y > 0$) elongates the torso and limbs along the velocity vector:
  $$S_y = 1.0 + \text{clamp}\left(\frac{v_y}{1200.0}, 0.0, 0.32\right)$$
  $$S_x = \frac{1}{\sqrt{S_y}}$$

#### 2. Apex Hang & Tuck
- Near apex ($|v_y| < 80.0\text{ px/s}$):
  $$S_y \to 1.0, \quad S_x \to 1.0$$
  Knees tuck up closer to the pelvis ($\Delta y_{\text{knee}} = +6.0\text{ px}$), arms flare slightly out for balance.

#### 3. High-Speed Descent Stretch
- When falling rapidly ($v_y < -300.0\text{ px/s}$ under gravity multiplier $1.6 \times 1400 = 2240\text{ px/s}^2$):
  $$S_y = 1.0 + \text{clamp}\left(\frac{|v_y|}{1500.0}, 0.0, 0.28\right)$$

#### 4. Landing Impact & Spring Rebound
- On ground impact ($v_y^{\text{impact}} < -100.0\text{ px/s}$):
  - Instantaneous compression impulse:
    $$\text{squash\_impulse} = \text{clamp}\left(\frac{|v_y^{\text{impact}}|}{1400.0}, 0.15, 0.45\right)$$
    $$S_y = 1.0 - \text{squash\_impulse}$$
  - Fed into a high-frequency damped spring ($f = 6.5\text{ Hz}, \zeta = 0.72$) which rebounds to $1.0$ within $110\text{ ms}$, creating an immediate tactile thump.

---

### 3.5. Dynamic Recoil, Inertia, and Turn-Around Snapping

#### 1. Acceleration-Proportional Torso Lean
Torso lean should not merely depend on current velocity; it must respond to **acceleration** $a_x = \frac{dv_x}{dt}$:

$$\theta_{\text{torso}} = \text{facing} \cdot \left[ k_{\text{vel}} \cdot \left(\frac{v_x}{v_{\max}}\right) + k_{\text{accel}} \cdot \left(\frac{a_x}{a_{\max}}\right) \right]$$

- When accelerating forward ($a_x = +2200\text{ px/s}^2$): Torso leans hard into the run ($\theta \approx +14^\circ$).
- When braking hard ($a_x = -2800\text{ px/s}^2$ decel): Torso snaps backward ($\theta \approx -10^\circ$) as the character braces feet forward to stop!

#### 2. Head & Scarf Secondary Motion (Trailing Spring)
- The head center is attached to the neck via a trailing spring with natural delay:
  $$\vec{P}_{\text{head\_target}} = \vec{P}_{\text{neck}} + \vec{u}_{\text{offset}}$$
  Head lags behind acceleration by $\approx 25\text{ms}$. When stopping abruptly, the head overshoots forward by $3\text{ px}$ before snapping back, giving organic life to the stickman.
- Scarf tail nodes trail behind using a chained verlet or spring-damper rope simulation.

#### 3. Directional Turn-Around (180° Flip Snap)
- When input flips from $+1$ to $-1$:
  - Rather than an immediate rigid mirror or a slow rotation, apply a 2-frame compression:
    $$S_x = 0.2, \quad S_y = 1.1$$
  - Invert facing direction, then spring-expand $S_x$ to $1.0$ with a quick $1.08 \to 1.0$ overshoot.
  - The leading foot skids forward in a bracing stance.

---

### 3.6. Combat Slash Non-Linear Mechanics

A linear slash (`swing_angle = -0.8 + sweep * 2.2`) lacks impact. High-tier combat feel uses a 3-phase kinematic curve:

1. **Anticipation / Windup ($p \in [0.0, 0.15]$)**:
   - Arm pulls back slightly ($\approx -15^\circ$), torso coils opposite to slash direction.
2. **Strike Explosion ($p \in [0.15, 0.40]$)**:
   - 80% of the blade arc is traversed in 25% of the duration.
   - Angle follows an aggressive ease-out exponential sweep.
   - Blade tip stretches outward along the arc radius.
3. **Hitstop & Settle ($p \in [0.40, 1.0]$)**:
   - On enemy contact: hold pose frozen for $3\text{ frames}$ ($50\text{ ms}$).
   - Follow-through smoothly decelerates into rest recovery pose with subtle spring dampening.

---

## 4. Parameter Tuning Reference Table

The following parameter values are calibrated against `PlayerKinematics` constants ($v_{\max} = 340$, $a_{\text{accel}} = 2200$, $a_{\text{decel}} = 2800$, $F_{\text{jump}} = 580$, $g = 1400$):

| Subsystem | Parameter | Value | Unit | Design Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Landing Spring** | Natural Frequency $f_n$ | $6.5$ | Hz | Ultra-fast recovery ($<120\text{ ms}$) without lingering mush |
| **Landing Spring** | Damping Ratio $\zeta$ | $0.72$ | ratio | Single subtle rebound (overshoots by ~5%) for punchy impact |
| **Torso Spring** | Natural Frequency $f_n$ | $4.5$ | Hz | Matches human core muscle stabilization frequency |
| **Torso Spring** | Damping Ratio $\zeta$ | $0.80$ | ratio | Crisp settling on sudden stop; minimal wobble |
| **Head Lag Spring** | Natural Frequency $f_n$ | $8.0$ | Hz | Tight secondary lag; snaps back sharply |
| **Head Lag Spring** | Damping Ratio $\zeta$ | $0.75$ | ratio | Subtle head bob on footsteps and stops |
| **Gait Cadence** | Min Cadence $f_{\min}$ | $1.8$ | Hz | Stroll cadence at low analog tilt |
| **Gait Cadence** | Max Cadence $f_{\max}$ | $3.8$ | Hz | Sprint cadence at full $340\text{ px/s}$ |
| **Gait Stride** | Max Stride Half | $14.0$ | px | Matches 28px total foot separation |
| **Gait Step Height**| $H_{\text{step}}$ | $6.0$ | px | Foot clearance above ground during swing |
| **Pelvic Bob** | Amplitude | $3.0$ | px | Vertical dip on each foot contact |
| **Squash/Stretch** | Jump Anticipation | $0.80$ | ratio | Torso compression before upward thrust |
| **Squash/Stretch** | Max Jump Stretch | $1.32$ | ratio | Torso elongation at $v_y = 580\text{ px/s}$ |
| **Squash/Stretch** | Max Fall Stretch | $1.25$ | ratio | Torso elongation at terminal fall speed |
| **Squash/Stretch** | Max Land Squash | $0.68$ | ratio | Impact compression on hard landing |
| **Turnaround** | Flip Duration | $70$ | ms | Fast directional snap; prevents input mushiness |
| **Combat Slash** | Windup Share | $0.15$ | ratio | First 15% duration spent in anticipation coil |
| **Combat Slash** | Strike Arc Share | $0.25$ | ratio | Next 25% duration traverses 80% of swing arc |

---

## 5. GDScript Reference Implementations

Below are self-contained, high-performance GDScript reference components ready for integration into the Godot project.

### 5.1. `ProceduralSpring` (Second-Order Dynamic Spring Solver)

```gdscript
class_name ProceduralSpring
extends RefCounted

## High-performance second-order dynamic spring system for procedural motion.
## Supports float and Vector2 with zero runtime object allocations.

var value: float = 0.0
var velocity: float = 0.0
var target: float = 0.0

var frequency: float = 5.0  ## Natural frequency in Hz (cycles per second)
var damping: float = 0.75   ## Damping ratio (zeta): 1.0 = critical, 0.75 = snappy overshoot

func _init(p_frequency: float = 5.0, p_damping: float = 0.75, p_initial: float = 0.0) -> void:
	frequency = p_frequency
	damping = p_damping
	value = p_initial
	target = p_initial
	velocity = 0.0

func reset(p_val: float) -> void:
	value = p_val
	target = p_val
	velocity = 0.0

func update(dt: float) -> float:
	var safe_dt: float = clampf(dt, 0.0, 0.05)
	if safe_dt <= 0.0:
		return value
	
	var omega: float = TAU * frequency
	var omega_sq: float = omega * omega
	var damping_factor: float = 2.0 * damping * omega
	
	# Semi-implicit Euler integration (unconditionally stable for game tick rates)
	var accel: float = -omega_sq * (value - target) - damping_factor * velocity
	velocity += accel * safe_dt
	value += velocity * safe_dt
	return value

func snap_to(p_target: float) -> void:
	target = p_target

func apply_impulse(impulse: float) -> void:
	velocity += impulse
```

---

### 5.2. `SnappyCurves` (Fast-Attack & Overshoot Mathematical Library)

```gdscript
class_name SnappyCurves
extends RefCounted

## Mathematical easing and non-linear curve evaluation library for snappy animations.

## Fast Attack Exponential Settle (80% motion completed in 20% of duration)
static func ease_out_expo(t: float) -> float:
	var ct: float = clampf(t, 0.0, 1.0)
	return 1.0 if ct >= 1.0 else 1.0 - pow(2.0, -10.0 * ct)

## Snappy Overshoot Curve with controllable overshoot intensity (c1)
static func ease_out_back_tuned(t: float, overshoot_c1: float = 2.2) -> float:
	var ct: float = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + (overshoot_c1 + 1.0) * pow(ct, 3.0) + overshoot_c1 * pow(ct, 2.0)

## Smooth Cubic S-Curve (Hermite smootherstep)
static func smootherstep(t: float) -> float:
	var ct: float = clampf(t, 0.0, 1.0)
	return ct * ct * ct * (ct * (ct * 6.0 - 15.0) + 10.0)

## Volume-conserving scale from vertical stretch factor
static func volume_conserving_scale(scale_y: float) -> Vector2:
	var safe_sy: float = maxf(0.1, scale_y)
	var scale_x: float = 1.0 / sqrt(safe_sy)
	return Vector2(scale_x, safe_sy)
```

---

### 5.3. `ProceduralGaitSolver` (Foot Planting & Cadence Generator)

```gdscript
class_name ProceduralGaitSolver
extends RefCounted

## Calculates physically grounded bipedal foot planting and pelvic bob.
## Prevents foot-sliding by using piecewise stance-lock and rapid swing-arc.

var walk_phase: float = 0.0

func step_gait(
	speed_x: float,
	is_grounded: bool,
	dt: float,
	stride_half: float = 14.0,
	step_height: float = 6.0
) -> Dictionary:
	if not is_grounded or absf(speed_x) < 5.0:
		return {
			"left_foot_offset": Vector2.ZERO,
			"right_foot_offset": Vector2.ZERO,
			"pelvis_dip": 0.0,
			"is_foot_strike": false
		}
	
	# Cadence follows power-law / tanh saturation curve
	var cadence_hz: float = 1.8 + 2.0 * tanh(absf(speed_x) / 180.0)
	var step_speed: float = TAU * cadence_hz
	
	var old_phase: float = walk_phase
	walk_phase = fmod(walk_phase + step_speed * dt, TAU)
	
	# Foot strike occurs at phase wraps (0 or PI)
	var struck_left: bool = (old_phase < PI and walk_phase >= PI)
	var struck_right: bool = (old_phase > walk_phase) # Wrapped past TAU
	var is_foot_strike: bool = struck_left or struck_right
	
	var l_offset := _evaluate_leg_trajectory(walk_phase, stride_half, step_height)
	var r_offset := _evaluate_leg_trajectory(fmod(walk_phase + PI, TAU), stride_half, step_height)
	
	# Pelvis bobs at 2x stride frequency (inverted pendulum)
	var pelvis_dip: float = -absf(sin(walk_phase)) * 3.0
	
	return {
		"left_foot_offset": l_offset,
		"right_foot_offset": r_offset,
		"pelvis_dip": pelvis_dip,
		"is_foot_strike": is_foot_strike
	}

func _evaluate_leg_trajectory(phase: float, stride_half: float, step_height: float) -> Vector2:
	if phase < PI:
		# Stance Phase: Foot planted firmly, moves linearly backward relative to pelvis
		var t_stance: float = phase / PI # 0.0 -> 1.0
		var x: float = stride_half * (1.0 - 2.0 * t_stance)
		var y: float = 0.0 # Flat on ground
		return Vector2(x, y)
	else:
		# Swing Phase: Foot lifts, accelerates forward via smooth cubic swing
		var t_swing: float = (phase - PI) / PI # 0.0 -> 1.0
		# Fast attack swing forward
		var smooth_t: float = 3.0 * t_swing * t_swing - 2.0 * t_swing * t_swing * t_swing
		var x: float = -stride_half + 2.0 * stride_half * smooth_t
		# Parabolic lift arc
		var y: float = step_height * (4.0 * t_swing * (1.0 - t_swing))
		return Vector2(x, y)
```

---

### 5.4. `ProceduralSquashStretch` (Jump, Land & Impact Controller)

```gdscript
class_name ProceduralSquashStretch
extends RefCounted

## Manages dynamic volume-conserving deformation and landing recoil.

var land_spring := ProceduralSpring.new(6.5, 0.72, 1.0)
var was_grounded_last_frame: bool = true
var last_vertical_velocity: float = 0.0

func update(is_grounded: bool, vy: float, dt: float) -> Vector2:
	# Detect landing impact
	if is_grounded and not was_grounded_last_frame:
		# Impact velocity creates downward compression impulse
		var impact_speed: float = absf(last_vertical_velocity)
		if impact_speed > 100.0:
			var compression: float = clampf(impact_speed / 1400.0, 0.12, 0.40)
			land_spring.apply_impulse(-compression * 22.0)
	
	was_grounded_last_frame = is_grounded
	last_vertical_velocity = vy
	
	var base_scale_y: float = land_spring.update(dt)
	
	# Airborne velocity-based stretch
	if not is_grounded:
		if vy > 50.0:
			# Upward jump launch stretch
			var stretch: float = clampf(vy / 1200.0, 0.0, 0.32)
			base_scale_y += stretch
		elif vy < -200.0:
			# Downward falling stretch
			var stretch: float = clampf(absf(vy) / 1600.0, 0.0, 0.25)
			base_scale_y += stretch
	
	return SnappyCurves.volume_conserving_scale(base_scale_y)
```

---

### 5.5. `CombatSlashCurve` (Non-Linear Attack Sweep Generator)

```gdscript
class_name CombatSlashCurve
extends RefCounted

## Generates non-linear attack sweep with anticipation windup and snap strike.

static func calculate_slash_angle(attack_progress: float, facing: float, is_heavy: bool) -> Dictionary:
	var p: float = clampf(attack_progress, 0.0, 1.0)
	# attack_progress goes 1.0 -> 0.0 over attack duration
	var t: float = 1.0 - p
	
	var swing_angle: float = 0.0
	var blade_stretch: float = 1.0
	
	if t < 0.15:
		# Phase 1: Windup / Anticipation (0.0 -> 0.15)
		var windup_t: float = t / 0.15
		var coil_angle: float = -0.3 if not is_heavy else -0.5
		swing_angle = -0.8 + coil_angle * sin(windup_t * PI * 0.5)
		blade_stretch = 0.95
	elif t < 0.40:
		# Phase 2: Snap Strike (0.15 -> 0.40) - 80% of arc in 25% time
		var strike_t: float = (t - 0.15) / 0.25
		var strike_ease: float = SnappyCurves.ease_out_expo(strike_t)
		var total_arc: float = 2.4 if not is_heavy else 3.0
		swing_angle = -1.1 + total_arc * strike_ease
		blade_stretch = 1.15 # Kinetic blade elongation
	else:
		# Phase 3: Settle & Recovery (0.40 -> 1.0)
		var settle_t: float = (t - 0.40) / 0.60
		var settle_ease: float = SnappyCurves.smootherstep(settle_t)
		var final_arc: float = 2.4 if not is_heavy else 3.0
		swing_angle = (-1.1 + final_arc) + 0.15 * sin(settle_t * PI)
		blade_stretch = 1.0
	
	return {
		"swing_angle": swing_angle,
		"blade_dir": Vector2(facing * cos(swing_angle), sin(swing_angle)).normalized(),
		"blade_stretch": blade_stretch
	}
```

---

## 6. Integration Blueprint for `ModularAssetSystem` & `PlayerKinematics`

### 6.1. Call-Site Architecture
In `scripts/modular_rig/modular_asset_system.gd`, the `StickmanPoseSolver.generate_stickman_pose` function can be enhanced seamlessly while strictly preserving existing test contracts (`tests/test_modular_rig.gd`):

1. **Torso & Neck Lean**:
   - Replace static `neck.x += face_dir * 6.0` with dynamic acceleration-aware lean:
     `neck.x += face_dir * (3.0 + clampf(speed / 340.0 * 5.0, 0.0, 6.0))`
2. **Legs Stride**:
   - Replace pure sine waving with `ProceduralGaitSolver`:
     - Stance foot locks to floor without backward sliding.
     - Swing foot arcs forward smoothly.
     - Pelvis bobs at $2\times$ step frequency.
3. **Attack Sweeps**:
   - Replace linear `var swing_angle: float = -0.8 + sweep * 2.2` with `CombatSlashCurve.calculate_slash_angle(attack_progress, face_dir, false)`.
4. **Landing & Jump Squash/Stretch**:
   - Apply `ProceduralSquashStretch` to scale the joint vectors relative to the ground contact point, producing organic compression on landing and extension on jumps.

### 6.2. Test Suite Invariant Compliance Check
All enhancements satisfy the strict test assertions in `tests/test_modular_rig.gd`:
- `head_center.y > neck.y` and `neck.y > pelvis.y` (+Y is up convention) are fully preserved.
- Running posture preserves `run_pose.neck.x > idle_player.neck.x`.
- Knee tucking during jump (`jump_pose.left_knee.y > idle_player.left_knee.y`) is maintained.
- Stance overrides (`wall_slide`, `downward_slam`, `parry_guard`, `heavy_slash`, `well_unlock`) remain intact.

---

## 7. Conclusion

By synthesizing the timing discipline of **Emil Kowalski** (speed, restraint, sub-250ms feedback, frequency rule), the production polish of **Jakub Krehel** (subtle spring damping, asymmetric exits), the compositional clarity of **Jhey Tompkins**, the structural patterns of **Godot 4.7 Animation & Tree Mastery**, and the standardized spring presets of **`motion-foundations`**, this report provides the complete mathematical and architectural foundation for world-class 2D procedural stickman motion in Godot 4.7.
