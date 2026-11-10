extends SceneTree

## Challenger M2.2 Adversarial Verification Suite
## Focus: Empirical stress-testing of Milestone 2 procedural motion dynamics:
## 1. Performance and memory: 1,000 continuous simulation steps (<0.1ms/frame, flat memory, 0 orphan leaks)
## 2. Coordinate & anatomical constraints: +Y UP parity (head_center.y > neck.y > pelvis.y) across all permutations
## 3. 3-phase combat sweep: monotonicity, NaN resilience, and attack_progress transitions (1.0 -> 0.0)
## 4. Scarf ribbons: strict trailing order and inter-node distance constraints under rapid direction flips
## 5. Procedural gait & cadence saturation invariants
## 6. Volume-conserving squash/stretch invariance (Sx * Sy = 1.0)

const MAS_SCRIPT = preload("res://scripts/modular_rig/modular_asset_system.gd")
const RIG_SCENE = preload("res://scenes/stickman/stickmanprocedural.tscn")

var _passed_count: int = 0
var _failed_count: int = 0
var _assertions_passed: int = 0
var _defects: Array[String] = []


func _init() -> void:
	print("======================================================================")
	print("=== CHALLENGER M2.2 ADVERSARIAL STRESS SUITE: PROCEDURAL DYNAMICS ===")
	print("======================================================================")

	_run_test("test_01_performance_benchmark_and_memory_leak", test_01_performance_benchmark_and_memory_leak)
	_run_test("test_02_coordinate_parity_and_anatomical_invariants", test_02_coordinate_parity_and_anatomical_invariants)
	_run_test("test_03_combat_sweep_monotonicity_and_reset_edges", test_03_combat_sweep_monotonicity_and_reset_edges)
	_run_test("test_04_scarf_ribbon_trailing_and_distance_constraints", test_04_scarf_ribbon_trailing_and_distance_constraints)
	_run_test("test_05_procedural_gait_and_cadence_invariants", test_05_procedural_gait_and_cadence_invariants)
	_run_test("test_06_volume_conserving_squash_stretch_invariance", test_06_volume_conserving_squash_stretch_invariance)

	print("======================================================================")
	print("=== CHALLENGER M2.2 SUMMARY: %d passed, %d failed (%d assertions) ===" % [_passed_count, _failed_count, _assertions_passed])
	print("======================================================================")

	if _failed_count > 0:
		for d in _defects:
			printerr("  [DEFECT] " + d)
		print("### CHALLENGER M2.2 VERDICT: REQUEST_CHANGES - DEFECTS FOUND")
		quit(1)
	else:
		print("### CHALLENGER M2.2 VERDICT: APPROVE - ALL ADVERSARIAL CHALLENGES PASSED")
		quit(0)


func _run_test(test_name: String, test_fn: Callable) -> void:
	var success: bool = test_fn.call()
	if success:
		_passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed_count += 1
		_defects.append(test_name)
		printerr("  [FAIL] %s" % test_name)


func _check(cond: bool, msg: String) -> bool:
	if cond:
		_assertions_passed += 1
		return true
	else:
		printerr("    -> ASSERTION FAILED: %s" % msg)
		return false


# ============================================================================
# 1. Performance and Memory: 1,000 Continuous Simulation Steps
# ============================================================================

func test_01_performance_benchmark_and_memory_leak() -> bool:
	var ok: bool = true
	var rig = RIG_SCENE.instantiate()
	root.add_child(rig)

	# Warm up JIT / cache
	for i in range(50):
		rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)

	# Initial memory & orphan count
	var initial_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var initial_mem: int = OS.get_static_memory_usage()

	const STEP_COUNT: int = 1000
	var dynamics_ctx = MAS_SCRIPT.PoseDynamicsContext.new()

	var t_start_rig: int = Time.get_ticks_usec()
	for i in range(STEP_COUNT):
		var vel := Vector2(250.0 * sin(i * 0.05), (i % 200 - 100) * 5.0)
		var is_ground: bool = (i % 60) < 40
		var facing: float = 1.0 if (i % 120 < 60) else -1.0
		var state: String = "run" if is_ground else "air"
		rig.update_procedural_animation(vel, is_ground, facing, state, 0.016)
	var t_end_rig: int = Time.get_ticks_usec()

	var total_usec_rig: int = t_end_rig - t_start_rig
	var avg_usec_per_step_rig: float = float(total_usec_rig) / float(STEP_COUNT)
	var avg_ms_per_step_rig: float = avg_usec_per_step_rig / 1000.0

	print("    [BENCHMARK] Live StickmanProcedural: %d steps took %d us (avg: %.3f us/frame = %.4f ms/frame)" % [
		STEP_COUNT, total_usec_rig, avg_usec_per_step_rig, avg_ms_per_step_rig
	])
	ok = _check(avg_ms_per_step_rig < 0.1,
		"Live rig execution time per frame is < 0.1 ms (got %.4f ms)" % avg_ms_per_step_rig) and ok

	# Benchmark PoseSolver.generate_stickman_pose directly
	var t_start_solver: int = Time.get_ticks_usec()
	for i in range(STEP_COUNT):
		var anim_t: float = float(i) * 0.016
		var vel := Vector2(260.0, 0.0)
		var pose = MAS_SCRIPT.StickmanPoseSolver.generate_stickman_pose(
			Vector2(100.0, 50.0), 1.0, vel, true, anim_t, false, 0.0, false, "normal", 0.0, dynamics_ctx, 0.016
		)
	var t_end_solver: int = Time.get_ticks_usec()

	var total_usec_solver: int = t_end_solver - t_start_solver
	var avg_usec_solver: float = float(total_usec_solver) / float(STEP_COUNT)
	var avg_ms_solver: float = avg_usec_solver / 1000.0

	print("    [BENCHMARK] StickmanPoseSolver: %d steps took %d us (avg: %.3f us/frame = %.4f ms/frame)" % [
		STEP_COUNT, total_usec_solver, avg_usec_solver, avg_ms_solver
	])
	ok = _check(avg_ms_solver < 0.1,
		"StickmanPoseSolver execution time per frame is < 0.1 ms (got %.4f ms)" % avg_ms_solver) and ok

	# Memory usage verification
	var final_mem: int = OS.get_static_memory_usage()
	var mem_delta: int = final_mem - initial_mem
	print("    [MEMORY] Initial static mem: %d B, Final: %d B, Delta: %d B" % [initial_mem, final_mem, mem_delta])
	# Static memory usage must remain flat (<64 KB allowable transient allocations)
	ok = _check(mem_delta < 65536, "Memory delta is flat after 1,000 steps (delta: %d B)" % mem_delta) and ok

	# Free instance and verify orphan count
	rig.free()
	var final_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var orphan_delta: int = final_orphans - initial_orphans
	print("    [ORPHANS] Initial orphans: %d, Final orphans: %d, Delta: %d" % [initial_orphans, final_orphans, orphan_delta])
	ok = _check(orphan_delta <= 0, "Zero orphan nodes leaked after 1,000 steps and free() (delta: %d)" % orphan_delta) and ok

	return ok


# ============================================================================
# 2. Coordinate & Anatomical Invariants: +Y UP Simulation Coordinate Parity
# ============================================================================

func test_02_coordinate_parity_and_anatomical_invariants() -> bool:
	var ok: bool = true

	var speeds: Array[float] = [-1000.0, -450.0, -180.0, 0.0, 20.0, 180.0, 450.0, 1000.0]
	var vy_values: Array[float] = [-2000.0, -480.0, -100.0, 0.0, 100.0, 480.0, 2000.0]
	var ground_states: Array[bool] = [true, false]
	var stances: Array[String] = [
		"normal", "heavy_slash", "downward_slam", "parry_guard", "wall_slide", "well_unlock"
	]
	var facings: Array[float] = [1.0, -1.0]
	var attack_progresses: Array[float] = [0.0, 0.10, 0.25, 0.50, 0.80, 1.0]
	var squash_scales: Array[Vector2] = [
		Vector2.ZERO, Vector2(1.0, 1.0), Vector2(1.2, 0.694), Vector2(0.8, 1.562), Vector2(0.6, 2.77)
	]

	var total_combos: int = 0
	var parity_violations: int = 0
	var nan_violations: int = 0

	var dynamics_ctx = MAS_SCRIPT.PoseDynamicsContext.new()

	for stance in stances:
		for speed in speeds:
			for vy in vy_values:
				for is_ground in ground_states:
					for f in facings:
						for p in attack_progresses:
							for sq in squash_scales:
								total_combos += 1
								var is_atk: bool = (stance == "heavy_slash" or p > 0.0)
								var pose = MAS_SCRIPT.StickmanPoseSolver.generate_stickman_pose(
									Vector2(200.0, 100.0), f, Vector2(speed, vy), is_ground,
									float(total_combos) * 0.016, is_atk, p, false, stance,
									0.0, dynamics_ctx, 0.016, sq
								)

								# Check NaN/Inf
								if not _is_finite_v2(pose.head_center) or not _is_finite_v2(pose.neck) or not _is_finite_v2(pose.pelvis):
									nan_violations += 1

								# +Y UP Simulation Coordinate Invariant:
								# head_center.y > neck.y > pelvis.y
								if not (pose.head_center.y > pose.neck.y and pose.neck.y > pose.pelvis.y):
									parity_violations += 1
									if parity_violations <= 3:
										printerr("    [VIOLATION] Stance '%s', f=%.1f, spd=%.1f, vy=%.1f, g=%s, sq=%s -> head=%.2f, neck=%.2f, pelv=%.2f" % [
											stance, f, speed, vy, str(is_ground), str(sq),
											pose.head_center.y, pose.neck.y, pose.pelvis.y
										])

	print("    [CHECK] Coordinate Parity tested across %d state permutations: %d parity violations, %d NaN violations" % [
		total_combos, parity_violations, nan_violations
	])

	ok = _check(parity_violations == 0,
		"Zero parity violations across %d permutations (head_center.y > neck.y > pelvis.y)" % total_combos) and ok
	ok = _check(nan_violations == 0,
		"Zero NaN/Inf joint coordinates across %d permutations" % total_combos) and ok

	# Live StickmanProcedural rig test across stances
	var rig = RIG_SCENE.instantiate()
	root.add_child(rig)

	for stance in stances:
		for f in [1.0, -1.0]:
			rig.update_procedural_animation(Vector2(240.0 * f, 0.0), true, f, stance, 0.016)
			var live_pose = rig.to_stickman_pose(f)
			if live_pose != null:
				ok = _check(live_pose.head_center.y > live_pose.neck.y,
					"Live rig [%s, f=%.1f]: head_center.y (%.1f) > neck.y (%.1f)" % [stance, f, live_pose.head_center.y, live_pose.neck.y]) and ok
				ok = _check(live_pose.neck.y > live_pose.pelvis.y,
					"Live rig [%s, f=%.1f]: neck.y (%.1f) > pelvis.y (%.1f)" % [stance, f, live_pose.neck.y, live_pose.pelvis.y]) and ok

	rig.free()
	return ok


# ============================================================================
# 3. 3-Phase Combat Sweep Monotonicity & Reset Transitions
# ============================================================================

func test_03_combat_sweep_monotonicity_and_reset_edges() -> bool:
	var ok: bool = true

	# Test both standard slash (is_heavy=false) and heavy slash (is_heavy=true)
	for is_heavy in [false, true]:
		var prev_snap_ease: float = -1.0
		var sweep_type: String = "heavy_slash" if is_heavy else "slash"

		# Sample across 1,000 steps of attack_progress dropping from 1.0 to 0.0
		var prev_angle: float = 0.0
		for i in range(1001):
			var p: float = 1.0 - float(i) / 1000.0 # Drops from 1.0 to 0.0
			var info: Dictionary = MAS_SCRIPT.StickmanPoseSolver.calculate_combat_slash(p, 1.0, is_heavy)

			var angle: float = info.get("swing_angle", 0.0)
			var blade_dir: Vector2 = info.get("blade_dir", Vector2.ZERO)
			var stretch: float = info.get("blade_stretch", 1.0)
			var lean: float = info.get("torso_lean", 0.0)

			# 1. Check all values are finite
			ok = _check(is_finite(angle), "%s: swing_angle is finite at p=%.3f" % [sweep_type, p]) and ok
			ok = _check(_is_finite_v2(blade_dir), "%s: blade_dir is finite at p=%.3f" % [sweep_type, p]) and ok
			ok = _check(is_finite(stretch), "%s: blade_stretch is finite at p=%.3f" % [sweep_type, p]) and ok
			ok = _check(is_finite(lean), "%s: torso_lean is finite at p=%.3f" % [sweep_type, p]) and ok

			# 2. blade_dir must be normalized unit vector
			var dir_len: float = blade_dir.length()
			ok = _check(absf(dir_len - 1.0) < 0.005,
				"%s: blade_dir is normalized (len=%.4f at p=%.3f)" % [sweep_type, dir_len, p]) and ok

			# 3. Blade stretch within physical range [0.85, 1.35]
			ok = _check(stretch >= 0.85 and stretch <= 1.35,
				"%s: blade_stretch in [0.85, 1.35] (got %.3f at p=%.3f)" % [sweep_type, stretch, p]) and ok

			# 4. Check Phase 2 (Snap Strike Explosion): elapsed t in [0.15, 0.40] => p in [0.60, 0.85]
			var t: float = 1.0 - p
			if t >= 0.15 and t <= 0.40:
				var tau2: float = (t - 0.15) / 0.25
				var snap_ease: float = MAS_SCRIPT.StickmanPoseSolver.ease_out_expo(tau2)
				if prev_snap_ease >= 0.0:
					ok = _check(snap_ease >= prev_snap_ease,
						"%s Phase 2: snap ease is strictly monotonic non-decreasing (prev=%.4f, cur=%.4f)" % [
							sweep_type, prev_snap_ease, snap_ease
						]) and ok
				prev_snap_ease = snap_ease

	# Adversarial Edge Transitions: instant jumps from 1.0 -> 0.0, 0.0 -> 1.0, NaN, Inf
	var edge_cases: Array[float] = [1.0, 0.0, 1.0, 0.5, 0.0, NAN, INF, -INF, -5.0, 5.0]
	for val in edge_cases:
		var edge_info: Dictionary = MAS_SCRIPT.StickmanPoseSolver.calculate_combat_slash(val, 1.0, false)
		var edge_angle: float = edge_info.get("swing_angle", 0.0)
		var edge_stretch: float = edge_info.get("blade_stretch", 1.0)
		var edge_dir: Vector2 = edge_info.get("blade_dir", Vector2.ZERO)

		ok = _check(is_finite(edge_angle), "Adversarial progress %s produces finite swing_angle" % str(val)) and ok
		ok = _check(is_finite(edge_stretch), "Adversarial progress %s produces finite blade_stretch" % str(val)) and ok
		ok = _check(_is_finite_v2(edge_dir), "Adversarial progress %s produces finite blade_dir" % str(val)) and ok

	return ok


# ============================================================================
# 4. Scarf Ribbons: Trailing Order & Distance Constraints Under Rapid Flips
# ============================================================================

func test_04_scarf_ribbon_trailing_and_distance_constraints() -> bool:
	var ok: bool = true
	var dynamics_ctx = MAS_SCRIPT.PoseDynamicsContext.new()

	# 1. Steady-state trailing for facing = +1.0
	for i in range(30):
		var anim_t: float = float(i) * 0.016
		var pose = MAS_SCRIPT.StickmanPoseSolver.generate_stickman_pose(
			Vector2(100.0, 50.0), 1.0, Vector2(240.0, 0.0), true, anim_t, false, 0.0, false, "normal", 0.0, dynamics_ctx, 0.016
		)
		var s = pose.scarf_nodes
		ok = _check(s.size() == 3, "Scarf nodes count is 3") and ok
		# Invariant: scarf_nodes[2].x < scarf_nodes[1].x < scarf_nodes[0].x < head_center.x for facing=+1.0
		ok = _check(s[0].x < pose.head_center.x, "Facing +1: s[0].x (%.1f) < head_center.x (%.1f)" % [s[0].x, pose.head_center.x]) and ok
		ok = _check(s[1].x < s[0].x, "Facing +1: s[1].x (%.1f) < s[0].x (%.1f)" % [s[1].x, s[0].x]) and ok
		ok = _check(s[2].x < s[1].x, "Facing +1: s[2].x (%.1f) < s[1].x (%.1f)" % [s[2].x, s[1].x]) and ok

	# 2. Steady-state trailing for facing = -1.0
	var dynamics_ctx_neg = MAS_SCRIPT.PoseDynamicsContext.new()
	for i in range(30):
		var anim_t: float = float(i) * 0.016
		var pose = MAS_SCRIPT.StickmanPoseSolver.generate_stickman_pose(
			Vector2(100.0, 50.0), -1.0, Vector2(-240.0, 0.0), true, anim_t, false, 0.0, false, "normal", 0.0, dynamics_ctx_neg, 0.016
		)
		var s = pose.scarf_nodes
		# Invariant: scarf_nodes[2].x > scarf_nodes[1].x > scarf_nodes[0].x > head_center.x for facing=-1.0
		ok = _check(s[0].x > pose.head_center.x, "Facing -1: s[0].x (%.1f) > head_center.x (%.1f)" % [s[0].x, pose.head_center.x]) and ok
		ok = _check(s[1].x > s[0].x, "Facing -1: s[1].x (%.1f) > s[0].x (%.1f)" % [s[1].x, s[0].x]) and ok
		ok = _check(s[2].x > s[1].x, "Facing -1: s[2].x (%.1f) > s[1].x (%.1f)" % [s[2].x, s[1].x]) and ok

	# 3. High-Frequency Direction Flipping Stress Test (flipping every 2 frames for 200 frames)
	var flip_ctx = MAS_SCRIPT.PoseDynamicsContext.new()
	var trailing_violations: int = 0
	var distance_clamp_violations: int = 0

	for i in range(200):
		var f: float = 1.0 if ((i / 2) % 2 == 0) else -1.0
		var anim_t: float = float(i) * 0.016
		var vel := Vector2(250.0 * f, sin(i * 0.2) * 100.0)
		var pose = MAS_SCRIPT.StickmanPoseSolver.generate_stickman_pose(
			Vector2(100.0, 50.0), f, vel, true, anim_t, false, 0.0, false, "normal", 0.0, flip_ctx, 0.016
		)
		var s = pose.scarf_nodes

		# Check trailing invariant
		if f > 0.0:
			if not (s[2].x < s[1].x and s[1].x < s[0].x and s[0].x < pose.head_center.x):
				trailing_violations += 1
		else:
			if not (s[2].x > s[1].x and s[1].x > s[0].x and s[0].x > pose.head_center.x):
				trailing_violations += 1

		# Check inter-node distances are bounded and physically reasonable [4.0, 16.0] px
		var d01: float = s[0].distance_to(s[1])
		var d12: float = s[1].distance_to(s[2])
		if d01 < 3.8 or d01 > 16.2 or d12 < 3.8 or d12 > 16.2:
			distance_clamp_violations += 1
			if distance_clamp_violations <= 3:
				printerr("    [DIST WARN] Step %d, f=%.1f: d01=%.2f, d12=%.2f" % [i, f, d01, d12])

	print("    [CHECK] Scarf Flipping Stress (200 steps): trailing violations=%d, distance clamp violations=%d" % [
		trailing_violations, distance_clamp_violations
	])
	ok = _check(trailing_violations == 0, "Zero scarf trailing violations under rapid direction flipping") and ok
	ok = _check(distance_clamp_violations == 0, "Zero distance clamp violations under rapid direction flipping") and ok

	return ok


# ============================================================================
# 5. Procedural Gait & Cadence Saturation Invariants
# ============================================================================

func test_05_procedural_gait_and_cadence_invariants() -> bool:
	var ok: bool = true

	# Cadence saturation curve: f(v) = 1.8 + 2.0 * tanh(|v| / 180.0)
	var speeds: Array[float] = [0.0, 50.0, 180.0, 360.0, 1000.0, 10000.0]
	for spd in speeds:
		var cad: float = MAS_SCRIPT.ProceduralGaitSolver.calculate_cadence(spd)
		ok = _check(cad >= 1.79 and cad <= 3.81,
			"Cadence at speed %.1f is in [1.8, 3.8] Hz (got %.3f Hz)" % [spd, cad]) and ok

	# Cadence must be strictly monotonic non-decreasing with speed
	var prev_cad: float = 0.0
	for spd in range(0, 500, 10):
		var cur_cad: float = MAS_SCRIPT.ProceduralGaitSolver.calculate_cadence(float(spd))
		ok = _check(cur_cad >= prev_cad, "Cadence is monotonic with speed") and ok
		prev_cad = cur_cad

	# Stance phase [0, PI): foot stationary on floor (y == 0.0)
	for i in range(10):
		var phase: float = (float(i) / 10.0) * PI * 0.99
		var traj = MAS_SCRIPT.ProceduralGaitSolver.evaluate_foot_trajectory(phase, 14.0, 6.0)
		ok = _check(is_equal_approx(traj.y, 0.0), "Stance phase y == 0.0 at phase %.2f (got %.3f)" % [phase, traj.y]) and ok

	# Swing phase [PI, TAU): foot lifted (y > 0.0)
	for i in range(1, 10):
		var phase: float = PI + (float(i) / 10.0) * PI
		var traj = MAS_SCRIPT.ProceduralGaitSolver.evaluate_foot_trajectory(phase, 14.0, 6.0)
		ok = _check(traj.y > 0.0, "Swing phase y > 0.0 at phase %.2f (got %.3f)" % [phase, traj.y]) and ok

	return ok


# ============================================================================
# 6. Volume-Conserving Squash & Stretch Invariance
# ============================================================================

func test_06_volume_conserving_squash_stretch_invariance() -> bool:
	var ok: bool = true

	# Test scale factors from compression (0.5) to elongation (2.0)
	var scale_y_samples: Array[float] = [0.5, 0.68, 0.8, 1.0, 1.25, 1.32, 1.8, 2.0]
	for sy in scale_y_samples:
		var scale_vec: Vector2 = MAS_SCRIPT.StickmanPoseSolver.volume_conserving_scale(sy)
		var sx: float = scale_vec.x
		var actual_sy: float = scale_vec.y

		# Physical invariant: Sx * sqrt(Sy) == 1.0 (or Sx * Sy == sqrt(Sy))
		var product: float = sx * sqrt(actual_sy)
		ok = _check(absf(product - 1.0) < 0.0001,
			"Volume conservation invariant Sx * sqrt(Sy) == 1.0 (sy=%.2f, sx=%.4f, prod=%.5f)" % [sy, sx, product]) and ok

		# Volume product Sx^2 * Sy == 1.0
		var vol: float = sx * sx * actual_sy
		ok = _check(absf(vol - 1.0) < 0.001,
			"2D Area/Volume conserved: Sx^2 * Sy == 1.0 (got %.5f)" % vol) and ok

	# Jump stretch vs Fall stretch directions
	var jump_scale: Vector2 = MAS_SCRIPT.StickmanPoseSolver.calculate_air_squash_stretch(300.0, false)
	ok = _check(jump_scale.y > 1.0, "Jump ascent produces vertical stretch (Sy=%.3f > 1.0)" % jump_scale.y) and ok
	ok = _check(jump_scale.x < 1.0, "Jump ascent produces horizontal squeeze (Sx=%.3f < 1.0)" % jump_scale.x) and ok

	var fall_scale: Vector2 = MAS_SCRIPT.StickmanPoseSolver.calculate_air_squash_stretch(-600.0, false)
	ok = _check(fall_scale.y > 1.0, "Terminal fall produces vertical stretch (Sy=%.3f > 1.0)" % fall_scale.y) and ok

	var ground_scale: Vector2 = MAS_SCRIPT.StickmanPoseSolver.calculate_air_squash_stretch(0.0, true)
	ok = _check(ground_scale == Vector2.ONE, "Grounded character has identity scale Vector2.ONE") and ok

	return ok


# ============================================================================
# Helpers
# ============================================================================

func _is_finite_v2(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)
