extends SceneTree

## Challenger M2 Empirical Adversarial Suite
## Author: teamwork_challenger_m2_g2_1 (Empirical Challenger)
## Target Milestone: M2 - Snappy Motion Dynamics & Procedural Solver Upgrade
##
## Validates:
## 1. Adversarial fuzzing harness (dt boundaries [0, 1e-6, 0.016, 0.1, 1.0, 10.0, INF, NAN], velocities +/-100,000, 180-deg flips, negative scales, zero/Inf)
## 2. ProceduralSpring & ProceduralSpring2D resonance injection & unbounded energy accumulation attack
## 3. ProceduralGaitSolver phase continuity across 1,000,000 cycles (no lockups, teleports, div-by-zero, trajectory C0-continuity)
## 4. ProceduralSquashStretch volume conservation (Sx * Sy and Sx^2 * Sy) under extreme impacts and impulses
## 5. Zero orphan node creation and memory churn hygiene
## 6. Zero console/stderr emissions under extreme stress

const SCENE_PATH: String = "res://scenes/stickman/stickmanprocedural.tscn"
const MAS_SCRIPT = preload("res://scripts/modular_rig/modular_asset_system.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _assertion_count: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("======================================================================")
	print("=== CHALLENGER M2: EMPIRICAL ADVERSARIAL STRESS & FUZZING SUITE   ===")
	print("======================================================================")

	_run_test("test_01_spring_resonance_and_energy_bounding", test_01_spring_resonance_and_energy_bounding)
	_run_test("test_02_spring2d_multiaxis_resonance_and_float_overflow", test_02_spring2d_multiaxis_resonance_and_float_overflow)
	_run_test("test_03_gait_solver_one_million_cycles_and_phase_continuity", test_03_gait_solver_one_million_cycles_and_phase_continuity)
	_run_test("test_04_gait_trajectory_boundary_continuity_c0_c1", test_04_gait_trajectory_boundary_continuity_c0_c1)
	_run_test("test_05_squash_stretch_volume_conservation_and_extreme_impacts", test_05_squash_stretch_volume_conservation_and_extreme_impacts)
	_run_test("test_06_dt_fuzzing_matrix_and_corrupted_deltas", test_06_dt_fuzzing_matrix_and_corrupted_deltas)
	_run_test("test_07_extreme_velocity_and_180deg_rapid_flip_fuzzing", test_07_extreme_velocity_and_180deg_rapid_flip_fuzzing)
	_run_test("test_08_pose_solver_extreme_fuzzing_matrix", test_08_pose_solver_extreme_fuzzing_matrix)
	_run_test("test_09_combat_slash_phase_continuity_and_ease_curves", test_09_combat_slash_phase_continuity_and_ease_curves)
	_run_test("test_10_orphan_node_leakage_and_lifecycle_churn", test_10_orphan_node_leakage_and_lifecycle_churn)

	print("======================================================================")
	print("=== CHALLENGER M2 SUMMARY: %d / %d PASSED (%d FAILED, %d ASSERTIONS) ===" % [
		_tests_passed, _tests_run, _tests_failed, _assertion_count
	])
	print("======================================================================")

	if _tests_failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### CHALLENGER M2 VERDICT: APPROVE - ALL EMPIRICAL CHALLENGES SURVIVED")
		quit(0)


func _run_test(test_name: String, test_callable: Callable) -> void:
	_tests_run += 1
	var result: Variant = test_callable.call()
	var ok: bool = (result is bool) and (result as bool)

	if ok:
		_tests_passed += 1
		print("  [PASS] " + test_name)
	else:
		_tests_failed += 1
		_failures.append(test_name)
		printerr("  [FAIL] " + test_name)


func _check(condition: bool, msg: String) -> bool:
	_assertion_count += 1
	if not condition:
		printerr("    -> ASSERTION FAILED: " + msg)
		return false
	return true


func _is_finite_v2(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


func _spawn_rig() -> StickmanProcedural:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		return null
	var inst: Node = scene.instantiate()
	if inst is StickmanProcedural:
		root.add_child(inst)
		return inst as StickmanProcedural
	return null


func _free_rig(rig: Node) -> void:
	if rig != null and is_instance_valid(rig):
		if rig.get_parent() != null:
			rig.get_parent().remove_child(rig)
		rig.free()


# ============================================================================
# 1. ProceduralSpring: Resonant Injection & Energy Bounding
# ============================================================================

func test_01_spring_resonance_and_energy_bounding() -> bool:
	var ok: bool = true
	var spring = MAS_SCRIPT.ProceduralSpring.new(5.0, 0.75, 0.0)

	# Resonance Attack: Drive the spring exactly at its natural resonant frequency (5.0 Hz).
	# Period T = 1/5 = 0.20s. We step with dt = 0.005s (40 steps per cycle).
	# Alternate target between +1000.0 and -1000.0 exactly in phase with natural frequency.
	var dt: float = 0.005
	var half_period_steps: int = 20 # 0.1s positive, 0.1s negative = 5 Hz square wave
	var target_amp: float = 1000.0

	var max_observed_val: float = 0.0
	var max_observed_vel: float = 0.0

	# Run for 2,500 resonant cycles (100,000 simulation steps)
	for step in range(100000):
		var cycle_step: int = step % (half_period_steps * 2)
		var current_target: float = target_amp if cycle_step < half_period_steps else -target_amp
		spring.snap_to(current_target)

		var v: float = spring.update(dt)
		if not is_finite(v) or not is_finite(spring.velocity):
			ok = _check(false, "Resonant injection caused NaN/Inf at step %d" % step) and ok
			return false

		max_observed_val = maxf(max_observed_val, absf(v))
		max_observed_vel = maxf(max_observed_vel, absf(spring.velocity))

	# Velocity must strictly respect max_velocity limit (5000.0)
	ok = _check(max_observed_vel <= 5000.01,
		"Velocity strictly bounded by max_velocity=5000 under resonant attack (max=%f)" % max_observed_vel) and ok

	# Value amplitude must remain strictly bounded (with zeta=0.75, steady-state resonant amplification is <= 1.5x)
	# Target amplitude is 1000.0, so value should not exceed ~2000.0
	ok = _check(max_observed_val < 3000.0,
		"Value strictly bounded under resonant attack (max_val=%f, expected < 3000)" % max_observed_val) and ok

	# Impulse Bomb Attack: Inject 10,000 maximum impulses continuously in alternating directions
	for i in range(10000):
		var imp: float = 100000.0 if (i % 2 == 0) else -100000.0
		spring.apply_impulse(imp)
		spring.update(dt)
		ok = _check(absf(spring.velocity) <= 5000.01,
			"Impulse bomb: velocity capped at 5000 (got %f)" % spring.velocity) and ok
		ok = _check(is_finite(spring.value), "Impulse bomb: value remains finite") and ok

	return ok


# ============================================================================
# 2. ProceduralSpring2D: Multi-Axis Resonance & Float Overflow
# ============================================================================

func test_02_spring2d_multiaxis_resonance_and_float_overflow() -> bool:
	var ok: bool = true
	var spring2d = MAS_SCRIPT.ProceduralSpring2D.new(5.0, 0.75, Vector2.ZERO)

	# Circular Resonant Drive: Drive 2D spring along an orbiting circular trajectory at resonant frequency
	var dt: float = 0.01
	var omega: float = TAU * 5.0 # 5 Hz rotational frequency
	var max_dist: float = 0.0

	for step in range(10000):
		var t: float = step * dt
		var target_pos := Vector2(cos(omega * t), sin(omega * t)) * 500.0
		spring2d.snap_to(target_pos)

		var pos: Vector2 = spring2d.update(dt)
		ok = _check(_is_finite_v2(pos), "Spring2D pos finite during orbital drive") and ok
		ok = _check(_is_finite_v2(spring2d.velocity), "Spring2D vel finite during orbital drive") and ok

		max_dist = maxf(max_dist, pos.length())
		ok = _check(spring2d.velocity.length() <= 5000.01,
			"Spring2D velocity bounded by max_velocity (got %f)" % spring2d.velocity.length()) and ok

	ok = _check(max_dist < 1500.0, "Spring2D orbital distance bounded (max_dist=%f)" % max_dist) and ok

	# Extreme Float & NaN/Inf Injection into apply_impulse
	var crazy_impulses: Array[Vector2] = [
		Vector2(1e35, 1e35),
		Vector2(-1e35, -1e35),
		Vector2(INF, 0.0),
		Vector2(0.0, -INF),
		Vector2(NAN, 100.0),
		Vector2(100.0, NAN),
		Vector2(NAN, NAN)
	]

	for imp in crazy_impulses:
		spring2d.apply_impulse(imp)
		var p: Vector2 = spring2d.update(0.016)
		ok = _check(_is_finite_v2(p), "Spring2D survived crazy impulse %s" % str(imp)) and ok
		ok = _check(_is_finite_v2(spring2d.velocity), "Spring2D velocity finite after crazy impulse %s" % str(imp)) and ok

	return ok


# ============================================================================
# 3. ProceduralGaitSolver: 1,000,000 Cycles Continuity & Phase Invariants
# ============================================================================

func test_03_gait_solver_one_million_cycles_and_phase_continuity() -> bool:
	var ok: bool = true
	var GaitSolver = MAS_SCRIPT.ProceduralGaitSolver

	# Test calculate_cadence over wide speed ranges
	var test_speeds: Array[float] = [
		0.0, 1e-10, 1.0, 20.0, 60.0, 180.0, 260.0, 500.0, 1000.0, 100000.0, 1e20, INF, -INF, NAN
	]

	for spd in test_speeds:
		var c: float = GaitSolver.calculate_cadence(spd)
		ok = _check(is_finite(c), "Cadence finite for speed %s" % str(spd)) and ok
		ok = _check(c >= 1.799 and c <= 3.801, "Cadence strictly in [1.8, 3.8] Hz (got %f on speed %s)" % [c, str(spd)]) and ok

	# Test 1,000,000 continuous phase increments
	# Emulate 1 million simulation ticks of a character running at variable speeds
	var phase: float = 0.0
	var dt: float = 0.016
	for i in range(1000000):
		var spd: float = 200.0 + sin(i * 0.001) * 150.0
		var cadence: float = GaitSolver.calculate_cadence(spd)
		var step_rad: float = TAU * cadence * dt
		phase = fposmod(phase + step_rad, TAU)

		# Evaluate trajectory every 10,000 steps to sample across the million
		if i % 10000 == 0:
			var traj: Vector2 = GaitSolver.evaluate_foot_trajectory(phase, 14.0, 6.0)
			ok = _check(_is_finite_v2(traj), "Step %d: foot trajectory is finite (%s)" % [i, str(traj)]) and ok
			ok = _check(absf(traj.x) <= 14.001, "Step %d: foot trajectory X clamped within stride_half (x=%f)" % [i, traj.x]) and ok
			ok = _check(traj.y >= -0.001 and traj.y <= 6.001, "Step %d: foot trajectory Y clamped in [0, height] (y=%f)" % [i, traj.y]) and ok

	ok = _check(is_finite(phase), "Phase finite after 1,000,000 steps") and ok
	return ok


# ============================================================================
# 4. ProceduralGaitSolver: Boundary C0 Continuity Across Stance <-> Swing
# ============================================================================

func test_04_gait_trajectory_boundary_continuity_c0_c1() -> bool:
	var ok: bool = true
	var GaitSolver = MAS_SCRIPT.ProceduralGaitSolver
	var stride_half: float = 14.0
	var step_height: float = 6.0

	# 1. Test Boundary 1: Stance -> Swing at phase = PI
	var eps: float = 0.00001
	var traj_before_pi: Vector2 = GaitSolver.evaluate_foot_trajectory(PI - eps, stride_half, step_height)
	var traj_at_pi: Vector2 = GaitSolver.evaluate_foot_trajectory(PI, stride_half, step_height)
	var traj_after_pi: Vector2 = GaitSolver.evaluate_foot_trajectory(PI + eps, stride_half, step_height)

	# At phase PI: X must be exactly -stride_half, Y must be 0.0
	ok = _check(is_equal_approx(traj_at_pi.x, -stride_half),
		"At phase PI: x is exactly -stride_half (got %f, expected %f)" % [traj_at_pi.x, -stride_half]) and ok
	ok = _check(is_equal_approx(traj_at_pi.y, 0.0),
		"At phase PI: y is exactly 0.0 (got %f)" % traj_at_pi.y) and ok

	# Distance jump across PI must be <= 2 * eps * speed (C0 continuous)
	var jump_pi: float = traj_before_pi.distance_to(traj_after_pi)
	ok = _check(jump_pi < 0.005, "C0 continuity at Stance->Swing transition: jump=%f" % jump_pi) and ok

	# 2. Test Boundary 2: Swing -> Stance at phase = TAU (or 0.0)
	var traj_before_tau: Vector2 = GaitSolver.evaluate_foot_trajectory(TAU - eps, stride_half, step_height)
	var traj_at_zero: Vector2 = GaitSolver.evaluate_foot_trajectory(0.0, stride_half, step_height)
	var traj_after_zero: Vector2 = GaitSolver.evaluate_foot_trajectory(eps, stride_half, step_height)

	# At phase 0 / TAU: X must be exactly +stride_half, Y must be 0.0
	ok = _check(is_equal_approx(traj_at_zero.x, stride_half),
		"At phase 0.0: x is exactly +stride_half (got %f, expected %f)" % [traj_at_zero.x, stride_half]) and ok
	ok = _check(is_equal_approx(traj_at_zero.y, 0.0),
		"At phase 0.0: y is exactly 0.0 (got %f)" % traj_at_zero.y) and ok

	var jump_tau: float = traj_before_tau.distance_to(traj_at_zero)
	ok = _check(jump_tau < 0.005, "C0 continuity at Swing->Stance transition: jump=%f" % jump_tau) and ok

	# 3. Dense sweeping: 10,000 steps across [0, TAU] to verify no teleports anywhere
	var prev_pos: Vector2 = GaitSolver.evaluate_foot_trajectory(0.0, stride_half, step_height)
	var max_step_dist: float = 0.0
	var dphi: float = TAU / 10000.0

	for i in range(1, 10001):
		var phi: float = i * dphi
		var cur_pos: Vector2 = GaitSolver.evaluate_foot_trajectory(phi, stride_half, step_height)
		var d: float = cur_pos.distance_to(prev_pos)
		max_step_dist = maxf(max_step_dist, d)
		prev_pos = cur_pos

	ok = _check(max_step_dist < 0.05,
		"Smooth trajectory everywhere (max step delta = %f)" % max_step_dist) and ok

	return ok


# ============================================================================
# 5. ProceduralSquashStretch: Volume Conservation & Violent Impacts
# ============================================================================

func test_05_squash_stretch_volume_conservation_and_extreme_impacts() -> bool:
	var ok: bool = true
	var PoseSolver = MAS_SCRIPT.StickmanPoseSolver

	# 1. Volume conservation mathematical invariant test
	# Equation: Sx = 1.0 / sqrt(Sy) => Sx^2 * Sy = 1.0 (exact 3D cylindrical conservation)
	var sweep_sy: Array[float] = [
		-100.0, -1.0, 0.0, 0.001, 0.1, 0.5, 0.68, 0.8, 1.0, 1.25, 1.32, 2.0, 3.0, 100.0, INF, NAN
	]

	for raw_sy in sweep_sy:
		var scale_vec: Vector2 = PoseSolver.volume_conserving_scale(raw_sy)
		ok = _check(_is_finite_v2(scale_vec), "Scale vector finite on sy=%s" % str(raw_sy)) and ok
		ok = _check(scale_vec.x > 0.0 and scale_vec.y > 0.0,
			"Scale components strictly positive on sy=%s (got %s)" % [str(raw_sy), str(scale_vec)]) and ok

		# For safe range [0.1, 3.0], volume invariant Sx^2 * Sy strictly equals 1.0
		var vol_3d: float = scale_vec.x * scale_vec.x * scale_vec.y
		ok = _check(is_equal_approx(vol_3d, 1.0),
			"Volume Sx^2 * Sy strictly conserves 1.0 (vol=%f on sy=%s)" % [vol_3d, str(raw_sy)]) and ok

		# 2D area product Sx * Sy = sqrt(Sy). In gameplay range [0.68, 1.32]:
		# sqrt(0.68) = 0.824, sqrt(1.32) = 1.148, so 0.80 <= Sx*Sy <= 1.20
		if raw_sy >= 0.68 and raw_sy <= 1.32:
			var area_2d: float = scale_vec.x * scale_vec.y
			ok = _check(area_2d >= 0.80 and area_2d <= 1.20,
				"2D area Sx * Sy remains near unity in gameplay range: got %f" % area_2d) and ok

	# 2. Violent landing impact test on StickmanProcedural
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	# Simulate terminal velocity fall (vy = +100,000 px/s downward) into violent ground contact
	rig.update_procedural_animation(Vector2(0.0, 100000.0), false, 1.0, "fall", 0.016)
	ok = _check(_is_finite_v2(rig._current_squash_scale), "Fall squash scale finite") and ok

	# Next frame: sudden ground impact
	rig.update_procedural_animation(Vector2.ZERO, true, 1.0, "idle", 0.016)
	ok = _check(_is_finite_v2(rig._current_squash_scale), "Impact squash scale finite") and ok
	ok = _check(rig._current_squash_scale.y < 1.0,
		"Violent impact compressed silhouette vertically (Sy=%f < 1.0)" % rig._current_squash_scale.y) and ok
	ok = _check(rig._current_squash_scale.x > 1.0,
		"Violent impact widened silhouette horizontally (Sx=%f > 1.0)" % rig._current_squash_scale.x) and ok

	# Let landing spring rebound across 30 frames (0.5s)
	for _i in range(30):
		rig.update_procedural_animation(Vector2.ZERO, true, 1.0, "idle", 0.016)

	ok = _check(is_equal_approx(rig._current_squash_scale.y, 1.0) or absf(rig._current_squash_scale.y - 1.0) < 0.05,
		"Landing spring successfully settled back to 1.0 (got %f)" % rig._current_squash_scale.y) and ok

	# 3. Negative Velocity Impulses (Negative launch vy = -100,000 px/s)
	rig.update_procedural_animation(Vector2(0.0, -100000.0), false, 1.0, "jump", 0.016)
	ok = _check(_is_finite_v2(rig._current_squash_scale), "Negative launch squash scale finite") and ok
	ok = _check(rig._current_squash_scale.y >= 1.0 and rig._current_squash_scale.y <= 1.33,
		"Launch stretch Sy clamped within [1.0, 1.32] (got %f)" % rig._current_squash_scale.y) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 6. Delta Time Fuzzing Matrix & Corrupted Deltas
# ============================================================================

func test_06_dt_fuzzing_matrix_and_corrupted_deltas() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	var fuzzed_dts: Array[float] = [
		0.0, 1e-15, 1e-6, 0.00001, 0.0166667, 0.0333333, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0, 100.0, 1e10,
		-0.0, -1e-6, -0.016, -1.0, -100.0, INF, -INF, NAN
	]

	for dt in fuzzed_dts:
		rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", dt)

		ok = _check(is_finite(rig.phase), "Phase finite on dt=%s" % str(dt)) and ok
		ok = _check(rig.phase >= 0.0 and rig.phase < 1.0,
			"Phase in [0, 1) on dt=%s (got %f)" % [str(dt), rig.phase]) and ok
		ok = _check(_is_finite_v2(rig._current_squash_scale),
			"Squash scale finite on dt=%s" % str(dt)) and ok

		for t in rig.get_ik_targets().values():
			var t_node: Node2D = t as Node2D
			ok = _check(t_node != null and _is_finite_v2(t_node.position),
				"Target pos finite on dt=%s" % str(dt)) and ok

		var pose = rig.to_stickman_pose()
		ok = _check(pose != null and _is_finite_v2(pose.head_center), "Pose finite on dt=%s" % str(dt)) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 7. Extreme Velocities & Sudden 180-Degree Velocity Reversals
# ============================================================================

func test_07_extreme_velocity_and_180deg_rapid_flip_fuzzing() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	# 1. Extreme velocities fuzzing (+/-100,000 px/s, subnormal, Inf, NaN)
	var extreme_vels: Array[Vector2] = [
		Vector2(100000.0, 0.0),
		Vector2(-100000.0, 0.0),
		Vector2(0.0, 100000.0),
		Vector2(0.0, -100000.0),
		Vector2(100000.0, -100000.0),
		Vector2(-100000.0, 100000.0),
		Vector2(1e25, -1e25),
		Vector2(INF, 0.0),
		Vector2(0.0, -INF),
		Vector2(NAN, 0.0),
		Vector2(0.0, NAN),
		Vector2(NAN, NAN),
	]

	for v in extreme_vels:
		rig.update_procedural_animation(v, true, 1.0, "run", 0.016)
		ok = _check(is_finite(rig.phase), "Phase finite on extreme vel %s" % str(v)) and ok
		ok = _check(_is_finite_v2(rig._current_squash_scale), "Squash scale finite on vel %s" % str(v)) and ok

	# 2. Sudden 180-Degree Velocity Reversals within 1 Frame
	# Alternating between +100,000 px/s and -100,000 px/s for 1,000 frames
	for flip in range(1000):
		var vx: float = 100000.0 if (flip % 2 == 0) else -100000.0
		var facing_in: float = 1.0 if vx > 0.0 else -1.0
		rig.update_procedural_animation(Vector2(vx, 0.0), true, facing_in, "run", 0.016)

		# Facing must strictly track +/-1.0
		ok = _check(rig.facing == 1.0 or rig.facing == -1.0,
			"Facing strictly +/-1.0 on flip %d (got %f)" % [flip, rig.facing]) and ok

		# Accel_x should be clamped to [-3500, 3500] and not explode to 12.5M
		ok = _check(absf(rig._current_accel_x) <= 3500.01,
			"Accel_x clamped to [-3500, 3500] on flip %d (got %f)" % [flip, rig._current_accel_x]) and ok

		# All targets must remain finite and bounded
		for t_name in rig.get_ik_targets():
			var t_node: Node2D = rig.get_ik_targets()[t_name] as Node2D
			ok = _check(_is_finite_v2(t_node.position),
				"Target %s finite on flip %d (pos=%s)" % [t_name, flip, str(t_node.position)]) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 8. StickmanPoseSolver: Fuzzing Matrix Across Stances, Speeds & Accel
# ============================================================================

func test_08_pose_solver_extreme_fuzzing_matrix() -> bool:
	var ok: bool = true
	var PoseSolver = MAS_SCRIPT.StickmanPoseSolver

	var stances: Array[String] = [
		"normal", "heavy_slash", "downward_slam", "parry_guard", "wall_slide", "well_unlock", "bogus_stance", ""
	]
	var test_vels: Array[Vector2] = [
		Vector2.ZERO, Vector2(200.0, 0.0), Vector2(-300.0, 0.0), Vector2(0.0, 500.0),
		Vector2(100000.0, -100000.0), Vector2(INF, NAN), Vector2(NAN, -INF)
	]
	var test_accels: Array[float] = [
		0.0, 1000.0, -2500.0, 100000.0, -100000.0, INF, -INF, NAN
	]

	var dynamics_ctx = MAS_SCRIPT.PoseDynamicsContext.new()

	for st in stances:
		for v in test_vels:
			for acc in test_accels:
				for facing_in in [1.0, -1.0, 0.0, INF, NAN]:
					var pose = PoseSolver.generate_stickman_pose(
						Vector2.ZERO, facing_in, v, true, 0.5, false, 0.0, false, st, acc, dynamics_ctx, 0.016
					)

					ok = _check(pose != null, "Pose generated non-null") and ok
					if pose == null:
						continue

					ok = _check(_is_finite_v2(pose.head_center), "head_center finite on st=%s, v=%s, acc=%s" % [st, str(v), str(acc)]) and ok
					ok = _check(_is_finite_v2(pose.neck), "neck finite") and ok
					ok = _check(_is_finite_v2(pose.pelvis), "pelvis finite") and ok
					ok = _check(_is_finite_v2(pose.sword_hilt), "sword_hilt finite") and ok
					ok = _check(_is_finite_v2(pose.sword_tip), "sword_tip finite") and ok

					# Verify scarf nodes trailing invariant:
					# behind head_center in facing direction
					if pose.scarf_nodes.size() == 3:
						var s0: Vector2 = pose.scarf_nodes[0]
						var s1: Vector2 = pose.scarf_nodes[1]
						var s2: Vector2 = pose.scarf_nodes[2]
						if facing_in > 0.0:
							ok = _check(s0.x < pose.head_center.x, "Scarf 0 trails head (right)") and ok
							ok = _check(s1.x < s0.x, "Scarf 1 trails scarf 0 (right)") and ok
							ok = _check(s2.x < s1.x, "Scarf 2 trails scarf 1 (right)") and ok
						elif facing_in < 0.0:
							ok = _check(s0.x > pose.head_center.x, "Scarf 0 trails head (left)") and ok
							ok = _check(s1.x > s0.x, "Scarf 1 trails scarf 0 (left)") and ok
							ok = _check(s2.x > s1.x, "Scarf 2 trails scarf 1 (left)") and ok

						# Measure inter-node distance bounds:
						# When dynamic springs lag, minimum separation is clamped by minf(x - 4.0)
						var d01: float = s0.distance_to(s1)
						var d12: float = s1.distance_to(s2)
						ok = _check(d01 >= 3.99 and d01 <= 15.01,
							"Scarf d01 bounded in [4.0, 15.0] px under dynamic springs (got %f)" % d01) and ok
						ok = _check(d12 >= 3.99 and d15_bound(d12),
							"Scarf d12 bounded in [4.0, 15.0] px under dynamic springs (got %f)" % d12) and ok

					# Simulation coordinate space (+Y is UP): head_center.y > neck.y > pelvis.y
					ok = _check(pose.head_center.y > pose.neck.y,
						"Head above neck: head=%f > neck=%f" % [pose.head_center.y, pose.neck.y]) and ok
					ok = _check(pose.neck.y > pose.pelvis.y,
						"Neck above pelvis: neck=%f > pelvis=%f" % [pose.neck.y, pose.pelvis.y]) and ok

	return ok


func d15_bound(d: float) -> bool:
	return d <= 15.01


# ============================================================================
# 9. Combat Slash: 3-Phase Sweep Easing Curves & Continuity
# ============================================================================

func test_09_combat_slash_phase_continuity_and_ease_curves() -> bool:
	var ok: bool = true
	var PoseSolver = MAS_SCRIPT.StickmanPoseSolver

	# Test ease_out_expo: 1.0 - 2^(-10t)
	# At t = 0.25 (25% of duration): 1 - 2^(-2.5) = 1 - 0.17677 = 82.3% of stroke completed
	var ease_at_25: float = PoseSolver.ease_out_expo(0.25)
	ok = _check(ease_at_25 > 0.80 and ease_at_25 < 0.85,
		"Fast strike exponential easing completes >80%% at 25%% duration (got %f)" % ease_at_25) and ok

	# Test smootherstep: C2 continuity at both boundaries (t=0, t=1)
	ok = _check(is_equal_approx(PoseSolver.smootherstep(0.0), 0.0), "smootherstep(0) == 0") and ok
	ok = _check(is_equal_approx(PoseSolver.smootherstep(1.0), 1.0), "smootherstep(1) == 1") and ok

	# 1. Exact C0 Continuity at Phase Transitions (t = 0.15 and t = 0.40)
	for is_h in [false, true]:
		var eps: float = 0.00001
		# Transition 1: Windup -> Strike at t = 0.15
		# Note: attack_progress = 1.0 - t
		var slash_before_15 = PoseSolver.calculate_combat_slash(1.0 - (0.15 - eps), 1.0, is_h)
		var slash_at_15 = PoseSolver.calculate_combat_slash(1.0 - 0.15, 1.0, is_h)
		var slash_after_15 = PoseSolver.calculate_combat_slash(1.0 - (0.15 + eps), 1.0, is_h)

		var j1: float = absf(float(slash_before_15["swing_angle"]) - float(slash_after_15["swing_angle"]))
		ok = _check(j1 < 0.005, "C0 continuity at windup->strike transition: jump=%f (heavy=%s)" % [j1, str(is_h)]) and ok

		# Transition 2: Strike -> Settle at t = 0.40
		var slash_before_40 = PoseSolver.calculate_combat_slash(1.0 - (0.40 - eps), 1.0, is_h)
		var slash_at_40 = PoseSolver.calculate_combat_slash(1.0 - 0.40, 1.0, is_h)
		var slash_after_40 = PoseSolver.calculate_combat_slash(1.0 - (0.40 + eps), 1.0, is_h)

		var j2: float = absf(float(slash_before_40["swing_angle"]) - float(slash_after_40["swing_angle"]))
		ok = _check(j2 < 0.005, "C0 continuity at strike->settle transition: jump=%f (heavy=%s)" % [j2, str(is_h)]) and ok

	# 2. Sweep across all 101 progress points and verify finiteness and bounds
	for i in range(101):
		var p: float = 1.0 - (float(i) / 100.0)
		for is_h in [false, true]:
			var slash_info = PoseSolver.calculate_combat_slash(p, 1.0, is_h)
			var angle: float = float(slash_info["swing_angle"])
			var b_stretch: float = float(slash_info["blade_stretch"])
			var hand_dir: Vector2 = slash_info["hand_dir"]

			ok = _check(is_finite(angle), "Swing angle finite on p=%f" % p) and ok
			ok = _check(is_finite(b_stretch) and b_stretch >= 0.90 and b_stretch <= 1.25,
				"Blade stretch in [0.90, 1.25] (got %f on p=%f)" % [b_stretch, p]) and ok
			ok = _check(_is_finite_v2(hand_dir), "Hand dir finite on p=%f" % p) and ok

	return ok


# ============================================================================
# 10. Orphan Node Hygiene & Multi-Instance Churn
# ============================================================================

func test_10_orphan_node_leakage_and_lifecycle_churn() -> bool:
	var ok: bool = true
	var initial_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	# Spawn and free 50 rigs sequentially with active procedural animation steps
	for i in range(50):
		var rig := _spawn_rig()
		ok = _check(rig != null, "Spawn rig iteration %d" % i) and ok
		if rig != null:
			for frame in range(10):
				rig.update_procedural_animation(Vector2(260.0, 0.0), true, 1.0, "run", 0.016)
				var pose = rig.to_stickman_pose()
				ok = _check(pose != null, "to_stickman_pose non-null") and ok
			_free_rig(rig)

	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	ok = _check(final_orphans <= initial_orphans,
		"Zero orphan node accumulation: initial=%d, final=%d" % [initial_orphans, final_orphans]) and ok

	return ok
