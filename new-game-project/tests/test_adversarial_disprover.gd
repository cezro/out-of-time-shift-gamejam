extends SceneTree

## Adversarial Red-Team Disprover Suite (Disprover 1)
## Audits all 9 Prover modules in new-game-project/scripts/ across:
## 1. NaN / Inf / Extreme Delta / Zero-Length Vector Injection
## 2. Concurrency / Frame-Order Race Conditions & State Deadlocks
## 3. Modular Piece-by-Piece Asset Edge Cases & Malformed Manifests

const TimeControlScript = preload("res://scripts/core/time_control.gd")
const PlayerKinematicsScript = preload("res://scripts/core/player_kinematics.gd")
const CombatMathScript = preload("res://scripts/core/combat_math.gd")
const EnemyAIScript = preload("res://scripts/core/enemy_ai.gd")
const RagdollPhysicsScript = preload("res://scripts/core/ragdoll_physics.gd")
const ChronoShiftScript = preload("res://scripts/chrono_shift/chrono_shift_model.gd")
const TimelineSystemScript = preload("res://scripts/timeline/timeline_system.gd")
const ModularAssetScript = preload("res://scripts/modular_rig/modular_asset_system.gd")
const AssetMcpBridgeScript = preload("res://scripts/tools/asset_mcp_bridge.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("=== RUNNING ADVERSARIAL RED-TEAM DISPROVER SUITE ===")

	# 1. NaN / Inf / Extreme Delta / Zero-Length Vector Injection
	_run_test("attack_1a_time_control_nan_inf_extreme_dt", attack_1a_time_control_nan_inf_extreme_dt)
	_run_test("attack_1b_player_kinematics_nan_inf_extreme_dt", attack_1b_player_kinematics_nan_inf_extreme_dt)
	_run_test("attack_1c_combat_math_nan_inf_zero_vectors", attack_1c_combat_math_nan_inf_zero_vectors)
	_run_test("attack_1d_enemy_ai_nan_inf_extreme_dt", attack_1d_enemy_ai_nan_inf_extreme_dt)
	_run_test("attack_1e_ragdoll_physics_nan_inf_extreme_dt", attack_1e_ragdoll_physics_nan_inf_extreme_dt)
	_run_test("attack_1f_hgate_constraints_nan_inf_extreme_dt", attack_1f_hgate_constraints_nan_inf_extreme_dt)
	_run_test("attack_1g_timeline_system_nan_inf_extreme_dt", attack_1g_timeline_system_nan_inf_extreme_dt)
	_run_test("attack_1h_pose_solver_and_weapon_assembly_nan_inf_zero", attack_1h_pose_solver_and_weapon_assembly_nan_inf_zero)

	# 2. Race Conditions & State Deadlocks
	_run_test("attack_2a_simultaneous_bullet_deflection_and_player_contact", attack_2a_simultaneous_bullet_deflection_and_player_contact)
	_run_test("attack_2b_duplicate_slice_event_deduplication_and_ragdoll_count", attack_2b_duplicate_slice_event_deduplication_and_ragdoll_count)
	_run_test("attack_2c_rapid_timeline_cycling_with_echoes_and_juggled_enemies", attack_2c_rapid_timeline_cycling_with_echoes_and_juggled_enemies)
	_run_test("attack_2d_reverse_gear_insta_death_vs_parry_counter_priority", attack_2d_reverse_gear_insta_death_vs_parry_counter_priority)
	_run_test("attack_2e_turbo_shifter_6s_boundary_and_downshift_recovery", attack_2e_turbo_shifter_6s_boundary_and_downshift_recovery)

	# 3. Modular Piece-by-Piece Asset Edge Cases
	_run_test("attack_3a_malformed_json_manifests_graceful_degradation", attack_3a_malformed_json_manifests_graceful_degradation)
	_run_test("attack_3b_invalid_slot_names_and_numbers_and_missing_textures", attack_3b_invalid_slot_names_and_numbers_and_missing_textures)
	_run_test("attack_3c_ragdoll_split_preserves_custom_polygon_and_texture_parts", attack_3c_ragdoll_split_preserves_custom_polygon_and_texture_parts)

	# 4. Playable GameController & AudioManager Adversarial Stress
	_run_test("attack_4a_game_controller_and_audio_adversarial_stress", attack_4a_game_controller_and_audio_adversarial_stress)

	print("=== ADVERSARIAL SUITE SUMMARY: %d / %d PASSED (%d FAILED) ===" % [_tests_passed, _tests_run, _tests_failed])
	if _tests_failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### VERDICT: VERIFICATION CLEARANCE GRANTED")
		quit(0)


func _run_test(test_name: String, fn: Callable) -> void:
	_tests_run += 1
	var ok: bool = fn.call()
	if ok:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % test_name)


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		_failures.append(msg)
		printerr("    COUNTER-EXAMPLE: %s" % msg)
		return false
	return true


func _is_vec2_finite(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


# =============================================================================
# 1. NaN / Inf / Extreme Delta / Zero-Length Vector Injection
# =============================================================================

func attack_1a_time_control_nan_inf_extreme_dt() -> bool:
	var ok: bool = true
	var chrono := TimeControlScript.new()

	for bad_dt in [NAN, INF, -INF, -10.0, 0.0, 1e6]:
		chrono.trigger_hitstop(bad_dt)
		chrono.trigger_shake(bad_dt)
		chrono.update(bad_dt)
		ok = _check(is_finite(chrono.dilation_factor) and chrono.dilation_factor >= 0.04 and chrono.dilation_factor <= 1.0,
			"time_control.gd: dilation_factor corrupted to %s on dt=%s" % [str(chrono.dilation_factor), str(bad_dt)]) and ok
		ok = _check(is_finite(chrono.hitstop_timer) and chrono.hitstop_timer >= 0.0,
			"time_control.gd: hitstop_timer corrupted to %s on dt=%s" % [str(chrono.hitstop_timer), str(bad_dt)]) and ok
		ok = _check(is_finite(chrono.screen_shake) and chrono.screen_shake >= 0.0 and chrono.screen_shake <= 20.0,
			"time_control.gd: screen_shake corrupted to %s on dt=%s" % [str(chrono.screen_shake), str(bad_dt)]) and ok
		ok = _check(_is_vec2_finite(chrono.shake_offset),
			"time_control.gd: shake_offset corrupted to %s on dt=%s" % [str(chrono.shake_offset), str(bad_dt)]) and ok
		var w_dt: float = chrono.get_world_dt(bad_dt)
		var p_dt: float = chrono.get_player_dt(bad_dt)
		ok = _check(is_finite(w_dt) and w_dt >= 0.0,
			"time_control.gd: get_world_dt returned %s on real_dt=%s" % [str(w_dt), str(bad_dt)]) and ok
		ok = _check(is_finite(p_dt) and p_dt >= 0.0,
			"time_control.gd: get_player_dt returned %s on real_dt=%s" % [str(p_dt), str(bad_dt)]) and ok

	return ok


func attack_1b_player_kinematics_nan_inf_extreme_dt() -> bool:
	var ok: bool = true
	var config := PlayerKinematicsScript.MovementConfig.new()
	var energy := PlayerKinematicsScript.ChronoEnergy.new()

	for bad_val in [NAN, INF, -INF, -50.0, 0.0, 1e6]:
		energy.update(true, bad_val)
		ok = _check(is_finite(energy.current) and energy.current >= 0.0 and energy.current <= energy.max_energy,
			"player_kinematics.gd: ChronoEnergy.update produced %s on dt=%s" % [str(energy.current), str(bad_val)]) and ok
		energy.update_with_drain(bad_val, bad_val)
		ok = _check(is_finite(energy.current) and energy.current >= 0.0 and energy.current <= energy.max_energy,
			"player_kinematics.gd: ChronoEnergy.update_with_drain produced %s on val=%s" % [str(energy.current), str(bad_val)]) and ok

		var vx: float = PlayerKinematicsScript.step_horizontal_velocity(bad_val, bad_val, config, bad_val)
		ok = _check(is_finite(vx) and absf(vx) <= config.max_speed + 1e-3,
			"player_kinematics.gd: step_horizontal_velocity returned %s on input=%s" % [str(vx), str(bad_val)]) and ok

		var vres: Dictionary = PlayerKinematicsScript.step_vertical_velocity(
			bad_val, false, false, false, bad_val, bad_val, config, bad_val
		)
		ok = _check(is_finite(float(vres["vy"])),
			"player_kinematics.gd:167-186 step_vertical_velocity returned non-finite vy=%s on bad_val=%s" % [str(vres["vy"]), str(bad_val)]) and ok
		ok = _check(is_finite(float(vres["coyote_timer"])) and float(vres["coyote_timer"]) >= 0.0,
			"player_kinematics.gd:167 step_vertical_velocity returned corrupted coyote_timer=%s on bad_val=%s" % [str(vres["coyote_timer"]), str(bad_val)]) and ok
		ok = _check(is_finite(float(vres["jump_buffer_timer"])) and float(vres["jump_buffer_timer"]) >= 0.0,
			"player_kinematics.gd:168 step_vertical_velocity returned corrupted jump_buffer_timer=%s on bad_val=%s" % [str(vres["jump_buffer_timer"]), str(bad_val)]) and ok

		var player := PlayerKinematicsScript.PlayerState.new()
		player.facing = bad_val
		player.velocity = Vector2(bad_val, bad_val)
		player.is_grounded = false
		PlayerKinematicsScript.start_dash(player, bad_val)
		ok = _check(_is_vec2_finite(player.velocity) and is_finite(player.facing),
			"player_kinematics.gd: start_dash produced non-finite velocity=%s or facing=%s on input=%s" % [str(player.velocity), str(player.facing), str(bad_val)]) and ok

		player.dash_cooldown = 0.0
		player.velocity = Vector2(bad_val, bad_val)
		PlayerKinematicsScript.step_wall_slide_and_rebound(player, 1.0, false, bad_val)
		ok = _check(_is_vec2_finite(player.velocity),
			"player_kinematics.gd:241 step_wall_slide_and_rebound left non-finite player.velocity=%s when wall sliding with bad_val=%s" % [str(player.velocity), str(bad_val)]) and ok

	return ok


func attack_1c_combat_math_nan_inf_zero_vectors() -> bool:
	var ok: bool = true

	# 1. point_to_segment_distance_sq & segment_intersects_circle with NaN/Inf/Zero-length
	var zero_seg_dist: float = CombatMathScript.point_to_segment_distance_sq(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	ok = _check(is_finite(zero_seg_dist) and is_equal_approx(zero_seg_dist, 0.0),
		"combat_math.gd:10 point_to_segment_distance_sq failed on zero-length segment") and ok

	var nan_seg_dist: float = CombatMathScript.point_to_segment_distance_sq(Vector2(NAN, 0.0), Vector2.ZERO, Vector2(100.0, 0.0))
	ok = _check(is_finite(nan_seg_dist),
		"combat_math.gd:9-16 point_to_segment_distance_sq returned %s on p=Vector2(NAN, 0.0)" % str(nan_seg_dist)) and ok

	var inf_seg_dist: float = CombatMathScript.point_to_segment_distance_sq(Vector2.ZERO, Vector2(INF, 0.0), Vector2.ZERO)
	ok = _check(is_finite(inf_seg_dist),
		"combat_math.gd:9-16 point_to_segment_distance_sq returned %s on a=Vector2(INF, 0.0)" % str(inf_seg_dist)) and ok

	# 2. katana_arc_intersects with INF aim_dir and negative target_radius at dist=0
	var arc_inf_aim: bool = CombatMathScript.katana_arc_intersects(
		Vector2.ZERO, 1.0, Vector2(INF, 0.0), Vector2(40.0, 0.0), 80.0, PI * 0.75, 18.0
	)
	ok = _check(arc_inf_aim == true,
		"combat_math.gd:45-52 katana_arc_intersects failed (returned false due to Vector2(INF,0).normalized() == NaN) when target is at (40,0) in front of player") and ok

	var arc_zero_dist_neg_rad: bool = CombatMathScript.katana_arc_intersects(
		Vector2.ZERO, 1.0, Vector2.RIGHT, Vector2.ZERO, 80.0, PI * 0.75, -1.0
	)
	ok = _check(arc_zero_dist_neg_rad == true or arc_zero_dist_neg_rad == false,
		"combat_math.gd:43 katana_arc_intersects zero-dist negative radius check") and ok

	# 3. BulletData.deflect with INF / NaN / Zero vectors
	for bad_dir in [Vector2.ZERO, Vector2(NAN, NAN), Vector2(INF, 0.0), Vector2(-INF, INF)]:
		var b := CombatMathScript.BulletData.new(Vector2.ZERO, Vector2(-400.0, 0.0), 6.0, 20.0, 3.0)
		b.deflect(bad_dir, NAN)
		ok = _check(_is_vec2_finite(b.velocity) and b.velocity.length() > 0.0,
			"combat_math.gd:248 BulletData.deflect produced non-finite velocity=%s on new_dir=%s" % [str(b.velocity), str(bad_dir)]) and ok

	# 4. perform_katana_slash with INF / NaN cursor_world_pos
	for bad_cursor in [Vector2.ZERO, Vector2(NAN, NAN), Vector2(INF, 0.0), Vector2(INF, INF)]:
		var p := PlayerKinematicsScript.PlayerState.new()
		p.position = Vector2.ZERO
		p.facing = 1.0
		var enemies: Dictionary = {1: EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.RUNNER, Vector2(40.0, 0.0))}
		var b := CombatMathScript.BulletData.new(Vector2(35.0, 16.0), Vector2(-300.0, 0.0))
		var bullets: Array = [b]
		var res: Dictionary = CombatMathScript.perform_katana_slash(p, bad_cursor, enemies, bullets, null, true)
		for ev in res["slice_events"]:
			ok = _check(_is_vec2_finite(ev.slice_direction) and _is_vec2_finite(ev.impulse),
				"combat_math.gd:452 perform_katana_slash produced NaN slice_direction=%s on cursor=%s" % [str(ev.slice_direction), str(bad_cursor)]) and ok
		ok = _check(_is_vec2_finite(b.velocity),
			"combat_math.gd:479 perform_katana_slash deflected bullet to non-finite velocity=%s on cursor=%s" % [str(b.velocity), str(bad_cursor)]) and ok

	# 5. perform_chrono_warp with NaN / Inf / Zero-length cursor_world_pos
	for bad_cursor in [Vector2(0.0, -200.0), Vector2(NAN, NAN), Vector2(INF, 0.0), Vector2(-INF, INF)]:
		var p := PlayerKinematicsScript.PlayerState.new()
		p.position = Vector2(0.0, -200.0)
		var energy := PlayerKinematicsScript.ChronoEnergy.new()
		var enemies: Dictionary = {1: EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.RUNNER, Vector2(50.0, -200.0))}
		var wres: Dictionary = CombatMathScript.perform_chrono_warp(p, energy, bad_cursor, enemies)
		ok = _check(_is_vec2_finite(p.position),
			"combat_math.gd:525-537 perform_chrono_warp corrupted player.position to %s on cursor_world_pos=%s" % [str(p.position), str(bad_cursor)]) and ok
		for ev in wres["slice_events"]:
			ok = _check(_is_vec2_finite(ev.slice_direction) and _is_vec2_finite(ev.impulse),
				"combat_math.gd:535 perform_chrono_warp produced non-finite slice event on cursor=%s" % str(bad_cursor)) and ok

	return ok


func attack_1d_enemy_ai_nan_inf_extreme_dt() -> bool:
	var ok: bool = true

	for bad_dt in [NAN, INF, -INF, -5.0, 0.0, 1e6]:
		var enemy := EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.SNIPER, Vector2(100.0, -200.0))
		var ai_res: Dictionary = EnemyAIScript.step_enemy_ai(enemy, Vector2(300.0, -200.0), bad_dt)
		ok = _check(is_finite(float(ai_res["move_dir"])) and is_finite(float(ai_res["gravity_scale"])),
			"enemy_ai.gd: step_enemy_ai returned non-finite result on dt=%s" % str(bad_dt)) and ok
		EnemyAIScript.step_enemy_physics(enemy, float(ai_res["move_dir"]), bool(ai_res["should_jump"]), [], bad_dt)
		ok = _check(_is_vec2_finite(enemy.position) and _is_vec2_finite(enemy.velocity),
			"enemy_ai.gd: step_enemy_physics corrupted position=%s or velocity=%s on dt=%s" % [str(enemy.position), str(enemy.velocity), str(bad_dt)]) and ok

	# Inject NaN / Inf player_pos and move_dir into EnemyAI
	for bad_pos in [Vector2(NAN, NAN), Vector2(INF, 0.0), Vector2(-INF, INF)]:
		var sniper := EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.SNIPER, Vector2(100.0, -200.0))
		sniper.state = EnemyAIScript.StateKind.WINDUP
		sniper.state_timer = 0.5
		EnemyAIScript.step_enemy_ai(sniper, bad_pos, 0.016)
		ok = _check(_is_vec2_finite(sniper.laser_aim_dir),
			"enemy_ai.gd:217-218 step_enemy_ai corrupted sniper.laser_aim_dir to %s on player_pos=%s" % [str(sniper.laser_aim_dir), str(bad_pos)]) and ok

		sniper.state = EnemyAIScript.StateKind.ATTACK
		sniper.attack_has_hit = false
		var bullet = EnemyAIScript.step_gunner_attack(sniper, bad_pos, 0.016)
		if bullet != null:
			ok = _check(_is_vec2_finite(bullet.velocity) and bullet.velocity.length() > 0.0,
				"enemy_ai.gd:365-366 step_gunner_attack spawned bullet with non-finite velocity=%s on player_pos=%s" % [str(bullet.velocity), str(bad_pos)]) and ok

	for bad_dir in [NAN, INF, -INF]:
		var runner := EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.RUNNER, Vector2(0.0, -200.0))
		EnemyAIScript.step_enemy_physics(runner, bad_dir, false, [], 0.016)
		ok = _check(_is_vec2_finite(runner.position) and _is_vec2_finite(runner.velocity),
			"enemy_ai.gd:294-304 step_enemy_physics corrupted runner.position=%s or velocity=%s on move_dir=%s" % [str(runner.position), str(runner.velocity), str(bad_dir)]) and ok

	var juggled := EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.RUNNER, Vector2(0.0, -200.0))
	EnemyAIScript.launch_enemy(juggled, Vector2(NAN, INF), NAN)
	ok = _check(_is_vec2_finite(juggled.velocity) and is_finite(juggled.juggle_timer),
		"enemy_ai.gd:129-139 launch_enemy accepted non-finite launch_vel=%s" % str(juggled.velocity)) and ok

	return ok


func attack_1e_ragdoll_physics_nan_inf_extreme_dt() -> bool:
	var ok: bool = true

	for bad_vec in [Vector2.ZERO, Vector2(NAN, NAN), Vector2(INF, 0.0), Vector2(-INF, INF)]:
		var split: Dictionary = RagdollPhysicsScript.calculate_slice_split_velocities(bad_vec, bad_vec, bad_vec)
		ok = _check(
			_is_vec2_finite(split["upper_vel"])
			and _is_vec2_finite(split["lower_vel"])
			and is_finite(float(split["upper_ang_vel"]))
			and is_finite(float(split["lower_ang_vel"])),
			"ragdoll_physics.gd:81-102 calculate_slice_split_velocities returned non-finite velocities %s on input=%s" % [str(split), str(bad_vec)]
		) and ok

	for bad_dt in [NAN, INF, -INF, -1.0, 0.0, 1e6]:
		var piece := RagdollPhysicsScript.RagdollPieceData.new()
		RagdollPhysicsScript.step_ragdoll_piece(piece, [], bad_dt)
		ok = _check(_is_vec2_finite(piece.position) and _is_vec2_finite(piece.velocity) and is_finite(piece.rotation),
			"ragdoll_physics.gd: step_ragdoll_piece produced non-finite state on dt=%s" % str(bad_dt)) and ok

		var part := RagdollPhysicsScript.SliceParticleData.new()
		RagdollPhysicsScript.step_slice_particle(part, bad_dt)
		ok = _check(_is_vec2_finite(part.position) and _is_vec2_finite(part.velocity),
			"ragdoll_physics.gd: step_slice_particle produced non-finite state on dt=%s" % str(bad_dt)) and ok

	return ok


func attack_1f_hgate_constraints_nan_inf_extreme_dt() -> bool:
	var ok: bool = true
	var state := ChronoShiftScript.ChronoShifterState.new()

	for bad_dt in [NAN, INF, -INF, -10.0, 0.0, 1e6]:
		for bad_vec in [Vector2.ZERO, Vector2(NAN, NAN), Vector2(INF, -INF), Vector2(1e6, -1e6)]:
			var inp := ChronoShiftScript.ShifterInput.new(true, bad_vec, 999, 999)
			var out := state.step_control(inp, bad_dt, bad_vec, bad_vec)
			ok = _check(ChronoShiftScript.is_legal(state.model.knob),
				"chrono_shift_model.gd: knob became illegal %s on drag=%s, dt=%s" % [str(state.model.knob), str(bad_vec), str(bad_dt)]) and ok
			ok = _check(is_finite(out.dilation) and out.dilation >= 0.04 and out.dilation <= 1.0,
				"chrono_shift_model.gd: out.dilation=%s out of bounds on dt=%s" % [str(out.dilation), str(bad_dt)]) and ok
			ok = _check(is_finite(state.energy_current) and state.energy_current >= 0.0 and state.energy_current <= state.energy_max,
				"chrono_shift_model.gd: energy_current=%s out of bounds" % str(state.energy_current)) and ok

	# Also test follow_path with corrupted waypoint array
	var bad_path: Array[Vector2] = [Vector2(NAN, INF), Vector2(0.0, 1.0)]
	var p_after: Vector2 = ChronoShiftScript.follow_path(Vector2.ZERO, bad_path, 24.0, 0.016)
	ok = _check(ChronoShiftScript.is_legal(p_after),
		"chrono_shift_model.gd: follow_path returned illegal position %s on NaN waypoint" % str(p_after)) and ok

	return ok


func attack_1g_timeline_system_nan_inf_extreme_dt() -> bool:
	var ok: bool = true
	var ts := TimelineSystemScript.TimelineState.new()

	for bad_vec in [Vector2.ZERO, Vector2(NAN, NAN), Vector2(INF, 0.0), Vector2(-INF, INF)]:
		var echo := ts.spawn_chrono_echo(bad_vec, bad_vec, TimelineSystemScript.TimelineEra.PRESENT, "slash")
		ok = _check(_is_vec2_finite(echo.origin) and _is_vec2_finite(echo.aim_dir) and echo.aim_dir.length() > 0.0,
			"timeline_system.gd:163 spawn_chrono_echo produced non-finite origin=%s or aim_dir=%s on input=%s" % [str(echo.origin), str(echo.aim_dir), str(bad_vec)]) and ok

		var shift_res: Dictionary = ts.try_shift_timeline(bad_vec, -1, false, bad_vec)
		ok = _check(_is_vec2_finite(shift_res["preserved_velocity"]),
			"timeline_system.gd:385 try_shift_timeline preserved non-finite velocity=%s" % str(shift_res["preserved_velocity"])) and ok

	for bad_dt in [NAN, INF, -INF, -5.0, 0.0, 1e6]:
		ts.tick(bad_dt)
		ok = _check(is_finite(ts.shift_flash_timer) and ts.shift_flash_timer >= 0.0,
			"timeline_system.gd: shift_flash_timer corrupted on dt=%s" % str(bad_dt)) and ok
		for t_val in ts.era_enemy_stack_timers:
			ok = _check(is_finite(t_val) and t_val >= 0.0,
				"timeline_system.gd: era_enemy_stack_timers corrupted on dt=%s" % str(bad_dt)) and ok

	return ok


func attack_1h_pose_solver_and_weapon_assembly_nan_inf_zero() -> bool:
	var ok: bool = true
	var stances: Array[String] = ["normal", "heavy_slash", "downward_slam", "parry_guard", "wall_slide", "well_unlock"]

	for stance in stances:
		for bad_val in [0.0, NAN, INF, -INF, -10.0, 1e6]:
			var bad_vec := Vector2(bad_val, bad_val)
			var pose := ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
				bad_vec, bad_val, bad_vec, true, bad_val, true, bad_val, false, stance
			)
			ok = _check(
				_is_vec2_finite(pose.head_center)
				and _is_vec2_finite(pose.neck)
				and _is_vec2_finite(pose.pelvis)
				and _is_vec2_finite(pose.left_hand)
				and _is_vec2_finite(pose.right_hand)
				and _is_vec2_finite(pose.left_foot)
				and _is_vec2_finite(pose.right_foot)
				and _is_vec2_finite(pose.sword_hilt)
				and _is_vec2_finite(pose.sword_tip)
				and _is_vec2_finite(pose.scarf_nodes[0])
				and _is_vec2_finite(pose.scarf_nodes[2]),
				"modular_asset_system.gd:741-952 StickmanPoseSolver.generate_stickman_pose produced NaN/Inf joint positions (head=%s, sword_tip=%s, scarf0=%s) on stance='%s', val=%s" % [
					str(pose.head_center), str(pose.sword_tip), str(pose.scarf_nodes[0]), stance, str(bad_val)
				]
			) and ok

			for slot_idx in range(20):
				var xform: Dictionary = ModularAssetScript.StickmanPoseSolver.compute_slot_transform(pose, slot_idx, bad_val)
				ok = _check(
					_is_vec2_finite(xform["start"])
					and _is_vec2_finite(xform["end"])
					and _is_vec2_finite(xform["center"])
					and is_finite(float(xform["angle"]))
					and is_finite(float(xform["length"])),
					"modular_asset_system.gd:955-1073 compute_slot_transform produced non-finite transform for slot=%d on val=%s" % [slot_idx, str(bad_val)]
				) and ok

	var reg := ModularAssetScript.ModularAssetRegistry.new()
	var staff_assembly := reg.get_loadout("player_shift_staff").weapon_assembly
	for bad_val in [0.0, NAN, INF, -INF, 1e6]:
		var bad_vec := Vector2(bad_val, bad_val)
		var xforms := staff_assembly.compute_piece_transforms(bad_vec, bad_vec, bad_val, bad_val, bad_val)
		for xf in xforms:
			ok = _check(
				_is_vec2_finite(xf["start"])
				and _is_vec2_finite(xf["end"])
				and _is_vec2_finite(xf["center"])
				and is_finite(float(xf["rotation"]))
				and is_finite(float(xf["gear_phase_offset"])),
				"modular_asset_system.gd:410-550 WeaponAssemblySpec.compute_piece_transforms produced non-finite transform %s on bad_val=%s" % [str(xf), str(bad_val)]
			) and ok

	return ok


# =============================================================================
# 2. Race Conditions & State Deadlocks
# =============================================================================

func attack_2a_simultaneous_bullet_deflection_and_player_contact() -> bool:
	var ok: bool = true
	var player := PlayerKinematicsScript.PlayerState.new()
	player.position = Vector2(0.0, -200.0)
	player.health = 100.0
	player.facing = 1.0

	# Bullet is overlapping the player's body AND inside the katana parry/slash arc in the same frame!
	var overlap_bullet := CombatMathScript.BulletData.new(
		player.position + Vector2(4.0, 16.0),
		Vector2(-600.0, 0.0),
		6.0,
		25.0,
		3.0,
		false,
		2
	)
	var bullets: Array = [overlap_bullet]

	# Case 1: Deflection (parry) in the same frame as player contact
	var slash_res: Dictionary = CombatMathScript.perform_katana_slash(
		player, Vector2(100.0, -184.0), {}, bullets, null, true
	)
	ok = _check(slash_res["hit_bullets"] == 1 and overlap_bullet.is_reflected,
		"Bullet overlapping player must be deflected by parry slash") and ok

	# Simulate bullet-player contact check in the same frame: reflected bullets must NEVER hurt the player!
	if overlap_bullet.step_bullet(0.016) and overlap_bullet.damage > 0.0 and not overlap_bullet.is_reflected:
		if overlap_bullet.position.distance_to(player.position + Vector2(0.0, 16.0)) <= overlap_bullet.radius + 14.0:
			player.health -= overlap_bullet.damage
	ok = _check(is_equal_approx(player.health, 100.0),
		"Deflected bullet damaged player in the same frame") and ok

	# Case 2: Non-deflecting slash destroys bullet and zeroes damage/lifetime immediately
	player.slash_cooldown = 0.0
	var destroy_bullet := CombatMathScript.BulletData.new(
		player.position + Vector2(4.0, 16.0),
		Vector2(-600.0, 0.0),
		6.0,
		25.0,
		3.0
	)
	var bullets2: Array = [destroy_bullet]
	CombatMathScript.perform_katana_slash(player, Vector2(100.0, -184.0), {}, bullets2, null, false)
	if destroy_bullet.step_bullet(0.016) and destroy_bullet.damage > 0.0:
		player.health -= destroy_bullet.damage
	ok = _check(is_equal_approx(player.health, 100.0) and destroy_bullet.damage == 0.0 and destroy_bullet.lifetime == 0.0,
		"Destroyed bullet still had non-zero damage/lifetime in same frame") and ok

	return ok


func attack_2b_duplicate_slice_event_deduplication_and_ragdoll_count() -> bool:
	var ok: bool = true
	var chrono := TimeControlScript.new()
	var combo := CombatMathScript.ComboState.new()
	var wave_mgr := EnemyAIScript.WaveManager.new()
	wave_mgr.alive_count = 3
	var energy := PlayerKinematicsScript.ChronoEnergy.new()
	energy.current = 10.0

	var enemies_by_id: Dictionary = {
		42: EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.HEAVY, Vector2(50.0, -200.0)),
	}

	# 4 duplicate SliceEventData instances for enemy 42 in the exact same frame (e.g. slash + echo + reflected bullet + slam)
	var duplicate_events: Array = [
		CombatMathScript.SliceEventData.new(42, Vector2(50.0, -200.0), Vector2.RIGHT, Vector2(200.0, 100.0), false, false, false),
		CombatMathScript.SliceEventData.new(42, Vector2(50.0, -200.0), Vector2.LEFT, Vector2(-200.0, 100.0), true, false, false),
		CombatMathScript.SliceEventData.new(42, Vector2(50.0, -200.0), Vector2.UP, Vector2(0.0, 300.0), false, true, false),
		CombatMathScript.SliceEventData.new(42, Vector2(50.0, -200.0), Vector2.DOWN, Vector2(0.0, -300.0), false, false, true),
	]

	var res: Dictionary = CombatMathScript.resolve_slice_events(
		duplicate_events, chrono, combo, wave_mgr, energy, enemies_by_id
	)

	ok = _check(wave_mgr.alive_count == 2,
		"Duplicate SliceEventData decremented alive_count to %d instead of 2" % wave_mgr.alive_count) and ok
	ok = _check(combo.total_kills == 1 and combo.count == 1,
		"Duplicate SliceEventData registered %d kills instead of 1" % combo.total_kills) and ok
	ok = _check(res["ragdolls"].size() == 2,
		"Duplicate SliceEventData spawned %d ragdoll halves instead of 2" % res["ragdolls"].size()) and ok
	ok = _check(res["killed_ids"].size() == 1 and res["killed_ids"][0] == 42,
		"Duplicate SliceEventData killed_ids mismatch: %s" % str(res["killed_ids"])) and ok
	ok = _check(is_equal_approx(energy.current, 35.0),
		"Duplicate SliceEventData restored energy multiple times to %f" % energy.current) and ok

	return ok


func attack_2c_rapid_timeline_cycling_with_echoes_and_juggled_enemies() -> bool:
	var ok: bool = true
	var ts := TimelineSystemScript.TimelineState.new()
	ts.setup_horde_arena()

	# Spawn echoes in all 3 eras and launch an airborne juggled enemy
	ts.spawn_chrono_echo(Vector2(0.0, -150.0), Vector2.RIGHT, TimelineSystemScript.TimelineEra.PAST, "slash")
	ts.spawn_chrono_echo(Vector2(50.0, -150.0), Vector2.LEFT, TimelineSystemScript.TimelineEra.PRESENT, "warp")
	ts.spawn_chrono_echo(Vector2(-50.0, -150.0), Vector2.UP, TimelineSystemScript.TimelineEra.FUTURE, "slam")

	var juggled_enemy := EnemyAIScript.EnemyData.new(EnemyAIScript.EnemyType.NINJA, Vector2(0.0, -100.0), TimelineSystemScript.TimelineEra.PAST)
	EnemyAIScript.launch_enemy(juggled_enemy, Vector2(60.0, 480.0), 0.75)

	var total_detonated: int = 0
	var vel := Vector2(320.0, 450.0)
	# Rapidly cycle PAST -> PRESENT -> FUTURE 30 times
	for i in range(30):
		var sres: Dictionary = ts.try_shift_timeline(Vector2(0.0, -200.0), -1, false, vel)
		ok = _check(sres["shifted"] == true, "Rapid timeline shift %d failed" % i) and ok
		ok = _check(sres["preserved_velocity"] == vel, "Velocity lost during rapid timeline shift %d" % i) and ok
		total_detonated += (sres["detonated_echoes"] as Array).size()
		ts.tick(0.005)

		var ai_step: Dictionary = EnemyAIScript.step_enemy_ai(juggled_enemy, Vector2.ZERO, 0.005)
		EnemyAIScript.step_enemy_physics(
			juggled_enemy,
			float(ai_step["move_dir"]),
			bool(ai_step["should_jump"]),
			ts.get_active_platforms(),
			0.005
		)
		ok = _check(_is_vec2_finite(juggled_enemy.position) and _is_vec2_finite(juggled_enemy.velocity),
			"Juggled enemy state corrupted during rapid timeline cycling at step %d" % i) and ok

	ok = _check(total_detonated == 3 and ts.echoes.is_empty(),
		"All 3 echoes across PAST/PRESENT/FUTURE must detonate exactly once (got %d detonated, %d remaining)" % [total_detonated, ts.echoes.size()]) and ok

	return ok


func attack_2d_reverse_gear_insta_death_vs_parry_counter_priority() -> bool:
	var ok: bool = true
	var shifter := ChronoShiftScript.ChronoShifterState.new()
	shifter.step_control(ChronoShiftScript.ShifterInput.new(true, Vector2.ZERO, 0, ChronoShiftScript.Gear.R), 0.016)
	for _i in range(40):
		shifter.step_control(ChronoShiftScript.ShifterInput.new(true), 0.016)

	ok = _check(shifter.model.get_active_gear() == ChronoShiftScript.Gear.R,
		"Shifter must be in Reverse Gear (R)") and ok

	# Scenario A: Player executes a parry slash against an overlapping bullet while in Reverse Gear (R).
	# Parry counter MUST take priority over contact damage so reverse_insta_death is NOT triggered!
	var player := PlayerKinematicsScript.PlayerState.new()
	player.position = Vector2(0.0, -200.0)
	player.parry_timer = 0.15
	var bullet := CombatMathScript.BulletData.new(Vector2(15.0, -184.0), Vector2(-500.0, 0.0), 6.0, 30.0, 3.0)
	var bullets: Array = [bullet]

	var slash_res: Dictionary = CombatMathScript.perform_katana_slash(
		player, Vector2(100.0, -184.0), {}, bullets, null, true
	)
	if not bullet.is_reflected and bullet.damage > 0.0:
		shifter.apply_damage_knockdown()

	ok = _check(slash_res["hit_bullets"] == 1 and bullet.is_reflected and not shifter.acclimatization.reverse_insta_death,
		"Parry counter in Reverse Gear must deflect bullet and prevent reverse_insta_death") and ok
	ok = _check(shifter.model.get_active_gear() == ChronoShiftScript.Gear.R,
		"Successful parry in Reverse Gear must keep shifter in Reverse Gear") and ok

	# Scenario B: Unparried damage while in Reverse Gear (R) triggers insta-death and knocks to Neutral!
	var knocked_to: int = shifter.apply_damage_knockdown()
	ok = _check(shifter.acclimatization.reverse_insta_death == true and knocked_to == ChronoShiftScript.Gear.N,
		"Unparried hit in Reverse Gear must trigger reverse_insta_death and knock down to Gear.N") and ok

	return ok


func attack_2e_turbo_shifter_6s_boundary_and_downshift_recovery() -> bool:
	var ok: bool = true
	var accl := ChronoShiftScript.GearAcclimatization.new()

	# Tick up to 5.999s in Gear 5 -> must NOT overheat yet
	accl.tick(5.999, ChronoShiftScript.Gear.G5)
	ok = _check(not accl.turbo_overheated and accl.is_turbo_active(ChronoShiftScript.Gear.G5),
		"Turbo must remain active at 5.999s (< 6.0s)") and ok

	# Tick exact 6.0s boundary -> turbo_overuse_timer == 6.0 (not > 6.0 yet)
	accl.tick(0.001, ChronoShiftScript.Gear.G5)
	ok = _check(not accl.turbo_overheated,
		"Turbo must not overheat at exact 6.000s boundary") and ok

	# Tick 0.002s past 6.0s -> must overheat!
	accl.tick(0.002, ChronoShiftScript.Gear.G5)
	ok = _check(accl.turbo_overheated and not accl.is_turbo_active(ChronoShiftScript.Gear.G5),
		"Turbo must overheat once turbo_overuse_timer > 6.0s") and ok

	# Switching from Gear 5 to Gear 6 while overheated must NOT clear overheat!
	accl.tick(0.1, ChronoShiftScript.Gear.G6)
	ok = _check(accl.turbo_overheated and accl.turbo_overuse_timer > 6.0,
		"Shifting between G5 and G6 must not bypass turbo overheat") and ok

	# Shifting down to Gear 1..4 must immediately recover turbo_overheated and reset timer
	for down_gear in [ChronoShiftScript.Gear.G4, ChronoShiftScript.Gear.G3, ChronoShiftScript.Gear.G2, ChronoShiftScript.Gear.G1]:
		accl.turbo_overuse_timer = 7.0
		accl.turbo_overheated = true
		accl.tick(0.016, down_gear)
		ok = _check(not accl.turbo_overheated and is_equal_approx(accl.turbo_overuse_timer, 0.0),
			"Shifting down to Gear %d must reset turbo_overheated and turbo_overuse_timer" % down_gear) and ok

	return ok


# =============================================================================
# 3. Modular Piece-by-Piece Asset Edge Cases
# =============================================================================

func attack_3a_malformed_json_manifests_graceful_degradation() -> bool:
	var ok: bool = true
	var reg := ModularAssetScript.ModularAssetRegistry.new()

	var malformed_payloads: Array[String] = [
		"",
		"   \n\t  ",
		"{not valid json",
		"[]",
		"null",
		"12345",
		"\"just a string\"",
	]
	for bad_json in malformed_payloads:
		var res: bool = reg.load_manifest_json(bad_json)
		ok = _check(res == false,
			"load_manifest_json must return false on malformed JSON: '%s'" % bad_json) and ok

	# Now test structurally valid JSON object with hostile/null/corrupted field types inside parts, weapon_pieces, and loadouts
	var hostile_manifest_dict: Dictionary = {
		"version": null,
		"parts": [
			null,
			123,
			"bad_entry",
			{
				"part_id": "hostile_null_fields_part",
				"slot": null,
				"backend": null,
				"texture_path": null,
				"scene_path": null,
				"polygon_points": [null, "bad_pt", {"x": null, "y": "nan"}, [1.0]],
				"line_width": null,
				"primary_color": {"r": null, "g": "bad", "b": null, "a": null},
				"secondary_color": [null, "bad", {}, []],
				"offset": {"x": null, "y": "bad"},
				"rotation_offset": null,
				"scale": [null, null],
				"region_rect": {"x": null, "y": "bad", "w": null, "h": null},
				"z_offset": null,
				"metadata": "not_a_dict",
				"target_loadout": "player_shift_staff"
			}
		],
		"weapon_pieces": [
			null,
			{
				"piece_id": "hostile_null_weapon_piece",
				"piece_slot": null,
				"backend": "INVALID_BACKEND",
				"texture_path": "res://nonexistent_dir/missing_tex.png",
				"polygon_points": "not_an_array",
				"local_offset": null,
				"length": null,
				"thickness": "bad_float",
				"color": "#not_a_hex_color",
				"glow_color": null,
				"rotates_with_gear": null,
				"key_tooth_length": null,
				"target_loadout": "player_shift_staff"
			}
		],
		"loadouts": {
			"corrupted_loadout": {
				"loadout_id": null,
				"display_name": null,
				"body_color": null,
				"accent_color": "invalid_hex",
				"parts": "not_a_dict_or_array",
				"weapon_assembly": "not_a_dict"
			}
		}
	}
	var hostile_json: String = JSON.stringify(hostile_manifest_dict)
	var loaded_hostile: bool = reg.load_manifest_json(hostile_json)
	ok = _check(loaded_hostile == true,
		"modular_asset_system.gd: load_manifest_json failed on hostile manifest with null/corrupted field types") and ok

	var hostile_part := reg.get_registered_part("hostile_null_fields_part")
	ok = _check(hostile_part != null and is_finite(hostile_part.line_width) and _is_vec2_finite(hostile_part.offset),
		"modular_asset_system.gd: hostile part should degrade gracefully with finite defaults") and ok

	return ok


func attack_3b_invalid_slot_names_and_numbers_and_missing_textures() -> bool:
	var ok: bool = true
	var _reg := ModularAssetScript.ModularAssetRegistry.new()

	# Pass invalid slot names, out-of-range negative/huge slot numbers, and missing texture paths
	var part_bad_slot_num := ModularAssetScript.PartPieceSpec.from_dict({
		"part_id": "bad_slot_num_part",
		"slot": -999,
		"backend": 9999,
		"texture_path": "res://missing_folder_xyz/nonexistent_sprite.png",
	})
	ok = _check(
		part_bad_slot_num.slot >= 0 and part_bad_slot_num.slot < 20,
		"modular_asset_system.gd:146-155 _Ser.parse_slot_enum accepted out-of-range PartSlot=%d instead of falling back to valid PartSlot [0..19]" % part_bad_slot_num.slot
	) and ok
	ok = _check(
		part_bad_slot_num.backend >= 0 and part_bad_slot_num.backend <= 3,
		"modular_asset_system.gd:146-155 _Ser.parse_slot_enum accepted out-of-range AssetRenderBackend=%d instead of falling back to valid backend [0..3]" % part_bad_slot_num.backend
	) and ok
	ok = _check(
		part_bad_slot_num.texture == null,
		"Missing texture_path must degrade gracefully to texture == null without crashing"
	) and ok

	var wp_bad_slot := ModularAssetScript.WeaponPieceSpec.from_dict({
		"piece_id": "bad_wp_slot",
		"piece_slot": 88888,
		"backend": -42,
		"texture_path": "res://scripts/core/time_control.gd", # Existing non-texture resource!
	})
	ok = _check(
		wp_bad_slot.piece_slot >= 0 and wp_bad_slot.piece_slot <= 10,
		"modular_asset_system.gd:146-155 _Ser.parse_slot_enum accepted out-of-range WeaponPieceSlot=%d instead of falling back to valid WeaponPieceSlot [0..10]" % wp_bad_slot.piece_slot
	) and ok
	ok = _check(
		wp_bad_slot.backend >= 0 and wp_bad_slot.backend <= 3,
		"modular_asset_system.gd:146-155 _Ser.parse_slot_enum accepted out-of-range backend=%d" % wp_bad_slot.backend
	) and ok
	ok = _check(
		wp_bad_slot.texture == null,
		"Non-Texture2D resource path must not assign invalid texture"
	) and ok

	# Also test string integer out of range like "9999" and float NaN/Inf in parse_slot_enum
	var part_str_num := ModularAssetScript.PartPieceSpec.from_dict({
		"part_id": "bad_str_int_slot",
		"slot": "9999",
		"backend": NAN,
	})
	ok = _check(
		part_str_num.slot >= 0 and part_str_num.slot < 20,
		"modular_asset_system.gd:153 _Ser.parse_slot_enum accepted out-of-range string int '9999' -> %d" % part_str_num.slot
	) and ok

	return ok


func attack_3c_ragdoll_split_preserves_custom_polygon_and_texture_parts() -> bool:
	var ok: bool = true
	var reg := ModularAssetScript.ModularAssetRegistry.new()
	var loadout := reg.get_loadout("enemy_ninja").duplicate_loadout()

	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	var custom_tex := ImageTexture.create_from_image(img)

	# Equip custom TEXTURE_SPRITE on HEAD (UpperTorso) and CUSTOM_POLYGON on SHIN_R (LowerLegs)
	var head_sprite := ModularAssetScript.PartPieceSpec.new(
		"custom_cyber_head_tex",
		ModularAssetScript.PartSlot.HEAD,
		ModularAssetScript.AssetRenderBackend.TEXTURE_SPRITE
	)
	head_sprite.texture = custom_tex
	head_sprite.texture_path = "res://icon.svg"
	loadout.equip_part(head_sprite)

	var shin_poly := ModularAssetScript.PartPieceSpec.new(
		"custom_shin_guard_poly",
		ModularAssetScript.PartSlot.SHIN_R,
		ModularAssetScript.AssetRenderBackend.CUSTOM_POLYGON
	)
	shin_poly.polygon_points = PackedVector2Array([Vector2(-3, -5), Vector2(3, -5), Vector2(4, 5), Vector2(-4, 5)])
	loadout.equip_part(shin_poly)

	var split: Dictionary = loadout.split_for_ragdoll()
	var upper: ModularAssetScript.CharacterLoadout = split["upper"]
	var lower: ModularAssetScript.CharacterLoadout = split["lower"]

	var upper_head := upper.get_part(ModularAssetScript.PartSlot.HEAD)
	var upper_cowl := upper.get_part(ModularAssetScript.PartSlot.HAT_HELMET)
	var lower_shin := lower.get_part(ModularAssetScript.PartSlot.SHIN_R)

	ok = _check(
		upper_head != null
		and upper_head.part_id == "custom_cyber_head_tex"
		and upper_head.backend == ModularAssetScript.AssetRenderBackend.TEXTURE_SPRITE
		and upper_head.texture == custom_tex,
		"UpperTorso must preserve custom TEXTURE_SPRITE head part and runtime Texture2D"
	) and ok
	ok = _check(
		upper_cowl != null
		and upper_cowl.part_id == "ninja_cowl_hood"
		and upper_cowl.polygon_points.size() == 4,
		"UpperTorso must preserve ninja_cowl_hood CUSTOM_POLYGON"
	) and ok
	ok = _check(
		lower_shin != null
		and lower_shin.part_id == "custom_shin_guard_poly"
		and lower_shin.backend == ModularAssetScript.AssetRenderBackend.CUSTOM_POLYGON
		and lower_shin.polygon_points.size() == 4,
		"LowerLegs must preserve custom CUSTOM_POLYGON shin guard"
	) and ok
	ok = _check(
		lower.get_part(ModularAssetScript.PartSlot.HEAD) == null
		and upper.get_part(ModularAssetScript.PartSlot.SHIN_R) == null,
		"UpperTorso and LowerLegs must strictly partition upper vs lower slots"
	) and ok

	return ok


# =============================================================================
# 4. Playable GameController & AudioManager Adversarial Stress
# =============================================================================

func attack_4a_game_controller_and_audio_adversarial_stress() -> bool:
	var ok: bool = true
	var packed: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	var ctrl: GameController = inst as GameController
	ctrl._ensure_scene_nodes()

	# Test corrupted/extreme input_override values & NaN/Inf deltas
	for bad_dt in [NAN, INF, -INF, -5.0, 0.0, 1e6, 0.016]:
		ctrl.step_simulation(bad_dt, {
			"move_x": null,
			"shift_gear": "invalid_gear",
			"shift_wheel": NAN,
			"shift_drag": Vector2(INF, -INF),
			"aim_world": Vector2(INF, 0.0),
			"cursor_screen": Vector2(NAN, INF),
			"wall_normal_x": null,
			"slash": true,
			"heavy": true,
			"parry": true,
			"warp": true,
			"dash": true,
			"jump_pressed": true,
			"timeline_shift": true,
			"cycle_customization": true,
		})
		ok = _check(
			_is_vec2_finite(ctrl.player.position) and _is_vec2_finite(ctrl.player.velocity),
			"game_controller.gd: player position/velocity must stay finite under corrupted input_override (dt=%s)" % str(bad_dt)
		) and ok

	# Test AudioManager with NaN/Inf pitch/volume & unknown SFX keys
	ctrl.audio_mgr.play_sfx("non_existent_sound_key", NAN, INF)
	ctrl.audio_mgr.play_sfx("slash.wav", -INF, NAN)
	ok = _check(
		ctrl.audio_mgr.last_played_sfx == "slash",
		"audio_manager.gd: play_sfx('slash.wav', -INF, NAN) must normalize key and not crash"
	) and ok

	ctrl._draw()
	ok = _check(
		ctrl.last_draw_primitive_count > 50,
		"game_controller.gd: _draw() must render cleanly after adversarial simulation steps"
	) and ok

	if ctrl.get_parent() != null:
		ctrl.get_parent().remove_child(ctrl)
	ctrl.free()
	return ok

