extends SceneTree

## Challenger M2.1 Adversarial Stress Test Suite
## Comprehensive adversarial stress-testing of StickmanProcedural:
## - scripts/stickman/stickmanprocedural.gd
## - scenes/stickman/stickmanprocedural.tscn
##
## Validates:
## 1. Velocity extremes (subnormal, massive, astronomical, Inf, NaN, negative zero)
## 2. Delta time anomalies (zero, negative, picosecond, frame drop, huge, Inf, NaN)
## 3. High-frequency facing direction inversions & degenerate facing inputs
## 4. Non-standard, malicious, unicode, and ultra-long state strings
## 5. to_stickman_pose contract, data integrity, and simulation coordinate space (+Y UP)
## 6. Autonomous physics parameters & state machine transitions
## 7. Export property tampering & self-healing resilience
## 8. Skeleton2D CCDIK live solver convergence & bone transform finiteness
## 9. Bare script instantiation lifecycle (StickmanProcedural.new() without scene)
## 10. Multi-instance churn, isolation, and orphan node leak prevention

const SCENE_PATH: String = "res://scenes/stickman/stickmanprocedural.tscn"
const MAS_SCRIPT = preload("res://scripts/modular_rig/modular_asset_system.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _assertion_count: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("======================================================================")
	print("=== CHALLENGER M2.1 ADVERSARIAL STRESS SUITE: PROCEDURAL STICKMAN ===")
	print("======================================================================")

	_run_test("test_01_velocity_extremes_and_special_floats", test_01_velocity_extremes_and_special_floats)
	_run_test("test_02_delta_time_boundaries_and_corruption", test_02_delta_time_boundaries_and_corruption)
	_run_test("test_03_high_frequency_facing_inversions_and_mirroring", test_03_high_frequency_facing_inversions_and_mirroring)
	_run_test("test_04_nonstandard_and_malicious_state_strings", test_04_nonstandard_and_malicious_state_strings)
	_run_test("test_05_to_stickman_pose_contract_and_coords", test_05_to_stickman_pose_contract_and_coords)
	_run_test("test_06_autonomous_physics_and_state_logic", test_06_autonomous_physics_and_state_logic)
	_run_test("test_07_property_tampering_and_healing", test_07_property_tampering_and_healing)
	_run_test("test_08_skeleton2d_ccdik_bone_transforms", test_08_skeleton2d_ccdik_bone_transforms)
	_run_test("test_09_bare_script_lifecycle_resilience", test_09_bare_script_lifecycle_resilience)
	_run_test("test_10_multi_instance_churn_and_orphan_hygiene", test_10_multi_instance_churn_and_orphan_hygiene)

	print("======================================================================")
	print("=== CHALLENGER M2.1 SUMMARY: %d / %d PASSED (%d FAILED, %d ASSERTIONS) ===" % [
		_tests_passed, _tests_run, _tests_failed, _assertion_count
	])
	print("======================================================================")

	if _tests_failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### CHALLENGER M2.1 VERDICT: APPROVE - ALL ADVERSARIAL CHECKS PASSED")
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
# 1. Extreme Velocities & Floating-Point Special Values
# ============================================================================

func test_01_velocity_extremes_and_special_floats() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	ok = _check(rig != null, "Spawn rig succeeded") and ok
	if rig == null:
		return false

	var chaotic_velocities: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-0.0, -0.0),
		Vector2(1e-38, 1e-38),
		Vector2(-1e-38, 0.0),
		Vector2(260.0, 0.0),
		Vector2(-260.0, 0.0),
		Vector2(0.0, -480.0),
		Vector2(0.0, 900.0),
		Vector2(100000.0, -100000.0),
		Vector2(-100000.0, 100000.0),
		Vector2(1e30, 0.0),
		Vector2(0.0, 1e30),
		Vector2(-1e30, -1e30),
		Vector2(INF, 0.0),
		Vector2(0.0, -INF),
		Vector2(INF, INF),
		Vector2(-INF, -INF),
		Vector2(NAN, 0.0),
		Vector2(0.0, NAN),
		Vector2(NAN, NAN),
		Vector2(NAN, INF),
		Vector2(-INF, NAN)
	]

	for vel in chaotic_velocities:
		for grounded in [true, false]:
			rig.update_procedural_animation(vel, grounded, 1.0, "run" if grounded else "jump", 0.016)

			# Gait phase must strictly remain finite and within [0.0, 1.0)
			ok = _check(is_finite(rig.phase), "Phase is finite for vel %s" % str(vel)) and ok
			ok = _check(rig.phase >= 0.0 and rig.phase < 1.0, "Phase in [0, 1) on vel %s (got %f)" % [str(vel), rig.phase]) and ok

			# All IK targets must have finite positions
			var targets: Dictionary = rig.get_ik_targets()
			for t_name in targets:
				var t_node: Node2D = targets[t_name] as Node2D
				ok = _check(t_node != null and _is_finite_v2(t_node.position),
					"Target '%s' finite on vel %s (pos=%s)" % [t_name, str(vel), str(t_node.position if t_node else Vector2.ZERO)]) and ok

			# All live bones must have finite local positions
			var bones: Dictionary = rig.get_bone_positions()
			for b_name in bones:
				var b_pos: Vector2 = bones[b_name] as Vector2
				ok = _check(_is_finite_v2(b_pos), "Bone '%s' finite on vel %s (pos=%s)" % [b_name, str(vel), str(b_pos)]) and ok

	# Test recovery: after feeding pure NaNs, feed valid motion and verify full convergence
	for step in range(15):
		rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)

	for t_name in rig.get_ik_targets():
		var t_node: Node2D = rig.get_ik_targets()[t_name] as Node2D
		ok = _check(_is_finite_v2(t_node.position), "Post-recovery target '%s' is finite" % t_name) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 2. Delta Time Boundaries & Corruption Matrix
# ============================================================================

func test_02_delta_time_boundaries_and_corruption() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	var anomalous_deltas: Array[float] = [
		0.0,
		-0.0,
		-0.000001,
		-0.0166667,
		-1.0,
		-100.0,
		-1e20,
		1e-30,
		1e-15,
		0.00001,
		0.001,
		0.0166667,
		0.0333333,
		0.25,
		1.0,
		10.0,
		60.0,
		3600.0,
		1e15,
		1e30,
		INF,
		-INF,
		NAN
	]

	for dt in anomalous_deltas:
		rig.update_procedural_animation(Vector2(250.0, 0.0), true, 1.0, "run", dt)

		ok = _check(is_finite(rig.phase), "Phase remains finite on dt=%f" % dt) and ok
		ok = _check(rig.phase >= 0.0 and rig.phase < 1.0, "Phase in [0, 1) on dt=%f (got %f)" % [dt, rig.phase]) and ok

		for t_name in rig.get_ik_targets():
			var t_node: Node2D = rig.get_ik_targets()[t_name] as Node2D
			ok = _check(t_node != null and _is_finite_v2(t_node.position),
				"Target '%s' position finite on dt=%f (pos=%s)" % [t_name, dt, str(t_node.position if t_node else Vector2.ZERO)]) and ok

	# Verify recovery to normal cadence
	for _i in range(10):
		rig.update_procedural_animation(Vector2(260.0, 0.0), true, 1.0, "run", 0.016)

	ok = _check(rig.phase >= 0.0 and rig.phase < 1.0, "Phase valid post-recovery") and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 3. High-Frequency Facing Inversions & Mirroring Invariant
# ============================================================================

func test_03_high_frequency_facing_inversions_and_mirroring() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	# 1. 500-cycle high-frequency rapid direction flips
	var facing_inputs: Array[float] = [1.0, -1.0, 0.5, -0.5, 0.0, 100.0, -100.0, 1e-10, -1e-10, INF, -INF, NAN]
	for i in range(500):
		var dir_in: float = facing_inputs[i % facing_inputs.size()]
		var state: String = "run" if (i % 3 != 0) else "slash"
		rig.update_procedural_animation(Vector2(200.0 * (1.0 if i % 2 == 0 else -1.0), 0.0), true, dir_in, state, 0.016)

		# Rig facing invariant: MUST be strictly +1.0 or -1.0 at all times
		ok = _check(is_finite(rig.facing), "Cycle %d: Facing is finite (%f)" % [i, rig.facing]) and ok
		ok = _check(rig.facing == 1.0 or rig.facing == -1.0, "Cycle %d: Facing is strictly +/-1.0 (got %f on input %f)" % [i, rig.facing, dir_in]) and ok

		var pose = rig.to_stickman_pose()
		ok = _check(pose != null and _is_finite_v2(pose.head_center), "Cycle %d: Pose finite during rapid flip" % i) and ok

	# 2. Mathematical Mirroring Symmetry Check
	# Hip center reference is HIP_REST_X (284.51)
	var hip_center_x: float = StickmanProcedural.HIP_REST_X

	# Settle right-facing idle
	for _i in range(30):
		rig.update_procedural_animation(Vector2.ZERO, true, 1.0, "idle", 0.033)
	var right_targets: Dictionary = {}
	for k in rig.get_ik_targets():
		right_targets[k] = (rig.get_ik_targets()[k] as Node2D).position

	# Settle left-facing idle
	for _i in range(30):
		rig.update_procedural_animation(Vector2.ZERO, true, -1.0, "idle", 0.033)
	var left_targets: Dictionary = {}
	for k in rig.get_ik_targets():
		left_targets[k] = (rig.get_ik_targets()[k] as Node2D).position

	for k in right_targets:
		var r_pos: Vector2 = right_targets[k] as Vector2
		var l_pos: Vector2 = left_targets[k] as Vector2
		var expected_mirrored_x: float = hip_center_x - (r_pos.x - hip_center_x)
		ok = _check(is_equal_approx(l_pos.x, expected_mirrored_x),
			"Mirroring check for target '%s': right.x=%f, left.x=%f, expected=%f" % [k, r_pos.x, l_pos.x, expected_mirrored_x]) and ok
		ok = _check(is_equal_approx(r_pos.y, l_pos.y),
			"Y invariance for target '%s': right.y=%f, left.y=%f" % [k, r_pos.y, l_pos.y]) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 4. Non-Standard, Malicious, and Degenerate State Strings
# ============================================================================

func test_04_nonstandard_and_malicious_state_strings() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	var malicious_states: Array[String] = [
		"",
		" ",
		"   \t\n\r   ",
		"IDLE",
		"RUN",
		"JUMP",
		"undefined",
		"null",
		"None",
		"0",
		"-1",
		"true",
		"false",
		"DROP TABLE poses;--",
		"%s%s%s%s%n%d%f",
		"__init__",
		"eval()",
		"🔥⚡🛡️🗡️",
		"a".repeat(1000),
		"a".repeat(10000),
		"wall_slide_hidden_payload",
		"heavy_slash_overdrive_super_combo"
	]

	for state in malicious_states:
		for facing in [1.0, -1.0]:
			rig.update_procedural_animation(Vector2(120.0 * facing, 0.0), true, facing, state, 0.016)

			ok = _check(rig.current_anim_state == state, "State accurately retained for '%s'" % state.substr(0, 20)) and ok
			ok = _check(is_finite(rig.phase), "Phase finite on state '%s'" % state.substr(0, 20)) and ok

			# Targets must remain finite
			for t_name in rig.get_ik_targets():
				var t_node: Node2D = rig.get_ik_targets()[t_name] as Node2D
				ok = _check(_is_finite_v2(t_node.position), "Target '%s' finite on state '%s'" % [t_name, state.substr(0, 20)]) and ok

			# to_stickman_pose must handle without crash
			var pose = rig.to_stickman_pose(facing)
			ok = _check(pose != null, "to_stickman_pose non-null on state '%s'" % state.substr(0, 20)) and ok
			if pose != null:
				ok = _check(pose.stance == state, "pose.stance matches state '%s'" % state.substr(0, 20)) and ok
				ok = _check(_is_finite_v2(pose.head_center), "pose.head_center finite") and ok
				ok = _check(_is_finite_v2(pose.sword_tip), "pose.sword_tip finite") and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 5. to_stickman_pose Contract, Coordinate Spaces, and Props
# ============================================================================

func test_05_to_stickman_pose_contract_and_coords() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	# Settle animation across multiple standard stances
	var stances: Array[String] = [
		"idle", "run", "walk", "jump", "fall", "air", "wall_slide", "slash", "heavy_slash", "parry_guard"
	]

	var facing_test_cases: Array[float] = [
		1.0, -1.0, 0.0, -0.0, 10.0, -10.0, 0.5, -0.5, INF, -INF, NAN
	]

	for stance in stances:
		rig.update_procedural_animation(Vector2(200.0, 0.0), stance in ["idle", "run", "walk"], 1.0, stance, 0.016)

		for f_arg in facing_test_cases:
			var pose = rig.to_stickman_pose(f_arg)
			ok = _check(pose != null, "to_stickman_pose returned non-null for stance '%s', f_arg=%f" % [stance, f_arg]) and ok
			if pose == null:
				continue

			ok = _check(pose.get_script() == MAS_SCRIPT.StickmanPose, "Pose is instance of ModularAssetSystem.StickmanPose") and ok

			# Check all 15 joint positions are finite
			var joints: Array[Vector2] = [
				pose.head_center, pose.neck, pose.pelvis,
				pose.left_shoulder, pose.left_elbow, pose.left_hand,
				pose.right_shoulder, pose.right_elbow, pose.right_hand,
				pose.left_hip, pose.left_knee, pose.left_foot,
				pose.right_hip, pose.right_knee, pose.right_foot,
				pose.sword_hilt, pose.sword_tip
			]

			for j in joints:
				ok = _check(_is_finite_v2(j), "Joint %s is finite on stance '%s'" % [str(j), stance]) and ok

			# Check scarf nodes
			ok = _check(pose.scarf_nodes.size() == 3, "Scarf nodes count is exactly 3 (got %d)" % pose.scarf_nodes.size()) and ok
			for sn in pose.scarf_nodes:
				ok = _check(_is_finite_v2(sn), "Scarf node %s is finite on stance '%s'" % [str(sn), stance]) and ok

			# Simulation space orientation: +Y is UP
			# In simulation space, head_center.y > neck.y > pelvis.y
			ok = _check(pose.head_center.y > pose.neck.y,
				"Simulation coordinate: head_center.y (%f) > neck.y (%f)" % [pose.head_center.y, pose.neck.y]) and ok
			ok = _check(pose.neck.y > pose.pelvis.y,
				"Simulation coordinate: neck.y (%f) > pelvis.y (%f)" % [pose.neck.y, pose.pelvis.y]) and ok

			# Sword tip offset check: sword_tip must differ from sword_hilt
			ok = _check(pose.sword_tip != pose.sword_hilt, "Sword tip has non-zero length relative to hilt") and ok
			ok = _check(pose.sword_tip.distance_to(pose.sword_hilt) > 10.0,
				"Sword length > 10px (got %f)" % pose.sword_tip.distance_to(pose.sword_hilt)) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 6. Autonomous Physics Parameters & State Machine
# ============================================================================

func test_06_autonomous_physics_and_state_logic() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	# Validate configuration defaults
	ok = _check(rig.autonomous_physics == false, "autonomous_physics defaults to false for packed rig") and ok
	ok = _check(rig.move_speed > 0.0, "move_speed is positive (%f)" % rig.move_speed) and ok
	ok = _check(rig.acceleration > 0.0, "acceleration is positive (%f)" % rig.acceleration) and ok
	ok = _check(rig.deceleration > 0.0, "deceleration is positive (%f)" % rig.deceleration) and ok
	ok = _check(rig.gravity > 0.0, "gravity is positive (%f)" % rig.gravity) and ok
	ok = _check(rig.jump_velocity < 0.0, "jump_velocity is negative upwards (%f)" % rig.jump_velocity) and ok
	ok = _check(rig.maximum_fall_speed > 0.0, "maximum_fall_speed is positive (%f)" % rig.maximum_fall_speed) and ok

	# Test velocity transition computation directly
	var test_vels: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(10.0, 0.0),
		Vector2(25.0, 0.0),
		Vector2(-250.0, 0.0),
		Vector2(0.0, -100.0),
		Vector2(100.0, 500.0)
	]

	for v in test_vels:
		for on_floor in [true, false]:
			var computed_state: String = "run" if (on_floor and absf(v.x) > 20.0) else ("air" if not on_floor else "idle")
			rig.update_procedural_animation(v, on_floor, 1.0 if v.x >= 0.0 else -1.0, computed_state, 0.016)

			ok = _check(rig.current_anim_state == computed_state, "Computed state '%s' tracked" % computed_state) and ok
			ok = _check(is_finite(rig.phase), "Phase finite during state transitions") and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 7. Property Tampering & Self-Healing Resilience
# ============================================================================

func test_07_property_tampering_and_healing() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	# Tamper stride_length
	rig.stride_length = 0.0
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "stride_length=0.0 handled safely") and ok

	rig.stride_length = -100.0
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "Negative stride_length handled safely") and ok

	rig.stride_length = INF
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "INF stride_length handled safely") and ok

	rig.stride_length = 52.0 # restore

	# Tamper move_speed
	rig.move_speed = 0.0
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "move_speed=0.0 handled safely") and ok

	rig.move_speed = -500.0
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "Negative move_speed handled safely") and ok
	rig.move_speed = 260.0 # restore

	# Tamper snappiness
	rig.snappiness = 0.0
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	for t in rig.get_ik_targets().values():
		ok = _check(_is_finite_v2((t as Node2D).position), "snappiness=0.0 targets finite") and ok

	rig.snappiness = -20.0
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	for t in rig.get_ik_targets().values():
		ok = _check(_is_finite_v2((t as Node2D).position), "Negative snappiness handled safely") and ok

	rig.snappiness = 1e6
	rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)
	for t in rig.get_ik_targets().values():
		ok = _check(_is_finite_v2((t as Node2D).position), "Astronomical snappiness handled safely") and ok
	rig.snappiness = 18.0 # restore

	# Deliberate corruption of IK Target node positions to NaN (simulating external engine corruption)
	for t in rig.get_ik_targets().values():
		(t as Node2D).position = Vector2(NAN, NAN)

	# Next animation step MUST self-heal targets back to finite base_rest
	rig.update_procedural_animation(Vector2(100.0, 0.0), true, 1.0, "idle", 0.016)
	for t_name in rig.get_ik_targets():
		var t_pos: Vector2 = (rig.get_ik_targets()[t_name] as Node2D).position
		ok = _check(_is_finite_v2(t_pos), "Self-healing recovered corrupted target '%s' to finite position (%s)" % [t_name, str(t_pos)]) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 8. Skeleton2D CCDIK Bone Transforms Finiteness
# ============================================================================

func test_08_skeleton2d_ccdik_bone_transforms() -> bool:
	var ok: bool = true
	var rig: StickmanProcedural = _spawn_rig()
	if rig == null:
		return false

	var skeleton: Skeleton2D = rig.get_node_or_null("Rig/Bones/Skeleton2D") as Skeleton2D
	ok = _check(skeleton != null, "Skeleton2D located") and ok
	if skeleton == null:
		_free_rig(rig)
		return false

	# Drive 100 simulation frames with alternating movements to exercise CCDIK modification stack
	for frame in range(100):
		var vx: float = sin(frame * 0.1) * 300.0
		var vy: float = cos(frame * 0.05) * 400.0
		var facing_val: float = 1.0 if vx >= 0.0 else -1.0
		var is_ground: bool = (vy >= 0.0)
		var state: String = "run" if (is_ground and absf(vx) > 20.0) else ("jump" if not is_ground else "idle")

		rig.update_procedural_animation(Vector2(vx, vy), is_ground, facing_val, state, 0.016)

		# Inspect all bone positions returned by get_bone_positions()
		var bones: Dictionary = rig.get_bone_positions()
		ok = _check(bones.size() >= 18, "Frame %d: get_bone_positions returns at least 18 bones" % frame) and ok
		for b_name in bones:
			var b_pos: Vector2 = bones[b_name] as Vector2
			ok = _check(_is_finite_v2(b_pos), "Frame %d: Bone '%s' pos %s is finite" % [frame, b_name, str(b_pos)]) and ok

	_free_rig(rig)
	return ok


# ============================================================================
# 9. Bare Script Lifecycle Resilience (StickmanProcedural.new())
# ============================================================================

func test_09_bare_script_lifecycle_resilience() -> bool:
	var ok: bool = true

	# What if caller instantiates the script directly without the scene nodes?
	var bare_rig: StickmanProcedural = StickmanProcedural.new()
	ok = _check(bare_rig != null, "StickmanProcedural.new() creates instance") and ok
	if bare_rig == null:
		return false

	# Must not crash when called on bare unmounted instance
	bare_rig.update_procedural_animation(Vector2(100.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(bare_rig.phase), "Bare rig phase is finite") and ok

	var bones: Dictionary = bare_rig.get_bone_positions()
	ok = _check(bones.is_empty(), "Bare rig get_bone_positions() returns empty dictionary gracefully") and ok

	var ik_targets: Dictionary = bare_rig.get_ik_targets()
	ok = _check(ik_targets.size() == 5, "Bare rig get_ik_targets() returns target structure") and ok

	var pose = bare_rig.to_stickman_pose(1.0)
	ok = _check(pose != null, "Bare rig to_stickman_pose() returns fallback StickmanPose") and ok
	if pose != null:
		ok = _check(_is_finite_v2(pose.head_center), "Bare rig pose.head_center finite") and ok

	bare_rig.free()
	ok = _check(not is_instance_valid(bare_rig), "Bare rig freed cleanly") and ok

	return ok


# ============================================================================
# 10. Multi-Instance Churn & Orphan Node Hygiene
# ============================================================================

func test_10_multi_instance_churn_and_orphan_hygiene() -> bool:
	var ok: bool = true
	var initial_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var active_rigs: Array[StickmanProcedural] = []

	# Instantiate 15 rigs in parallel
	for i in range(15):
		var rig := _spawn_rig()
		ok = _check(rig != null, "Multi-rig %d instantiated" % i) and ok
		if rig != null:
			active_rigs.append(rig)

	# Run distinct adversarial profiles across all rigs
	for step in range(50):
		for idx in range(active_rigs.size()):
			var rig: StickmanProcedural = active_rigs[idx]
			var dir: float = 1.0 if (idx % 2 == 0) else -1.0
			var speed: float = 150.0 + idx * 20.0
			var state: String = "run" if (step % 2 == 0) else "slash"
			rig.update_procedural_animation(Vector2(speed * dir, 0.0), true, dir, state, 0.016)

			var pose = rig.to_stickman_pose(dir)
			ok = _check(pose != null and _is_finite_v2(pose.head_center),
				"Multi-rig %d step %d pose finite" % [idx, step]) and ok

	# Free first 7 rigs
	for _k in range(7):
		var rig = active_rigs.pop_front()
		_free_rig(rig)

	# Instantiate 7 replacement rigs
	for _k in range(7):
		var rig := _spawn_rig()
		if rig != null:
			active_rigs.append(rig)

	# Teardown all remaining rigs
	for rig in active_rigs:
		_free_rig(rig)

	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	ok = _check(final_orphans <= initial_orphans,
		"No orphan node leakage during churn (initial=%d, final=%d)" % [initial_orphans, final_orphans]) and ok

	return ok
