class_name StickmanProcedural
extends CharacterBody2D

## Procedural 2D Stickman Character Controller & IK Rig
## Combines 2D Skeletal Inverse Kinematics (CCDIK + LookAt) with a distance-driven mathematical gait.
## Integrates with ModularAssetSystem and game entities in new-game-project.

@export_group("Control Mode")
## If true, reads Input and executes physics movement autonomously (e.g. standalone showcase).
## If false (default for entities/PACKED_SCENE), driven externally via update_procedural_animation.
@export var autonomous_physics: bool = false

@export_group("Movement")
@export var move_speed: float = 260.0
@export var acceleration: float = 1400.0
@export var deceleration: float = 1800.0
@export var gravity: float = 1400.0
@export var jump_velocity: float = -480.0
@export var maximum_fall_speed: float = 900.0

@export_group("Running Animation")
@export var stride_length: float = 52.0
@export var foot_lift: float = 6.0
@export var arm_swing: float = 24.0
@export var hand_lift: float = 6.0
@export var head_bounce: float = 2.5
@export var head_lean: float = 9.0
@export var snappiness: float = 18.0

@export_group("Dynamic Squash & Stretch")
@export var squash_stretch_enabled: bool = true
@export var landing_spring_frequency: float = 6.5
@export var landing_spring_damping: float = 0.72
@export var max_jump_stretch: float = 1.32
@export var max_fall_stretch: float = 1.25
@export var max_landing_squash: float = 0.68

@export_group("Air Animation")
@export var air_foot_spread: float = 14.0
@export var air_foot_lift: float = 12.0
@export var air_hand_lift: float = 18.0

# ----------------------------------------------------------------------------
# Backward Compatibility Property Aliases
# ----------------------------------------------------------------------------

var hand_swing: float:
	get: return arm_swing
	set(v): arm_swing = v

var pose_response: float:
	get: return snappiness
	set(v): snappiness = v

# ----------------------------------------------------------------------------
# Node References
# ----------------------------------------------------------------------------

@onready var rig_node: Node2D = get_node_or_null("Rig")
@onready var ik_targets_node: Node2D = get_node_or_null("IK Targets")
@onready var skeleton: Skeleton2D = get_node_or_null("Rig/Bones/Skeleton2D")

@onready var foot_r: Node2D = get_node_or_null("IK Targets/FootR Target")
@onready var foot_l: Node2D = get_node_or_null("IK Targets/FootL Target")
@onready var arm_r: Node2D = get_node_or_null("IK Targets/ArmR Target")
@onready var arm_l: Node2D = get_node_or_null("IK Targets/ArmL Target")
@onready var head_target: Node2D = get_node_or_null("IK Targets/Head Target")

var targets: Array[Node2D] = []
var rest_positions: Dictionary = {}

var phase: float = 0.0
var facing: float = 1.0
var current_anim_state: String = "idle"

const HIP_REST_X: float = 284.51

# Motion dynamics & second-order spring states
var _land_spring_val: float = 1.0
var _land_spring_vel: float = 0.0
var _was_grounded_last: bool = true
var _last_vy: float = 0.0
var _current_squash_scale: Vector2 = Vector2.ONE

var _prev_velocity: Vector2 = Vector2.ZERO
var _current_accel_x: float = 0.0
var _torso_lean_spring = null
var _attack_timer: float = 0.0
var _attack_duration: float = 0.22
var rig_rest_position: Vector2 = Vector2(-284.0, -303.0)
var _rig_rest_initialized: bool = false


# ----------------------------------------------------------------------------
# Lifecycle
# ----------------------------------------------------------------------------

func _init_dynamics_springs() -> void:
	if _torso_lean_spring == null:
		var mas = load("res://scripts/modular_rig/modular_asset_system.gd")
		if mas != null and "ProceduralSpring" in mas:
			_torso_lean_spring = mas.ProceduralSpring.new(4.5, 0.80, 0.0)


func _ensure_references() -> void:
	if rig_node == null:
		rig_node = get_node_or_null("Rig")
	if rig_node != null and not _rig_rest_initialized:
		rig_rest_position = rig_node.position
		_rig_rest_initialized = true
	_init_dynamics_springs()
	if ik_targets_node == null:
		ik_targets_node = get_node_or_null("IK Targets")
	if skeleton == null:
		skeleton = get_node_or_null("Rig/Bones/Skeleton2D")
	if foot_r == null:
		foot_r = get_node_or_null("IK Targets/FootR Target")
	if foot_l == null:
		foot_l = get_node_or_null("IK Targets/FootL Target")
	if arm_r == null:
		arm_r = get_node_or_null("IK Targets/ArmR Target")
	if arm_l == null:
		arm_l = get_node_or_null("IK Targets/ArmL Target")
	if head_target == null:
		head_target = get_node_or_null("IK Targets/Head Target")
	if targets.is_empty():
		for t in [foot_r, foot_l, arm_r, arm_l, head_target]:
			if t != null:
				targets.append(t)
				if not rest_positions.has(t):
					rest_positions[t] = t.position


func _ready() -> void:
	_ensure_references()
	floor_snap_length = 6.0

	# When externally controlled by game entities, autonomous physics is deactivated
	if not autonomous_physics:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not autonomous_physics:
		return

	var direction: float = get_move_input()

	if direction != 0.0:
		# BUG FIX: original code had 'facing - signf(direction)' which was a no-op
		facing = signf(direction)

	var target_velocity: float = direction * move_speed
	var rate: float = acceleration if direction != 0.0 else deceleration

	velocity.x = move_toward(velocity.x, target_velocity, rate * delta)

	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		if jump_pressed():
			velocity.y = jump_velocity
	else:
		velocity.y = minf(velocity.y + gravity * delta, maximum_fall_speed)

	var _previous_position: Vector2 = global_position
	move_and_slide()

	var is_grounded: bool = is_on_floor()
	var state: String = "run" if (is_grounded and absf(velocity.x) > 20.0) else ("air" if not is_grounded else "idle")

	update_procedural_animation(velocity, is_grounded, facing, state, delta)


func get_move_input() -> float:
	return Input.get_axis("ui_left", "ui_right")


func jump_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept")


# ----------------------------------------------------------------------------
# External Interface Methods
# ----------------------------------------------------------------------------

## Primary interface method: updates gait phase, target offsets, and IK lerping.
func update_procedural_animation(
	p_velocity: Vector2,
	is_on_ground: bool,
	facing_direction: float,
	current_state: String,
	delta: float
) -> void:
	_ensure_references()
	current_anim_state = current_state

	# Sanitize velocity and delta inputs against NaN/Inf
	var safe_vel: Vector2 = p_velocity if (is_finite(p_velocity.x) and is_finite(p_velocity.y)) else Vector2.ZERO
	var safe_delta: float = delta if (is_finite(delta) and delta >= 0.0) else 0.0

	# Track horizontal acceleration (ax = dvx / dt) for dynamic torso lean
	if safe_delta > 0.0001:
		_current_accel_x = clampf((safe_vel.x - _prev_velocity.x) / safe_delta, -3500.0, 3500.0)
	else:
		_current_accel_x = 0.0
	_prev_velocity = safe_vel

	# Update facing direction if valid and non-zero; preserve valid +/-1.0 invariant
	if not is_nan(facing_direction) and facing_direction != 0.0:
		facing = 1.0 if facing_direction > 0.0 else -1.0
	elif not is_finite(facing) or absf(facing) != 1.0:
		facing = 1.0

	# Guard against non-finite phase latching
	if not is_finite(phase):
		phase = 0.0

	var speed: float = absf(safe_vel.x)
	var speed_ratio: float = clampf(speed / maxf(move_speed, 1.0), 0.0, 1.0)

	# Accumulate gait phase based on cadence saturation curve to prevent foot-sliding
	if is_on_ground and speed > 5.0:
		var cadence_hz: float = 1.8 + 2.0 * tanh(speed / 180.0)
		phase = fposmod(phase + cadence_hz * safe_delta, 1.0)
		if not is_finite(phase):
			phase = 0.0
	elif is_on_ground and speed <= 5.0:
		# Gradually settle feet toward rest stance when stopped
		phase = move_toward(phase, 0.0, 4.0 * safe_delta)

	update_target_animation(safe_delta, speed_ratio, is_on_ground, safe_vel, current_state)


## Updates IK target positions by interpolating toward rest_position + computed offsets.
func update_target_animation(
	delta: float,
	speed_ratio: float,
	is_on_ground: bool = true,
	p_velocity: Vector2 = Vector2.ZERO,
	current_state: String = "idle"
) -> void:
	var safe_delta: float = delta if (is_finite(delta) and delta >= 0.0) else 0.0
	var safe_speed_ratio: float = clampf(speed_ratio, 0.0, 1.0) if is_finite(speed_ratio) else 0.0
	var safe_vel: Vector2 = p_velocity if (is_finite(p_velocity.x) and is_finite(p_velocity.y)) else Vector2.ZERO

	# Manage attack animation progress timer
	if current_state in ["slash", "heavy_slash"]:
		_attack_timer = minf(_attack_timer + safe_delta, _attack_duration)
	else:
		_attack_timer = 0.0

	# Update landing impact spring and aerial squash/stretch
	_current_squash_scale = _update_squash_stretch(safe_vel, is_on_ground, safe_delta)

	var offsets: Dictionary = {}

	# Default standing / resting pose
	for target in targets:
		offsets[target] = Vector2.ZERO

	if current_state == "downward_slam":
		apply_air_offsets(offsets, safe_vel)
		if arm_r != null and arm_l != null:
			offsets[arm_r] = Vector2(facing * 6.0, hand_lift * 2.5)
			offsets[arm_l] = Vector2(-facing * 4.0, hand_lift * 2.0)
	elif current_state in ["aim", "gunner_aim", "sniper_brace"]:
		apply_aim_offsets(offsets, current_state == "sniper_brace")
	elif current_state in ["hitstun", "juggled"]:
		apply_hitstun_offsets(offsets, current_state == "juggled")
	elif not is_on_ground or current_state in ["jump", "fall", "air"]:
		apply_air_offsets(offsets, safe_vel)
	elif current_state == "wall_slide":
		apply_wall_slide_offsets(offsets)
	elif current_state in ["slash", "heavy_slash"]:
		apply_attack_offsets(offsets, current_state)
	elif current_state == "parry_guard":
		apply_parry_offsets(offsets)
	elif safe_speed_ratio > 0.02 or current_state in ["run", "walk"]:
		apply_run_offsets(offsets, safe_speed_ratio)

	# Inverted pendulum pelvic bobbing on rig container (2x stride frequency)
	if rig_node != null:
		if is_on_ground and safe_speed_ratio > 0.02:
			var pelvic_bob: float = (0.5 - 0.5 * cos(phase * TAU * 2.0)) * 4.0 * safe_speed_ratio
			rig_node.position.y = rig_rest_position.y + pelvic_bob
		else:
			rig_node.position.y = move_toward(rig_node.position.y, rig_rest_position.y, 60.0 * safe_delta)

	var safe_snappiness: float = snappiness if (is_finite(snappiness) and snappiness >= 0.0) else 18.0
	var weight: float = clampf(1.0 - exp(-safe_snappiness * safe_delta), 0.0, 1.0) if safe_delta > 0.0 else 1.0
	if not is_finite(weight):
		weight = 1.0

	const FLOOR_Y: float = 628.0 # Standard floor level of IK targets
	var sx: float = _current_squash_scale.x
	var sy: float = _current_squash_scale.y

	for target in targets:
		if target == null:
			continue
		var base_rest: Vector2 = get_mirrored_rest_position(target, facing)
		var offset: Vector2 = offsets.get(target, Vector2.ZERO)
		if not is_finite(offset.x) or not is_finite(offset.y):
			offset = Vector2.ZERO

		# Compute raw target position
		var raw_target: Vector2 = base_rest + offset

		# Apply volume-preserving deformation anchored at (HIP_REST_X, FLOOR_Y)
		var deformed_target: Vector2
		if is_equal_approx(sy, 1.0) and is_equal_approx(sx, 1.0):
			deformed_target = raw_target
		else:
			var height_from_floor: float = FLOOR_Y - raw_target.y
			var scaled_y: float = FLOOR_Y - height_from_floor * sy
			var dx_from_hip: float = raw_target.x - HIP_REST_X
			var scaled_x: float = HIP_REST_X + dx_from_hip * sx
			deformed_target = Vector2(scaled_x, scaled_y)

		# Self-heal corrupted target position before lerp to break irreversible NaN latching
		if not is_finite(target.position.x) or not is_finite(target.position.y):
			target.position = deformed_target

		target.position = target.position.lerp(deformed_target, weight)


## Calculates volume-preserving squash/stretch scale vector (Sx * Sy = 1.0 => Sx = 1.0 / sqrt(Sy)).
func _update_squash_stretch(safe_vel: Vector2, is_on_ground: bool, dt: float) -> Vector2:
	if not squash_stretch_enabled:
		_land_spring_val = 1.0
		_land_spring_vel = 0.0
		_was_grounded_last = is_on_ground
		_last_vy = safe_vel.y
		return Vector2.ONE

	# In Godot 2D coordinates: +Y is DOWN (downward fall velocity is vy > 0)
	var downward_impact_speed: float = maxf(_last_vy, 0.0)
	if is_on_ground and not _was_grounded_last and downward_impact_speed > 100.0:
		var compression_ratio: float = clampf((downward_impact_speed - 100.0) / 1300.0, 0.0, 1.0) * (1.0 - max_landing_squash)
		_land_spring_vel -= compression_ratio * 45.0

	_was_grounded_last = is_on_ground
	_last_vy = safe_vel.y

	# Update landing spring (Semi-implicit Euler)
	var safe_dt: float = clampf(dt, 0.0, 0.033)
	if safe_dt > 0.0:
		var omega: float = TAU * landing_spring_frequency
		var omega_sq: float = omega * omega
		var damping_factor: float = 2.0 * landing_spring_damping * omega
		var accel: float = -omega_sq * (_land_spring_val - 1.0) - damping_factor * _land_spring_vel
		_land_spring_vel += accel * safe_dt
		_land_spring_val += _land_spring_vel * safe_dt
		_land_spring_val = clampf(_land_spring_val, 0.60, 1.40)

	var sy: float = _land_spring_val

	# Aerial velocity-driven elongation (when not on ground)
	if not is_on_ground:
		if safe_vel.y < -50.0:
			# Upward jump launch stretch (vy < -50 in Godot space)
			var stretch: float = clampf((absf(safe_vel.y) - 50.0) / 1656.25, 0.0, max_jump_stretch - 1.0)
			sy += stretch
		elif safe_vel.y > 150.0:
			# High-speed fall plunge elongation (vy > 150 in Godot space)
			var stretch: float = clampf((safe_vel.y - 150.0) / 3200.0, 0.0, max_fall_stretch - 1.0)
			sy += stretch

	var safe_sy: float = clampf(sy, 0.50, 2.0)
	var sx: float = 1.0 / sqrt(safe_sy)
	return Vector2(sx, safe_sy)


## Calculates mirrored rest position relative to the hip center (HIP_REST_X) to support facing flip.
func get_mirrored_rest_position(target: Node2D, cur_facing: float) -> Vector2:
	var base_rest: Vector2 = rest_positions.get(target, Vector2.ZERO)
	if not is_finite(base_rest.x) or not is_finite(base_rest.y):
		if target != null and is_finite(target.position.x) and is_finite(target.position.y):
			base_rest = target.position
		else:
			base_rest = Vector2(HIP_REST_X, 0.0)

	var safe_facing: float = cur_facing if is_finite(cur_facing) else 1.0
	if safe_facing >= 0.0:
		return base_rest
	var dx: float = base_rest.x - HIP_REST_X
	return Vector2(HIP_REST_X - dx, base_rest.y)


# ----------------------------------------------------------------------------
# Offset Solvers
# ----------------------------------------------------------------------------

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

	# Dynamic Torso Lean responding to velocity and horizontal acceleration
	var vel_ratio: float = clampf(cur_speed / maxf(move_speed, 1.0), 0.0, 1.0)
	var acc_ratio: float = clampf((_current_accel_x * facing) / maxf(acceleration, 1.0), -1.2, 1.2)
	var target_lean: float = (head_lean * vel_ratio) + (head_lean * 0.75 * acc_ratio)

	var live_lean: float = target_lean * facing
	if _torso_lean_spring != null:
		_torso_lean_spring.snap_to(target_lean * facing)
		live_lean = _torso_lean_spring.update(0.016)

	offsets[head_target] = Vector2(
		live_lean + sin(angle) * 1.5 * facing * speed_ratio,
		-vert_bounce + pitch_sway
	)


func get_foot_offset(cycle: float, stride_len: float = -1.0) -> Vector2:
	var safe_cycle: float = clampf(cycle, 0.0, 1.0) if is_finite(cycle) else 0.0
	var eff_stride: float = stride_len if (stride_len > 0.0 and is_finite(stride_len)) else stride_length
	var half_stride: float = maxf(0.0, eff_stride) * 0.5
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


func apply_air_offsets(offsets: Dictionary, p_velocity: Vector2 = Vector2.ZERO) -> void:
	if foot_r == null or foot_l == null or arm_r == null or arm_l == null or head_target == null:
		return

	var rising: bool = (p_velocity.y < 0.0) if p_velocity != Vector2.ZERO else (velocity.y < 0.0)
	var tuck: float = 1.0 if rising else 0.45

	offsets[foot_r] = Vector2(air_foot_spread * facing, -air_foot_lift * tuck)
	offsets[foot_l] = Vector2(-air_foot_spread * facing, -air_foot_lift * tuck * 0.5)
	offsets[arm_r] = Vector2(-arm_swing * facing * 0.3, -air_hand_lift)
	offsets[arm_l] = Vector2(arm_swing * facing * 0.3, -air_hand_lift * 0.8)
	offsets[head_target] = Vector2(head_lean * facing * 0.4, -2.0)


func apply_wall_slide_offsets(offsets: Dictionary) -> void:
	if foot_r == null or foot_l == null or arm_r == null or arm_l == null or head_target == null:
		return
	offsets[foot_r] = Vector2(-15.0 * facing, -air_foot_lift * 1.4)
	offsets[foot_l] = Vector2(10.0 * facing, 8.0)
	offsets[arm_r] = Vector2(20.0 * facing, -10.0)
	offsets[arm_l] = Vector2(25.0 * facing, -5.0)
	offsets[head_target] = Vector2(-head_lean * facing * 0.5, 0.0)


func apply_attack_offsets(offsets: Dictionary, stance: String) -> void:
	if arm_r == null or arm_l == null or head_target == null:
		return

	var t: float = clampf(_attack_timer / maxf(0.001, _attack_duration), 0.0, 1.0)
	var is_heavy: bool = (stance == "heavy_slash")
	var reach_mult: float = 1.6 if is_heavy else 1.2

	if t < 0.15:
		# Phase 1: Windup Coil (0% -> 15%)
		var tau1: float = t / 0.15
		var coil: float = sin(tau1 * PI * 0.5)
		offsets[arm_r] = Vector2(-arm_swing * facing * 0.4 * coil, hand_lift * 1.2 * coil)
		offsets[arm_l] = Vector2(arm_swing * facing * 0.2 * coil, hand_lift * 0.4)
		offsets[head_target] = Vector2(-head_lean * facing * 0.5 * coil, -1.0 * coil)
	elif t < 0.40:
		# Phase 2: Snap Strike Explosion (15% -> 40%) - Ease-out exponential
		var tau2: float = (t - 0.15) / 0.25
		var strike_ease: float = 1.0 - pow(2.0, -10.0 * tau2)
		var strike_reach: float = reach_mult * (1.0 + 0.15 * sin(tau2 * PI))
		offsets[arm_r] = Vector2(arm_swing * facing * strike_reach * strike_ease, -hand_lift * 2.2 * strike_ease)
		offsets[arm_l] = Vector2(-arm_swing * facing * 0.5 * strike_ease, -hand_lift * 0.8)
		offsets[head_target] = Vector2(head_lean * facing * 1.4 * strike_ease, 2.5 * strike_ease)
	else:
		# Phase 3: Settle & Follow-Through Recovery (40% -> 100%) - Smootherstep
		var tau3: float = (t - 0.40) / 0.60
		var settle: float = tau3 * tau3 * tau3 * (tau3 * (tau3 * 6.0 - 15.0) + 10.0)
		var recoil_x: float = lerpf(arm_swing * facing * reach_mult, arm_swing * facing * 0.8, settle)
		offsets[arm_r] = Vector2(recoil_x, -hand_lift * lerpf(2.2, 1.0, settle))
		offsets[arm_l] = Vector2(-arm_swing * facing * 0.3 * (1.0 - settle), -hand_lift * 0.5)
		offsets[head_target] = Vector2(head_lean * facing * lerpf(1.4, 0.4, settle), lerpf(2.5, 0.0, settle))


func apply_parry_offsets(offsets: Dictionary) -> void:
	if arm_r == null or arm_l == null or head_target == null:
		return
	offsets[arm_r] = Vector2(15.0 * facing, -hand_lift * 2.5)
	offsets[arm_l] = Vector2(10.0 * facing, -hand_lift * 2.2)
	offsets[head_target] = Vector2(-head_lean * facing * 0.3, 0.0)


func apply_aim_offsets(offsets: Dictionary, is_sniper: bool = false) -> void:
	if arm_r == null or arm_l == null:
		return
	var reach: float = 38.0 if is_sniper else 28.0
	offsets[arm_r] = Vector2(facing * reach, -hand_lift * 2.0)
	offsets[arm_l] = Vector2(facing * (reach * 0.8), -hand_lift * 1.8)
	if head_target != null:
		offsets[head_target] = Vector2(facing * (6.0 if is_sniper else 3.0), 2.0 if is_sniper else 0.0)


func apply_hitstun_offsets(offsets: Dictionary, is_juggled: bool = false) -> void:
	if arm_r == null or arm_l == null:
		return
	offsets[arm_r] = Vector2(-facing * 16.0, -hand_lift * 3.5)
	offsets[arm_l] = Vector2(-facing * 12.0, -hand_lift * 3.0)
	if head_target != null:
		offsets[head_target] = Vector2(-facing * head_lean * 1.5, -4.0)
	if is_juggled and foot_r != null and foot_l != null:
		offsets[foot_r] = Vector2(facing * 8.0, -air_foot_lift * 1.5)
		offsets[foot_l] = Vector2(-facing * 12.0, -air_foot_lift * 0.8)


func apply_archetype_configuration(
	_archetype_id: String,
	body_color: Color = Color.WHITE,
	scale_factor: float = 1.0
) -> void:
	_ensure_references()
	var body_node = get_node_or_null("Rig/Body")
	if body_node != null:
		body_node.modulate = body_color
	elif rig_node != null:
		rig_node.modulate = body_color
	else:
		modulate = body_color
	if is_finite(scale_factor) and scale_factor > 0.0:
		scale = Vector2(scale_factor, scale_factor)


# ----------------------------------------------------------------------------
# Bone / Joint & Target Retrieval Interface
# ----------------------------------------------------------------------------

## Returns dictionary mapping joint/bone names to 2D coordinates in character-local space.
func get_bone_positions() -> Dictionary:
	_ensure_references()
	var result: Dictionary = {}
	if skeleton == null:
		return result

	var bone_map: Dictionary = {
		"pelvis": "Hip",
		"hip": "Hip",
		"neck": "Hip/Waist/Torso/Neck",
		"head": "Hip/Waist/Torso/Neck/Head",
		"head_center": "Hip/Waist/Torso/Neck/Head",
		"torso": "Hip/Waist/Torso",
		"waist": "Hip/Waist",
		"left_shoulder": "Hip/ArmL",
		"left_elbow": "Hip/ArmL/ForearmL",
		"left_hand": "Hip/ArmL/ForearmL/HandL",
		"right_shoulder": "Hip/ArmR",
		"right_elbow": "Hip/ArmR/ForearmR",
		"right_hand": "Hip/ArmR/ForearmR/HandR",
		"left_hip": "Hip/LegL",
		"left_knee": "Hip/LegL/ShinL",
		"left_foot": "Hip/LegL/ShinL/FootL",
		"right_hip": "Hip/LegR",
		"right_knee": "Hip/LegR/ShinR",
		"right_foot": "Hip/LegR/ShinR/FootR",
	}

	for key in bone_map.keys():
		var b_path: String = bone_map[key]
		var b_node: Node2D = skeleton.get_node_or_null(b_path)
		if b_node != null:
			var local_pos: Vector2 = to_local(b_node.global_position)
			if is_finite(local_pos.x) and is_finite(local_pos.y):
				result[key] = local_pos
			else:
				result[key] = Vector2.ZERO

	return result


## Returns dictionary mapping target names to target Node2D references.
func get_ik_targets() -> Dictionary:
	_ensure_references()
	return {
		"foot_r": foot_r,
		"foot_l": foot_l,
		"arm_r": arm_r,
		"arm_l": arm_l,
		"head": head_target,
	}


## Converts character-local Godot 2D coordinates (+Y DOWN) to simulation coordinates (+Y UP).
## Preserves horizontal coordinates (X) exactly, inverting only the vertical component (Y).
static func _to_sim_coord(local_pos: Vector2) -> Vector2:
	var safe_x: float = local_pos.x if is_finite(local_pos.x) else 0.0
	var safe_y: float = local_pos.y if is_finite(local_pos.y) else 0.0
	return Vector2(safe_x, -safe_y)


## Constructs a ModularAssetSystem.StickmanPose populated from this rig's live bone positions.
## Transforms coordinates from Godot 2D character-local space (+Y DOWN) into simulation space (+Y UP).
func to_stickman_pose(loadout_facing: float = 1.0) -> RefCounted:
	var bones := get_bone_positions()
	var mas_script = load("res://scripts/modular_rig/modular_asset_system.gd")
	if mas_script == null:
		return null
	var pose_class = mas_script.StickmanPose
	var pose = pose_class.new()
	if bones.is_empty():
		return pose

	pose.head_center = _to_sim_coord(bones.get("head_center", Vector2.ZERO))
	pose.neck = _to_sim_coord(bones.get("neck", Vector2.ZERO))
	pose.pelvis = _to_sim_coord(bones.get("pelvis", Vector2.ZERO))
	pose.left_shoulder = _to_sim_coord(bones.get("left_shoulder", Vector2.ZERO))
	pose.left_elbow = _to_sim_coord(bones.get("left_elbow", Vector2.ZERO))
	pose.left_hand = _to_sim_coord(bones.get("left_hand", Vector2.ZERO))
	pose.right_shoulder = _to_sim_coord(bones.get("right_shoulder", Vector2.ZERO))
	pose.right_elbow = _to_sim_coord(bones.get("right_elbow", Vector2.ZERO))
	pose.right_hand = _to_sim_coord(bones.get("right_hand", Vector2.ZERO))
	pose.left_hip = _to_sim_coord(bones.get("left_hip", Vector2.ZERO))
	pose.left_knee = _to_sim_coord(bones.get("left_knee", Vector2.ZERO))
	pose.left_foot = _to_sim_coord(bones.get("left_foot", Vector2.ZERO))
	pose.right_hip = _to_sim_coord(bones.get("right_hip", Vector2.ZERO))
	pose.right_knee = _to_sim_coord(bones.get("right_knee", Vector2.ZERO))
	pose.right_foot = _to_sim_coord(bones.get("right_foot", Vector2.ZERO))
	pose.stance = current_anim_state

	var eff_facing: float = facing if (is_finite(facing) and facing != 0.0) else (
		loadout_facing if (is_finite(loadout_facing) and loadout_facing != 0.0) else 1.0
	)
	var face_dir: float = 1.0 if eff_facing >= 0.0 else -1.0

	pose.sword_hilt = pose.right_hand
	pose.sword_tip = pose.right_hand + Vector2(face_dir * 28.0, -14.0)

	var head_back: Vector2 = pose.head_center + Vector2(-face_dir * pose.head_radius, 0.0)
	var nodes: Array[Vector2] = [
		head_back + Vector2(-face_dir * 8.0, 1.0),
		head_back + Vector2(-face_dir * 18.0, -1.0),
		head_back + Vector2(-face_dir * 28.0, -4.0),
	]
	pose.scarf_nodes = nodes

	return pose
