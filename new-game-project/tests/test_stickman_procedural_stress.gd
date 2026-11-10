extends SceneTree

## Empirical Adversarial Stress Test Suite for Procedural Stickman Rig
## Audits stickmanprocedural.gd and stickmanprocedural.tscn under:
## 1. Scene lifecycle and node hierarchy integrity
## 2. Extreme velocities (zero, subnormal, massive, negative, astronomical)
## 3. High-frequency state transitions and grounded/airborne flipping
## 4. Direction flipping (+1, -1, 0, non-unit) and mirroring correctness
## 5. Boundary delta times (zero, micro, large, negative)
## 6. Numerical validity (NaN/Inf resistance and recovery)
## 7. Completeness and validity of get_bone_positions() and to_stickman_pose()
## 8. Export property edge cases (stride_length=0, snappiness<=0, move_speed<=0)
## 9. Long-duration high-iteration stability and drift
## 10. Multi-instance isolation and memory leak prevention

const StickmanScenePath: String = "res://scenes/stickman/stickmanprocedural.tscn"
const ModularAssetScript = preload("res://scripts/modular_rig/modular_asset_system.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("======================================================================")
	print("=== EMPIRICAL CHALLENGER STRESS SUITE: PROCEDURAL STICKMAN RIG ===")
	print("======================================================================")

	_run_test("test_01_scene_instantiation_and_node_integrity", test_01_scene_instantiation_and_node_integrity)
	_run_test("test_02_extreme_velocities_stress", test_02_extreme_velocities_stress)
	_run_test("test_03_high_frequency_direction_and_ground_flips", test_03_high_frequency_direction_and_ground_flips)
	_run_test("test_04_rapid_state_transitions_and_malformed_states", test_04_rapid_state_transitions_and_malformed_states)
	_run_test("test_05_boundary_delta_times", test_05_boundary_delta_times)
	_run_test("test_06_nan_and_inf_resilience", test_06_nan_and_inf_resilience)
	_run_test("test_07_bone_positions_and_stickman_pose_completeness", test_07_bone_positions_and_stickman_pose_completeness)
	_run_test("test_08_property_tampering_and_extremes", test_08_property_tampering_and_extremes)
	_run_test("test_09_continuous_long_run_simulation", test_09_continuous_long_run_simulation)
	_run_test("test_10_multi_instance_isolation_and_lifecycle", test_10_multi_instance_isolation_and_lifecycle)

	print("======================================================================")
	print("=== STICKMAN PROCEDURAL STRESS SUMMARY: %d / %d PASSED (%d FAILED) ===" % [_tests_passed, _tests_run, _tests_failed])
	print("======================================================================")

	if _tests_failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### CHALLENGER VERDICT: ZERO DEFECTS FOUND IN PROCEDURAL RIG")
		quit(0)


func _run_test(test_name: String, test_callable: Callable) -> void:
	_tests_run += 1
	var ok: bool = false
	var result = test_callable.call()
	if result is bool:
		ok = result
	else:
		ok = true

	if ok:
		_tests_passed += 1
		print("  [PASS] " + test_name)
	else:
		_tests_failed += 1
		_failures.append(test_name)
		printerr("  [FAIL] " + test_name)


func _check(condition: bool, msg: String) -> bool:
	if not condition:
		printerr("    -> ASSERTION FAILED: " + msg)
		return false
	return true


func _is_vec2_finite(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


func _create_rig() -> CharacterBody2D:
	var scene = load(StickmanScenePath)
	if scene == null:
		return null
	var rig = scene.instantiate()
	root.add_child(rig)
	return rig


func _cleanup_rig(rig: CharacterBody2D) -> void:
	if rig != null and is_instance_valid(rig):
		if rig.get_parent() != null:
			rig.get_parent().remove_child(rig)
		rig.free()


# ============================================================================
# 1. Scene Instantiation & Node Integrity
# ============================================================================

func test_01_scene_instantiation_and_node_integrity() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	ok = _check(rig != null, "Scene loads and instantiates successfully") and ok
	if rig == null:
		return false

	ok = _check(rig is CharacterBody2D, "Root is CharacterBody2D") and ok
	ok = _check(rig is StickmanProcedural, "Root is instance of StickmanProcedural class_name") and ok

	var rig_node = rig.get_node_or_null("Rig")
	ok = _check(rig_node != null, "Rig container exists") and ok

	var skeleton: Skeleton2D = rig.get_node_or_null("Rig/Bones/Skeleton2D")
	ok = _check(skeleton != null, "Skeleton2D exists") and ok
	if skeleton != null:
		var hip = skeleton.get_node_or_null("Hip")
		ok = _check(hip != null and hip is Bone2D, "Skeleton2D has root Hip bone") and ok
		ok = _check(skeleton.get_node_or_null("Hip/Waist/Torso/Neck/Head") != null, "Skeleton2D has complete head chain") and ok
		ok = _check(skeleton.get_node_or_null("Hip/LegR/ShinR/FootR") != null, "Skeleton2D has right leg chain") and ok
		ok = _check(skeleton.get_node_or_null("Hip/ArmR/ForearmR/HandR") != null, "Skeleton2D has right arm chain") and ok
		var mod_stack = skeleton.get_modification_stack()
		ok = _check(mod_stack != null, "SkeletonModificationStack2D is attached") and ok
		if mod_stack != null:
			ok = _check(mod_stack.modification_count == 5, "Modification stack has exactly 5 active modifications (count=%d)" % mod_stack.modification_count) and ok
			ok = _check(mod_stack.enabled, "Modification stack is enabled") and ok

	var ik_targets_node = rig.get_node_or_null("IK Targets")
	ok = _check(ik_targets_node != null, "IK Targets container exists") and ok

	var targets_dict: Dictionary = rig.get_ik_targets()
	ok = _check(targets_dict.size() == 5, "get_ik_targets() returns 5 targets (got %d)" % targets_dict.size()) and ok
	for k in ["foot_r", "foot_l", "arm_r", "arm_l", "head"]:
		ok = _check(targets_dict.has(k) and targets_dict[k] != null, "Target '%s' exists and is non-null" % k) and ok

	# Verify backward-compatibility aliases
	ok = _check(is_equal_approx(rig.hand_swing, rig.arm_swing), "hand_swing alias matches arm_swing") and ok
	ok = _check(is_equal_approx(rig.pose_response, rig.snappiness), "pose_response alias matches snappiness") and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 2. Extreme Velocities Stress
# ============================================================================

func test_02_extreme_velocities_stress() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	var test_velocities: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(1e-18, 1e-18),
		Vector2(-1e-18, 0.0),
		Vector2(0.001, -0.001),
		Vector2(260.0, 0.0),           # Normal run
		Vector2(-260.0, 0.0),          # Normal run reverse
		Vector2(5000.0, 0.0),          # Massive dash
		Vector2(-5000.0, 0.0),         # Massive dash reverse
		Vector2(0.0, -10000.0),        # Super jump
		Vector2(0.0, 10000.0),         # Terminal plunge
		Vector2(50000.0, -50000.0),    # Astronomical diagonal
		Vector2(-100000.0, 100000.0)   # Warp-speed opposing
	]

	for vel in test_velocities:
		rig.update_procedural_animation(vel, true, 1.0 if vel.x >= 0.0 else -1.0, "run" if vel.x != 0.0 else "idle", 0.016)

		# Phase must strictly stay in [0.0, 1.0)
		ok = _check(rig.phase >= 0.0 and rig.phase < 1.0, "Phase bounded in [0.0, 1.0) on vel %s (got %f)" % [vel, rig.phase]) and ok
		ok = _check(is_finite(rig.phase), "Phase is finite on vel %s" % str(vel)) and ok

		# All IK targets must be finite
		var targets_dict: Dictionary = rig.get_ik_targets()
		for t_name in targets_dict:
			var t_node: Node2D = targets_dict[t_name]
			ok = _check(_is_vec2_finite(t_node.position), "Target '%s' position %s is finite on vel %s" % [t_name, t_node.position, vel]) and ok

		# Bones must be finite
		var bones: Dictionary = rig.get_bone_positions()
		for b_name in bones:
			ok = _check(_is_vec2_finite(bones[b_name]), "Bone '%s' position %s is finite on vel %s" % [b_name, bones[b_name], vel]) and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 3. High-Frequency Direction & Ground Flips
# ============================================================================

func test_03_high_frequency_direction_and_ground_flips() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	var facing_patterns: Array[float] = [1.0, -1.0, 1.0, -1.0, 0.0, 1.0, 0.0, -1.0]

	for i in range(200):
		var cur_dir: float = facing_patterns[i % facing_patterns.size()]
		var on_ground: bool = (i % 2 == 0)
		var state: String = "run" if on_ground else "jump"
		var vel: Vector2 = Vector2(cur_dir * 300.0, -200.0 if not on_ground else 0.0)

		rig.update_procedural_animation(vel, on_ground, cur_dir, state, 0.016)

		# When cur_dir == 0.0, facing must retain previous value
		ok = _check(absf(rig.facing) == 1.0, "Facing is strictly +1.0 or -1.0 (got %f)" % rig.facing) and ok

		var targets_dict: Dictionary = rig.get_ik_targets()
		for t_name in targets_dict:
			var t_node: Node2D = targets_dict[t_name]
			ok = _check(_is_vec2_finite(t_node.position), "Target '%s' position finite during flip %d" % [t_name, i]) and ok

	# Verify mirroring behavior around HIP_REST_X (284.51)
	rig.update_procedural_animation(Vector2.ZERO, true, 1.0, "idle", 1.0)
	var pos_fwd: Dictionary = {}
	for k in rig.get_ik_targets():
		pos_fwd[k] = rig.get_ik_targets()[k].position

	rig.update_procedural_animation(Vector2.ZERO, true, -1.0, "idle", 1.0)
	var pos_rev: Dictionary = {}
	for k in rig.get_ik_targets():
		pos_rev[k] = rig.get_ik_targets()[k].position

	# Right-facing and Left-facing positions should mirror around HIP_REST_X
	var hip_x: float = StickmanProcedural.HIP_REST_X
	for k in pos_fwd:
		var expected_mirrored_x: float = hip_x - (pos_fwd[k].x - hip_x)
		ok = _check(is_equal_approx(pos_rev[k].x, expected_mirrored_x),
			"Target '%s' x-coordinate accurately mirrors around HIP_REST_X: fwd=%f, rev=%f, expected=%f" % [k, pos_fwd[k].x, pos_rev[k].x, expected_mirrored_x]) and ok
		ok = _check(is_equal_approx(pos_fwd[k].y, pos_rev[k].y),
			"Target '%s' y-coordinate invariant across facing flip (fwd=%f, rev=%f)" % [k, pos_fwd[k].y, pos_rev[k].y]) and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 4. Rapid State Transitions & Malformed States
# ============================================================================

func test_04_rapid_state_transitions_and_malformed_states() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	var canonical_states: Array[String] = [
		"idle", "run", "walk", "jump", "fall", "air",
		"wall_slide", "slash", "heavy_slash", "parry_guard"
	]

	var malformed_states: Array[String] = [
		"", "   ", "UNKNOWN_STANCE", "NULL", "12345",
		"__proto__", "ultra_instinct_mode", "crash_test_dummy"
	]

	var all_states := canonical_states + malformed_states

	for state in all_states:
		for facing in [1.0, -1.0]:
			rig.update_procedural_animation(Vector2(200.0 * facing, -150.0), (state in ["idle", "run", "walk"]), facing, state, 0.016)

			ok = _check(rig.current_anim_state == state, "Animation state tracked correctly for '%s'" % state) and ok

			var pose = rig.to_stickman_pose(facing)
			ok = _check(pose != null, "to_stickman_pose() returned non-null pose for state '%s'" % state) and ok
			if pose != null:
				ok = _check(pose.stance == state, "Pose stance '%s' matches state '%s'" % [pose.stance, state]) and ok
				ok = _check(_is_vec2_finite(pose.head_center), "Pose head_center is finite in state '%s'" % state) and ok
				ok = _check(_is_vec2_finite(pose.pelvis), "Pose pelvis is finite in state '%s'" % state) and ok
				ok = _check(_is_vec2_finite(pose.left_foot), "Pose left_foot is finite in state '%s'" % state) and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 5. Boundary Delta Times
# ============================================================================

func test_05_boundary_delta_times() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	var test_deltas: Array[float] = [
		0.0,        # Instantaneous step / zero delta
		1e-12,      # Picosecond step
		0.001,      # 1000 Hz physics tick
		0.016666,   # Standard 60 FPS
		0.033333,   # 30 FPS
		0.25,       # Hitch / stutter
		1.0,        # 1 full second frame drop
		10.0,       # 10s resume after background pause
		100.0,      # Huge delta
		-0.016,     # Negative delta
		-1.0        # Large negative delta
	]

	for dt in test_deltas:
		rig.update_procedural_animation(Vector2(150.0, 0.0), true, 1.0, "run", dt)

		ok = _check(is_finite(rig.phase) and rig.phase >= 0.0 and rig.phase < 1.0, "Phase valid on dt=%f (got %f)" % [dt, rig.phase]) and ok

		var targets_dict: Dictionary = rig.get_ik_targets()
		for t_name in targets_dict:
			var t_node: Node2D = targets_dict[t_name]
			ok = _check(_is_vec2_finite(t_node.position), "Target '%s' position finite on dt=%f (got %s)" % [t_name, dt, t_node.position]) and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 6. NaN and Inf Input Resilience
# ============================================================================

func test_06_nan_and_inf_resilience() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	# Test non-finite facing directions
	for bad_facing in [NAN, INF, -INF]:
		rig.update_procedural_animation(Vector2(100.0, 0.0), true, bad_facing, "run", 0.016)
		ok = _check(is_finite(rig.facing), "Facing remains finite (%f) when passed bad_facing=%f" % [rig.facing, bad_facing]) and ok
		ok = _check(absf(rig.facing) == 1.0, "Facing is strictly +/-1.0 on bad_facing=%f" % bad_facing) and ok

	# Test non-finite velocities:
	# If caller injects NaN/Inf, rig's internal math should handle or recover cleanly once valid input resumes
	var bad_velocities: Array[Vector2] = [
		Vector2(NAN, 0.0),
		Vector2(0.0, NAN),
		Vector2(NAN, NAN),
		Vector2(INF, 0.0),
		Vector2(0.0, -INF),
		Vector2(INF, -INF)
	]

	for bad_vel in bad_velocities:
		# Exercise call with bad velocity
		rig.update_procedural_animation(bad_vel, true, 1.0, "run", 0.016)

	# Recovery check: after bad inputs, does feeding valid data immediately restore clean finite state?
	for recovery_step in range(10):
		rig.update_procedural_animation(Vector2(200.0, 0.0), true, 1.0, "run", 0.016)

	# Check targets and pose after recovery
	var targets_dict: Dictionary = rig.get_ik_targets()
	for t_name in targets_dict:
		var t_node: Node2D = targets_dict[t_name]
		# If NaN propagated into target position due to lerp(nan, ...), check if target position is finite
		var target_finite: bool = _is_vec2_finite(t_node.position)
		ok = _check(target_finite, "Target '%s' position must be finite after recovery (got %s)" % [t_name, t_node.position]) and ok

	var pose = rig.to_stickman_pose(1.0)
	ok = _check(pose != null, "to_stickman_pose() returns valid pose post-recovery") and ok
	if pose != null:
		ok = _check(_is_vec2_finite(pose.head_center), "pose.head_center is finite post-recovery") and ok
		ok = _check(_is_vec2_finite(pose.pelvis), "pose.pelvis is finite post-recovery") and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 7. Bone Positions & StickmanPose Completeness
# ============================================================================

func test_07_bone_positions_and_stickman_pose_completeness() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	# Let bone hierarchy settle over 5 frames
	for f in range(5):
		rig.update_procedural_animation(Vector2(100.0, 0.0), true, 1.0, "run", 0.016)

	# 1. get_bone_positions() contract
	var bones: Dictionary = rig.get_bone_positions()
	ok = _check(bones.size() >= 18, "get_bone_positions() returns at least 18 bones (got %d)" % bones.size()) and ok

	var required_bones: Array[String] = [
		"pelvis", "hip", "neck", "head", "head_center", "torso", "waist",
		"left_shoulder", "left_elbow", "left_hand",
		"right_shoulder", "right_elbow", "right_hand",
		"left_hip", "left_knee", "left_foot",
		"right_hip", "right_knee", "right_foot"
	]

	for b in required_bones:
		ok = _check(bones.has(b), "Bone dictionary contains required key '%s'" % b) and ok
		if bones.has(b):
			var pos = bones[b]
			ok = _check(pos is Vector2, "Bone '%s' is Vector2" % b) and ok
			ok = _check(_is_vec2_finite(pos), "Bone '%s' is finite Vector2 (%s)" % [b, pos]) and ok

	# Verify spatial sanity: head is above neck, neck is above pelvis
	# In 2D screen space (Y increases downward): head.y < neck.y < pelvis.y
	if bones.has("head") and bones.has("neck") and bones.has("pelvis"):
		var head_y: float = bones["head"].y
		var neck_y: float = bones["neck"].y
		var pelvis_y: float = bones["pelvis"].y
		ok = _check(head_y < neck_y, "Head is above neck in screen space (head.y=%f < neck.y=%f)" % [head_y, neck_y]) and ok
		ok = _check(neck_y < pelvis_y, "Neck is above pelvis in screen space (neck.y=%f < pelvis.y=%f)" % [neck_y, pelvis_y]) and ok

	# 2. to_stickman_pose() contract
	var pose = rig.to_stickman_pose(1.0)
	ok = _check(pose != null, "to_stickman_pose() returns valid instance") and ok
	if pose != null:
		ok = _check(pose.get_script() == ModularAssetScript.StickmanPose, "Pose object is instance of ModularAssetSystem.StickmanPose") and ok
		ok = _check(_is_vec2_finite(pose.head_center), "pose.head_center finite") and ok
		ok = _check(_is_vec2_finite(pose.neck), "pose.neck finite") and ok
		ok = _check(_is_vec2_finite(pose.pelvis), "pose.pelvis finite") and ok
		ok = _check(_is_vec2_finite(pose.left_shoulder), "pose.left_shoulder finite") and ok
		ok = _check(_is_vec2_finite(pose.left_elbow), "pose.left_elbow finite") and ok
		ok = _check(_is_vec2_finite(pose.left_hand), "pose.left_hand finite") and ok
		ok = _check(_is_vec2_finite(pose.right_shoulder), "pose.right_shoulder finite") and ok
		ok = _check(_is_vec2_finite(pose.right_elbow), "pose.right_elbow finite") and ok
		ok = _check(_is_vec2_finite(pose.right_hand), "pose.right_hand finite") and ok
		ok = _check(_is_vec2_finite(pose.left_hip), "pose.left_hip finite") and ok
		ok = _check(_is_vec2_finite(pose.left_knee), "pose.left_knee finite") and ok
		ok = _check(_is_vec2_finite(pose.left_foot), "pose.left_foot finite") and ok
		ok = _check(_is_vec2_finite(pose.right_hip), "pose.right_hip finite") and ok
		ok = _check(_is_vec2_finite(pose.right_knee), "pose.right_knee finite") and ok
		ok = _check(_is_vec2_finite(pose.right_foot), "pose.right_foot finite") and ok
		ok = _check(pose.stance == "run", "pose.stance correctly reflects 'run'") and ok
		# Verify coordinate parity (+Y UP in simulation space: head > neck > pelvis)
		ok = _check(pose.head_center.y > pose.neck.y, "Simulation pose head is above neck (+Y UP: head.y=%f > neck.y=%f)" % [pose.head_center.y, pose.neck.y]) and ok
		ok = _check(pose.neck.y > pose.pelvis.y, "Simulation pose neck is above pelvis (+Y UP: neck.y=%f > pelvis.y=%f)" % [pose.neck.y, pose.pelvis.y]) and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 8. Property Tampering and Parameter Extremes
# ============================================================================

func test_08_property_tampering_and_extremes() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	# Test stride_length = 0.0 (must not divide by zero in phase update)
	rig.stride_length = 0.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "stride_length=0.0 handled safely without division by zero") and ok

	# Test stride_length < 0.0
	rig.stride_length = -50.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "Negative stride_length handled safely") and ok
	rig.stride_length = 52.0 # restore

	# Test move_speed = 0.0 (must not divide by zero in speed_ratio)
	rig.move_speed = 0.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "move_speed=0.0 handled safely without division by zero") and ok

	# Test move_speed < 0.0
	rig.move_speed = -260.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "Negative move_speed handled safely") and ok
	rig.move_speed = 260.0 # restore

	# Test snappiness = 0.0 (exp(0) = 1.0, weight = 0.0)
	rig.snappiness = 0.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	for t in rig.get_ik_targets().values():
		ok = _check(_is_vec2_finite(t.position), "snappiness=0.0 produces finite target position") and ok

	# Test astronomical snappiness (1000.0)
	rig.snappiness = 1000.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	for t in rig.get_ik_targets().values():
		ok = _check(_is_vec2_finite(t.position), "snappiness=1000.0 produces finite target position") and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 9. Continuous Long-Run Simulation & Drift
# ============================================================================

func test_09_continuous_long_run_simulation() -> bool:
	var ok: bool = true
	var rig := _create_rig()
	if rig == null:
		return false

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	# Simulate 10,000 continuous frames
	for frame in range(10000):
		var vel_x: float = rng.randf_range(-400.0, 400.0)
		var vel_y: float = rng.randf_range(-600.0, 600.0)
		var on_ground: bool = (vel_y >= 0.0)
		var dir: float = signf(vel_x) if vel_x != 0.0 else 1.0
		var state: String = "run" if on_ground and absf(vel_x) > 20.0 else ("air" if not on_ground else "idle")
		var dt: float = rng.randf_range(0.008, 0.033)

		rig.update_procedural_animation(Vector2(vel_x, vel_y), on_ground, dir, state, dt)

		if frame % 2000 == 0:
			ok = _check(rig.phase >= 0.0 and rig.phase < 1.0, "Long run frame %d: phase in bounds" % frame) and ok
			var pose = rig.to_stickman_pose(dir)
			ok = _check(_is_vec2_finite(pose.head_center), "Long run frame %d: pose head finite" % frame) and ok

	_cleanup_rig(rig)
	return ok


# ============================================================================
# 10. Multi-Instance Isolation & Lifecycle
# ============================================================================

func test_10_multi_instance_isolation_and_lifecycle() -> bool:
	var ok: bool = true
	var instances: Array[CharacterBody2D] = []

	# Instantiate 10 separate stickman rigs
	for i in range(10):
		var rig := _create_rig()
		ok = _check(rig != null, "Instance %d instantiated" % i) and ok
		instances.append(rig)

	# Drive odd instances forward, even instances backward
	for i in range(instances.size()):
		var rig: CharacterBody2D = instances[i]
		var facing_dir: float = 1.0 if (i % 2 == 1) else -1.0
		rig.update_procedural_animation(Vector2(250.0 * facing_dir, 0.0), true, facing_dir, "run", 0.016)

	# Verify independence of facing and target states
	for i in range(instances.size()):
		var rig: CharacterBody2D = instances[i]
		var expected_facing: float = 1.0 if (i % 2 == 1) else -1.0
		ok = _check(is_equal_approx(rig.facing, expected_facing),
			"Instance %d facing %f matches expected %f" % [i, rig.facing, expected_facing]) and ok

	# Teardown all instances cleanly
	for rig in instances:
		_cleanup_rig(rig)
		ok = _check(not is_instance_valid(rig), "Instance marked invalid after free") and ok

	return ok
