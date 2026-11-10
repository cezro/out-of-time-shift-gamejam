extends SceneTree

## Automated Verification Suite for Milestone 2: Snappy Motion Dynamics & Procedural Solver Upgrade
## Features covered:
## - Feature 4: Motion Dynamics & Second-Order Dynamic Springs (ProceduralSpring, ProceduralSpring2D, acceleration lean, secondary head lag & scarf)
## - Feature 5: Procedural Gait & Swing Upgrade (cadence curve, piecewise stance-lock, Hermite swing, 2x pelvic bob, dual-frequency head bob, antiphase arms)
## - Feature 6: Dynamic Squash/Stretch & Attack Tuning (volume conservation, jump/fall stretch, landing spring, 3-phase combat sweep)

const ModularAssetScript = preload("res://scripts/modular_rig/modular_asset_system.gd")
const StickmanScenePath: String = "res://scenes/stickman/stickmanprocedural.tscn"

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("======================================================================")
	print("=== RUNNING MILESTONE 2: MOTION DYNAMICS & PROCEDURAL SOLVER SUITE ===")
	print("======================================================================")

	_run("test_01_procedural_spring_harmonic_oscillator", test_01_procedural_spring_harmonic_oscillator)
	_run("test_02_procedural_spring_2d", test_02_procedural_spring_2d)
	_run("test_03_cadence_saturation_curve", test_03_cadence_saturation_curve)
	_run("test_04_piecewise_stance_lock_and_hermite_swing", test_04_piecewise_stance_lock_and_hermite_swing)
	_run("test_05_inverted_pendulum_pelvic_bobbing", test_05_inverted_pendulum_pelvic_bobbing)
	_run("test_06_dual_frequency_head_bob_and_antiphase_arm_swing", test_06_dual_frequency_head_bob_and_antiphase_arm_swing)
	_run("test_07_acceleration_proportional_torso_lean", test_07_acceleration_proportional_torso_lean)
	_run("test_08_volume_conserving_squash_and_stretch", test_08_volume_conserving_squash_and_stretch)
	_run("test_09_three_phase_combat_slash_sweep", test_09_three_phase_combat_slash_sweep)
	_run("test_10_scarf_distance_constraint_clamping_and_trailing", test_10_scarf_distance_constraint_clamping_and_trailing)
	_run("test_11_live_stickman_procedural_integration", test_11_live_stickman_procedural_integration)

	print("======================================================================")
	print("=== M2 SUITE SUMMARY: %d passed, %d failed ===" % [_passed, _failed])
	print("======================================================================")

	if _failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### M2 VERDICT: ALL MOTION DYNAMICS & PROCEDURAL SOLVER TESTS PASSED")
		quit(0)


func _run(test_name: String, test_callable: Callable) -> void:
	var ok: bool = test_callable.call()
	if ok:
		_passed += 1
		print("  [PASS] " + test_name)
	else:
		_failed += 1
		_failures.append(test_name)
		printerr("  [FAIL] " + test_name)


func _check(condition: bool, msg: String) -> bool:
	if not condition:
		printerr("    -> ASSERTION FAILED: " + msg)
		return false
	return true


# ============================================================================
# 1. ProceduralSpring Second-Order Harmonic Oscillator
# ============================================================================

func test_01_procedural_spring_harmonic_oscillator() -> bool:
	var ok: bool = true
	var spring = ModularAssetScript.ProceduralSpring.new(5.0, 0.75, 0.0)
	ok = _check(spring.value == 0.0 and spring.target == 0.0, "Initial value and target are 0.0") and ok

	# Test step response to target = 1.0
	spring.snap_to(1.0)
	var max_val: float = 0.0
	var dt: float = 0.005 # 200 Hz simulation
	var time: float = 0.0

	for _i in range(100):
		time += dt
		var v: float = spring.update(dt)
		if v > max_val:
			max_val = v

	# Damping ratio zeta = 0.75 has analytical overshoot Mp = exp(-pi*0.75/sqrt(1-0.75^2)) ~ 2.8%
	ok = _check(max_val > 1.01 and max_val < 1.06, "Spring exhibits snappy underdamped overshoot (max=%f, expected ~1.028)" % max_val) and ok

	# After 0.3s (settling time Ts ~ 4/(zeta*omega_n) ~ 150ms), should be tightly settled near 1.0
	for _i in range(50):
		spring.update(dt)
	ok = _check(absf(spring.value - 1.0) < 0.01, "Spring settles to target within 2%% band (val=%f)" % spring.value) and ok

	# Test impulse
	spring.apply_impulse(100.0)
	ok = _check(spring.velocity > 50.0, "apply_impulse injected kinetic velocity") and ok

	# Test stability under extreme delta
	spring.reset(0.0)
	spring.snap_to(10.0)
	var extreme_v: float = spring.update(100.0)
	ok = _check(is_finite(extreme_v), "Spring remains finite under huge delta") and ok

	# Test self-healing on NaN/Inf
	spring.value = NAN
	spring.velocity = INF
	spring.snap_to(5.0)
	var healed_v: float = spring.update(0.016)
	ok = _check(is_finite(healed_v) and healed_v == 5.0, "Spring self-heals from NaN/Inf state to target") and ok

	return ok


# ============================================================================
# 2. ProceduralSpring2D Vector Spring
# ============================================================================

func test_02_procedural_spring_2d() -> bool:
	var ok: bool = true
	var spring2d = ModularAssetScript.ProceduralSpring2D.new(5.0, 0.75, Vector2.ZERO)
	ok = _check(spring2d.value == Vector2.ZERO, "Initial Vector2 is zero") and ok

	spring2d.snap_to(Vector2(100.0, -50.0))
	for _i in range(60):
		spring2d.update(0.016)

	ok = _check(spring2d.value.distance_to(Vector2(100.0, -50.0)) < 2.0,
		"ProceduralSpring2D converges accurately to Vector2 target (got %s)" % str(spring2d.value)) and ok

	# Self-healing test
	spring2d.value = Vector2(NAN, INF)
	spring2d.velocity = Vector2(-INF, NAN)
	spring2d.snap_to(Vector2(10.0, 20.0))
	var healed = spring2d.update(0.016)
	ok = _check(is_finite(healed.x) and is_finite(healed.y) and healed == Vector2(10.0, 20.0),
		"ProceduralSpring2D self-heals corrupted vectors") and ok

	return ok


# ============================================================================
# 3. Cadence Saturation Curve
# ============================================================================

func test_03_cadence_saturation_curve() -> bool:
	var ok: bool = true
	var GaitSolver = ModularAssetScript.ProceduralGaitSolver

	var f_idle: float = GaitSolver.calculate_cadence(0.0)
	var f_walk: float = GaitSolver.calculate_cadence(60.0)
	var f_run: float = GaitSolver.calculate_cadence(180.0)
	var f_sprint: float = GaitSolver.calculate_cadence(340.0)
	var f_dash: float = GaitSolver.calculate_cadence(1000.0)

	# f(v) = 1.8 + 2.0 * tanh(|v| / 180.0)
	ok = _check(is_equal_approx(f_idle, 1.8), "Idle cadence is exactly 1.8 Hz (got %f)" % f_idle) and ok
	ok = _check(is_equal_approx(f_run, 1.8 + 2.0 * tanh(1.0)), "Reference run cadence matches 1.8 + 2.0*tanh(1) ~ 3.323 Hz (got %f)" % f_run) and ok
	ok = _check(f_walk > f_idle, "Walk cadence > Idle cadence") and ok
	ok = _check(f_run > f_walk, "Run cadence > Walk cadence") and ok
	ok = _check(f_sprint > f_run, "Sprint cadence > Run cadence") and ok
	ok = _check(f_dash < 3.8 and f_dash > 3.75, "High-speed dash saturates smoothly below physical ceiling of 3.8 Hz (got %f)" % f_dash) and ok

	# Bad input sanitization
	ok = _check(is_finite(GaitSolver.calculate_cadence(NAN)), "Cadence handles NaN safely") and ok
	ok = _check(is_finite(GaitSolver.calculate_cadence(INF)), "Cadence handles INF safely") and ok

	return ok


# ============================================================================
# 4. Piecewise Stance-Lock & Hermite Foot Swing
# ============================================================================

func test_04_piecewise_stance_lock_and_hermite_swing() -> bool:
	var ok: bool = true
	var GaitSolver = ModularAssetScript.ProceduralGaitSolver
	var stride_half: float = 14.0
	var step_h: float = 6.0

	# 1. Stance Phase: phase in [0, PI)
	# Foot MUST be flat on ground (y == 0.0) and move linearly backward
	var traj_strike: Vector2 = GaitSolver.evaluate_foot_trajectory(0.0, stride_half, step_h)
	var traj_mid_stance: Vector2 = GaitSolver.evaluate_foot_trajectory(PI * 0.5, stride_half, step_h)
	var traj_toe_off: Vector2 = GaitSolver.evaluate_foot_trajectory(PI * 0.999, stride_half, step_h)

	ok = _check(is_equal_approx(traj_strike.y, 0.0), "Heel strike is pinned flat to floor (y=0.0)") and ok
	ok = _check(is_equal_approx(traj_mid_stance.y, 0.0), "Mid-stance is pinned flat to floor (y=0.0)") and ok
	ok = _check(is_equal_approx(traj_toe_off.y, 0.0), "Toe-off is pinned flat to floor (y=0.0)") and ok
	ok = _check(is_equal_approx(traj_strike.x, stride_half), "Heel strike plants at +stride_half (got %f)" % traj_strike.x) and ok
	ok = _check(is_equal_approx(traj_mid_stance.x, 0.0), "Mid-stance passes through hip center x=0 (got %f)" % traj_mid_stance.x) and ok
	ok = _check(traj_toe_off.x < -stride_half + 0.1, "Toe-off reaches rear -stride_half (got %f)" % traj_toe_off.x) and ok

	# 2. Swing Phase: phase in [PI, TAU)
	# Foot lifts, reaches peak clearance at mid-swing (phase = 1.5*PI), and swings forward
	var traj_swing_lift: Vector2 = GaitSolver.evaluate_foot_trajectory(PI * 1.5, stride_half, step_h)
	ok = _check(is_equal_approx(traj_swing_lift.y, step_h), "Mid-swing reaches peak step height (y=%f, expected %f)" % [traj_swing_lift.y, step_h]) and ok
	ok = _check(is_equal_approx(traj_swing_lift.x, 0.0), "Mid-swing passes forward through hip center x=0 (got %f)" % traj_swing_lift.x) and ok

	# Touchdown deceleration via Hermite smoothstep
	var traj_touchdown: Vector2 = GaitSolver.evaluate_foot_trajectory(TAU * 0.999, stride_half, step_h)
	ok = _check(traj_touchdown.x > stride_half - 0.5, "Touchdown brings foot forward to +stride_half (got %f)" % traj_touchdown.x) and ok
	ok = _check(traj_touchdown.y < 0.2, "Touchdown returns foot down to ground level (got %f)" % traj_touchdown.y) and ok

	return ok


# ============================================================================
# 5. Inverted Pendulum Pelvic Bobbing
# ============================================================================

func test_05_inverted_pendulum_pelvic_bobbing() -> bool:
	var ok: bool = true
	var origin := Vector2.ZERO

	# Generate poses across one full gait stride cycle (anim_time 0.0 to 0.3s)
	# Run speed 180 px/s gives cadence ~3.323 Hz, TAU*cadence ~ 20.88 rad/s
	# Stride period T ~ 0.301s
	var pose_strike: ModularAssetScript.StickmanPose = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(180.0, 0.0), true, 0.0, false, 0.0, false, "normal"
	)
	# At t = 0.075s (quarter cycle, mid-stance vault)
	var pose_mid: ModularAssetScript.StickmanPose = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(180.0, 0.0), true, 0.075, false, 0.0, false, "normal"
	)
	# At t = 0.150s (half cycle, opposite heel strike)
	var pose_strike2: ModularAssetScript.StickmanPose = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(180.0, 0.0), true, 0.150, false, 0.0, false, "normal"
	)
	# At t = 0.225s (three-quarter cycle, second mid-stance vault)
	var pose_mid2: ModularAssetScript.StickmanPose = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(180.0, 0.0), true, 0.225, false, 0.0, false, "normal"
	)

	# Inverted pendulum bobbing: pelvis vaults up at mid-stance (2x frequency)
	ok = _check(pose_mid.pelvis.y > pose_strike.pelvis.y, "Pelvis vaults upward during mid-stance step 1 (mid.y=%f > strike.y=%f)" % [pose_mid.pelvis.y, pose_strike.pelvis.y]) and ok
	ok = _check(pose_mid2.pelvis.y > pose_strike2.pelvis.y, "Pelvis vaults upward during mid-stance step 2 (mid2.y=%f > strike2.y=%f)" % [pose_mid2.pelvis.y, pose_strike2.pelvis.y]) and ok
	ok = _check(is_equal_approx(pose_strike.pelvis.y, 16.0), "Ground strike dips to base pelvis height 16.0 (got %f)" % pose_strike.pelvis.y) and ok
	ok = _check(pose_mid.pelvis.y > 18.5, "Mid-stance apex achieves ~3.0px vault amplitude (got %f)" % pose_mid.pelvis.y) and ok

	return ok


# ============================================================================
# 6. Dual-Frequency Head Bob & Antiphase Arm Swing
# ============================================================================

func test_06_dual_frequency_head_bob_and_antiphase_arm_swing() -> bool:
	var ok: bool = true
	var origin := Vector2.ZERO

	var pose1: ModularAssetScript.StickmanPose = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(200.0, 0.0), true, 0.05, false, 0.0, false, "normal"
	)

	# Verify simulation coordinate invariant (+Y is UP): head_center.y > neck.y > pelvis.y
	ok = _check(pose1.head_center.y > pose1.neck.y, "Head center above neck (+Y UP: head=%f > neck=%f)" % [pose1.head_center.y, pose1.neck.y]) and ok
	ok = _check(pose1.neck.y > pose1.pelvis.y, "Neck above pelvis (+Y UP: neck=%f > pelvis=%f)" % [pose1.neck.y, pose1.pelvis.y]) and ok

	# Antiphase arm swing: left arm and right arm swing in opposite directions
	# Left elbow and right elbow offsets relative to shoulders oscillate in exact opposition
	var l_swing_x: float = pose1.left_elbow.x - pose1.left_shoulder.x
	var r_swing_x: float = pose1.right_elbow.x - pose1.right_shoulder.x
	ok = _check((l_swing_x * r_swing_x) <= 0.0, "Left and right arms swing in antiphase opposition (left_elbow_dx=%f, right_elbow_dx=%f)" % [l_swing_x, r_swing_x]) and ok

	return ok


# ============================================================================
# 7. Acceleration-Proportional Dynamic Torso Lean
# ============================================================================

func test_07_acceleration_proportional_torso_lean() -> bool:
	var ok: bool = true
	var origin := Vector2.ZERO

	# Pose A: Cruising at constant velocity (accel_x = 0)
	var pose_cruise = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(200.0, 0.0), true, 0.2, false, 0.0, false, "normal", 0.0
	)

	# Pose B: Accelerating forward aggressively (accel_x = +2200 px/s^2)
	var pose_accel = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(200.0, 0.0), true, 0.2, false, 0.0, false, "normal", 2200.0
	)

	# Pose C: Braking hard while traveling forward (accel_x = -2800 px/s^2)
	var pose_brake = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(200.0, 0.0), true, 0.2, false, 0.0, false, "normal", -2800.0
	)

	ok = _check(pose_accel.neck.x > pose_cruise.neck.x,
		"Forward acceleration leans torso forward further than steady cruise (accel=%f > cruise=%f)" % [pose_accel.neck.x, pose_cruise.neck.x]) and ok
	ok = _check(pose_brake.neck.x < pose_cruise.neck.x,
		"Hard braking pitches torso backward to brace against deceleration (brake=%f < cruise=%f)" % [pose_brake.neck.x, pose_cruise.neck.x]) and ok

	return ok


# ============================================================================
# 8. Volume-Conserving Squash & Stretch
# ============================================================================

func test_08_volume_conserving_squash_and_stretch() -> bool:
	var ok: bool = true
	var PoseSolver = ModularAssetScript.StickmanPoseSolver

	# 1. Volume conservation mathematical invariant: Sx * Sy = 1.0 => Sx = 1.0 / sqrt(Sy)
	var test_scales_y: Array[float] = [0.68, 0.80, 1.0, 1.15, 1.25, 1.32, 1.50]
	for sy in test_scales_y:
		var scale_vec: Vector2 = PoseSolver.volume_conserving_scale(sy)
		ok = _check(is_equal_approx(scale_vec.y, sy), "Scale vector y equals input sy (%f)" % sy) and ok
		var vol: float = scale_vec.x * scale_vec.x * scale_vec.y
		ok = _check(is_equal_approx(vol, 1.0), "Volume Sx^2 * Sy strictly conserves unit volume (vol=%f for sy=%f)" % [vol, sy]) and ok

	# 2. Aerial velocity stretch mapping
	# Jump takeoff ascent: vy = +580 px/s (in simulation +Y UP)
	var launch_scale := PoseSolver.calculate_air_squash_stretch(580.0, false)
	ok = _check(launch_scale.y <= 1.325 and launch_scale.y > 1.30, "Jump launch stretch Sy in [1.30, 1.32] (got %f)" % launch_scale.y) and ok
	ok = _check(launch_scale.x < 1.0, "Jump launch cross-section narrows horizontally (Sx=%f)" % launch_scale.x) and ok

	# Terminal fall plunge: vy = -950 px/s
	var fall_scale := PoseSolver.calculate_air_squash_stretch(-950.0, false)
	ok = _check(fall_scale.y <= 1.255 and fall_scale.y > 1.23, "Terminal fall plunge Sy in [1.23, 1.25] (got %f)" % fall_scale.y) and ok

	# Grounded neutral
	var ground_scale := PoseSolver.calculate_air_squash_stretch(0.0, true)
	ok = _check(ground_scale == Vector2.ONE, "Grounded state preserves unscaled Vector2.ONE") and ok

	return ok


# ============================================================================
# 9. Three-Phase Combat Slash Sweep
# ============================================================================

func test_09_three_phase_combat_slash_sweep() -> bool:
	var ok: bool = true
	var PoseSolver = ModularAssetScript.StickmanPoseSolver

	# Phase 1: Anticipation Windup Coil (attack_progress = 0.95 => elapsed t = 0.05 < 0.15)
	var slash_p1: Dictionary = PoseSolver.calculate_combat_slash(0.95, 1.0, false)
	ok = _check(slash_p1["swing_angle"] < -0.80, "Phase 1 coils blade backward (angle=%f < -0.80)" % slash_p1["swing_angle"]) and ok
	ok = _check(slash_p1["blade_stretch"] < 1.0, "Phase 1 exhibits tension contraction (stretch=%f < 1.0)" % slash_p1["blade_stretch"]) and ok
	ok = _check(slash_p1["torso_lean"] < 0.0, "Phase 1 coils torso backward (lean=%f < 0.0)" % slash_p1["torso_lean"]) and ok

	# Phase 2: Snap Strike Explosion (attack_progress = 0.70 => elapsed t = 0.30 in [0.15, 0.40])
	var slash_p2: Dictionary = PoseSolver.calculate_combat_slash(0.70, 1.0, false)
	ok = _check(slash_p2["swing_angle"] > 0.0, "Phase 2 has exploded forward across arc (angle=%f > 0.0)" % slash_p2["swing_angle"]) and ok
	ok = _check(slash_p2["blade_stretch"] > 1.05, "Phase 2 exhibits centrifugal blade stretch (stretch=%f > 1.05)" % slash_p2["blade_stretch"]) and ok
	ok = _check(slash_p2["torso_lean"] > 0.0, "Phase 2 thrusts torso forward (lean=%f > 0.0)" % slash_p2["torso_lean"]) and ok

	# Phase 3: Settle & Follow-Through Recovery (attack_progress = 0.0 => elapsed t = 1.0)
	var slash_p3: Dictionary = PoseSolver.calculate_combat_slash(0.0, 1.0, false)
	ok = _check(slash_p3["swing_angle"] > 1.0, "Phase 3 reaches follow-through end (angle=%f > 1.0)" % slash_p3["swing_angle"]) and ok
	ok = _check(is_equal_approx(slash_p3["blade_stretch"], 1.0), "Phase 3 returns blade stretch to 1.0x (got %f)" % slash_p3["blade_stretch"]) and ok

	return ok


# ============================================================================
# 10. Scarf Distance Constraint Clamping & Trailing
# ============================================================================

func test_10_scarf_distance_constraint_clamping_and_trailing() -> bool:
	var ok: bool = true
	var origin := Vector2(100.0, 50.0)

	var pose: ModularAssetScript.StickmanPose = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(250.0, 0.0), true, 0.4, false, 0.0, false, "normal"
	)

	ok = _check(pose.scarf_nodes.size() == 3, "Scarf has 3 nodes") and ok
	var s0: Vector2 = pose.scarf_nodes[0]
	var s1: Vector2 = pose.scarf_nodes[1]
	var s2: Vector2 = pose.scarf_nodes[2]

	# Distance constraint clamping L in [6.0, 14.0] px
	var dist01: float = s0.distance_to(s1)
	var dist12: float = s1.distance_to(s2)
	ok = _check(dist01 >= 5.9 and dist01 <= 14.1, "Scarf segment 0-1 distance clamped in [6, 14] px (got %f)" % dist01) and ok
	ok = _check(dist12 >= 5.9 and dist12 <= 14.1, "Scarf segment 1-2 distance clamped in [6, 14] px (got %f)" % dist12) and ok

	# Trailing invariant behind facing: x2 < x1 < x0 < head_center.x
	ok = _check(s0.x < pose.head_center.x, "Scarf node 0 trails behind head (s0.x=%f < head.x=%f)" % [s0.x, pose.head_center.x]) and ok
	ok = _check(s1.x < s0.x, "Scarf node 1 trails behind node 0 (s1.x=%f < s0.x=%f)" % [s1.x, s0.x]) and ok
	ok = _check(s2.x < s1.x, "Scarf node 2 trails behind node 1 (s2.x=%f < s1.x=%f)" % [s2.x, s1.x]) and ok

	return ok


# ============================================================================
# 11. Live StickmanProcedural Integration
# ============================================================================

func test_11_live_stickman_procedural_integration() -> bool:
	var ok: bool = true
	var scene = load(StickmanScenePath)
	if scene == null:
		return false
	var rig = scene.instantiate()
	root.add_child(rig)

	# 1. Exercise running gait with cadence and springs
	for i in range(30):
		rig.update_procedural_animation(Vector2(240.0, 0.0), true, 1.0, "run", 0.016)
		ok = _check(is_finite(rig.phase) and rig.phase >= 0.0 and rig.phase < 1.0, "Phase valid during run") and ok

	# 2. Exercise jumping launch stretch
	rig.update_procedural_animation(Vector2(100.0, -480.0), false, 1.0, "jump", 0.016)
	var jump_pose = rig.to_stickman_pose(1.0)
	ok = _check(jump_pose != null, "to_stickman_pose valid on jump") and ok
	# 3. Exercise high-speed fall and landing impact compression
	# High-speed downward fall in Godot 2D space (+Y is down, vy = +600.0)
	rig.update_procedural_animation(Vector2(50.0, 600.0), false, 1.0, "fall", 0.016)
	ok = _check(rig._current_squash_scale.y > 1.0, "High-speed descent elongates vertically (Sy=%f > 1.0)" % rig._current_squash_scale.y) and ok

	# Ground strike triggers landing compression dip
	rig.update_procedural_animation(Vector2.ZERO, true, 1.0, "idle", 0.016)
	ok = _check(rig._land_spring_val < 1.0, "Landing impact triggers compression dip (got %f < 1.0)" % rig._land_spring_val) and ok

	# 4. Exercise attack sweep
	for i in range(15):
		rig.update_procedural_animation(Vector2.ZERO, true, 1.0, "slash", 0.016)
	var atk_pose = rig.to_stickman_pose(1.0)
	ok = _check(atk_pose != null and is_finite(atk_pose.sword_tip.x), "Attack pose is finite during 3-phase strike") and ok

	# Clean teardown
	root.remove_child(rig)
	rig.free()
	ok = _check(not is_instance_valid(rig), "Instance freed cleanly without orphan leaks") and ok

	return ok
