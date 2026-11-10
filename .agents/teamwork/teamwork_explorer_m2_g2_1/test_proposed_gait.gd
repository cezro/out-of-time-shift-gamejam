extends SceneTree

const MAS = preload("res://scripts/modular_rig/modular_asset_system.gd")

func _init() -> void:
	print("=== Running Proposed Gait & Stance Invariant Test ===")
	var stats := [0, 0] # [passed, failed]
	
	# Helper assert
	var check = func(cond: bool, msg: String):
		if cond:
			stats[0] += 1
		else:
			stats[1] += 1
			printerr("[FAIL] " + msg)

	var origin := Vector2(100.0, -200.0)

	# 1. Idle stance
	var idle_player := MAS.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2.ZERO, true, 0.0, false, 0.0, false, "normal"
	)
	var idle_enemy := MAS.StickmanPoseSolver.generate_stickman_pose(
		origin, -1.0, Vector2.ZERO, true, 0.0, false, 0.0, true, "normal"
	)
	check.call(is_equal_approx(idle_player.head_radius, 8.5), "Player head_radius should be 8.5")
	check.call(is_equal_approx(idle_enemy.head_radius, 7.5), "Enemy head_radius should be 7.5")
	check.call(idle_player.head_center.y > idle_player.neck.y, "Head center above neck in Bevy Y-up pose")
	check.call(idle_player.neck.y > idle_player.pelvis.y, "Neck above pelvis")
	check.call(idle_player.scarf_nodes.size() == 3, "Scarf has 3 trail nodes")
	check.call(idle_player.scarf_nodes[2].x < idle_player.head_center.x, "Scarf trails behind facing=+1")

	# Test proposed running pose math
	# Let's test across anim_times: 0.0, 0.1, 0.2, 0.35, 0.5, 1.0
	for t in [0.0, 0.1, 0.2, 0.35, 0.5, 1.0]:
		var run_pose := _generate_proposed_stickman_pose(
			origin, 1.0, Vector2(220.0, 0.0), true, t, false, 0.0, false, "normal"
		)
		check.call(run_pose.neck.x > idle_player.neck.x, "Running leans torso forward in facing direction (t=%.2f)" % t)
		check.call(run_pose.head_center.y > run_pose.neck.y, "Run head above neck (t=%.2f)" % t)
		check.call(run_pose.neck.y > run_pose.pelvis.y, "Run neck above pelvis (t=%.2f)" % t)
		if t == 0.35:
			check.call(run_pose.left_foot != idle_player.left_foot, "Running animates foot stride (t=0.35)")

		# Check all 20 PartSlot transforms
		for slot_idx in range(20):
			var xform: Dictionary = MAS.StickmanPoseSolver.compute_slot_transform(run_pose, slot_idx, 1.0)
			check.call(xform.has("start") and _is_vec2_finite(xform["start"]), "Slot %d start finite (t=%.2f)" % [slot_idx, t])
			check.call(xform.has("end") and _is_vec2_finite(xform["end"]), "Slot %d end finite (t=%.2f)" % [slot_idx, t])
			check.call(xform.has("center") and _is_vec2_finite(xform["center"]), "Slot %d center finite (t=%.2f)" % [slot_idx, t])
			check.call(is_finite(float(xform.get("angle", 0.0))), "Slot %d angle finite (t=%.2f)" % [slot_idx, t])
			check.call(float(xform.get("length", 0.0)) > 0.0, "Slot %d length > 0 (t=%.2f)" % [slot_idx, t])

	# Test adversarial bad values
	for bad_val in [0.0, NAN, INF, -INF, -10.0, 1e6]:
		var bad_vec := Vector2(bad_val, bad_val)
		var pose := _generate_proposed_stickman_pose(
			bad_vec, bad_val, bad_vec, true, bad_val, true, bad_val, false, "normal"
		)
		var all_finite: bool = (
			_is_vec2_finite(pose.head_center)
			and _is_vec2_finite(pose.neck)
			and _is_vec2_finite(pose.pelvis)
			and _is_vec2_finite(pose.left_foot)
			and _is_vec2_finite(pose.right_foot)
			and _is_vec2_finite(pose.left_knee)
			and _is_vec2_finite(pose.right_knee)
		)
		check.call(all_finite, "Proposed pose solver finite on bad_val=%s" % str(bad_val))

	print("=== Test Summary: %d passed, %d failed ===" % [stats[0], stats[1]])
	quit(1 if stats[1] > 0 else 0)

static func _is_vec2_finite(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)

static func _generate_proposed_stickman_pose(
	pos: Vector2,
	facing: float,
	velocity: Vector2,
	is_grounded: bool,
	anim_time: float,
	is_attacking: bool,
	attack_progress: float,
	is_enemy: bool,
	stance: String = "normal"
) -> MAS.StickmanPose:
	var safe_pos: Vector2 = pos if (is_finite(pos.x) and is_finite(pos.y)) else Vector2.ZERO
	var safe_facing: float = facing if is_finite(facing) else 1.0
	var face_dir: float = 1.0 if safe_facing >= 0.0 else -1.0
	var safe_vel: Vector2 = velocity if (is_finite(velocity.x) and is_finite(velocity.y)) else Vector2.ZERO
	var safe_anim_time: float = fposmod(anim_time, 10000.0) if is_finite(anim_time) else 0.0
	var safe_attack_progress: float = clampf(attack_progress, 0.0, 1.0) if is_finite(attack_progress) else 0.0
	var speed: float = absf(safe_vel.x)
	var is_running: bool = is_grounded and speed > 20.0
	var is_jumping: bool = not is_grounded

	var base_pelvis: Vector2 = safe_pos + Vector2(0.0, 16.0)
	var pelvis: Vector2 = base_pelvis
	var neck: Vector2 = pelvis + Vector2(face_dir * 3.0, 24.0)

	# Cadence & Gait Phase
	var cadence_hz: float = 1.8 + 2.0 * tanh(speed / 180.0)
	var step_speed: float = TAU * cadence_hz
	var gait_phase: float = fposmod(safe_anim_time * step_speed, TAU)

	# Torso lean & Pelvic bobbing
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
		# Inverted pendulum pelvic bobbing at 2x stride frequency (vaulting mid-stance, dipping on foot strikes)
		pelvis.y += absf(sin(gait_phase)) * 3.0
		# Torso lean scales forward with velocity
		neck.x += face_dir * (6.0 + clampf(speed / 340.0, 0.0, 1.0) * 2.0)
	elif is_jumping:
		neck.x += face_dir * 4.0

	# Dual-frequency head bob in running stance
	var head_center: Vector2
	if is_running:
		var head_vert_bob: float = (0.5 - 0.5 * cos(gait_phase * 2.0)) * 1.5
		var head_pitch: float = sin(gait_phase) * 0.8
		head_center = neck + Vector2(face_dir * (3.0 + 1.5 + head_pitch), 10.0 - head_vert_bob)
	else:
		head_center = neck + Vector2(face_dir * 3.0, 10.0)

	var head_radius: float = 7.5 if is_enemy else 8.5

	# Legs
	var left_hip: Vector2 = pelvis + Vector2(-face_dir * 3.0, 0.0)
	var right_hip: Vector2 = pelvis + Vector2(face_dir * 3.0, 0.0)
	var left_knee: Vector2
	var left_foot: Vector2
	var right_knee: Vector2
	var right_foot: Vector2

	if stance == "wall_slide":
		left_knee = left_hip + Vector2(-face_dir * 5.0, -6.0)
		left_foot = left_knee + Vector2(-face_dir * 3.0, -7.0)
		right_knee = right_hip + Vector2(face_dir * 4.0, -13.0)
		right_foot = right_knee + Vector2(face_dir * 2.0, -13.0)
	elif stance == "downward_slam" or is_jumping:
		left_knee = left_hip + Vector2(-face_dir * 6.0, -10.0)
		left_foot = left_knee + Vector2(-face_dir * 4.0, -10.0)
		right_knee = right_hip + Vector2(face_dir * 8.0, -8.0)
		right_foot = right_knee + Vector2(face_dir * 6.0, -12.0)
	elif is_running:
		var speed_norm: float = clampf(speed / 340.0, 0.0, 1.0)
		var stride_half: float = lerpf(8.0, 14.0, speed_norm)
		var step_height: float = lerpf(3.0, 6.0, speed_norm)

		# Piecewise stance-lock & Hermite smoothstep foot swing
		var l_traj := _eval_leg(gait_phase, stride_half, step_height)
		var r_traj := _eval_leg(fposmod(gait_phase + PI, TAU), stride_half, step_height)

		left_foot = Vector2(left_hip.x + face_dir * l_traj.x, pelvis.y - 26.0 + l_traj.y)
		var l_mid: Vector2 = (left_hip + left_foot) * 0.5
		left_knee = Vector2(l_mid.x + face_dir * (3.0 + (l_traj.y / step_height) * 3.0), l_mid.y + 1.0 + l_traj.y * 0.4)

		right_foot = Vector2(right_hip.x + face_dir * r_traj.x, pelvis.y - 26.0 + r_traj.y)
		var r_mid: Vector2 = (right_hip + right_foot) * 0.5
		right_knee = Vector2(r_mid.x + face_dir * (3.0 + (r_traj.y / step_height) * 3.0), r_mid.y + 1.0 + r_traj.y * 0.4)
	else:
		var breath: float = sin(safe_anim_time * 3.0) * 1.5
		left_knee = left_hip + Vector2(-face_dir * 4.0, -13.0 + breath)
		left_foot = left_knee + Vector2(0.0, -13.0)
		right_knee = right_hip + Vector2(face_dir * 6.0, -12.0 + breath)
		right_foot = right_knee + Vector2(0.0, -14.0)

	# Arms (Antiphase arm swing)
	var left_shoulder: Vector2 = neck + Vector2(-face_dir * 4.0, -2.0)
	var right_shoulder: Vector2 = neck + Vector2(face_dir * 4.0, -2.0)
	var left_elbow: Vector2
	var left_hand: Vector2
	var right_elbow: Vector2
	var right_hand: Vector2
	var sword_hilt: Vector2
	var sword_tip: Vector2

	if is_running:
		# Antiphase arm swing: left leg stance -> left arm swings forward
		var l_swing: float = sin(gait_phase)
		var r_swing: float = sin(gait_phase + PI)

		left_elbow = left_shoulder + Vector2(face_dir * l_swing * 8.0, -10.0)
		left_hand = left_elbow + Vector2(face_dir * l_swing * 6.0, -8.0)

		right_elbow = right_shoulder + Vector2(face_dir * r_swing * 8.0, -8.0)
		right_hand = right_elbow + Vector2(face_dir * 10.0, 4.0)

		var sword_dir: Vector2 = Vector2(face_dir * 0.8, -0.6).normalized()
		sword_hilt = right_hand - sword_dir * 4.0
		sword_tip = right_hand + sword_dir * 32.0
	else:
		left_elbow = left_shoulder + Vector2(-face_dir * 4.0, -10.0)
		left_hand = pelvis + Vector2(face_dir * 4.0, 4.0)
		right_elbow = right_shoulder + Vector2(face_dir * 6.0, -8.0)
		right_hand = pelvis + Vector2(face_dir * 8.0, 6.0)
		var sword_dir: Vector2 = Vector2(face_dir * 0.7, 0.7).normalized()
		sword_hilt = right_hand - sword_dir * 5.0
		sword_tip = right_hand + sword_dir * 34.0

	var clamped_vy: float = clampf(safe_vel.y, -2000.0, 2000.0)
	var head_back: Vector2 = head_center + Vector2(-face_dir * head_radius, 0.0)
	var scarf_0: Vector2 = head_back + Vector2(-face_dir * 8.0, (sin(safe_anim_time * 8.0) * 3.0) - clamped_vy * 0.02)
	var scarf_1: Vector2 = scarf_0 + Vector2(-face_dir * 10.0, (sin(safe_anim_time * 8.0 + 1.2) * 4.0) - clamped_vy * 0.03)
	var scarf_2: Vector2 = scarf_1 + Vector2(-face_dir * 12.0, (sin(safe_anim_time * 8.0 + 2.4) * 5.0) - clamped_vy * 0.04)

	var pose := MAS.StickmanPose.new()
	pose.head_center = head_center
	pose.head_radius = head_radius
	pose.neck = neck
	pose.pelvis = pelvis
	pose.left_shoulder = left_shoulder
	pose.left_elbow = left_elbow
	pose.left_hand = left_hand
	pose.right_shoulder = right_shoulder
	pose.right_elbow = right_elbow
	pose.right_hand = right_hand
	pose.left_hip = left_hip
	pose.left_knee = left_knee
	pose.left_foot = left_foot
	pose.right_hip = right_hip
	pose.right_knee = right_knee
	pose.right_foot = right_foot
	pose.sword_hilt = sword_hilt
	pose.sword_tip = sword_tip
	pose.scarf_nodes = [scarf_0, scarf_1, scarf_2]
	pose.stance = stance
	return pose

static func _eval_leg(phase: float, stride_half: float, step_height: float) -> Vector2:
	if phase < PI:
		var t_stance: float = phase / PI
		var x: float = stride_half * (1.0 - 2.0 * t_stance)
		return Vector2(x, 0.0)
	else:
		var tau: float = (phase - PI) / PI
		var smooth_tau: float = tau * tau * (3.0 - 2.0 * tau)
		var x: float = -stride_half + 2.0 * stride_half * smooth_tau
		var y: float = step_height * (4.0 * tau * (1.0 - tau))
		return Vector2(x, y)
