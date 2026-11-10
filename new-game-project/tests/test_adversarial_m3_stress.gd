extends SceneTree

## Adversarial Empirical Stress Test Suite for Milestone 3 Global Stickman Coverage
## Tests:
## 1. 100+ enemies across all 6 archetypes rapidly cycling AI states (CHASE, WINDUP, ATTACK, HITSTUN, JUGGLED)
## 2. 50+ enemies (100+ pieces) sliced into upper and lower ragdoll pieces simultaneously with armor tumbling
## 3. 50+ Chrono-Echoes across all 3 eras (PAST, PRESENT, FUTURE) with rapid era shifting and rewinds
## 4. Rapid player directional flipping (+1.0 <-> -1.0) and high-speed vertical launch/slam cycles
## 5. Performance.OBJECT_ORPHAN_NODE_COUNT monitoring verifying delta == 0

const TimeControlScript = preload("res://scripts/core/time_control.gd")
const PlayerKinematicsScript = preload("res://scripts/core/player_kinematics.gd")
const CombatMathScript = preload("res://scripts/core/combat_math.gd")
const EnemyAIScript = preload("res://scripts/core/enemy_ai.gd")
const RagdollPhysicsScript = preload("res://scripts/core/ragdoll_physics.gd")
const ChronoShiftScript = preload("res://scripts/chrono_shift/chrono_shift_model.gd")
const TimelineSystemScript = preload("res://scripts/timeline/timeline_system.gd")
const ModularAssetScript = preload("res://scripts/modular_rig/modular_asset_system.gd")
const GameControllerScript = preload("res://scripts/game/game_controller.gd")
const StickmanProceduralScript = preload("res://scripts/stickman/stickmanprocedural.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _failures: Array[String] = []


var _has_run: bool = false

func _process(_delta: float) -> bool:
	if _has_run:
		return true
	_has_run = true
	print("IN _process: root.is_inside_tree=", root.is_inside_tree())

	_run_test("test_stress_01_spawn_100_plus_enemies_all_6_archetypes_and_state_cycling", test_stress_01_spawn_100_plus_enemies_all_6_archetypes_and_state_cycling)
	_run_test("test_stress_02_slice_50_plus_enemies_into_ragdoll_pieces_and_tumble", test_stress_02_slice_50_plus_enemies_into_ragdoll_pieces_and_tumble)
	_run_test("test_stress_03_spawn_50_plus_chrono_echoes_across_all_eras_and_rapid_shifts", test_stress_03_spawn_50_plus_chrono_echoes_across_all_eras_and_rapid_shifts)
	_run_test("test_stress_04_rapid_player_directional_flipping_and_slam_cycles", test_stress_04_rapid_player_directional_flipping_and_slam_cycles)
	_run_test("test_stress_05_orphan_node_monitor_zero_delta", test_stress_05_orphan_node_monitor_zero_delta)

	print("=== M3 STRESS TEST SUMMARY: %d / %d PASSED (%d FAILED) ===" % [_tests_passed, _tests_run, _tests_failed])
	if _tests_failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### VERDICT: ADVERSARIAL EMPIRICAL CLEARANCE GRANTED (0 DEFECTS)")
		quit(0)
	return true


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
		_failures.append(msg)
		printerr("    ADVERSARIAL STRESS FAILURE: %s" % msg)
		return false
	return true


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
		ctrl.free()


# =============================================================================
# 1. 100+ enemies across all 6 archetypes rapidly cycling AI states
# =============================================================================

func test_stress_01_spawn_100_plus_enemies_all_6_archetypes_and_state_cycling() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	var archetypes: Array[int] = [
		EnemyAIScript.EnemyType.RUNNER,
		EnemyAIScript.EnemyType.NINJA,
		EnemyAIScript.EnemyType.HEAVY,
		EnemyAIScript.EnemyType.GUNNER_SEMI,
		EnemyAIScript.EnemyType.GUNNER_AUTO,
		EnemyAIScript.EnemyType.SNIPER,
	]
	var eras: Array[int] = [
		TimelineSystemScript.TimelineEra.PAST,
		TimelineSystemScript.TimelineEra.PRESENT,
		TimelineSystemScript.TimelineEra.FUTURE,
	]

	# Spawn 120 enemies: 20 per archetype
	var total_enemies: int = 120
	for i in range(total_enemies):
		var arch_type: int = archetypes[i % archetypes.size()]
		var era: int = eras[i % eras.size()]
		var spawn_x: float = -500.0 + (float(i) / float(total_enemies)) * 1000.0
		var enemy = EnemyAIScript.EnemyData.new(arch_type, Vector2(spawn_x, -260.0), era)
		enemy.facing = 1.0 if (i % 2 == 0) else -1.0
		enemy.velocity = Vector2(enemy.facing * 80.0, 0.0)
		ctrl.enemies.append(enemy)

	ok = _assert(ctrl.enemies.size() == 120, "120 enemies successfully spawned in GameController") and ok

	# Execute 60 simulation frames cycling through 5 AI states:
	# CHASE -> WINDUP -> ATTACK -> HITSTUN -> JUGGLED
	var state_sequence: Array[int] = [
		EnemyAIScript.StateKind.CHASE,
		EnemyAIScript.StateKind.WINDUP,
		EnemyAIScript.StateKind.ATTACK,
		EnemyAIScript.StateKind.HITSTUN,
		EnemyAIScript.StateKind.JUGGLED,
	]

	for frame in range(60):
		var active_state: int = state_sequence[(frame / 12) % state_sequence.size()]

		for enemy_idx in range(ctrl.enemies.size()):
			var e: EnemyAIScript.EnemyData = ctrl.enemies[enemy_idx]
			e.state = active_state
			e.state_timer = 0.08
			e.state_duration = 0.25

			match active_state:
				EnemyAIScript.StateKind.CHASE:
					e.is_grounded = true
					e.velocity = Vector2(e.facing * 120.0, 0.0)
				EnemyAIScript.StateKind.WINDUP:
					e.is_grounded = true
					e.velocity = Vector2.ZERO
					if e.enemy_type == EnemyAIScript.EnemyType.SNIPER:
						e.laser_aim_dir = Vector2(e.facing, 0.2).normalized()
				EnemyAIScript.StateKind.ATTACK:
					e.is_grounded = true
					e.velocity = Vector2(e.facing * 60.0, 0.0)
				EnemyAIScript.StateKind.HITSTUN:
					e.is_grounded = true
					e.velocity = Vector2(-e.facing * 100.0, 40.0)
				EnemyAIScript.StateKind.JUGGLED:
					e.is_grounded = false
					e.velocity = Vector2(e.facing * 20.0, -280.0 + float(frame) * 5.0)

		# Step simulation and perform full procedural + modular render
		ctrl.step_simulation(0.016, {})
		ctrl._draw()

		ok = _assert(ctrl.last_draw_primitive_count > 250,
			"Frame %d: _draw() rendered >250 primitives for 120 enemies (got %d)" % [frame, ctrl.last_draw_primitive_count]) and ok

	# Verify enemy rig pool scaling and node integrity
	ok = _assert(ctrl._enemy_rig_pool.size() >= 120,
		"Enemy rig pool scaled to handle 120 enemies (size=%d)" % ctrl._enemy_rig_pool.size()) and ok

	for rig_i in range(ctrl._enemy_rig_pool.size()):
		var rig_node = ctrl._enemy_rig_pool[rig_i]
		ok = _assert(rig_node is StickmanProceduralScript, "Rig %d is StickmanProcedural" % rig_i) and ok
		var erig := rig_node as StickmanProceduralScript
		ok = _assert(is_finite(erig.global_position.x) and is_finite(erig.global_position.y),
			"Rig %d position is finite" % rig_i) and ok
		ok = _assert(is_finite(erig.scale.x) and erig.scale.x > 0.0,
			"Rig %d scale is finite and positive" % rig_i) and ok
		ok = _assert(is_finite(erig.modulate.a) and erig.modulate.a > 0.0,
			"Rig %d modulate alpha is finite" % rig_i) and ok

	_cleanup_scene(ctrl)
	return ok


# =============================================================================
# 2. 50+ enemies (100+ pieces) sliced simultaneously into tumbling ragdoll pieces
# =============================================================================

func test_stress_02_slice_50_plus_enemies_into_ragdoll_pieces_and_tumble() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	var archetype_names: Array[String] = [
		"enemy_runner",
		"enemy_ninja",
		"enemy_heavy",
		"enemy_gunner_semi",
		"enemy_gunner_auto",
		"enemy_sniper",
	]

	# Simultaneously slice 60 enemies (10 of each archetype) -> 120 ragdoll pieces
	var slice_count: int = 60
	for i in range(slice_count):
		var arch_name: String = archetype_names[i % archetype_names.size()]
		var center_pos := Vector2(-450.0 + (float(i) / float(slice_count)) * 900.0, -180.0)
		var cut_angle: float = float(i) * 0.15
		var cut_dir := Vector2(cos(cut_angle), sin(cut_angle)).normalized()
		var perp := Vector2(-cut_dir.y, cut_dir.x)

		# Upper torso piece
		var upper_pos := center_pos + perp * 8.0
		var upper_vel := perp * 260.0 + Vector2(0.0, 150.0)
		var upper_piece = RagdollPhysicsScript.RagdollPieceData.new(
			RagdollPhysicsScript.RagdollPart.UPPER_TORSO,
			upper_pos,
			upper_vel,
			12.0,
			1.0 if (i % 2 == 0) else -1.0,
			Color(1.0, 0.4, 0.4, 1.0),
			arch_name
		)
		upper_piece.rotation = cut_angle
		ctrl.ragdolls.append(upper_piece)

		# Lower legs piece
		var lower_pos := center_pos - perp * 8.0
		var lower_vel := -perp * 240.0 + Vector2(0.0, 80.0)
		var lower_piece = RagdollPhysicsScript.RagdollPieceData.new(
			RagdollPhysicsScript.RagdollPart.LOWER_LEGS,
			lower_pos,
			lower_vel,
			-14.0,
			1.0 if (i % 2 == 0) else -1.0,
			Color(0.8, 0.3, 0.3, 1.0),
			arch_name
		)
		lower_piece.rotation = cut_angle + PI * 0.5
		ctrl.ragdolls.append(lower_piece)

	ok = _assert(ctrl.ragdolls.size() == 120, "120 ragdoll pieces spawned (60 upper + 60 lower)") and ok

	# Simulate 60 physics & rendering frames of tumbling pieces
	for frame in range(60):
		# Physics update: gravity, drag, angular tumbling, floor bounce
		var dt: float = 0.016
		for p_idx in range(ctrl.ragdolls.size()):
			var piece: RagdollPhysicsScript.RagdollPieceData = ctrl.ragdolls[p_idx]
			piece.velocity.y -= 980.0 * dt
			piece.position += piece.velocity * dt
			piece.rotation += piece.angular_velocity * dt
			if piece.position.y <= -260.0:
				piece.position.y = -260.0
				piece.velocity.y = absf(piece.velocity.y) * 0.4
				piece.velocity.x *= 0.8
				piece.angular_velocity *= 0.75
			piece.lifetime -= dt

		# Execute full canvas draw for all tumbling ragdoll pieces
		ctrl._draw()

		ok = _assert(ctrl.last_draw_primitive_count > 150,
			"Frame %d: _draw() rendered >150 primitives for tumbling ragdolls (got %d)" % [frame, ctrl.last_draw_primitive_count]) and ok

	# Verify split loadout registration and valid ragdoll poses
	for arch_name in archetype_names:
		var split_upper_id: String = arch_name + "_upper"
		var split_lower_id: String = arch_name + "_lower"
		var up_lo = ctrl.asset_registry.get_loadout(split_upper_id)
		var lo_lo = ctrl.asset_registry.get_loadout(split_lower_id)
		ok = _assert(up_lo != null, "Split loadout '%s' registered" % split_upper_id) and ok
		ok = _assert(lo_lo != null, "Split loadout '%s' registered" % split_lower_id) and ok

		# Generate test ragdoll poses and verify transforms are finite
		var r_up = ModularAssetScript.StickmanPoseSolver.generate_ragdoll_pose(
			Vector2(100.0, 50.0), 1.25, 1.0, RagdollPhysicsScript.RagdollPart.UPPER_TORSO, arch_name
		)
		var r_lo = ModularAssetScript.StickmanPoseSolver.generate_ragdoll_pose(
			Vector2(100.0, 50.0), -0.85, 1.0, RagdollPhysicsScript.RagdollPart.LOWER_LEGS, arch_name
		)
		ok = _assert(r_up.head_center.is_finite() and r_up.neck.is_finite() and r_up.sword_tip.is_finite(),
			"Upper ragdoll pose for '%s' has finite joints" % arch_name) and ok
		ok = _assert(r_lo.left_foot.is_finite() and r_lo.right_foot.is_finite() and r_lo.pelvis.is_finite(),
			"Lower ragdoll pose for '%s' has finite joints" % arch_name) and ok

		var helm_xf = ModularAssetScript.StickmanPoseSolver.compute_slot_transform(r_up, ModularAssetScript.PartSlot.HAT_HELMET, 1.0)
		ok = _assert((helm_xf["center"] as Vector2).is_finite(),
			"Helmet transform on '%s' is finite" % arch_name) and ok
		var boot_xf = ModularAssetScript.StickmanPoseSolver.compute_slot_transform(r_lo, ModularAssetScript.PartSlot.FOOT_R, 1.0)
		ok = _assert((boot_xf["center"] as Vector2).is_finite(),
			"Boot transform on '%s' is finite" % arch_name) and ok

	_cleanup_scene(ctrl)
	return ok


# =============================================================================
# 3. 50+ Chrono-Echoes across all 3 eras with rapid era shifting and rewinds
# =============================================================================

func test_stress_03_spawn_50_plus_chrono_echoes_across_all_eras_and_rapid_shifts() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	var eras: Array[int] = [
		TimelineSystemScript.TimelineEra.PAST,
		TimelineSystemScript.TimelineEra.PRESENT,
		TimelineSystemScript.TimelineEra.FUTURE,
	]
	var stances: Array[String] = ["normal", "jump", "slash", "heavy_slash", "downward_slam", "parry_guard"]

	# Spawn 60 Chrono-Echoes: 20 per era
	var total_echoes: int = 60
	for i in range(total_echoes):
		var era: int = eras[i % eras.size()]
		var stance: String = stances[i % stances.size()]
		var spawn_pos := Vector2(-400.0 + (float(i) / float(total_echoes)) * 800.0, -200.0 + float(i % 10) * 15.0)
		var facing: float = 1.0 if (i % 2 == 0) else -1.0
		var vel := Vector2(facing * (150.0 + float(i) * 5.0), float(i % 5) * 50.0)

		ctrl.timeline.spawn_chrono_echo(
			spawn_pos,
			Vector2(facing, 0.0),
			era,
			"stress_action_%d" % i,
			80.0,
			4.0,
			facing,
			vel,
			(i % 3 != 0),
			stance,
			float(i) * 0.05,
			"player_shift_staff"
		)

	ok = _assert(ctrl.timeline.echoes.size() == 60, "60 Chrono-Echoes spawned into timeline") and ok

	# Execute 30 rapid era shifts cycling across PAST, PRESENT, FUTURE
	for cycle in range(30):
		var target_era: int = eras[cycle % eras.size()]
		ctrl.timeline.try_shift_timeline(ctrl.player.position, target_era, false, ctrl.player.velocity)

		# Step simulation and perform drawing
		ctrl.step_simulation(0.016, {})
		ctrl._draw()

		ok = _assert(ctrl.last_draw_primitive_count > 100,
			"Cycle %d: _draw() rendered >100 primitives under rapid era shift (got %d)" % [cycle, ctrl.last_draw_primitive_count]) and ok

		# Verify all active echoes maintain valid, finite state and bounded fade_ratio
		for echo_i in range(ctrl.timeline.echoes.size()):
			var echo: TimelineSystemScript.ChronoEchoData = ctrl.timeline.echoes[echo_i]
			ok = _assert(echo.origin.is_finite(), "Echo %d origin is finite" % echo_i) and ok
			ok = _assert(echo.velocity.is_finite(), "Echo %d velocity is finite" % echo_i) and ok
			var fr: float = echo.fade_ratio()
			ok = _assert(fr >= 0.0 and fr <= 1.0, "Echo %d fade_ratio in [0, 1] (got %f)" % [echo_i, fr]) and ok

	# Advance timeline clock by 5.0 seconds to verify complete echo decay without memory leaks
	ctrl.timeline.tick(5.0)
	ok = _assert(ctrl.timeline.echoes.is_empty(), "All 60 echoes decayed cleanly after full lifetime") and ok

	# Verify echo rig pool (MAX_ECHO_RIGS = 4) handles empty echoes array gracefully
	ctrl._update_echo_rigs(0.016)
	for rig in ctrl._echo_rig_pool:
		var sp := rig as StickmanProceduralScript
		ok = _assert(sp.visible == false, "All pooled echo rigs hidden when echoes array is empty") and ok

	_cleanup_scene(ctrl)
	return ok


# =============================================================================
# 4. Rapid player directional flipping (+1.0 <-> -1.0) and high-speed vertical launch/slam
# =============================================================================

func test_stress_04_rapid_player_directional_flipping_and_slam_cycles() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	# Stress-test 120 consecutive frames (2.0 simulated seconds):
	# Alternating directional flips every single frame (+1.0 <-> -1.0)
	# Cycles of high-speed vertical launch (+1500.0) into slam (-3000.0) into landing squash
	for frame in range(120):
		var flip_facing: float = 1.0 if (frame % 2 == 0) else -1.0
		var flip_input_x: float = flip_facing

		# Determine vertical launch / slam phase
		var cycle_phase: int = frame % 30
		var is_slam: bool = false
		var override_vy: float = 0.0

		if cycle_phase < 10:
			# High-speed vertical launch
			override_vy = 1400.0
			ctrl.player.is_grounded = false
			ctrl.player.is_slamming = false
		elif cycle_phase < 20:
			# High-speed downward slam
			override_vy = -2800.0
			ctrl.player.is_grounded = false
			ctrl.player.is_slamming = true
			is_slam = true
		else:
			# Landing & recovery
			override_vy = 0.0
			ctrl.player.is_grounded = true
			ctrl.player.is_slamming = false

		ctrl.player.facing = flip_facing
		ctrl.player.velocity = Vector2(flip_facing * 500.0, override_vy)

		# Step simulation with active inputs
		ctrl.step_simulation(0.016, {
			"move_x": flip_input_x,
			"slash": (frame % 5 == 0),
			"heavy": (frame % 15 == 0),
			"parry": (frame % 20 == 0),
		})
		ctrl._draw()

		# Assert player state invariants
		ok = _assert(ctrl.player.position.is_finite() and ctrl.player.velocity.is_finite(),
			"Frame %d: Player position & velocity strictly finite" % frame) and ok
		ok = _assert(is_finite(ctrl.player_accel_x),
			"Frame %d: Player horizontal acceleration is finite (%f)" % [frame, ctrl.player_accel_x]) and ok

		# Assert scarf node distance constraint invariants: L in [5.9, 14.1] px
		var dyn_ctx: ModularAssetScript.PoseDynamicsContext = ctrl.player_dynamics_ctx
		var pose: ModularAssetScript.StickmanPose = ModularAssetScript.StickmanPoseSolver.generate_stickman_pose(
			ctrl.player.position,
			ctrl.player.facing,
			ctrl.player.velocity,
			ctrl.player.is_grounded,
			ctrl.anim_time,
			false,
			0.0,
			false,
			ctrl.last_stance,
			ctrl.player_accel_x,
			dyn_ctx,
			0.016
		)

		var d01: float = pose.scarf_nodes[0].distance_to(pose.scarf_nodes[1])
		var d12: float = pose.scarf_nodes[1].distance_to(pose.scarf_nodes[2])
		ok = _assert(d01 >= 5.9 and d01 <= 14.1,
			"Frame %d: Scarf segment 0-1 distance clamped in [6, 14] px (got %f)" % [frame, d01]) and ok
		ok = _assert(d12 >= 5.9 and d12 <= 14.1,
			"Frame %d: Scarf segment 1-2 distance clamped in [6, 14] px (got %f)" % [frame, d12]) and ok

		# Invariant: Scarf strictly trails behind head in opposite of facing direction
		if ctrl.player.facing > 0.0:
			ok = _assert(pose.scarf_nodes[2].x <= pose.head_center.x,
				"Frame %d: Facing +1.0 scarf trails to the left" % frame) and ok
		else:
			ok = _assert(pose.scarf_nodes[2].x >= pose.head_center.x,
				"Frame %d: Facing -1.0 scarf trails to the right" % frame) and ok

		# Verify live player rig node
		if ctrl.player_rig != null:
			ok = _assert(is_finite(ctrl.player_rig.global_position.x) and is_finite(ctrl.player_rig.global_position.y),
				"Frame %d: Player rig node position is finite" % frame) and ok

	_cleanup_scene(ctrl)
	return ok


# =============================================================================
# 5. Monitor orphan nodes via Performance.OBJECT_ORPHAN_NODE_COUNT (delta == 0)
# =============================================================================

func test_stress_05_orphan_node_monitor_zero_delta() -> bool:
	var ok: bool = true

	# Baseline orphan count before running stress scenarios
	var initial_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	# Run 3 consecutive full lifecycle cycles of instantiating, heavily stressing, and freeing GameController
	for cycle in range(3):
		var ctrl: GameController = _spawn_main_scene()

		# 1. Spawn 60 enemies across all 6 archetypes
		for i in range(60):
			var arch: int = i % 6
			var enemy = EnemyAIScript.EnemyData.new(arch, Vector2(float(i * 10 - 300), -260.0), 1)
			ctrl.enemies.append(enemy)

		# 2. Spawn 40 ragdoll pieces
		for i in range(40):
			var r_part: int = RagdollPhysicsScript.RagdollPart.UPPER_TORSO if (i % 2 == 0) else RagdollPhysicsScript.RagdollPart.LOWER_LEGS
			var piece = RagdollPhysicsScript.RagdollPieceData.new(
				r_part,
				Vector2(float(i * 15 - 300), -200.0),
				Vector2(100.0, 150.0),
				10.0,
				1.0,
				Color.WHITE,
				"enemy_heavy"
			)
			ctrl.ragdolls.append(piece)

		# 3. Spawn 30 Chrono-Echoes
		for i in range(30):
			ctrl.timeline.spawn_chrono_echo(
				Vector2(float(i * 20 - 300), -220.0),
				Vector2.RIGHT,
				i % 3,
				"action",
				60.0,
				2.0
			)

		# Step and draw multiple frames
		for f in range(10):
			ctrl.step_simulation(0.016, {"move_x": 1.0 if (f % 2 == 0) else -1.0})
			ctrl._draw()

		# Free the scene cleanly
		_cleanup_scene(ctrl)

	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var delta_orphans: int = final_orphans - initial_orphans

	print("    [ORPHAN MONITOR] Initial: %d | Final: %d | Delta: %d" % [initial_orphans, final_orphans, delta_orphans])

	ok = _assert(delta_orphans == 0,
		"Orphan node count must not increase after scene lifecycle stress (delta=%d)" % delta_orphans) and ok

	return ok
