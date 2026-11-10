extends SceneTree

## Challenger M3.2 Adversarial Verification & Stress Test Suite
## Focus: Empirical stress-testing of Milestone 3 Global Procedural Stickman Coverage:
## 1. Benchmark live frame rendering: 500 frames of full gameplay simulation with active player,
##    enemies, clones (Chrono-Echoes), and ragdolls in headless Godot (per-frame entity render overhead < 0.5 ms).
## 2. Invariant fuzzing: Pass corrupt/extreme velocities (+-100,000), NaN dt, and zero vectors into
##    apply_archetype_configuration, apply_aim_offsets, apply_hitstun_offsets, and generate_ragdoll_pose.
##    Ensure 100% finite results without crashes.
## 3. Distance-accumulated ghost spawning under extreme time dilation (Gear 6, 0.04x speed vs Gear 1).
## 4. Live rig to_stickman_pose coordinate parity (+Y UP) and echo rig pool integrity.

const ModularRig = preload("res://scripts/modular_rig/modular_asset_system.gd")
const RigScene = preload("res://scenes/stickman/stickmanprocedural.tscn")
const TimelineSys = preload("res://scripts/timeline/timeline_system.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _assertions_passed: int = 0
var _defects: Array[String] = []


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	print("======================================================================")
	print("=== CHALLENGER M3.2 ADVERSARIAL STRESS SUITE: GLOBAL M3 COVERAGE   ===")
	print("======================================================================")

	_run_test("test_01_benchmark_live_frame_rendering_500_frames", test_01_benchmark_live_frame_rendering_500_frames)
	_run_test("test_02_invariant_fuzzing_archetype_configuration", test_02_invariant_fuzzing_archetype_configuration)
	_run_test("test_03_invariant_fuzzing_aim_and_hitstun_offsets", test_03_invariant_fuzzing_aim_and_hitstun_offsets)
	_run_test("test_04_invariant_fuzzing_procedural_ragdoll_pose_solver", test_04_invariant_fuzzing_procedural_ragdoll_pose_solver)
	_run_test("test_05_invariant_fuzzing_generate_stickman_pose_extremes", test_05_invariant_fuzzing_generate_stickman_pose_extremes)
	_run_test("test_06_distance_accumulated_ghosts_extreme_dilation", test_06_distance_accumulated_ghosts_extreme_dilation)
	_run_test("test_07_live_rig_to_sim_pose_and_echo_pool_integrity", test_07_live_rig_to_sim_pose_and_echo_pool_integrity)

	print("======================================================================")
	print("=== CHALLENGER M3.2 SUMMARY: %d passed, %d failed (%d assertions) ===" % [_tests_passed, _tests_failed, _assertions_passed])
	print("======================================================================")

	if _tests_failed > 0:
		for d in _defects:
			printerr("  [DEFECT] " + d)
		print("### CHALLENGER M3.2 VERDICT: REQUEST_CHANGES - DEFECTS FOUND")
		quit(1)
	else:
		print("### CHALLENGER M3.2 VERDICT: APPROVE - ALL ADVERSARIAL CHALLENGES PASSED")
		quit(0)


func _run_test(test_name: String, test_fn: Callable) -> void:
	_tests_run += 1
	var success: bool = test_fn.call()
	if success:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		_defects.append(test_name)
		printerr("  [FAIL] %s" % test_name)


func _check(cond: bool, msg: String) -> bool:
	if cond:
		_assertions_passed += 1
		return true
	printerr("    FAIL: %s" % msg)
	return false


func _spawn_main_scene() -> GameController:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	var ctrl: GameController = inst as GameController
	ctrl._ensure_scene_nodes()
	return ctrl


func _cleanup_scene(ctrl: GameController) -> void:
	if ctrl != null:
		if ctrl.get_parent() != null:
			ctrl.get_parent().remove_child(ctrl)
		for erig in ctrl._echo_rig_pool:
			if erig != null and is_instance_valid(erig):
				erig.free()
		ctrl._echo_rig_pool.clear()
		ctrl.free()


# ---------------------------------------------------------------------------------------------
# Task 1: Benchmark live frame rendering (< 0.5 ms entity render overhead over 500 frames)
# ---------------------------------------------------------------------------------------------

func test_01_benchmark_live_frame_rendering_500_frames() -> bool:
	print("  --> Benchmarking live frame rendering (500 frames in headless Godot)...")
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	# Active battle scenario: 1 live player, 1 active enemy (runner), 1 Chrono-Echo, 2 severed ragdoll pieces
	ctrl.enemies.clear()
	ctrl.enemies.append(EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(100.0, -260.0), TimelineSys.TimelineEra.PRESENT))

	ctrl.timeline.echoes.clear()
	ctrl.timeline.spawn_chrono_echo(
		Vector2(50.0, -240.0),
		Vector2.RIGHT,
		TimelineSys.TimelineEra.PRESENT,
		"slash",
		95.0,
		3.0,
		1.0,
		Vector2(120.0, 0.0),
		true,
		"normal",
		0.15,
		"player_shift_staff"
	)

	ctrl.ragdolls.clear()
	var r_upper := RagdollPhysics.RagdollPieceData.new(
		RagdollPhysics.RagdollPart.UPPER_TORSO,
		Vector2(200.0, -200.0),
		Vector2(50.0, 80.0),
		2.5,
		1.0,
		Color.ORANGE,
		"enemy_heavy"
	)
	var r_lower := RagdollPhysics.RagdollPieceData.new(
		RagdollPhysics.RagdollPart.LOWER_LEGS,
		Vector2(200.0, -220.0),
		Vector2(-40.0, 60.0),
		-3.0,
		1.0,
		Color.ORANGE,
		"enemy_heavy"
	)
	ctrl.ragdolls.append(r_upper)
	ctrl.ragdolls.append(r_lower)

	for i in range(2):
		ctrl.bullets.append(CombatMath.BulletData.new(
			Vector2(float(i) * 50.0, -220.0),
			Vector2(-350.0, 0.0),
			6.0,
			20.0,
			2.0,
			false,
			1,
			TimelineSys.TimelineEra.PRESENT
		))

	for i in range(6):
		ctrl.particles.append(RagdollPhysics.SliceParticleData.new(
			Vector2(float(i) * 15.0, -240.0),
			Vector2(float(i - 3) * 30.0, 20.0),
			0.35,
			3.0,
			Color.RED
		))

	# Warm up 50 frames
	for _w in range(50):
		ctrl.step_simulation(0.016, {"move_x": 0.5})
		ctrl._draw()

	const TOTAL_BENCHMARK_FRAMES: int = 500
	var sim_times_usec: Array[int] = []
	var draw_times_usec: Array[int] = []
	sim_times_usec.resize(TOTAL_BENCHMARK_FRAMES)
	draw_times_usec.resize(TOTAL_BENCHMARK_FRAMES)

	for f in range(TOTAL_BENCHMARK_FRAMES):
		var t_s0 := Time.get_ticks_usec()
		ctrl.step_simulation(0.016, {"move_x": 1.0 if (f % 60 < 30) else -1.0})
		var t_s1 := Time.get_ticks_usec()
		sim_times_usec[f] = int(t_s1 - t_s0)

		var t_d0 := Time.get_ticks_usec()
		ctrl._draw()
		var t_d1 := Time.get_ticks_usec()
		draw_times_usec[f] = int(t_d1 - t_d0)

	var total_draw_usec: int = 0
	for dt_u in draw_times_usec:
		total_draw_usec += dt_u
	var full_draw_avg_ms: float = (float(total_draw_usec) / float(TOTAL_BENCHMARK_FRAMES)) / 1000.0

	# Measure baseline environment (no enemies, echoes, or ragdolls) to isolate entity render overhead
	ctrl.enemies.clear()
	ctrl.timeline.echoes.clear()
	ctrl.ragdolls.clear()
	var base_draw_usec: int = 0
	for f in range(TOTAL_BENCHMARK_FRAMES):
		var t_b0 := Time.get_ticks_usec()
		ctrl._draw()
		var t_b1 := Time.get_ticks_usec()
		base_draw_usec += int(t_b1 - t_b0)
	var base_draw_avg_ms: float = (float(base_draw_usec) / float(TOTAL_BENCHMARK_FRAMES)) / 1000.0

	var entity_render_overhead_ms: float = full_draw_avg_ms - base_draw_avg_ms
	var active_entity_count: int = 1 + 1 + 2 # 1 enemy + 1 echo + 2 ragdolls = 4 stickmen
	var per_entity_overhead_ms: float = entity_render_overhead_ms / float(active_entity_count)

	print("    [BENCHMARK RESULT] 500 frames:")
	print("      - Full battle scene _draw avg:       %.4f ms / frame" % full_draw_avg_ms)
	print("      - Baseline environment _draw avg:   %.4f ms / frame" % base_draw_avg_ms)
	print("      - Additional entity render overhead: %.4f ms / frame (across %d stickmen entities)" % [entity_render_overhead_ms, active_entity_count])
	print("      - Per-entity procedural render cost: %.4f ms / entity (< 0.15 ms/entity)" % per_entity_overhead_ms)

	ok = ok and _check(entity_render_overhead_ms < 0.50, "Additional stickman entity render overhead is strictly < 0.5 ms (actual: %.4f ms)" % entity_render_overhead_ms)
	ok = ok and _check(per_entity_overhead_ms < 0.15, "Per-entity procedural render cost is < 0.15 ms (actual: %.4f ms)" % per_entity_overhead_ms)

	# Direct StickmanPoseSolver micro-benchmark (1,000 steps)
	var dyn_ctx := ModularRig.PoseDynamicsContext.new()
	var t_solver_start := Time.get_ticks_usec()
	for i in range(1000):
		var _pose = ModularRig.StickmanPoseSolver.generate_stickman_pose(
			Vector2(100.0, 50.0), 1.0, Vector2(240.0, 0.0), true, float(i) * 0.016, false, 0.0, false, "normal", 0.0, dyn_ctx, 0.016
		)
	var solver_avg_ms: float = ((Time.get_ticks_usec() - t_solver_start) / 1000.0) / 1000.0
	print("      - PoseSolver.generate_stickman_pose: %.4f ms / call (< 0.05 ms)" % solver_avg_ms)
	ok = ok and _check(solver_avg_ms < 0.05, "PoseSolver.generate_stickman_pose is < 0.05 ms (actual: %.4f ms)" % solver_avg_ms)

	# Direct StickmanPoseSolver.generate_ragdoll_pose micro-benchmark (1,000 steps)
	var t_ragdoll_start := Time.get_ticks_usec()
	for i in range(1000):
		var _rpose = ModularRig.StickmanPoseSolver.generate_ragdoll_pose(
			Vector2(200.0, 100.0), float(i) * 0.05, 1.0, i % 2, "enemy_heavy"
		)
	var ragdoll_solver_avg_ms: float = ((Time.get_ticks_usec() - t_ragdoll_start) / 1000.0) / 1000.0
	print("      - PoseSolver.generate_ragdoll_pose:  %.4f ms / call (< 0.05 ms)" % ragdoll_solver_avg_ms)
	ok = ok and _check(ragdoll_solver_avg_ms < 0.05, "PoseSolver.generate_ragdoll_pose is < 0.05 ms (actual: %.4f ms)" % ragdoll_solver_avg_ms)

	_cleanup_scene(ctrl)
	return ok


# ---------------------------------------------------------------------------------------------
# Task 2: Invariant fuzzing on apply_archetype_configuration
# ---------------------------------------------------------------------------------------------

func test_02_invariant_fuzzing_archetype_configuration() -> bool:
	print("  --> Invariant fuzzing: apply_archetype_configuration...")
	var ok: bool = true
	var rig_packed: PackedScene = load(ModularRig.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH)
	ok = ok and _check(rig_packed != null, "Procedural stickman scene loaded")
	var rig_inst = rig_packed.instantiate()
	root.add_child(rig_inst)

	var fuzzed_scales: Array = [
		1.0, 1.35, 0.8, 0.0, -1.0, 100000.0, -100000.0,
		NAN, INF, -INF, 0.00001, 3.5
	]
	var fuzzed_colors: Array[Color] = [
		Color.WHITE,
		Color.RED,
		Color(NAN, NAN, NAN, NAN),
		Color(INF, -INF, 0.0, 1.0),
		Color(-1.0, 2.0, 50.0, -0.5),
		Color(0.2, 0.8, 0.45, 1.0)
	]
	var archetypes: Array[String] = [
		"runner", "ninja", "heavy", "gunner_semi", "gunner_auto", "sniper",
		"player", "unknown_bogus_archetype", ""
	]

	for s in fuzzed_scales:
		for c in fuzzed_colors:
			for arch in archetypes:
				rig_inst.apply_archetype_configuration(arch, c, s)
				var cur_scale: Vector2 = rig_inst.scale
				ok = ok and _check(cur_scale.is_finite(), "Rig scale remains finite for scale=%s" % str(s))
				ok = ok and _check(cur_scale.x > 0.0 and cur_scale.y > 0.0, "Rig scale remains positive for scale=%s" % str(s))

	# Step procedural animation after fuzzing to verify stability
	rig_inst.update_procedural_animation(Vector2(100000.0, -100000.0), true, 1.0, "run", 0.016)
	var bones: Dictionary = rig_inst.get_bone_positions()
	ok = ok and _check(not bones.is_empty(), "get_bone_positions populated after scale fuzzing")
	for b_name in bones.keys():
		var b_pos: Vector2 = bones[b_name]
		ok = ok and _check(b_pos.is_finite(), "Bone '%s' is finite" % b_name)

	root.remove_child(rig_inst)
	rig_inst.free()
	return ok


# ---------------------------------------------------------------------------------------------
# Task 2: Invariant fuzzing on apply_aim_offsets & apply_hitstun_offsets
# ---------------------------------------------------------------------------------------------

func test_03_invariant_fuzzing_aim_and_hitstun_offsets() -> bool:
	print("  --> Invariant fuzzing: apply_aim_offsets & apply_hitstun_offsets...")
	var ok: bool = true
	var rig_packed: PackedScene = load(ModularRig.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH)
	var rig_inst = rig_packed.instantiate()
	root.add_child(rig_inst)
	rig_inst._ensure_references()

	var fuzzed_facings: Array[float] = [
		1.0, -1.0, 0.0, 100000.0, -100000.0, NAN, INF, -INF
	]
	var fuzzed_velocities: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(100000.0, -100000.0),
		Vector2(-100000.0, 100000.0),
		Vector2(NAN, NAN),
		Vector2(INF, -INF),
		Vector2(-INF, INF)
	]
	var fuzzed_deltas: Array[float] = [
		0.0, 0.016, 1.0, 100.0, -0.016, NAN, INF, -INF
	]

	# Test 1: Invariant fuzzing through update_procedural_animation pipeline
	# Rig must self-heal corrupt facing/velocities/deltas and produce 100% finite aim & hitstun offsets
	for vel in fuzzed_velocities:
		for dt in fuzzed_deltas:
			for f in fuzzed_facings:
				rig_inst.update_procedural_animation(vel, true, f, "aim", dt)
				var aim_offsets := {}
				rig_inst.apply_aim_offsets(aim_offsets, false)
				ok = ok and _check(not aim_offsets.is_empty(), "apply_aim_offsets populated targets (vel=%s, dt=%s, facing=%s)" % [str(vel), str(dt), str(f)])
				for t in aim_offsets.keys():
					var off: Vector2 = aim_offsets[t]
					ok = ok and _check(off.is_finite(), "Aim offset is finite (facing_input=%s): %s" % [str(f), str(off)])

				rig_inst.update_procedural_animation(vel, true, f, "hitstun", dt)
				var hit_offsets := {}
				rig_inst.apply_hitstun_offsets(hit_offsets, false)
				ok = ok and _check(not hit_offsets.is_empty(), "apply_hitstun_offsets populated targets (vel=%s, dt=%s, facing=%s)" % [str(vel), str(dt), str(f)])
				for t in hit_offsets.keys():
					var off: Vector2 = hit_offsets[t]
					ok = ok and _check(off.is_finite(), "Hitstun offset is finite (facing_input=%s): %s" % [str(f), str(off)])

	# Test 2: Invariant fuzzing on direct method invocation with finite facings
	for f in [1.0, -1.0, 0.0, 100000.0, -100000.0]:
		rig_inst.facing = f
		for is_sniper in [false, true]:
			var offsets := {}
			rig_inst.apply_aim_offsets(offsets, is_sniper)
			for t in offsets.keys():
				var off: Vector2 = offsets[t]
				ok = ok and _check(off.is_finite(), "Aim offset is finite for finite facing=%s" % str(f))

		for is_juggled in [false, true]:
			var offsets := {}
			rig_inst.apply_hitstun_offsets(offsets, is_juggled)
			for t in offsets.keys():
				var off: Vector2 = offsets[t]
				ok = ok and _check(off.is_finite(), "Hitstun offset is finite for finite facing=%s" % str(f))

	# Test 3: Verify to_stickman_pose produces finite simulation poses (+Y UP) across all combat states
	for vel in fuzzed_velocities:
		for dt in fuzzed_deltas:
			for f in fuzzed_facings:
				for st in ["aim", "gunner_aim", "sniper_brace", "hitstun", "juggled", "downward_slam"]:
					rig_inst.update_procedural_animation(vel, true, f, st, dt)
					var pose: RefCounted = rig_inst.to_stickman_pose(f)
					ok = ok and _check(pose != null, "to_stickman_pose returned non-null pose under fuzz inputs")
					ok = ok and _check((pose.get("head_center") as Vector2).is_finite(), "Pose head_center is finite")
					ok = ok and _check((pose.get("pelvis") as Vector2).is_finite(), "Pose pelvis is finite")
					ok = ok and _check((pose.get("left_hand") as Vector2).is_finite(), "Pose left_hand is finite")

	root.remove_child(rig_inst)
	rig_inst.free()
	return ok


# ---------------------------------------------------------------------------------------------
# Task 2: Invariant fuzzing on generate_ragdoll_pose
# ---------------------------------------------------------------------------------------------

func test_04_invariant_fuzzing_procedural_ragdoll_pose_solver() -> bool:
	print("  --> Invariant fuzzing: generate_ragdoll_pose...")
	var ok: bool = true

	var fuzzed_positions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(200.0, 100.0),
		Vector2(100000.0, -100000.0),
		Vector2(-100000.0, 100000.0),
		Vector2(NAN, NAN),
		Vector2(INF, -INF),
		Vector2(-INF, INF)
	]
	var fuzzed_rotations: Array[float] = [
		0.0, 0.785, PI, TAU * 20.0, 100000.0, -100000.0, NAN, INF, -INF
	]
	var fuzzed_facings: Array[float] = [
		1.0, -1.0, 0.0, 100000.0, -100000.0, NAN, INF, -INF
	]
	var parts: Array[int] = [0, 1, -1, 2, 999]
	var loadout_ids: Array[String] = [
		"enemy_heavy", "enemy_runner", "enemy_ninja", "enemy_sniper",
		"player_shift_staff", "unknown_id", ""
	]

	for pos in fuzzed_positions:
		for rot in fuzzed_rotations:
			for fac in fuzzed_facings:
				for part in parts:
					for lid in loadout_ids:
						var pose: ModularRig.StickmanPose = ModularRig.StickmanPoseSolver.generate_ragdoll_pose(
							pos, rot, fac, part, lid
						)
						ok = ok and _check(pose != null, "generate_ragdoll_pose returned valid pose")
						ok = ok and _check(pose.head_center.is_finite(), "ragdoll head_center is finite")
						ok = ok and _check(pose.neck.is_finite(), "ragdoll neck is finite")
						ok = ok and _check(pose.pelvis.is_finite(), "ragdoll pelvis is finite")
						ok = ok and _check(pose.left_shoulder.is_finite() and pose.right_shoulder.is_finite(), "ragdoll shoulders are finite")
						ok = ok and _check(pose.left_hand.is_finite() and pose.right_hand.is_finite(), "ragdoll hands are finite")
						ok = ok and _check(pose.left_knee.is_finite() and pose.right_knee.is_finite(), "ragdoll knees are finite")
						ok = ok and _check(pose.left_foot.is_finite() and pose.right_foot.is_finite(), "ragdoll feet are finite")
						ok = ok and _check(pose.sword_hilt.is_finite() and pose.sword_tip.is_finite(), "ragdoll sword is finite")

						for s_node in pose.scarf_nodes:
							ok = ok and _check(s_node.is_finite(), "ragdoll scarf node is finite")

						# Test slot transforms across all 20 PartSlots
						for slot_idx in range(20):
							var xf: Dictionary = ModularRig.StickmanPoseSolver.compute_slot_transform(pose, slot_idx, fac)
							var c: Vector2 = xf["center"]
							var a: float = float(xf["angle"])
							var l: float = float(xf["length"])
							ok = ok and _check(c.is_finite(), "Slot %d center is finite" % slot_idx)
							ok = ok and _check(is_finite(a), "Slot %d angle is finite" % slot_idx)
							ok = ok and _check(is_finite(l) and l > 0.0, "Slot %d length is finite and positive" % slot_idx)

	return ok


# ---------------------------------------------------------------------------------------------
# Task 2: Invariant fuzzing on generate_stickman_pose extremes
# ---------------------------------------------------------------------------------------------

func test_05_invariant_fuzzing_generate_stickman_pose_extremes() -> bool:
	print("  --> Invariant fuzzing: generate_stickman_pose with extreme kinematics...")
	var ok: bool = true

	var extreme_vels: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(100000.0, 0.0),
		Vector2(-100000.0, 0.0),
		Vector2(0.0, 100000.0),
		Vector2(0.0, -100000.0),
		Vector2(100000.0, -100000.0),
		Vector2(NAN, NAN),
		Vector2(INF, -INF),
	]
	var extreme_accels: Array[float] = [
		0.0, 3500.0, -3500.0, 100000.0, -100000.0, NAN, INF, -INF
	]
	var extreme_dts: Array[float] = [
		0.0, 0.016, 1.0, 1000.0, -1.0, NAN, INF
	]
	var stances: Array[String] = [
		"normal", "jump", "heavy_slash", "downward_slam", "parry_guard",
		"wall_slide", "slash", "ragdoll", "aim", "well_unlock", "invalid"
	]

	var dyn_ctx := ModularRig.PoseDynamicsContext.new()

	for vel in extreme_vels:
		for acc in extreme_accels:
			for dt in extreme_dts:
				for st in stances:
					var p: ModularRig.StickmanPose = ModularRig.StickmanPoseSolver.generate_stickman_pose(
						Vector2.ZERO,
						1.0,
						vel,
						true,
						0.1,
						false,
						0.0,
						false,
						st,
						acc,
						dyn_ctx,
						dt
					)
					ok = ok and _check(p != null, "generate_stickman_pose returned non-null pose")
					ok = ok and _check(p.head_center.is_finite(), "head_center is finite")
					ok = ok and _check(p.neck.is_finite(), "neck is finite")
					ok = ok and _check(p.pelvis.is_finite(), "pelvis is finite")
					ok = ok and _check(p.left_foot.is_finite() and p.right_foot.is_finite(), "feet are finite")
					ok = ok and _check(dyn_ctx.prev_velocity.is_finite(), "dyn_ctx.prev_velocity is finite")
					ok = ok and _check(is_finite(dyn_ctx.torso_lean_spring.value), "dyn_ctx torso_lean_spring.value is finite")

	return ok


# ---------------------------------------------------------------------------------------------
# Task 3: Distance-accumulated ghost spawning under extreme time dilation
# ---------------------------------------------------------------------------------------------

func test_06_distance_accumulated_ghosts_extreme_dilation() -> bool:
	print("  --> Validating distance-accumulated ghost spawning (Gear 6 0.04x vs Gear 1 1.0x)...")
	var ok: bool = true

	# 1. Gear 1 (Normal Dilation 1.0x)
	var ctrl1: GameController = _spawn_main_scene()
	ctrl1.ghost_trails.clear()
	ctrl1.step_simulation(0.016, {"dash": true, "move_x": 1.0})
	ok = ok and _check(ctrl1.player.dash_timer > 0.0, "Kinetic dash started in Gear 1")

	# Step through entire dash duration in Gear 1 (normal dt = 0.016)
	while ctrl1.player.dash_timer > 0.0:
		ctrl1.step_simulation(0.016, {"move_x": 1.0})

	var g1_ghosts: Array = ctrl1.ghost_trails.duplicate()
	print("    Gear 1 (1.0x speed): spawned %d ghosts across dash" % g1_ghosts.size())
	ok = ok and _check(g1_ghosts.size() >= 2, "Gear 1 spawned at least 2 ghosts across dash")

	# Check pairwise distances between consecutive ghosts in Gear 1
	for i in range(g1_ghosts.size() - 1):
		var g_a: GameController.GhostTrailData = g1_ghosts[i]
		var g_b: GameController.GhostTrailData = g1_ghosts[i + 1]
		var dist: float = (g_b.position - g_a.position).length()
		print("      Gear 1 Ghost[%d -> %d] distance: %.2f px" % [i, i + 1, dist])
		ok = ok and _check(dist >= 16.0, "Gear 1 ghost distance is >= 16.0 px (actual: %.2f)" % dist)

	_cleanup_scene(ctrl1)

	# 2. Gear 6 (Extreme Dilation 0.04x speed)
	var ctrl6: GameController = _spawn_main_scene()
	ctrl6.ghost_trails.clear()

	# Engage Gear 6
	ctrl6.shifter.model.knob = ChronoShiftModel.gear_pos(ChronoShiftModel.Gear.G6)
	ctrl6.shifter.model.set_target(ChronoShiftModel.Gear.G6)
	ctrl6.shifter.model.held = true
	ctrl6.chrono.slowmo_factor = 0.04
	ctrl6.chrono.is_dilating = true
	ctrl6.chrono.dilation_factor = 0.04

	ok = ok and _check(ctrl6.shifter.model.get_active_gear() == ChronoShiftModel.Gear.G6, "Gear 6 engaged in shifter model")
	ok = ok and _check(ctrl6.chrono.dilation_factor <= 0.05, "Chrono dilation factor plunged in Gear 6 (%.2fx)" % ctrl6.chrono.dilation_factor)

	# Start dash under extreme dilation
	ctrl6.step_simulation(0.016, {"dash": true, "move_x": 1.0})
	ok = ok and _check(ctrl6.player.dash_timer > 0.0, "Kinetic dash started in Gear 6")

	# Step with small simulation ticks (e.g. dt = 0.005s) to simulate high-frequency dilation sampling
	while ctrl6.player.dash_timer > 0.0:
		ctrl6.step_simulation(0.005, {"move_x": 1.0})

	var g6_ghosts: Array = ctrl6.ghost_trails.duplicate()
	print("    Gear 6 (0.04x speed): spawned %d ghosts across dash" % g6_ghosts.size())
	ok = ok and _check(g6_ghosts.size() >= 2, "Gear 6 spawned at least 2 ghosts across dash")

	# Check pairwise distances between consecutive ghosts in Gear 6:
	# Invariant: Distance-accumulated threshold guarantees ghosts DO NOT cluster/bunch up!
	for i in range(g6_ghosts.size() - 1):
		var g_a: GameController.GhostTrailData = g6_ghosts[i]
		var g_b: GameController.GhostTrailData = g6_ghosts[i + 1]
		var dist: float = (g_b.position - g_a.position).length()
		print("      Gear 6 Ghost[%d -> %d] distance: %.2f px" % [i, i + 1, dist])
		ok = ok and _check(dist >= 16.0, "Gear 6 ghost distance is >= 16.0 px (actual: %.2f)" % dist)

	# Verify spatial invariance: total ghosts between Gear 1 and Gear 6 is preserved
	var diff_count: int = abs(g6_ghosts.size() - g1_ghosts.size())
	ok = ok and _check(diff_count <= 1, "Ghost count is spatially invariant across dilation factors (Gear 1: %d, Gear 6: %d)" % [g1_ghosts.size(), g6_ghosts.size()])

	_cleanup_scene(ctrl6)
	return ok


# ---------------------------------------------------------------------------------------------
# Task 4: Live rig to_stickman_pose and echo rig pool integrity
# ---------------------------------------------------------------------------------------------

func test_07_live_rig_to_sim_pose_and_echo_pool_integrity() -> bool:
	print("  --> Validating live rig to_stickman_pose coordinate parity and rig pool...")
	var ok: bool = true
	var ctrl: GameController = _spawn_main_scene()

	# 1. Verify Player Procedural Rig existence and scale
	ok = ok and _check(ctrl.player_rig != null, "player_rig initialized in GameController")
	ok = ok and _check(ctrl.player_rig.visible == true, "player_rig is visible")
	ok = ok and _check(ctrl.player_rig.scale == Vector2(0.12, 0.12), "player_rig scaled to 0.12x")

	# 2. Verify _echo_rig_pool size and initial hidden state
	ok = ok and _check(ctrl._echo_rig_pool.size() == GameController.MAX_ECHO_RIGS, "_echo_rig_pool has %d rigs" % GameController.MAX_ECHO_RIGS)
	for i in range(ctrl._echo_rig_pool.size()):
		var erig = ctrl._echo_rig_pool[i]
		ok = ok and _check(erig != null and erig is StickmanProcedural, "Echo rig %d is StickmanProcedural" % i)
		ok = ok and _check(erig.visible == false, "Echo rig %d initially hidden" % i)

	# 3. Spawn 2 echoes and step simulation -> verify echo rigs activate
	ctrl.timeline.spawn_chrono_echo(
		Vector2(100.0, -220.0),
		Vector2(1.0, 0.0),
		TimelineSys.TimelineEra.PRESENT,
		"slash",
		95.0,
		3.0,
		1.0,
		Vector2(200.0, 0.0),
		true,
		"jump",
		0.2,
		"player_shift_staff"
	)
	ctrl.timeline.spawn_chrono_echo(
		Vector2(-100.0, -220.0),
		Vector2(-1.0, 0.0),
		TimelineSys.TimelineEra.PAST,
		"slash",
		95.0,
		3.0,
		-1.0,
		Vector2(-200.0, 0.0),
		true,
		"parry_guard",
		0.1,
		"player_shift_staff"
	)
	ctrl.step_simulation(0.016, {})

	ok = ok and _check(ctrl._echo_rig_pool[0].visible == true, "Echo rig 0 active and visible")
	ok = ok and _check(ctrl._echo_rig_pool[1].visible == true, "Echo rig 1 active and visible")
	ok = ok and _check(ctrl._echo_rig_pool[2].visible == false, "Echo rig 2 remains hidden (unoccupied)")

	# 4. Verify to_stickman_pose coordinate parity (+Y UP in sim)
	var live_pose = ctrl.player_rig.to_stickman_pose(ctrl.player.facing)
	ok = ok and _check(live_pose != null, "to_stickman_pose returned non-null pose")
	var hc: Vector2 = live_pose.head_center
	var nk: Vector2 = live_pose.neck
	var pv: Vector2 = live_pose.pelvis
	ok = ok and _check(hc.is_finite() and nk.is_finite() and pv.is_finite(), "Live pose joints are finite")
	ok = ok and _check(hc.y > nk.y and nk.y > pv.y, "Live pose maintains +Y UP simulation invariant (head.y: %.1f > neck.y: %.1f > pelvis.y: %.1f)" % [hc.y, nk.y, pv.y])

	_cleanup_scene(ctrl)
	return ok
