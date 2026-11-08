extends SceneTree

## Comprehensive Unit & Adversarial Test Suite for Core Kinematics, Combat, Enemies, Ragdolls & Time Control.
## Ports all core gameplay tests from bevy-game-test/src/tests.rs + OUT OF TIME spec tests.

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0


func _init() -> void:
	print("=== RUNNING CORE KINEMATICS & COMBAT TEST SUITE ===")

	_run_test("test_step_horizontal_velocity_accel_decel", test_step_horizontal_velocity_accel_decel)
	_run_test("test_step_horizontal_velocity_reverse_direction", test_step_horizontal_velocity_reverse_direction)
	_run_test("test_step_vertical_velocity_jump_and_gravity", test_step_vertical_velocity_jump_and_gravity)
	_run_test("test_coyote_time_allows_late_jump", test_coyote_time_allows_late_jump)
	_run_test("test_jump_buffer_triggers_on_landing", test_jump_buffer_triggers_on_landing)
	_run_test("test_chrono_energy_drain_and_regen", test_chrono_energy_drain_and_regen)
	_run_test("test_chrono_energy_teleport_cost_and_kill_reward", test_chrono_energy_teleport_cost_and_kill_reward)
	_run_test("test_chrono_time_dilation_math", test_chrono_time_dilation_math)
	_run_test("test_point_to_line_segment_distance_and_circle_intersection", test_point_to_line_segment_distance_and_circle_intersection)
	_run_test("test_katana_arc_intersection", test_katana_arc_intersection)
	_run_test("test_combo_multiplier_scaling_and_decay", test_combo_multiplier_scaling_and_decay)
	_run_test("test_enemy_ai_windup_transition_and_jump", test_enemy_ai_windup_transition_and_jump)
	_run_test("test_wave_scaling_formula", test_wave_scaling_formula)
	_run_test("test_wave_manager_progression", test_wave_manager_progression)
	_run_test("test_ragdoll_slice_velocities_split", test_ragdoll_slice_velocities_split)
	_run_test("test_degenerate_zero_length_teleport_segment", test_degenerate_zero_length_teleport_segment)
	_run_test("test_zero_slice_direction_ragdoll_velocity_no_nan", test_zero_slice_direction_ragdoll_velocity_no_nan)
	_run_test("test_hitstop_duration_max_stacking", test_hitstop_duration_max_stacking)
	_run_test("test_screen_shake_clamping_and_decay", test_screen_shake_clamping_and_decay)
	_run_test("test_combo_multiplier_all_tier_boundaries", test_combo_multiplier_all_tier_boundaries)
	_run_test("test_adversarial_ragdoll_piece_leak_verification", test_adversarial_ragdoll_piece_leak_verification)
	_run_test("test_adversarial_duplicate_slice_events_double_decrement_alive_count", test_adversarial_duplicate_slice_events_double_decrement_alive_count)
	_run_test("test_adversarial_wave_phase_zero_enemies_deadlock", test_adversarial_wave_phase_zero_enemies_deadlock)
	_run_test("test_adversarial_enemy_out_of_bounds_recovery", test_adversarial_enemy_out_of_bounds_recovery)
	_run_test("test_gunner_ai_tactical_distance_and_shooting", test_gunner_ai_tactical_distance_and_shooting)
	_run_test("test_gunner_spawning_and_bullet_firing_system", test_gunner_spawning_and_bullet_firing_system)
	_run_test("test_bullet_system_slow_motion_dilation", test_bullet_system_slow_motion_dilation)
	_run_test("test_katana_slash_slashes_bullet_and_reduces_cooldown", test_katana_slash_slashes_bullet_and_reduces_cooldown)
	_run_test("test_katana_slash_hits_enemy_and_reduces_cooldown", test_katana_slash_hits_enemy_and_reduces_cooldown)
	_run_test("test_chrono_warp_hits_enemy_reduces_cooldown_but_not_bullets", test_chrono_warp_hits_enemy_reduces_cooldown_but_not_bullets)
	_run_test("test_wave_cleared_real_time_transition", test_wave_cleared_real_time_transition)
	_run_test("test_wave_manager_spawn_distribution_gunners", test_wave_manager_spawn_distribution_gunners)
	_run_test("test_adversarial_bullet_slice_race_condition", test_adversarial_bullet_slice_race_condition)
	_run_test("test_adversarial_gunner_multi_attack_cycle_permanent_lockout", test_adversarial_gunner_multi_attack_cycle_permanent_lockout)
	_run_test("test_adversarial_gunner_auto_burst_and_subsequent_cycle", test_adversarial_gunner_auto_burst_and_subsequent_cycle)
	_run_test("test_adversarial_slash_both_enemy_and_bullet_simultaneously", test_adversarial_slash_both_enemy_and_bullet_simultaneously)
	_run_test("test_adversarial_zero_distance_bullet_aiming_no_nan", test_adversarial_zero_distance_bullet_aiming_no_nan)

	# New OUT OF TIME Spec Tests
	_run_test("test_kinetic_dash_cancels_light_slash_recovery", test_kinetic_dash_cancels_light_slash_recovery)
	_run_test("test_wall_slide_and_diagonal_wall_rebound_jump", test_wall_slide_and_diagonal_wall_rebound_jump)
	_run_test("test_heavy_launcher_and_aerial_juggle_gravity", test_heavy_launcher_and_aerial_juggle_gravity)
	_run_test("test_downward_slam_shockwave_and_parry_bullet_reflection_with_sniper_ricochet", test_downward_slam_shockwave_and_parry_bullet_reflection_with_sniper_ricochet)
	_run_test("test_dmc_style_rank_progression_d_to_sss", test_dmc_style_rank_progression_d_to_sss)

	print("=== TEST SUMMARY: %d / %d PASSED (%d FAILED) ===" % [_tests_passed, _tests_run, _tests_failed])
	quit(0 if _tests_failed == 0 else 1)


func _run_test(test_name: String, fn: Callable) -> void:
	_tests_run += 1
	var ok: bool = fn.call()
	if ok:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % test_name)


func _assert(cond: bool, msg: String = "Assertion failed") -> bool:
	if not cond:
		printerr("    ASSERTION FAILED: %s" % msg)
		return false
	return true


# -----------------------------------------------------------------------------
# 1. Ported Bevy Core Tests
# -----------------------------------------------------------------------------

func test_step_horizontal_velocity_accel_decel() -> bool:
	var config := PlayerKinematics.MovementConfig.new()
	config.accel = 2000.0
	config.decel = 3000.0
	config.max_speed = 300.0

	var dt: float = 0.05
	var v1: float = PlayerKinematics.step_horizontal_velocity(0.0, 1.0, config, dt)
	if not _assert(is_equal_approx(v1, 100.0), "Expected v1 == 100.0, got %f" % v1):
		return false

	var v_max: float = PlayerKinematics.step_horizontal_velocity(250.0, 1.0, config, dt)
	if not _assert(is_equal_approx(v_max, 300.0), "Expected v_max == 300.0, got %f" % v_max):
		return false

	var v_stop: float = PlayerKinematics.step_horizontal_velocity(100.0, 0.0, config, dt)
	if not _assert(is_equal_approx(v_stop, 0.0), "Expected v_stop == 0.0, got %f" % v_stop):
		return false

	return true


func test_step_horizontal_velocity_reverse_direction() -> bool:
	var config := PlayerKinematics.MovementConfig.new()
	config.accel = 2000.0
	config.decel = 3000.0
	config.max_speed = 300.0

	var dt: float = 0.05
	var v: float = PlayerKinematics.step_horizontal_velocity(200.0, -1.0, config, dt)
	return _assert(is_equal_approx(v, 100.0), "Expected v == 100.0, got %f" % v)


func test_step_vertical_velocity_jump_and_gravity() -> bool:
	var config := PlayerKinematics.MovementConfig.new()
	config.jump_force = 500.0
	config.gravity = 1000.0
	config.fall_gravity_mult = 1.5
	config.short_hop_mult = 2.0
	config.coyote_time_max = 0.1
	config.jump_buffer_max = 0.1

	var dt: float = 0.02
	var res1: Dictionary = PlayerKinematics.step_vertical_velocity(0.0, true, true, true, 0.0, 0.0, config, dt)
	if not _assert(res1["did_jump"] == true, "Expected did_jump == true"):
		return false
	if not _assert(is_equal_approx(res1["vy"], 500.0), "Expected vy == 500.0"):
		return false
	if not _assert(is_equal_approx(res1["coyote_timer"], 0.0), "Expected coyote == 0.0"):
		return false
	if not _assert(is_equal_approx(res1["jump_buffer_timer"], 0.0), "Expected buffer == 0.0"):
		return false

	var res_rise: Dictionary = PlayerKinematics.step_vertical_velocity(500.0, false, true, false, 0.0, 0.0, config, dt)
	if not _assert(is_equal_approx(res_rise["vy"], 480.0), "Expected vy_rise == 480.0"):
		return false

	var res_short: Dictionary = PlayerKinematics.step_vertical_velocity(500.0, false, false, false, 0.0, 0.0, config, dt)
	if not _assert(is_equal_approx(res_short["vy"], 460.0), "Expected vy_short == 460.0"):
		return false

	var res_fall: Dictionary = PlayerKinematics.step_vertical_velocity(-50.0, false, false, false, 0.0, 0.0, config, dt)
	if not _assert(is_equal_approx(res_fall["vy"], -80.0), "Expected vy_fall == -80.0"):
		return false

	return true


func test_coyote_time_allows_late_jump() -> bool:
	var config := PlayerKinematics.MovementConfig.new()
	config.jump_force = 500.0
	config.coyote_time_max = 0.12
	config.jump_buffer_max = 0.12

	var dt: float = 0.03
	var res1: Dictionary = PlayerKinematics.step_vertical_velocity(-10.0, false, true, true, 0.10, 0.0, config, dt)
	if not _assert(res1["did_jump"] == true and is_equal_approx(res1["vy"], 500.0), "Coyote jump should succeed"):
		return false

	var res2: Dictionary = PlayerKinematics.step_vertical_velocity(-10.0, false, true, true, 0.0, 0.0, config, dt)
	if not _assert(res2["did_jump"] == false and res2["vy"] < -10.0, "Expired coyote timer should not jump"):
		return false

	return true


func test_jump_buffer_triggers_on_landing() -> bool:
	var config := PlayerKinematics.MovementConfig.new()
	config.jump_force = 500.0
	config.coyote_time_max = 0.12
	config.jump_buffer_max = 0.12

	var dt: float = 0.04
	var res1: Dictionary = PlayerKinematics.step_vertical_velocity(-200.0, false, true, true, 0.0, 0.0, config, dt)
	if not _assert(res1["did_jump"] == false and res1["jump_buffer_timer"] > 0.0, "Midair jump should buffer"):
		return false

	var res2: Dictionary = PlayerKinematics.step_vertical_velocity(0.0, true, true, false, 0.0, res1["jump_buffer_timer"], config, dt)
	if not _assert(res2["did_jump"] == true and is_equal_approx(res2["vy"], 500.0), "Landing with active buffer should jump"):
		return false

	return true


func test_chrono_energy_drain_and_regen() -> bool:
	var energy := PlayerKinematics.ChronoEnergy.new()
	energy.current = 100.0
	energy.max_energy = 100.0
	energy.drain_rate = 20.0
	energy.regen_rate = 10.0
	energy.teleport_cost = 25.0
	energy.kill_restore = 20.0

	energy.update(true, 1.0)
	if not _assert(is_equal_approx(energy.current, 80.0), "Expected 80.0 after drain"):
		return false

	energy.update(false, 1.0)
	if not _assert(is_equal_approx(energy.current, 90.0), "Expected 90.0 after regen"):
		return false

	energy.update(false, 2.0)
	if not _assert(is_equal_approx(energy.current, 100.0), "Expected clamp at 100.0"):
		return false

	return true


func test_chrono_energy_teleport_cost_and_kill_reward() -> bool:
	var energy := PlayerKinematics.ChronoEnergy.new()
	energy.current = 30.0
	energy.max_energy = 100.0
	energy.drain_rate = 20.0
	energy.regen_rate = 10.0
	energy.teleport_cost = 25.0
	energy.kill_restore = 20.0

	if not _assert(energy.can_teleport(), "Should be able to teleport at 30.0"):
		return false
	if not _assert(energy.consume_teleport() and is_equal_approx(energy.current, 5.0), "Consume teleport leaves 5.0"):
		return false
	if not _assert(not energy.can_teleport() and not energy.consume_teleport(), "Cannot teleport at 5.0"):
		return false

	energy.reward_kill()
	return _assert(is_equal_approx(energy.current, 25.0) and energy.can_teleport(), "Kill reward restores to 25.0")


func test_chrono_time_dilation_math() -> bool:
	var chrono := ChronoState.new()
	chrono.dilation_factor = 1.0
	chrono.is_dilating = true
	chrono.hitstop_timer = 0.0
	chrono.slowmo_factor = 0.15

	chrono.update(0.1)
	if not _assert(chrono.dilation_factor < 0.5, "Dilation should lerp towards slowmo_factor"):
		return false

	chrono.dilation_factor = 0.15
	var real_dt: float = 0.1
	var world_dt: float = chrono.get_world_dt(real_dt)
	var player_dt: float = chrono.get_player_dt(real_dt)

	if not _assert(absf(world_dt - 0.015) < 1e-5, "Expected world_dt == 0.015"):
		return false
	if not _assert(player_dt >= real_dt, "Player is not slowed down"):
		return false

	chrono.trigger_hitstop(0.05)
	if not _assert(chrono.get_world_dt(real_dt) == 0.0 and chrono.get_player_dt(real_dt) == 0.0, "Hitstop freezes both"):
		return false

	return true


func test_point_to_line_segment_distance_and_circle_intersection() -> bool:
	var a := Vector2(0.0, 0.0)
	var b := Vector2(100.0, 0.0)

	var dist_sq: float = CombatMath.point_to_segment_distance_sq(Vector2(50.0, 0.0), a, b)
	if not _assert(is_equal_approx(dist_sq, 0.0), "Point on segment distance_sq == 0"):
		return false

	var dist_sq_above: float = CombatMath.point_to_segment_distance_sq(Vector2(50.0, 10.0), a, b)
	if not _assert(is_equal_approx(dist_sq_above, 100.0), "Point 10 units above distance_sq == 100"):
		return false

	var dist_sq_past: float = CombatMath.point_to_segment_distance_sq(Vector2(110.0, 0.0), a, b)
	if not _assert(is_equal_approx(dist_sq_past, 100.0), "Point 10 units past B distance_sq == 100"):
		return false

	var enemy_center := Vector2(50.0, 15.0)
	if not _assert(CombatMath.segment_intersects_circle(a, b, enemy_center, 18.0), "Intersects radius 18"):
		return false
	if not _assert(not CombatMath.segment_intersects_circle(a, b, enemy_center, 12.0), "Does not intersect radius 12"):
		return false

	return true


func test_katana_arc_intersection() -> bool:
	var origin := Vector2(0.0, 0.0)
	var facing: float = 1.0
	var aim_dir := Vector2(1.0, 0.0)
	var slash_range: float = 80.0
	var arc_rad: float = PI * 0.75

	if not _assert(CombatMath.katana_arc_intersects(origin, facing, aim_dir, Vector2(50.0, 10.0), slash_range, arc_rad, 15.0), "Target in front"):
		return false
	if not _assert(not CombatMath.katana_arc_intersects(origin, facing, aim_dir, Vector2(-50.0, 0.0), slash_range, arc_rad, 15.0), "Target behind"):
		return false
	if not _assert(not CombatMath.katana_arc_intersects(origin, facing, aim_dir, Vector2(120.0, 0.0), slash_range, arc_rad, 15.0), "Target too far"):
		return false

	return true


func test_combo_multiplier_scaling_and_decay() -> bool:
	var combo := CombatMath.ComboState.new()
	if not _assert(combo.multiplier == 1, "Initial multiplier == 1"):
		return false

	combo.register_kill(false)
	if not _assert(combo.count == 1 and combo.multiplier == 1 and combo.score == 100, "Kill 1"):
		return false

	combo.register_kill(false)
	if not _assert(combo.count == 2 and combo.multiplier == 2 and combo.score == 300, "Kill 2"):
		return false

	combo.register_kill(true)
	if not _assert(combo.count == 3 and combo.multiplier == 2 and combo.score == 800, "Kill 3 warp"):
		return false

	combo.update(3.0)
	return _assert(combo.count == 0 and combo.multiplier == 1 and combo.score == 800, "Decay resets combo, preserves score")


func test_enemy_ai_windup_transition_and_jump() -> bool:
	var enemy := EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(40.0, 0.0))
	var player_pos := Vector2(0.0, 0.0)

	EnemyAI.step_enemy_ai(enemy, player_pos, 0.016)
	if not _assert(enemy.state == EnemyAI.StateKind.WINDUP, "Expected transition to WINDUP"):
		return false

	var enemy_low := EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(80.0, -100.0))
	var player_high := Vector2(40.0, 0.0)
	var step_res: Dictionary = EnemyAI.step_enemy_ai(enemy_low, player_high, 0.016)
	return _assert(step_res["should_jump"] == true, "Higher player elevation should trigger jump")


func test_wave_scaling_formula() -> bool:
	return _assert(
		EnemyAI.calculate_wave_enemy_count(1) == 6
		and EnemyAI.calculate_wave_enemy_count(2) == 9
		and EnemyAI.calculate_wave_enemy_count(3) == 12
		and EnemyAI.calculate_wave_enemy_count(5) == 18,
		"Wave scaling formula 3 + wave * 3"
	)


func test_wave_manager_progression() -> bool:
	var mgr := EnemyAI.WaveManager.new()
	mgr.current_wave = 1
	mgr.phase = EnemyAI.WavePhase.INTERMISSION
	mgr.phase_timer = 0.1
	mgr.total_wave_enemies = 6
	mgr.alive_count = 0
	mgr.spawn_interval = 1.0
	mgr.intermission_duration = 2.0

	var act1: Dictionary = mgr.update(0.15, 1000.0, -200.0)
	if not _assert(act1.get("action") == "announce_wave" and act1.get("wave") == 1, "Expected announce_wave 1"):
		return false

	var act2: Dictionary = mgr.update(0.15, 1000.0, -200.0)
	if not _assert(act2.get("action") == "spawn_enemy" and mgr.alive_count == 1, "Expected spawn_enemy and alive_count == 1"):
		return false

	return true


func test_ragdoll_slice_velocities_split() -> bool:
	var base_vel := Vector2(100.0, 0.0)
	var slice_dir := Vector2(1.0, 0.0)
	var impulse := Vector2(200.0, 50.0)

	var res: Dictionary = RagdollPhysics.calculate_slice_split_velocities(base_vel, slice_dir, impulse)
	var upper_vel: Vector2 = res["upper_vel"]
	var lower_vel: Vector2 = res["lower_vel"]
	var upper_rot: float = res["upper_ang_vel"]
	var lower_rot: float = res["lower_ang_vel"]

	return _assert(
		upper_vel.y > 0.0 and not is_equal_approx(upper_rot, lower_rot) and (upper_vel - lower_vel).length() > 50.0,
		"Ragdoll halves must separate with distinct linear and angular velocities"
	)


func test_degenerate_zero_length_teleport_segment() -> bool:
	var a := Vector2(50.0, 50.0)
	var b := Vector2(50.0, 50.0)
	var target := Vector2(50.0, 60.0)

	var dist_sq: float = CombatMath.point_to_segment_distance_sq(target, a, b)
	if not _assert(is_equal_approx(dist_sq, 100.0), "Zero-length segment distance_sq == 100"):
		return false
	return _assert(
		CombatMath.segment_intersects_circle(a, b, target, 11.0)
		and not CombatMath.segment_intersects_circle(a, b, target, 9.0),
		"Zero-length segment circle intersection"
	)


func test_zero_slice_direction_ragdoll_velocity_no_nan() -> bool:
	var res: Dictionary = RagdollPhysics.calculate_slice_split_velocities(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var upper_vel: Vector2 = res["upper_vel"]
	var lower_vel: Vector2 = res["lower_vel"]
	var upper_rot: float = res["upper_ang_vel"]
	var lower_rot: float = res["lower_ang_vel"]

	return _assert(
		is_finite(upper_vel.x) and is_finite(upper_vel.y)
		and is_finite(lower_vel.x) and is_finite(lower_vel.y)
		and is_finite(upper_rot) and is_finite(lower_rot),
		"Zero slice direction must not produce NaN"
	)


func test_hitstop_duration_max_stacking() -> bool:
	var chrono := ChronoState.new()
	chrono.trigger_hitstop(0.04)
	if not _assert(is_equal_approx(chrono.hitstop_timer, 0.04), "Hitstop 0.04"):
		return false

	chrono.trigger_hitstop(0.02)
	if not _assert(is_equal_approx(chrono.hitstop_timer, 0.04), "Shorter hitstop must not diminish existing"):
		return false

	chrono.trigger_hitstop(0.07)
	return _assert(is_equal_approx(chrono.hitstop_timer, 0.07), "Longer hitstop extends timer")


func test_screen_shake_clamping_and_decay() -> bool:
	var chrono := ChronoState.new()
	chrono.trigger_shake(35.0)
	if not _assert(is_equal_approx(chrono.screen_shake, 20.0), "Clamped at 20.0"):
		return false

	chrono.update(0.5)
	return _assert(chrono.screen_shake < 20.0, "Screen shake decays over time")


func test_combo_multiplier_all_tier_boundaries() -> bool:
	var combo := CombatMath.ComboState.new()
	combo.register_kill(false) # 1
	if not _assert(combo.multiplier == 1, "Count 1 -> 1x"):
		return false

	for _i in range(2, 5):
		combo.register_kill(false)
		if not _assert(combo.multiplier == 2, "Count 2..4 -> 2x"):
			return false

	for _i in range(5, 9):
		combo.register_kill(false)
		if not _assert(combo.multiplier == 3, "Count 5..8 -> 3x"):
			return false

	for _i in range(9, 14):
		combo.register_kill(false)
		if not _assert(combo.multiplier == 4, "Count 9..13 -> 4x"):
			return false

	combo.register_kill(false) # 14
	if not _assert(combo.multiplier == 5, "Count 14 -> 5x"):
		return false
	combo.register_kill(false) # 15
	return _assert(combo.multiplier == 5, "Count 15 -> 5x")


func test_adversarial_ragdoll_piece_leak_verification() -> bool:
	var piece := RagdollPhysics.RagdollPieceData.new(
		RagdollPhysics.RagdollPart.UPPER_TORSO,
		Vector2.ZERO,
		Vector2.ZERO,
		0.0,
		1.0,
		Color.WHITE
	)
	var alive: bool = true
	for _i in range(60):
		alive = RagdollPhysics.step_ragdoll_piece(piece, [], 0.1)
		if not alive:
			break

	return _assert(not alive, "RagdollPieceData must expire after 4.5s lifetime to prevent leaks")


func test_adversarial_duplicate_slice_events_double_decrement_alive_count() -> bool:
	var chrono := ChronoState.new()
	var combo := CombatMath.ComboState.new()
	var wave_mgr := EnemyAI.WaveManager.new()
	wave_mgr.alive_count = 1
	var energy := PlayerKinematics.ChronoEnergy.new()

	var enemies_by_id: Dictionary = {
		101: EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2.ZERO),
	}

	var events: Array = [
		CombatMath.SliceEventData.new(101, Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO, false),
		CombatMath.SliceEventData.new(101, Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO, true),
	]

	CombatMath.resolve_slice_events(events, chrono, combo, wave_mgr, energy, enemies_by_id)

	return _assert(
		combo.total_kills == 1 and wave_mgr.alive_count == 0,
		"Duplicate slice events for same enemy must be deduplicated (kills=%d, alive=%d)" % [combo.total_kills, wave_mgr.alive_count]
	)


func test_adversarial_wave_phase_zero_enemies_deadlock() -> bool:
	var mgr := EnemyAI.WaveManager.new()
	mgr.current_wave = 0
	mgr.phase = EnemyAI.WavePhase.SPAWNING
	mgr.remaining_to_spawn = 0
	mgr.spawn_timer = 0.1
	mgr.total_wave_enemies = 0
	mgr.alive_count = 0

	for _i in range(10):
		mgr.update(0.5, 1000.0, -200.0)

	return _assert(mgr.phase != EnemyAI.WavePhase.SPAWNING, "WaveManager must not deadlock in SPAWNING with 0 remaining")


func test_adversarial_enemy_out_of_bounds_recovery() -> bool:
	var enemy := EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(100.0, -500.0))
	var ai_step: Dictionary = EnemyAI.step_enemy_ai(enemy, Vector2(0.0, -260.0), 0.05)
	EnemyAI.step_enemy_physics(enemy, ai_step["move_dir"], ai_step["should_jump"], [], 0.05, -260.0, 1200.0)
	return _assert(is_equal_approx(enemy.position.y, -260.0), "Out-of-bounds enemy must recover to floor_y (-260.0)")


func test_gunner_ai_tactical_distance_and_shooting() -> bool:
	var gunner := EnemyAI.EnemyData.new(EnemyAI.EnemyType.GUNNER_SEMI, Vector2(100.0, 0.0))

	# 1. Backpedal if < 140px
	var res1: Dictionary = EnemyAI.step_enemy_ai(gunner, Vector2(30.0, 0.0), 0.016)
	if not _assert(gunner.state == EnemyAI.StateKind.CHASE and is_equal_approx(res1["move_dir"], 1.0), "Backpedal when < 140px"):
		return false

	# 2. Advance if > 360px
	var res2: Dictionary = EnemyAI.step_enemy_ai(gunner, Vector2(500.0, 0.0), 0.016)
	if not _assert(gunner.state == EnemyAI.StateKind.CHASE and is_equal_approx(res2["move_dir"], 1.0), "Advance when > 360px"):
		return false

	# 3. Windup when in tactical sweet spot [140, 360]
	EnemyAI.step_enemy_ai(gunner, Vector2(300.0, 0.0), 0.016)
	if not _assert(gunner.state == EnemyAI.StateKind.WINDUP and is_equal_approx(gunner.state_duration, 0.45), "Enter WINDUP in range"):
		return false

	# 4. Windup transitions to Attack
	gunner.state_timer = 0.01
	EnemyAI.step_enemy_ai(gunner, Vector2(300.0, 0.0), 0.02)
	return _assert(gunner.state == EnemyAI.StateKind.ATTACK, "WINDUP transitions to ATTACK")


func test_gunner_spawning_and_bullet_firing_system() -> bool:
	var gunner := EnemyAI.EnemyData.new(EnemyAI.EnemyType.GUNNER_SEMI, Vector2(200.0, -260.0))
	gunner.state = EnemyAI.StateKind.ATTACK
	gunner.state_timer = 0.35
	gunner.state_duration = 0.35
	gunner.attack_has_hit = false
	gunner.facing = -1.0

	var player_pos := Vector2(0.0, -260.0)
	EnemyAI.step_enemy_ai(gunner, player_pos, 0.05)
	var bullet: CombatMath.BulletData = EnemyAI.step_gunner_attack(gunner, player_pos, 0.05)

	if not _assert(bullet != null, "GunnerSemi must fire 1 bullet"):
		return false
	return _assert(
		not bullet.is_automatic and is_equal_approx(bullet.damage, 20.0) and bullet.velocity.x < 0.0,
		"Bullet properties match GunnerSemi"
	)


func test_bullet_system_slow_motion_dilation() -> bool:
	var chrono := ChronoState.new()
	var bullet := CombatMath.BulletData.new(Vector2.ZERO, Vector2(500.0, 0.0), 6.0, 20.0, 3.0, false)

	bullet.step_bullet(chrono.get_world_dt(0.1))
	var pos1: float = bullet.position.x
	if not _assert(absf(pos1 - 50.0) < 1.0, "Normal time moved 50px"):
		return false

	chrono.dilation_factor = 0.04
	chrono.slowmo_factor = 0.04
	chrono.is_dilating = true

	bullet.step_bullet(chrono.get_world_dt(0.1))
	var delta: float = bullet.position.x - pos1
	return _assert(absf(delta - 2.0) < 0.1, "Bullet crawls at 2.0px in 0.04x slowmo")


func test_katana_slash_slashes_bullet_and_reduces_cooldown() -> bool:
	var player := PlayerKinematics.PlayerState.new()
	player.position = Vector2(0.0, -16.0)
	player.facing = 1.0
	player.slash_cooldown = 0.0

	var bullet := CombatMath.BulletData.new(Vector2(40.0, 0.0), Vector2(-400.0, 0.0), 6.0, 20.0, 2.0, false)
	var bullets: Array = [bullet]

	var res: Dictionary = CombatMath.perform_katana_slash(player, Vector2(100.0, 0.0), {}, bullets)
	return _assert(
		res["hit_bullets"] == 1 and bullets.is_empty() and is_equal_approx(player.slash_cooldown, 0.04),
		"Katana slash destroys bullet and reduces cooldown to 0.04"
	)


func test_katana_slash_hits_enemy_and_reduces_cooldown() -> bool:
	var player := PlayerKinematics.PlayerState.new()
	player.position = Vector2(0.0, -16.0)
	player.facing = 1.0
	player.slash_cooldown = 0.0

	var enemies: Dictionary = {
		1: EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(45.0, -16.0)),
	}
	var res: Dictionary = CombatMath.perform_katana_slash(player, Vector2(100.0, 0.0), enemies, [])
	return _assert(
		res["hit_enemies"] == 1 and is_equal_approx(player.slash_cooldown, 0.04),
		"Katana slash hits enemy and reduces cooldown to 0.04"
	)


func test_chrono_warp_hits_enemy_reduces_cooldown_but_not_bullets() -> bool:
	var player := PlayerKinematics.PlayerState.new()
	player.position = Vector2(0.0, -200.0)
	player.warp_cooldown = 0.0
	var energy := PlayerKinematics.ChronoEnergy.new()

	var enemies: Dictionary = {
		1: EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(100.0, -200.0)),
	}
	var res1: Dictionary = CombatMath.perform_chrono_warp(player, energy, Vector2(200.0, -200.0), enemies)
	if not _assert(res1["did_warp"] and res1["hit_enemies"] == 1 and is_equal_approx(player.warp_cooldown, 0.05), "Warp through enemy reduces cooldown to 0.05"):
		return false

	# Now warp with no enemies (only bullets in world) -> cooldown stays 0.20
	enemies.clear()
	player.warp_cooldown = 0.0
	var res2: Dictionary = CombatMath.perform_chrono_warp(player, energy, Vector2(0.0, -200.0), enemies)
	return _assert(
		res2["did_warp"] and res2["hit_enemies"] == 0 and is_equal_approx(player.warp_cooldown, 0.20),
		"Warp without hitting enemies keeps 0.20 cooldown"
	)


func test_wave_cleared_real_time_transition() -> bool:
	var mgr := EnemyAI.WaveManager.new()
	mgr.phase = EnemyAI.WavePhase.WAVE_CLEARED
	mgr.phase_timer = 2.0

	var chrono := ChronoState.new()
	chrono.slowmo_factor = 0.04
	chrono.dilation_factor = 0.04
	chrono.is_dilating = true

	var real_dt: float = 0.5
	var dt1: float = real_dt if mgr.is_real_time_phase() else chrono.get_world_dt(real_dt)
	mgr.update(dt1, 1160.0, -250.0)
	if not _assert(absf(mgr.phase_timer - 1.5) < 1e-3, "WaveCleared advances in real time"):
		return false

	mgr.phase = EnemyAI.WavePhase.INTERMISSION
	mgr.phase_timer = 2.5
	var dt2: float = real_dt if mgr.is_real_time_phase() else chrono.get_world_dt(real_dt)
	mgr.update(dt2, 1160.0, -250.0)
	return _assert(absf(mgr.phase_timer - 2.0) < 1e-3, "Intermission advances in real time")


func test_wave_manager_spawn_distribution_gunners() -> bool:
	var mgr := EnemyAI.WaveManager.new()
	mgr.current_wave = 2
	mgr.phase = EnemyAI.WavePhase.SPAWNING
	mgr.remaining_to_spawn = 6
	mgr.spawn_timer = 0.0
	mgr.total_wave_enemies = 6

	var wave2_types: Array[int] = []
	while mgr.phase != EnemyAI.WavePhase.ACTIVE:
		mgr.spawn_timer = 0.0
		var act: Dictionary = mgr.update(0.01, 1000.0, -200.0)
		if act.get("action") == "spawn_enemy":
			wave2_types.append(act["enemy_type"])

	if not _assert(
		wave2_types.has(EnemyAI.EnemyType.GUNNER_SEMI)
		and wave2_types.has(EnemyAI.EnemyType.NINJA)
		and wave2_types.has(EnemyAI.EnemyType.RUNNER),
		"Wave 2 spawns GunnerSemi, Ninja, Runner"
	):
		return false

	var mgr3 := EnemyAI.WaveManager.new()
	mgr3.current_wave = 3
	mgr3.phase = EnemyAI.WavePhase.SPAWNING
	mgr3.remaining_to_spawn = 12
	mgr3.spawn_timer = 0.0
	mgr3.total_wave_enemies = 12

	var wave3_types: Array[int] = []
	while mgr3.phase != EnemyAI.WavePhase.ACTIVE:
		mgr3.spawn_timer = 0.0
		var act: Dictionary = mgr3.update(0.01, 1000.0, -200.0)
		if act.get("action") == "spawn_enemy":
			wave3_types.append(act["enemy_type"])

	return _assert(
		wave3_types.has(EnemyAI.EnemyType.GUNNER_AUTO)
		and wave3_types.has(EnemyAI.EnemyType.GUNNER_SEMI)
		and wave3_types.has(EnemyAI.EnemyType.HEAVY),
		"Wave 3 spawns GunnerAuto, GunnerSemi, Heavy"
	)


func test_adversarial_bullet_slice_race_condition() -> bool:
	var player := PlayerKinematics.PlayerState.new()
	player.position = Vector2(0.0, -16.0)
	player.health = 100.0
	player.slash_cooldown = 0.0
	player.invulnerability_timer = 0.0
	player.facing = 1.0

	var bullet := CombatMath.BulletData.new(Vector2(10.0, 0.0), Vector2(-300.0, 0.0), 6.0, 20.0, 3.0, false)
	var bullets: Array = [bullet]

	# 1. Katana slash runs first
	CombatMath.perform_katana_slash(player, Vector2(10.0, 0.0), {}, bullets)

	# 2. Even if someone still holds a reference to `bullet` and steps it, damage & lifetime were zeroed!
	var still_active: bool = bullet.step_bullet(0.016)
	if still_active and bullet.damage > 0.0:
		player.health -= bullet.damage

	return _assert(is_equal_approx(player.health, 100.0), "Slashed bullet must not damage player via race condition")


func test_adversarial_gunner_multi_attack_cycle_permanent_lockout() -> bool:
	var gunner := EnemyAI.EnemyData.new(EnemyAI.EnemyType.GUNNER_SEMI, Vector2(200.0, -260.0))
	gunner.state = EnemyAI.StateKind.ATTACK
	gunner.state_timer = 0.35
	gunner.state_duration = 0.35
	gunner.attack_has_hit = false
	gunner.facing = -1.0

	var player_pos := Vector2(0.0, -260.0)
	var b1: CombatMath.BulletData = EnemyAI.step_gunner_attack(gunner, player_pos, 0.05)
	if not _assert(b1 != null, "Attack cycle 1 fires bullet"):
		return false

	# Enter attack cycle 2
	gunner.state = EnemyAI.StateKind.ATTACK
	gunner.state_timer = 0.35
	gunner.state_duration = 0.35
	gunner.attack_has_hit = false

	var b2: CombatMath.BulletData = EnemyAI.step_gunner_attack(gunner, player_pos, 0.05)
	return _assert(b2 != null, "Attack cycle 2 must not be locked out and must fire bullet")


func test_adversarial_gunner_auto_burst_and_subsequent_cycle() -> bool:
	var gunner := EnemyAI.EnemyData.new(EnemyAI.EnemyType.GUNNER_AUTO, Vector2(200.0, -260.0))
	gunner.state = EnemyAI.StateKind.ATTACK
	gunner.state_timer = 0.45
	gunner.state_duration = 0.45
	gunner.attack_has_hit = false
	gunner.facing = -1.0

	var player_pos := Vector2(0.0, -260.0)
	var count1: int = 0
	for _i in range(15):
		EnemyAI.step_enemy_ai(gunner, player_pos, 0.03)
		var b: CombatMath.BulletData = EnemyAI.step_gunner_attack(gunner, player_pos, 0.03)
		if b != null:
			count1 += 1

	if not _assert(count1 == 4, "GunnerAuto must fire all 4 bullets in burst 1, got %d" % count1):
		return false

	# Trigger attack 2
	gunner.state = EnemyAI.StateKind.ATTACK
	gunner.state_timer = 0.45
	gunner.state_duration = 0.45
	gunner.attack_has_hit = false

	var count2: int = 0
	for _i in range(15):
		EnemyAI.step_enemy_ai(gunner, player_pos, 0.03)
		var b: CombatMath.BulletData = EnemyAI.step_gunner_attack(gunner, player_pos, 0.03)
		if b != null:
			count2 += 1

	return _assert(count2 == 4, "GunnerAuto must fire all 4 bullets in burst 2, got %d" % count2)


func test_adversarial_slash_both_enemy_and_bullet_simultaneously() -> bool:
	var chrono := ChronoState.new()
	var combo := CombatMath.ComboState.new()
	var wave_mgr := EnemyAI.WaveManager.new()
	wave_mgr.alive_count = 1
	var energy := PlayerKinematics.ChronoEnergy.new()

	var player := PlayerKinematics.PlayerState.new()
	player.position = Vector2(0.0, -16.0)
	player.health = 100.0
	player.slash_cooldown = 0.0
	player.invulnerability_timer = 0.0
	player.facing = 1.0

	var enemies: Dictionary = {
		1: EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(40.0, -16.0)),
	}
	var bullet := CombatMath.BulletData.new(Vector2(20.0, 0.0), Vector2(-300.0, 0.0), 6.0, 20.0, 2.0, false)
	var bullets: Array = [bullet]

	var slash_res: Dictionary = CombatMath.perform_katana_slash(player, Vector2(50.0, 0.0), enemies, bullets, chrono)
	CombatMath.resolve_slice_events(slash_res["slice_events"], chrono, combo, wave_mgr, energy, enemies)

	return _assert(
		is_equal_approx(player.slash_cooldown, 0.04)
		and is_equal_approx(player.health, 100.0)
		and enemies.is_empty()
		and bullets.is_empty()
		and combo.count == 1,
		"Simultaneous enemy and bullet slash must succeed cleanly"
	)


func test_adversarial_zero_distance_bullet_aiming_no_nan() -> bool:
	var enemy_pos := Vector2(100.0, 100.0)
	var facing: float = 1.0
	var muzzle := enemy_pos + Vector2(facing * 20.0, 14.0)
	var player_pos := muzzle - Vector2(0.0, 16.0)

	var gunner := EnemyAI.EnemyData.new(EnemyAI.EnemyType.GUNNER_SEMI, enemy_pos)
	gunner.state = EnemyAI.StateKind.ATTACK
	gunner.state_timer = 0.35
	gunner.state_duration = 0.35
	gunner.attack_has_hit = false
	gunner.facing = facing

	var bullet: CombatMath.BulletData = EnemyAI.step_gunner_attack(gunner, player_pos, 0.016)
	if not _assert(bullet != null, "Bullet must spawn even at zero distance"):
		return false

	return _assert(
		is_finite(bullet.velocity.x) and is_finite(bullet.velocity.y) and bullet.velocity.x > 0.0,
		"Zero-distance bullet velocity must be finite and default to +facing"
	)


# -----------------------------------------------------------------------------
# 2. New OUT OF TIME Spec Tests
# -----------------------------------------------------------------------------

func test_kinetic_dash_cancels_light_slash_recovery() -> bool:
	var player := PlayerKinematics.PlayerState.new()
	player.slash_cooldown = 0.22
	player.dash_cooldown = 0.0
	player.facing = 1.0

	var started: bool = PlayerKinematics.start_dash(player, -1.0)
	return _assert(
		started
		and is_equal_approx(player.slash_cooldown, 0.0)
		and is_equal_approx(player.dash_timer, player.config.dash_duration)
		and is_equal_approx(player.invulnerability_timer, player.config.dash_duration)
		and is_equal_approx(player.velocity.x, -player.config.dash_speed),
		"Kinetic Dash must cancel light slash recovery frames (slash_cooldown -> 0.0) and launch at dash_speed"
	)


func test_wall_slide_and_diagonal_wall_rebound_jump() -> bool:
	var player := PlayerKinematics.PlayerState.new()
	player.is_grounded = false
	player.velocity = Vector2(-50.0, -400.0) # Falling fast against left wall (normal = +1.0)

	# 1. Wall slide caps downward speed at wall_slide_speed (-110.0)
	var did_rebound_slide: bool = PlayerKinematics.step_wall_slide_and_rebound(player, 1.0, false, 0.016)
	if not _assert(
		not did_rebound_slide
		and player.is_wall_sliding
		and is_equal_approx(player.velocity.y, player.config.wall_slide_speed),
		"Wall slide must clamp downward velocity to wall_slide_speed (-110.0)"
	):
		return false

	# 2. Pressing jump while wall sliding triggers diagonal wall rebound jump
	var did_rebound_jump: bool = PlayerKinematics.step_wall_slide_and_rebound(player, 1.0, true, 0.016)
	return _assert(
		did_rebound_jump
		and not player.is_wall_sliding
		and is_equal_approx(player.velocity.x, player.config.wall_jump_force.x)
		and is_equal_approx(player.velocity.y, player.config.wall_jump_force.y)
		and is_equal_approx(player.facing, 1.0),
		"Wall rebound jump must launch player diagonally upward away from wall"
	)


func test_heavy_launcher_and_aerial_juggle_gravity() -> bool:
	var enemy_juggled := EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(100.0, -200.0))
	var enemy_normal := EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(100.0, -200.0))
	enemy_normal.is_grounded = false
	enemy_normal.velocity = Vector2(0.0, 500.0)

	EnemyAI.launch_enemy(enemy_juggled, Vector2(0.0, 500.0), 0.65)
	if not _assert(enemy_juggled.state == EnemyAI.StateKind.JUGGLED and not enemy_juggled.is_grounded, "Enemy launched into JUGGLED"):
		return false

	var ai_juggle: Dictionary = EnemyAI.step_enemy_ai(enemy_juggled, Vector2.ZERO, 0.1)
	if not _assert(is_equal_approx(ai_juggle["gravity_scale"], 0.55), "Juggled enemy gravity scale must be 0.55x"):
		return false

	EnemyAI.step_enemy_physics(enemy_juggled, ai_juggle["move_dir"], false, [], 0.1, -260.0, 1200.0)
	EnemyAI.step_enemy_physics(enemy_normal, 0.0, false, [], 0.1, -260.0, 1200.0)

	return _assert(
		enemy_juggled.velocity.y > enemy_normal.velocity.y,
		"Juggled enemy must fall slower than normal gravity (juggled vy=%f vs normal vy=%f)" % [enemy_juggled.velocity.y, enemy_normal.velocity.y]
	)


func test_downward_slam_shockwave_and_parry_bullet_reflection_with_sniper_ricochet() -> bool:
	# 1. Downward slam shockwave launches nearby enemies
	var player := PlayerKinematics.PlayerState.new()
	player.is_grounded = false
	player.position = Vector2(0.0, -50.0)
	if not _assert(PlayerKinematics.start_downward_slam(player) and player.is_slamming and is_equal_approx(player.velocity.y, player.config.slam_speed), "Start downward slam"):
		return false

	var nearby_enemy := EnemyAI.EnemyData.new(EnemyAI.EnemyType.HEAVY, Vector2(60.0, -260.0))
	var launched_count: int = CombatMath.apply_slam_shockwave(Vector2(0.0, -260.0), 140.0, [nearby_enemy], 540.0)
	if not _assert(launched_count == 1 and nearby_enemy.state == EnemyAI.StateKind.JUGGLED and nearby_enemy.velocity.y > 0.0, "Slam shockwave launches nearby enemy"):
		return false

	# 2. Sniper bullet ricochets off arena wall and preserves bounce on parry reflection
	var sniper := EnemyAI.EnemyData.new(EnemyAI.EnemyType.SNIPER, Vector2(400.0, -200.0))
	sniper.state = EnemyAI.StateKind.ATTACK
	sniper.state_timer = 0.30
	sniper.attack_has_hit = false
	sniper.facing = 1.0
	var sniper_bullet: CombatMath.BulletData = EnemyAI.step_gunner_attack(sniper, Vector2(600.0, -200.0), 0.016)
	if not _assert(sniper_bullet != null and sniper_bullet.bounces_remaining == 2, "Sniper fires ricochet bullet with 2 bounces"):
		return false

	# Step bullet across right wall (arena_half_width = 580.0)
	sniper_bullet.position = Vector2(575.0, -200.0)
	sniper_bullet.velocity = Vector2(600.0, 0.0)
	var alive_after_bounce: bool = sniper_bullet.step_bullet(0.05, 580.0, -260.0, 360.0)
	if not _assert(alive_after_bounce and sniper_bullet.velocity.x < 0.0 and sniper_bullet.bounces_remaining == 1, "Sniper bullet bounces off right arena wall"):
		return false

	# Parry / deflect the bullet back -> marks reflected, boosts speed & damage, restores/preserves bounces
	var pre_deflect_dmg: float = sniper_bullet.damage
	sniper_bullet.deflect(Vector2(1.0, 0.0), 1.5)
	return _assert(
		sniper_bullet.is_reflected
		and sniper_bullet.velocity.x > 0.0
		and sniper_bullet.damage > pre_deflect_dmg
		and sniper_bullet.bounces_remaining >= 2,
		"Deflected sniper bullet is reflected, boosted, and preserves bounces"
	)


func test_dmc_style_rank_progression_d_to_sss() -> bool:
	var combo := CombatMath.ComboState.new()
	if not _assert(combo.get_style_rank() == "D", "Initial rank D"):
		return false

	var seen_ranks: Array[String] = [combo.get_style_rank()]
	for _i in range(20):
		combo.register_kill(false)
		var r: String = combo.get_style_rank()
		if not seen_ranks.has(r):
			seen_ranks.append(r)

	var expected: Array[String] = ["D", "C", "B", "A", "S", "SS", "SSS"]
	for req_rank in expected:
		if not _assert(seen_ranks.has(req_rank), "Missing style rank %s in progression %s" % [req_rank, str(seen_ranks)]):
			return false

	if not _assert(combo.get_style_rank() == "SSS", "Peak style rank must be SSS"):
		return false

	combo.on_damage_taken()
	return _assert(combo.get_style_rank() == "D" and combo.count == 0, "Taking damage resets style rank to D")
