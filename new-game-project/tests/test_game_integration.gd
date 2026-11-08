extends SceneTree

## End-to-End Integration Test Suite for OUT OF TIME — Chronos Shift.
## Instantiates res://scenes/main.tscn headlessly and verifies GameController,
## GameAudioManager, HUD, _draw() procedural + modular rendering, and deterministic
## gameplay simulation across all mechanics.

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0


func _init() -> void:
	print("=== RUNNING END-TO-END GAME INTEGRATION TEST SUITE ===")

	_run_test("test_01_scene_instantiation_hud_and_draw", test_01_scene_instantiation_hud_and_draw)
	_run_test("test_02_running_jumping_and_wall_rebound", test_02_running_jumping_and_wall_rebound)
	_run_test("test_03_kinetic_dash_cancels_slash_recovery_and_spawns_echo", test_03_kinetic_dash_cancels_slash_recovery_and_spawns_echo)
	_run_test("test_04_light_slash_kills_enemy_and_spawns_split_ragdoll_halves", test_04_light_slash_kills_enemy_and_spawns_split_ragdoll_halves)
	_run_test("test_05_heavy_launcher_juggles_enemy_and_awards_style", test_05_heavy_launcher_juggles_enemy_and_awards_style)
	_run_test("test_06_downward_slam_landing_shockwave_launches_enemies", test_06_downward_slam_landing_shockwave_launches_enemies)
	_run_test("test_07_parry_reflects_sniper_ricochet_bullet_and_reverse_gear_parry_kill", test_07_parry_reflects_sniper_ricochet_bullet_and_reverse_gear_parry_kill)
	_run_test("test_08_chrono_warp_teleports_spawns_beam_and_slices_enemy", test_08_chrono_warp_teleports_spawns_beam_and_slices_enemy)
	_run_test("test_09_chrono_shift_gear_3_engagement_and_release_persistence", test_09_chrono_shift_gear_3_engagement_and_release_persistence)
	_run_test("test_10_timeline_shifting_past_present_future_and_chrono_echo_detonation", test_10_timeline_shifting_past_present_future_and_chrono_echo_detonation)
	_run_test("test_11_campaign_traversal_mode_toggle_and_camera_follow", test_11_campaign_traversal_mode_toggle_and_camera_follow)
	_run_test("test_12_live_piece_by_piece_modular_customization_cycling", test_12_live_piece_by_piece_modular_customization_cycling)

	print("=== INTEGRATION TEST SUMMARY: %d / %d PASSED (%d FAILED) ===" % [_tests_passed, _tests_run, _tests_failed])
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


# ---------------------------------------------------------------------------------------------
# Integration Tests
# ---------------------------------------------------------------------------------------------

func test_01_scene_instantiation_hud_and_draw() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ok = ok and _assert(ctrl != null, "main.tscn root is GameController")
	ok = ok and _assert(ctrl.chrono != null and ctrl.player != null and ctrl.energy != null, "Core states initialized")
	ok = ok and _assert(ctrl.combo != null and ctrl.wave_mgr != null and ctrl.shifter != null, "Combat/Wave/Shifter initialized")
	ok = ok and _assert(ctrl.timeline != null and ctrl.asset_registry != null and ctrl.audio_mgr != null, "Timeline/Rig/Audio initialized")
	ok = ok and _assert(ctrl.camera != null and ctrl.hud_layer != null, "Camera2D and HUD CanvasLayer created")
	ok = ok and _assert(ctrl.health_bar != null and ctrl.energy_bar != null and ctrl.style_rank_label != null, "HUD widgets created")
	ok = ok and _assert(ctrl.era_label.text.contains("PRESENT"), "Initial HUD era is PRESENT")
	ok = ok and _assert(ctrl.audio_mgr.streams.size() == 7, "All 7 WAV audio streams preloaded")

	# Execute _draw() directly with enemies, bullets, ragdolls, and visuals to verify zero draw errors
	ctrl.enemies.append(EnemyAI.EnemyData.new(EnemyAI.EnemyType.SNIPER, Vector2(200.0, -260.0), TimelineSystem.TimelineEra.PRESENT))
	ctrl.enemies[0].state = EnemyAI.StateKind.WINDUP
	ctrl.enemies.append(EnemyAI.EnemyData.new(EnemyAI.EnemyType.HEAVY, Vector2(-200.0, -260.0), TimelineSystem.TimelineEra.PAST))
	ctrl.bullets.append(CombatMath.BulletData.new(Vector2(50.0, -220.0), Vector2(-400.0, 0.0), 6.0, 20.0, 2.0, false, 2, TimelineSystem.TimelineEra.PRESENT))
	ctrl.step_simulation(0.016, {})
	ctrl._draw()
	ok = ok and _assert(ctrl.draw_call_count >= 1 and ctrl.last_draw_primitive_count > 100, "_draw() executed full procedural + modular renderer (>100 primitives)")

	# Verify coordinate conversion roundtrip
	var sim_pt := Vector2(480.0, 150.0)
	var scr_pt: Vector2 = GameController.to_screen(sim_pt)
	ok = ok and _assert(scr_pt == Vector2(480.0, -150.0) and GameController.to_sim(scr_pt) == sim_pt, "to_screen / to_sim conversion")

	_cleanup_scene(ctrl)
	return ok


func test_02_running_jumping_and_wall_rebound() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	var start_x: float = ctrl.player.position.x
	for _i in range(10):
		ctrl.step_simulation(0.016, {"move_x": 1.0})
	ok = ok and _assert(ctrl.player.position.x > start_x and ctrl.player.velocity.x > 0.0, "Running right increases position.x")

	# Jump from ground
	ctrl.step_simulation(0.016, {"jump_pressed": true, "jump_held": true})
	ok = ok and _assert(not ctrl.player.is_grounded and ctrl.player.velocity.y > 400.0, "Jump launches player upward")
	ok = ok and _assert(ctrl.audio_mgr.last_played_sfx == "jump", "Jump plays jump.wav")

	# Wall slide & wall rebound jump
	ctrl.player.position = Vector2(-570.0, -120.0)
	ctrl.player.velocity = Vector2(-100.0, -350.0)
	ctrl.player.is_grounded = false
	ctrl.step_simulation(0.016, {"jump_pressed": true, "wall_normal_x": 1.0})
	ok = ok and _assert(ctrl.player.velocity.x > 300.0 and ctrl.player.velocity.y > 400.0, "Wall rebound launches diagonally upward")

	_cleanup_scene(ctrl)
	return ok


func test_03_kinetic_dash_cancels_slash_recovery_and_spawns_echo() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	# Perform light slash -> sets slash_cooldown > 0
	ctrl.step_simulation(0.016, {"slash": true, "aim_world": Vector2(100.0, -240.0)})
	ok = ok and _assert(ctrl.player.slash_cooldown > 0.1, "Light slash sets recovery cooldown")

	# Trigger Kinetic Dash -> cancels slash_cooldown immediately, spawns GhostTrail & ChronoEcho
	var echoes_before: int = ctrl.timeline.echoes.size()
	ctrl.step_simulation(0.016, {"dash": true, "move_x": 1.0})
	ok = ok and _assert(is_equal_approx(ctrl.player.slash_cooldown, 0.0), "Kinetic Dash cancels slash recovery cooldown")
	ok = ok and _assert(ctrl.player.dash_timer > 0.0 and is_equal_approx(ctrl.player.velocity.x, ctrl.player.config.dash_speed), "Dash sets dash velocity")
	ok = ok and _assert(ctrl.ghost_trails.size() >= 1, "Dash spawns GhostTrail")
	ok = ok and _assert(ctrl.timeline.echoes.size() > echoes_before, "Dash spawns ChronoEcho")

	_cleanup_scene(ctrl)
	return ok


func test_04_light_slash_kills_enemy_and_spawns_split_ragdoll_halves() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ctrl.enemies.clear()
	var enemy := EnemyAI.EnemyData.new(
		EnemyAI.EnemyType.RUNNER,
		ctrl.player.position + Vector2(45.0, 0.0),
		ctrl.timeline.current_era
	)
	ctrl.enemies.append(enemy)
	ctrl.wave_mgr.alive_count = 1

	ctrl.step_simulation(0.016, {
		"slash": true,
		"aim_world": enemy.position + Vector2(0.0, 16.0),
	})

	ok = ok and _assert(ctrl.enemies.is_empty(), "Sliced enemy removed from active enemies")
	ok = ok and _assert(ctrl.combo.total_kills == 1 and ctrl.combo.score >= 100, "Kill registered in ComboState")
	ok = ok and _assert(ctrl.ragdolls.size() == 2, "Enemy split into 2 ragdoll halves (UPPER_TORSO + LOWER_LEGS)")
	ok = ok and _assert(ctrl.particles.size() >= 14, "Slice kill spawned blood/cyber particles")
	ok = ok and _assert(ctrl.slash_visuals.size() >= 1, "SlashArcVisualData spawned")
	ctrl._draw()
	ok = ok and _assert(ctrl.last_draw_primitive_count > 100, "Ragdoll halves and particles rendered in _draw()")

	_cleanup_scene(ctrl)
	return ok


func test_05_heavy_launcher_juggles_enemy_and_awards_style() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ctrl.enemies.clear()
	var enemy := EnemyAI.EnemyData.new(
		EnemyAI.EnemyType.HEAVY,
		ctrl.player.position + Vector2(70.0, 0.0),
		ctrl.timeline.current_era
	)
	ctrl.enemies.append(enemy)

	var style_before: float = ctrl.combo.style_points
	ctrl.step_simulation(0.016, {
		"heavy": true,
		"aim_world": enemy.position + Vector2(0.0, 16.0),
	})

	ok = ok and _assert(enemy.state == EnemyAI.StateKind.JUGGLED, "Heavy launcher puts enemy into JUGGLED state")
	ok = ok and _assert(not enemy.is_grounded and enemy.velocity.y > 400.0, "Launched enemy has upward juggle velocity")
	ok = ok and _assert(ctrl.combo.style_points > style_before, "Heavy launcher awards style points")

	_cleanup_scene(ctrl)
	return ok


func test_06_downward_slam_landing_shockwave_launches_enemies() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ctrl.enemies.clear()
	ctrl.player.position = Vector2(0.0, -150.0)
	ctrl.player.is_grounded = false
	var nearby_enemy := EnemyAI.EnemyData.new(
		EnemyAI.EnemyType.RUNNER,
		Vector2(65.0, GameController.FLOOR_Y),
		ctrl.timeline.current_era
	)
	ctrl.enemies.append(nearby_enemy)

	# Trigger airborne downward slam (S + LMB while airborne)
	ctrl.step_simulation(0.016, {"slash": true, "down_held": true})
	ok = ok and _assert(ctrl.player.is_slamming and is_equal_approx(ctrl.player.velocity.y, ctrl.player.config.slam_speed), "Downward slam initiated")

	# Step until landing on floor_y (-260.0)
	for _i in range(15):
		ctrl.step_simulation(0.016, {})
		if ctrl.player.is_grounded:
			break

	ok = ok and _assert(ctrl.player.is_grounded and not ctrl.player.is_slamming, "Player landed from downward slam")
	ok = ok and _assert(nearby_enemy.state == EnemyAI.StateKind.JUGGLED and nearby_enemy.velocity.y > 0.0, "Slam shockwave launched nearby enemy into JUGGLED")
	ok = ok and _assert(ctrl.shockwave_visuals.size() >= 1, "ShockwaveVisualData spawned on slam landing")

	_cleanup_scene(ctrl)
	return ok


func test_07_parry_reflects_sniper_ricochet_bullet_and_reverse_gear_parry_kill() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ctrl.enemies.clear()
	ctrl.bullets.clear()

	# Spawn incoming sniper bullet with 2 ricochet bounces
	var sniper_bullet := CombatMath.BulletData.new(
		ctrl.player.position + Vector2(50.0, 16.0),
		Vector2(-780.0, 0.0),
		6.0,
		30.0,
		3.5,
		false,
		2,
		ctrl.timeline.current_era
	)
	ctrl.bullets.append(sniper_bullet)

	# Press F (parry) aiming right
	ctrl.step_simulation(0.016, {
		"parry": true,
		"aim_world": ctrl.player.position + Vector2(300.0, 16.0),
	})

	ok = ok and _assert(ctrl.player.parry_timer > 0.0, "Parry window active")
	ok = ok and _assert(sniper_bullet.is_reflected and sniper_bullet.velocity.x > 0.0, "Sniper bullet reflected back")
	ok = ok and _assert(sniper_bullet.bounces_remaining >= 2, "Reflected sniper bullet preserves ricochet bounces")

	# Now shift into Reverse Gear (Gear.R) and parry a nearby melee enemy -> insta-kill!
	ctrl.player.parry_cooldown = 0.0
	ctrl.player.parry_timer = 0.0
	for _i in range(35):
		ctrl.step_simulation(0.016, {"shift_held": true, "shift_gear": ChronoShiftModel.Gear.R})
	ok = ok and _assert(ctrl.shifter.model.get_active_gear() == ChronoShiftModel.Gear.R, "Engaged Reverse Gear (R)")

	var attacker := EnemyAI.EnemyData.new(
		EnemyAI.EnemyType.RUNNER,
		ctrl.player.position + Vector2(40.0, 0.0),
		ctrl.timeline.current_era
	)
	ctrl.enemies.append(attacker)
	ctrl.step_simulation(0.016, {"parry": true})
	ok = ok and _assert(ctrl.enemies.is_empty() and ctrl.combo.parry_kills >= 1, "Reverse Gear parry insta-killed nearby attacker")

	_cleanup_scene(ctrl)
	return ok


func test_08_chrono_warp_teleports_spawns_beam_and_slices_enemy() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ctrl.enemies.clear()
	ctrl.ghost_trails.clear()
	ctrl.warp_visuals.clear()
	ctrl.player.position = Vector2(0.0, GameController.FLOOR_Y)
	ctrl.energy.current = 100.0

	var target_enemy := EnemyAI.EnemyData.new(
		EnemyAI.EnemyType.NINJA,
		Vector2(140.0, GameController.FLOOR_Y),
		ctrl.timeline.current_era
	)
	ctrl.enemies.append(target_enemy)

	var warp_dest := Vector2(260.0, GameController.FLOOR_Y)
	ctrl.step_simulation(0.016, {
		"warp": true,
		"aim_world": warp_dest,
	})

	ok = ok and _assert(ctrl.player.position.distance_to(warp_dest) < 1.0, "Player teleported to warp destination")
	ok = ok and _assert(ctrl.enemies.is_empty() and ctrl.combo.warp_kills == 1, "Enemy along warp path sliced")
	ok = ok and _assert(ctrl.warp_visuals.size() == 1, "WarpBeamVisualData spawned")
	ok = ok and _assert(ctrl.ghost_trails.size() >= 3, "3 GhostTrails spawned along warp path")

	_cleanup_scene(ctrl)
	return ok


func test_09_chrono_shift_gear_3_engagement_and_release_persistence() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	# Hold Shift and shift into Gear 3
	ctrl.step_simulation(0.016, {"shift_held": true, "shift_gear": ChronoShiftModel.Gear.G3})
	for _i in range(8):
		ctrl.step_simulation(0.016, {"shift_held": true})

	ok = ok and _assert(ctrl.shifter.is_held(), "Shifter is held while Shift is down")
	ok = ok and _assert(ctrl.shifter.model.get_active_gear() == ChronoShiftModel.Gear.G3, "Shifter engaged Gear 3")
	ok = ok and _assert(is_equal_approx(ctrl.chrono.slowmo_factor, 0.38), "Gear 3 slowmo_factor is 0.38")
	ok = ok and _assert(ctrl.chrono.is_dilating, "ChronoState is dilating in Gear 3")

	# Release Shift -> verify Gear 3 persists while cruising!
	ctrl.energy.current = 100.0
	for _i in range(8):
		ctrl.step_simulation(0.016, {"shift_held": false})

	ok = ok and _assert(not ctrl.shifter.is_held(), "Shifter is no longer held after release")
	ok = ok and _assert(ctrl.shifter.model.get_active_gear() == ChronoShiftModel.Gear.G3, "Gear 3 persists after releasing Shift")
	ok = ok and _assert(ctrl.chrono.is_dilating and is_equal_approx(ctrl.chrono.slowmo_factor, 0.38), "Time dilation persists after releasing Shift")
	ok = ok and _assert(ctrl.shifter_readout_label.text.begins_with("GEAR 3"), "HUD readout shows GEAR 3")

	_cleanup_scene(ctrl)
	return ok


func test_10_timeline_shifting_past_present_future_and_chrono_echo_detonation() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ctrl.enemies.clear()
	ok = ok and _assert(ctrl.timeline.current_era == TimelineSystem.TimelineEra.PRESENT, "Starts in PRESENT")

	# Spawn a ChronoEcho in PRESENT and place an enemy in PRESENT to be detonated when we cycle back
	var echo_origin: Vector2 = ctrl.player.position + Vector2(0.0, 16.0)
	ctrl.timeline.spawn_chrono_echo(echo_origin, Vector2.RIGHT, TimelineSystem.TimelineEra.PRESENT, "slash")

	# Give player velocity to verify momentum preservation across timeline shifts
	ctrl.player.velocity = Vector2(280.0, 150.0)

	# Shift 1: PRESENT -> FUTURE
	ctrl.step_simulation(0.001, {"timeline_shift": true, "move_x": 1.0})
	ok = ok and _assert(ctrl.timeline.current_era == TimelineSystem.TimelineEra.FUTURE, "Shifted PRESENT -> FUTURE")
	ok = ok and _assert(ctrl.player.velocity.x > 250.0, "Momentum preserved across timeline shift")

	# Shift 2: FUTURE -> PAST
	ctrl.step_simulation(0.001, {"timeline_shift": true, "move_x": 1.0})
	ok = ok and _assert(ctrl.timeline.current_era == TimelineSystem.TimelineEra.PAST, "Shifted FUTURE -> PAST")

	# Place an enemy in PRESENT near the waiting ChronoEcho, then shift PAST -> PRESENT to detonate it!
	var present_enemy := EnemyAI.EnemyData.new(
		EnemyAI.EnemyType.RUNNER,
		ctrl.player.position + Vector2(20.0, 0.0),
		TimelineSystem.TimelineEra.PRESENT
	)
	ctrl.enemies.append(present_enemy)

	# Shift 3: PAST -> PRESENT (detonates ChronoEcho and slices present_enemy!)
	ctrl.step_simulation(0.001, {"timeline_shift": true})
	ok = ok and _assert(ctrl.timeline.current_era == TimelineSystem.TimelineEra.PRESENT, "Shifted PAST -> PRESENT")
	ok = ok and _assert(ctrl.enemies.is_empty(), "ChronoEcho detonation in PRESENT sliced the enemy in that era")

	_cleanup_scene(ctrl)
	return ok


func test_11_campaign_traversal_mode_toggle_and_camera_follow() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	ok = ok and _assert(ctrl.timeline.mode == TimelineSystem.GameMode.HORDE_ARENA, "Starts in HORDE_ARENA mode")

	# Toggle mode via M ("toggle_mode": true)
	ctrl.step_simulation(0.016, {"toggle_mode": true})
	ok = ok and _assert(ctrl.timeline.mode == TimelineSystem.GameMode.CAMPAIGN_TRAVERSAL, "Toggled to CAMPAIGN_TRAVERSAL mode")

	# Move player forward into Zone 2 and verify camera smoothly follows player.position.x
	ctrl.player.position = Vector2(600.0, -200.0)
	for _i in range(30):
		ctrl.step_simulation(0.05, {})
	ok = ok and _assert(ctrl.camera.position.x > 400.0, "Camera smoothly follows player.position.x in Campaign Traversal mode")
	ok = ok and _assert(ctrl.wave_label.text.contains("CAMPAIGN TRAVERSAL"), "HUD wave label shows Campaign Traversal status")

	_cleanup_scene(ctrl)
	return ok


func test_12_live_piece_by_piece_modular_customization_cycling() -> bool:
	var ctrl: GameController = _spawn_main_scene()
	var ok: bool = true

	var player_loadout := ctrl.asset_registry.get_loadout("player_shift_staff")
	var initial_hat := player_loadout.get_part(ModularAssetSystem.PartSlot.HAT_HELMET)
	ok = ok and _assert(initial_hat == null, "Initially no HAT_HELMET equipped on default preset")

	# Press P ("cycle_customization": true) -> Tier 1 equips cyber-crown helmet + pauldrons + overclocked key teeth
	ctrl.step_simulation(0.016, {"cycle_customization": true})
	var tier1_hat := player_loadout.get_part(ModularAssetSystem.PartSlot.HAT_HELMET)
	ok = ok and _assert(tier1_hat != null and tier1_hat.part_id == "custom_chrono_crown_helm", "Tier 1 equipped custom_chrono_crown_helm")
	ok = ok and _assert(ctrl.customization_cycle_count == 1 and ctrl.customization_tier == 1, "Customization tier advanced to 1")

	# Press P -> Tier 2 equips breastplate + greaves + upper resonator shaft
	ctrl.step_simulation(0.016, {"cycle_customization": true})
	var tier2_chest := player_loadout.get_part(ModularAssetSystem.PartSlot.TORSO)
	var tier2_shaft := player_loadout.weapon_assembly.get_piece(ModularAssetSystem.WeaponPieceSlot.SHAFT_UPPER)
	ok = ok and _assert(tier2_chest != null and tier2_chest.part_id == "custom_aegis_breastplate", "Tier 2 equipped custom_aegis_breastplate")
	ok = ok and _assert(tier2_shaft != null and tier2_shaft.piece_id == "custom_upper_resonator_shaft", "Tier 2 equipped custom_upper_resonator_shaft")

	# Press P -> Tier 3 equips TEXTURE_SPRITE helmet + singularity blade
	ctrl.step_simulation(0.016, {"cycle_customization": true})
	var tier3_hat := player_loadout.get_part(ModularAssetSystem.PartSlot.HAT_HELMET)
	ok = ok and _assert(
		tier3_hat != null and tier3_hat.backend == ModularAssetSystem.AssetRenderBackend.TEXTURE_SPRITE,
		"Tier 3 equipped TEXTURE_SPRITE helmet"
	)
	ctrl._draw()
	ok = ok and _assert(ctrl.last_draw_primitive_count > 100, "Customized modular rig rendered in _draw()")

	_cleanup_scene(ctrl)
	return ok
