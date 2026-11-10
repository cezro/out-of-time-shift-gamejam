extends SceneTree

## Unit Test Suite for ModularAssetSystem & AssetMcpBridge
## Run via:
## godot --headless --path "<workspace>/new-game-project" --script res://tests/test_modular_rig.gd

const RigSystem = preload("res://scripts/modular_rig/modular_asset_system.gd")
const McpBridge = preload("res://scripts/tools/asset_mcp_bridge.gd")
const TimelineSys = preload("res://scripts/timeline/timeline_system.gd")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Running Modular Rig & Piece-by-Piece Asset System Tests ===")

	_test_stickman_pose_solver_stances()
	_test_all_20_part_slot_transforms()
	_test_shift_staff_7_piece_assembly_and_key_alignment()
	_test_runtime_piece_by_piece_injection()
	_test_ragdoll_loadout_splitting()
	_test_json_manifest_roundtrip_and_mcp_bridge()
	_test_packed_scene_backend_and_procedural_stickman()
	_test_m2_motion_dynamics_and_springs()
	_test_m3_global_coverage()

	print("=== Test Summary: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] " + message)


func _test_stickman_pose_solver_stances() -> void:
	print("-- Test 1: StickmanPoseSolver across all stances --")
	var origin := Vector2(100.0, -200.0)

	# 1. Idle stance (player vs enemy head_radius)
	var idle_player := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2.ZERO, true, 0.0, false, 0.0, false, "normal"
	)
	var idle_enemy := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, -1.0, Vector2.ZERO, true, 0.0, false, 0.0, true, "normal"
	)
	_assert(is_equal_approx(idle_player.head_radius, 8.5), "Player head_radius should be 8.5")
	_assert(is_equal_approx(idle_enemy.head_radius, 7.5), "Enemy head_radius should be 7.5")
	_assert(idle_player.head_center.y > idle_player.neck.y, "Head center above neck in Bevy Y-up pose")
	_assert(idle_player.neck.y > idle_player.pelvis.y, "Neck above pelvis")
	_assert(idle_player.scarf_nodes.size() == 3, "Scarf has 3 trail nodes")
	_assert(idle_player.scarf_nodes[2].x < idle_player.head_center.x, "Scarf trails behind facing=+1")

	# 2. Running stance
	var run_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(220.0, 0.0), true, 0.35, false, 0.0, false, "normal"
	)
	_assert(run_pose.neck.x > idle_player.neck.x, "Running leans torso forward in facing direction")
	_assert(run_pose.left_foot != idle_player.left_foot, "Running animates foot stride")

	# 3. Jumping stance
	var jump_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(80.0, 300.0), false, 0.2, false, 0.0, false, "normal"
	)
	_assert(jump_pose.left_knee.y > idle_player.left_knee.y, "Jumping tucks knees higher")

	# 4. Attacking slash sweep
	var atk_start := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2.ZERO, true, 0.1, true, 1.0, false, "normal"
	)
	var atk_end := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2.ZERO, true, 0.1, true, 0.0, false, "normal"
	)
	_assert(atk_start.sword_tip != atk_end.sword_tip, "Attack progress sweeps sword tip across arc")

	# 5. Wall-sliding stance
	var wall_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(0.0, -90.0), false, 0.4, false, 0.0, false, "wall_slide"
	)
	_assert(wall_pose.stance == "wall_slide", "Wall slide stance recorded")
	_assert(wall_pose.left_foot.y > wall_pose.right_foot.y, "Wall slide plants one foot higher on wall")

	# 6. Downward-slam stance
	var slam_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2(0.0, -500.0), false, 0.2, true, 0.5, false, "downward_slam"
	)
	_assert(slam_pose.sword_tip.y < slam_pose.sword_hilt.y, "Downward slam points Shift Staff straight down")

	# 7. Parry guard & Heavy slash & Well unlock stances
	var parry_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2.ZERO, true, 0.0, false, 0.0, false, "parry_guard"
	)
	_assert(parry_pose.sword_tip.y > parry_pose.sword_hilt.y, "Parry guard raises Shift Staff defensively")

	var heavy_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2.ZERO, true, 0.0, true, 0.5, false, "heavy_slash"
	)
	var well_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		origin, 1.0, Vector2.ZERO, true, 0.0, false, 0.0, false, "well_unlock"
	)
	_assert(heavy_pose.sword_hilt.distance_to(heavy_pose.sword_tip) > 45.0, "Heavy slash extends reach")
	_assert(is_equal_approx(well_pose.sword_tip.y, well_pose.sword_hilt.y), "Well unlock extends cane horizontally")


func _test_all_20_part_slot_transforms() -> void:
	print("-- Test 2: Bone transform calculation for all 20 PartSlot values --")
	var pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2(0.0, 0.0), 1.0, Vector2(120.0, 0.0), true, 0.5, false, 0.0, false, "normal"
	)
	for slot_idx in range(20):
		var xform: Dictionary = RigSystem.StickmanPoseSolver.compute_slot_transform(
			pose, slot_idx, 1.0
		)
		_assert(xform.has("start") and xform["start"] is Vector2, "Slot %d has valid start Vector2" % slot_idx)
		_assert(xform.has("end") and xform["end"] is Vector2, "Slot %d has valid end Vector2" % slot_idx)
		_assert(xform.has("center") and xform["center"] is Vector2, "Slot %d has valid center Vector2" % slot_idx)
		_assert(xform.has("angle") and not is_nan(float(xform["angle"])), "Slot %d has finite angle" % slot_idx)
		_assert(float(xform.get("length", 0.0)) > 0.0, "Slot %d has positive bone length" % slot_idx)


func _test_shift_staff_7_piece_assembly_and_key_alignment() -> void:
	print("-- Test 3: Shift Staff 7-piece weapon assembly & Chronos Key alignment --")
	var registry := RigSystem.ModularAssetRegistry.new()
	var player_loadout := registry.get_loadout("player_shift_staff")
	_assert(player_loadout != null, "player_shift_staff preset exists")
	_assert(player_loadout.weapon_assembly != null, "player_shift_staff has WeaponAssemblySpec")
	_assert(
		player_loadout.weapon_assembly.weapon_class == "shift_staff_cane",
		"player weapon_class is shift_staff_cane"
	)
	_assert(
		player_loadout.weapon_assembly.pieces.size() == 7,
		"Shift Staff has 7 modular weapon pieces by default"
	)

	var hilt := Vector2(10.0, 20.0)
	var tip := Vector2(50.0, 20.0) # Horizontal shaft (angle = 0.0)
	var unaligned_xforms := player_loadout.weapon_assembly.compute_piece_transforms(
		hilt, tip, 1.0, 0.0, 0.25
	)
	var aligned_xforms := player_loadout.weapon_assembly.compute_piece_transforms(
		hilt, tip, 1.0, 1.0, 0.25
	)
	_assert(unaligned_xforms.size() == 7, "Unaligned transform array has 7 entries")
	_assert(aligned_xforms.size() == 7, "Aligned transform array has 7 entries")

	var gear_unaligned: Dictionary = {}
	var gear_aligned: Dictionary = {}
	var teeth_unaligned: Dictionary = {}
	var teeth_aligned: Dictionary = {}

	for item in unaligned_xforms:
		if int(item["piece_slot"]) == RigSystem.WeaponPieceSlot.GEARWORK_CORE:
			gear_unaligned = item
		elif int(item["piece_slot"]) == RigSystem.WeaponPieceSlot.KEY_TEETH:
			teeth_unaligned = item

	for item in aligned_xforms:
		if int(item["piece_slot"]) == RigSystem.WeaponPieceSlot.GEARWORK_CORE:
			gear_aligned = item
		elif int(item["piece_slot"]) == RigSystem.WeaponPieceSlot.KEY_TEETH:
			teeth_aligned = item

	_assert(not gear_unaligned.is_empty() and not gear_aligned.is_empty(), "GEARWORK_CORE found in transforms")
	_assert(not teeth_unaligned.is_empty() and not teeth_aligned.is_empty(), "KEY_TEETH found in transforms")
	_assert(
		not is_equal_approx(float(gear_unaligned["gear_phase_offset"]), 0.0),
		"GEARWORK_CORE is out of phase when gear_alignment == 0.0"
	)
	_assert(
		is_equal_approx(float(gear_aligned["gear_phase_offset"]), 0.0),
		"GEARWORK_CORE locks into exact phase 0.0 when gear_alignment == 1.0"
	)
	_assert(
		float(teeth_aligned["key_tooth_length"]) > float(teeth_unaligned["key_tooth_length"]),
		"KEY_TEETH extend to full Chronos Key ward length at gear_alignment == 1.0"
	)
	_assert(bool(teeth_aligned["is_key_aligned"]) == true, "is_key_aligned flag is true at 1.0")


func _test_runtime_piece_by_piece_injection() -> void:
	print("-- Test 4: Runtime piece-by-piece injection of TEXTURE_SPRITE & CUSTOM_POLYGON --")
	var registry := RigSystem.ModularAssetRegistry.new()

	# Verify all 7 builtin loadouts exist
	var expected_presets: Array[String] = [
		"player_shift_staff",
		"enemy_runner",
		"enemy_ninja",
		"enemy_heavy",
		"enemy_gunner_semi",
		"enemy_gunner_auto",
		"enemy_sniper",
	]
	for preset_id in expected_presets:
		_assert(registry.get_loadout(preset_id) != null, "Builtin preset '%s' exists" % preset_id)

	# Create a procedural ImageTexture at runtime for TEXTURE_SPRITE backend test
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.9, 1.0, 1.0))
	var runtime_tex := ImageTexture.create_from_image(img)

	var applied_sprite: bool = registry.apply_part_to_loadout("player_shift_staff", {
		"part_id": "chrono_nomad_hood_tex",
		"slot": RigSystem.PartSlot.HAT_HELMET,
		"backend": RigSystem.AssetRenderBackend.TEXTURE_SPRITE,
		"texture_path": "res://icon.svg",
		"texture": runtime_tex,
		"primary_color": Color(0.9, 1.0, 1.0, 1.0),
		"offset": Vector2(0.0, 4.0),
		"scale": Vector2(1.2, 1.2),
	})
	_assert(applied_sprite, "apply_part_to_loadout succeeded for TEXTURE_SPRITE helmet")

	var player_lo := registry.get_loadout("player_shift_staff")
	var equipped_hat := player_lo.get_part(RigSystem.PartSlot.HAT_HELMET)
	_assert(equipped_hat != null, "Player HAT_HELMET slot is now equipped")
	_assert(
		equipped_hat.backend == RigSystem.AssetRenderBackend.TEXTURE_SPRITE,
		"Equipped hat uses TEXTURE_SPRITE backend"
	)
	_assert(equipped_hat.texture == runtime_tex, "Equipped hat retains runtime Texture2D reference")

	# Inject CUSTOM_POLYGON armor shin guards onto enemy_runner
	var applied_poly: bool = registry.apply_part_to_loadout("enemy_runner", {
		"part_id": "runner_cyber_greaves_l",
		"slot": RigSystem.PartSlot.SHIN_L,
		"backend": RigSystem.AssetRenderBackend.CUSTOM_POLYGON,
		"polygon_points": [Vector2(-3.0, -6.0), Vector2(3.0, -6.0), Vector2(4.0, 6.0), Vector2(-4.0, 6.0)],
		"primary_color": "#ff3344ff",
	})
	_assert(applied_poly, "apply_part_to_loadout succeeded for CUSTOM_POLYGON greaves")
	var runner_shin := registry.get_loadout("enemy_runner").get_part(RigSystem.PartSlot.SHIN_L)
	_assert(
		runner_shin != null and runner_shin.polygon_points.size() == 4,
		"Enemy runner SHIN_L has 4-vertex custom polygon"
	)

	# Inject a new modular weapon piece onto player_shift_staff
	var applied_wp: bool = registry.apply_weapon_piece_to_loadout("player_shift_staff", {
		"piece_id": "overclocked_chronos_key_teeth",
		"piece_slot": RigSystem.WeaponPieceSlot.KEY_TEETH,
		"backend": RigSystem.AssetRenderBackend.CUSTOM_POLYGON,
		"polygon_points": [Vector2(0, 0), Vector2(6, 0), Vector2(6, 12), Vector2(0, 12)],
		"key_tooth_length": 14.5,
		"rotates_with_gear": true,
	})
	_assert(applied_wp, "apply_weapon_piece_to_loadout succeeded")
	var updated_teeth := player_lo.weapon_assembly.get_piece(RigSystem.WeaponPieceSlot.KEY_TEETH)
	_assert(
		is_equal_approx(updated_teeth.key_tooth_length, 14.5),
		"Player Shift Staff KEY_TEETH updated to 14.5 tooth length"
	)


func _test_ragdoll_loadout_splitting() -> void:
	print("-- Test 5: Ragdoll Loadout Splitting (UpperTorso vs LowerLegs) --")
	var registry := RigSystem.ModularAssetRegistry.new()
	var heavy := registry.get_loadout("enemy_heavy")

	# Equip a custom boot on FOOT_L to verify lower half preservation
	var stone_boot := RigSystem.PartPieceSpec.new(
		"heavy_stone_sabatons_l",
		RigSystem.PartSlot.FOOT_L,
		RigSystem.AssetRenderBackend.CUSTOM_POLYGON,
		Color.ORANGE,
		Color.YELLOW,
		3.5
	)
	stone_boot.polygon_points = PackedVector2Array([Vector2(-4, -2), Vector2(6, -2), Vector2(6, 3), Vector2(-4, 3)])
	heavy.equip_part(stone_boot)

	var halves: Dictionary = heavy.split_for_ragdoll()
	_assert(halves.has("upper") and halves.has("lower"), "split_for_ragdoll returns upper and lower keys")
	var upper: RigSystem.CharacterLoadout = halves["upper"]
	var lower: RigSystem.CharacterLoadout = halves["lower"]

	# Verify all upper slots stay on UpperTorso and are absent from LowerLegs
	for u_slot in RigSystem.UPPER_BODY_SLOTS:
		if heavy.get_part(u_slot) != null:
			_assert(upper.get_part(u_slot) != null, "UpperTorso retains slot %d" % u_slot)
		_assert(lower.get_part(u_slot) == null, "LowerLegs does not contain upper slot %d" % u_slot)

	# Verify all lower slots stay on LowerLegs and are absent from UpperTorso
	for l_slot in RigSystem.LOWER_BODY_SLOTS:
		if heavy.get_part(l_slot) != null:
			_assert(lower.get_part(l_slot) != null, "LowerLegs retains slot %d" % l_slot)
		_assert(upper.get_part(l_slot) == null, "UpperTorso does not contain lower slot %d" % l_slot)

	_assert(
		upper.get_part(RigSystem.PartSlot.HAT_HELMET).part_id == "heavy_crest_helmet",
		"UpperTorso retains custom Golem crest helmet"
	)
	_assert(
		lower.get_part(RigSystem.PartSlot.FOOT_L).part_id == "heavy_stone_sabatons_l",
		"LowerLegs retains custom stone sabaton boot"
	)


func _test_json_manifest_roundtrip_and_mcp_bridge() -> void:
	print("-- Test 6: JSON Manifest Export/Import Roundtrip & AssetMcpBridge --")
	var reg_a := RigSystem.ModularAssetRegistry.new()
	reg_a.apply_part_to_loadout("enemy_ninja", {
		"part_id": "ninja_oni_mask",
		"slot": RigSystem.PartSlot.EYES,
		"backend": RigSystem.AssetRenderBackend.CUSTOM_POLYGON,
		"polygon_points": [Vector2(-4, -2), Vector2(4, -2), Vector2(0, 4)],
		"primary_color": "#ff0055ff",
	})

	var json_str: String = reg_a.export_manifest_json()
	_assert(not json_str.is_empty(), "export_manifest_json produces non-empty JSON string")

	var reg_b := RigSystem.ModularAssetRegistry.new()
	var loaded_ok: bool = reg_b.load_manifest_json(json_str)
	_assert(loaded_ok, "load_manifest_json parses exported manifest")
	var ninja_eyes := reg_b.get_loadout("enemy_ninja").get_part(RigSystem.PartSlot.EYES)
	_assert(
		ninja_eyes != null and ninja_eyes.part_id == "ninja_oni_mask",
		"Roundtripped manifest preserves custom ninja_oni_mask on enemy_ninja"
	)
	_assert(ninja_eyes.polygon_points.size() == 3, "Roundtripped polygon_points has 3 vertices")

	# Test AssetMcpBridge writing to res://assets/modular_parts_manifest.json
	var test_manifest_path := "res://assets/modular_parts_manifest.json"
	var part_ok: bool = McpBridge.register_modular_part({
		"manifest_path": test_manifest_path,
		"part_id": "mcp_injected_chrono_pauldron",
		"slot": RigSystem.PartSlot.UPPER_ARM_R,
		"backend": RigSystem.AssetRenderBackend.CUSTOM_POLYGON,
		"polygon_points": [{"x": -5.0, "y": -4.0}, {"x": 5.0, "y": -4.0}, {"x": 0.0, "y": 6.0}],
		"primary_color": "#00ffccff",
		"target_loadout": "player_shift_staff",
	})
	var wp_ok: bool = McpBridge.register_weapon_piece({
		"manifest_path": test_manifest_path,
		"piece_id": "mcp_injected_brass_cog",
		"piece_slot": RigSystem.WeaponPieceSlot.GEARWORK_CORE,
		"backend": RigSystem.AssetRenderBackend.PROCEDURAL_VECTOR,
		"length": 9.5,
		"thickness": 4.0,
		"rotates_with_gear": true,
		"key_tooth_length": 6.5,
		"target_loadout": "player_shift_staff",
	})
	_assert(part_ok and wp_ok, "AssetMcpBridge registered modular part and weapon piece to manifest")
	_assert(FileAccess.file_exists(test_manifest_path), "res://assets/modular_parts_manifest.json exists on disk")

	var f := FileAccess.open(test_manifest_path, FileAccess.READ)
	var disk_json: String = f.get_as_text()
	f.close()

	var reg_c := RigSystem.ModularAssetRegistry.new()
	_assert(reg_c.load_manifest_json(disk_json), "Registry loaded MCP-generated manifest from disk")
	_assert(
		reg_c.get_loadout("player_shift_staff").get_part(RigSystem.PartSlot.UPPER_ARM_R).part_id == "mcp_injected_chrono_pauldron",
		"MCP-injected part automatically equipped onto target_loadout player_shift_staff"
	)
	_assert(
		reg_c.get_loadout("player_shift_staff").weapon_assembly.get_piece(RigSystem.WeaponPieceSlot.GEARWORK_CORE).piece_id == "mcp_injected_brass_cog",
		"MCP-injected weapon piece automatically equipped onto target_loadout player_shift_staff"
	)


func _test_packed_scene_backend_and_procedural_stickman() -> void:
	print("-- Test 7: PACKED_SCENE backend registration & procedural stickman scene instantiation --")
	var registry := RigSystem.ModularAssetRegistry.new()

	# 1. Preset & Part Registration Check
	var stickman_loadout := registry.get_loadout("player_procedural_stickman")
	_assert(stickman_loadout != null, "player_procedural_stickman preset exists in ModularAssetRegistry")
	_assert(
		registry.get_rig_scene_path("player_procedural_stickman") == RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH,
		"Procedural stickman scene path correctly mapped to res://scenes/stickman/stickmanprocedural.tscn"
	)

	var rig_part := stickman_loadout.get_part(RigSystem.PartSlot.TORSO)
	_assert(rig_part != null, "Torso slot has procedural stickman part equipped")
	_assert(
		rig_part.backend == RigSystem.AssetRenderBackend.PACKED_SCENE,
		"Equipped part uses AssetRenderBackend.PACKED_SCENE"
	)
	_assert(
		rig_part.scene_path == RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH,
		"Part scene_path matches PROCEDURAL_STICKMAN_SCENE_PATH"
	)

	# 2. File and ResourceLoader Check
	var scene_path: String = RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH
	var scene_exists: bool = ResourceLoader.exists(scene_path)
	_assert(scene_exists, "stickmanprocedural.tscn exists on disk at %s" % scene_path)
	if not scene_exists:
		printerr("    [SKIP] Cannot instantiate stickmanprocedural.tscn because file does not exist yet")
		return

	# 3. Instantiation via ModularAssetRegistry
	var rig_node: Node = registry.instantiate_rig("player_procedural_stickman")
	_assert(rig_node != null, "registry.instantiate_rig() successfully instantiated procedural stickman scene")
	if rig_node == null:
		return

	# Mount to SceneTree root to trigger @onready and _ready()
	root.add_child(rig_node)

	# 4. Hierarchy & Node Type Integrity Check
	_assert(rig_node is CharacterBody2D, "Root node is CharacterBody2D")
	_assert(rig_node.get_script() != null, "Root node has attached stickmanprocedural.gd script")
	_assert(rig_node.get_node_or_null("Rig") != null, "Rig Node2D exists in hierarchy")
	_assert(rig_node.get_node_or_null("Rig/Bones/Skeleton2D") != null, "Skeleton2D exists under Rig/Bones")
	_assert(rig_node.get_node_or_null("Rig/Body") != null, "Body visual container exists under Rig")
	_assert(rig_node.get_node_or_null("IK Targets") != null, "IK Targets container exists on root")

	# 5. Interface Contract Execution
	_assert(
		rig_node.has_method("update_procedural_animation"),
		"Rig implements update_procedural_animation() contract"
	)
	_assert(
		rig_node.has_method("get_bone_positions"),
		"Rig implements get_bone_positions() contract"
	)

	# Exercise running ground gait
	rig_node.call("update_procedural_animation", Vector2(240.0, 0.0), true, 1.0, "run", 0.016)
	_assert(is_equal_approx(float(rig_node.get("facing")), 1.0), "Rig facing is 1.0 after forward run")

	# Exercise aerial jump state with direction flip
	rig_node.call("update_procedural_animation", Vector2(-150.0, -320.0), false, -1.0, "jump", 0.016)
	_assert(is_equal_approx(float(rig_node.get("facing")), -1.0), "Rig facing turns to -1.0 on reverse jump")

	# Exercise bone position query
	var bone_dict: Dictionary = rig_node.call("get_bone_positions")
	_assert(bone_dict.has("hip") or bone_dict.has("Hip") or bone_dict.has("pelvis"), "Bone dictionary contains hip joint")
	_assert(bone_dict.has("head") or bone_dict.has("Head") or bone_dict.has("head_center"), "Bone dictionary contains head joint")

	# 6. Teardown & Clean Cleanup
	var initial_orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	root.remove_child(rig_node)
	rig_node.free()
	_assert(not is_instance_valid(rig_node), "Procedural stickman instance marked invalid after free")
	var final_orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_assert(final_orphans <= initial_orphans, "Procedural stickman freed without leaking orphan nodes")


func _test_m2_motion_dynamics_and_springs() -> void:
	print("-- Test 8: Milestone 2 Motion Dynamics, Second-Order Springs, and Procedural Gait --")

	# 1. ProceduralSpring harmonic oscillator
	var spring = RigSystem.ProceduralSpring.new(5.0, 0.75, 0.0)
	_assert(spring.value == 0.0 and spring.target == 0.0, "Spring starts at 0.0")
	spring.snap_to(1.0)
	var max_v: float = 0.0
	for _i in range(100):
		var val = spring.update(0.005)
		if val > max_v:
			max_v = val
	_assert(max_v > 1.01 and max_v < 1.06, "Spring exhibits snappy overshoot under zeta=0.75 (got %f)" % max_v)
	for _i in range(50):
		spring.update(0.005)
	_assert(absf(spring.value - 1.0) < 0.01, "Spring settles to target within 2%% band")

	# 2. Cadence saturation curve
	var f0: float = RigSystem.ProceduralGaitSolver.calculate_cadence(0.0)
	var f180: float = RigSystem.ProceduralGaitSolver.calculate_cadence(180.0)
	var f340: float = RigSystem.ProceduralGaitSolver.calculate_cadence(340.0)
	var f_dash: float = RigSystem.ProceduralGaitSolver.calculate_cadence(1000.0)
	_assert(is_equal_approx(f0, 1.8), "Idle cadence is 1.8 Hz")
	_assert(f180 > 3.3 and f180 < 3.35, "Reference run cadence is ~3.32 Hz (got %f)" % f180)
	_assert(f340 > f180 and f340 < 3.8, "Sprint cadence scales smoothly below 3.8 Hz")
	_assert(f_dash > f340 and f_dash < 3.8, "Dash cadence asymptotically saturates")

	# 3. Piecewise stance-lock and Hermite foot swing
	var traj_stance = RigSystem.ProceduralGaitSolver.evaluate_foot_trajectory(PI * 0.4, 14.0, 6.0)
	_assert(is_equal_approx(traj_stance.y, 0.0), "Foot is pinned flat on floor during stance phase")
	var traj_swing = RigSystem.ProceduralGaitSolver.evaluate_foot_trajectory(PI * 1.5, 14.0, 6.0)
	_assert(is_equal_approx(traj_swing.y, 6.0), "Foot reaches peak step height at mid-swing")

	# 4. Inverted pendulum pelvic bobbing at 2x stride frequency
	var p_strike = RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2.ZERO, 1.0, Vector2(180.0, 0.0), true, 0.0, false, 0.0, false, "normal"
	)
	var p_mid = RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2.ZERO, 1.0, Vector2(180.0, 0.0), true, 0.075, false, 0.0, false, "normal"
	)
	_assert(p_mid.pelvis.y > p_strike.pelvis.y, "Pelvis vaults upward during mid-stance (mid=%f > strike=%f)" % [p_mid.pelvis.y, p_strike.pelvis.y])

	# 5. Dynamic acceleration-proportional torso lean
	var p_cruise = RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2.ZERO, 1.0, Vector2(200.0, 0.0), true, 0.2, false, 0.0, false, "normal", 0.0
	)
	var p_accel = RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2.ZERO, 1.0, Vector2(200.0, 0.0), true, 0.2, false, 0.0, false, "normal", 2200.0
	)
	var p_brake = RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2.ZERO, 1.0, Vector2(200.0, 0.0), true, 0.2, false, 0.0, false, "normal", -2800.0
	)
	_assert(p_accel.neck.x > p_cruise.neck.x, "Forward acceleration leans torso forward further than cruise")
	_assert(p_brake.neck.x < p_cruise.neck.x, "Braking pitches torso backward to brace against deceleration")

	# 6. Volume-conserving squash & stretch
	var sq = RigSystem.StickmanPoseSolver.volume_conserving_scale(1.32)
	_assert(is_equal_approx(sq.x * sq.x * sq.y, 1.0), "Volume Sx^2 * Sy is strictly conserved")

	# 7. Three-phase combat slash
	var p1 = RigSystem.StickmanPoseSolver.calculate_combat_slash(0.95, 1.0, false)
	var p2 = RigSystem.StickmanPoseSolver.calculate_combat_slash(0.70, 1.0, false)
	var p3 = RigSystem.StickmanPoseSolver.calculate_combat_slash(0.0, 1.0, false)
	_assert(p1["blade_stretch"] < 1.0, "Phase 1 anticipation coil contracts blade")
	_assert(p2["blade_stretch"] > 1.05, "Phase 2 snap strike elongates blade")
	_assert(is_equal_approx(p3["blade_stretch"], 1.0), "Phase 3 settle recovers blade length")

	# 8. Scarf distance constraint clamping
	var p_run = RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2.ZERO, 1.0, Vector2(240.0, 0.0), true, 0.3, false, 0.0, false, "normal"
	)
	var d01: float = p_run.scarf_nodes[0].distance_to(p_run.scarf_nodes[1])
	var d12: float = p_run.scarf_nodes[1].distance_to(p_run.scarf_nodes[2])
	_assert(d01 >= 5.9 and d01 <= 14.1, "Scarf segment 0-1 clamped in [6, 14] px")
	_assert(d12 >= 5.9 and d12 <= 14.1, "Scarf segment 1-2 clamped in [6, 14] px")
	_assert(p_run.scarf_nodes[2].x < p_run.head_center.x, "Scarf trails behind head")


func _test_m3_global_coverage() -> void:
	print("-- Test 9: Milestone 3 Global Coverage (Player Rig, Clones/Echoes, Enemy Archetypes, Ragdoll Pieces) --")
	var registry := RigSystem.ModularAssetRegistry.new()

	# 1. Feature 7 & 9: player_default alias and procedural rig scene paths
	var def_lo := registry.get_loadout("player_default")
	_assert(def_lo != null, "player_default loadout is registered in ModularAssetRegistry")
	_assert(def_lo.rig_scene_path == RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH, "player_default has procedural stickman rig path")
	var staff_lo := registry.get_loadout("player_shift_staff")
	_assert(staff_lo != null, "player_shift_staff loadout is registered")
	_assert(def_lo.parts.size() == staff_lo.parts.size(), "player_default part count matches player_shift_staff")

	var all_archetypes: Array[String] = [
		"enemy_runner",
		"enemy_ninja",
		"enemy_heavy",
		"enemy_gunner_semi",
		"enemy_gunner_auto",
		"enemy_sniper",
		"player_shift_staff",
		"player_default",
		"player_procedural_stickman"
	]
	for arch in all_archetypes:
		var path: String = registry.get_rig_scene_path(arch)
		_assert(path == RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH, "Archetype '%s' wires to PROCEDURAL_STICKMAN_SCENE_PATH" % arch)
		var lo := registry.get_loadout(arch)
		_assert(lo != null, "Loadout for '%s' exists" % arch)
		if arch == "player_procedural_stickman":
			_assert(lo.parts.size() >= 1, "Loadout '%s' has rig scene part" % arch)
		else:
			_assert(lo.parts.size() >= 5, "Loadout '%s' has anatomical body parts" % arch)

	# 2. Feature 7: Persistent dynamics context and acceleration lean
	var dyn_ctx := RigSystem.PoseDynamicsContext.new()
	var p_accel := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2.ZERO, 1.0, Vector2(250.0, 0.0), true, 0.1, false, 0.0, false, "normal", 2400.0, dyn_ctx, 0.016
	)
	_assert(p_accel.neck.x > 3.0, "Forward acceleration drives neck forward")
	_assert(dyn_ctx.prev_velocity.x == 250.0, "Dynamics context stores previous velocity")
	_assert(p_accel.scarf_nodes.size() == 3, "Scarf nodes present in dynamics pose")

	# 3. Feature 8: ChronoEchoData fields and fade ratio
	var timeline := TimelineSys.TimelineState.new()
	timeline.spawn_chrono_echo(
		Vector2(100.0, 50.0),
		Vector2(1.0, 0.0),
		TimelineSys.TimelineEra.PAST,
		"dash",
		95.0,
		3.0,
		1.0,
		Vector2(320.0, 0.0),
		true,
		"jump",
		0.25,
		"player_shift_staff"
	)
	_assert(timeline.echoes.size() == 1, "Echo was spawned into timeline")
	var echo: TimelineSys.ChronoEchoData = timeline.echoes[0]
	_assert(echo.facing == 1.0, "Echo preserves facing")
	_assert(echo.velocity == Vector2(320.0, 0.0), "Echo preserves velocity")
	_assert(echo.is_grounded == true, "Echo preserves grounded flag")
	_assert(echo.stance == "jump", "Echo preserves stance")
	_assert(is_equal_approx(echo.anim_time, 0.25), "Echo preserves anim_time")
	_assert(echo.loadout_id == "player_shift_staff", "Echo preserves loadout_id")
	_assert(is_equal_approx(echo.fade_ratio(), 1.0), "Echo starts with 1.0 fade ratio")
	timeline.tick(1.5)
	_assert(echo.fade_ratio() < 0.6 and echo.fade_ratio() > 0.4, "Echo fades to ~0.5 after half lifetime")

	# 4. Feature 8 & 9: Jump stance pose generation
	var jump_pose := RigSystem.StickmanPoseSolver.generate_stickman_pose(
		Vector2(50.0, 100.0), 1.0, Vector2(100.0, -150.0), false, 0.1, false, 0.0, false, "jump"
	)
	_assert(jump_pose.left_knee.is_finite() and jump_pose.right_knee.is_finite(), "Jump stance knees are finite")
	_assert(jump_pose.left_foot.is_finite() and jump_pose.right_foot.is_finite(), "Jump stance feet are finite")

	# 5. Feature 10: Procedural Ragdoll Pose Solver (Upper and Lower tumbling pieces)
	var r_upper := RigSystem.StickmanPoseSolver.generate_ragdoll_pose(
		Vector2(200.0, 100.0), 0.785, 1.0, 0, "enemy_heavy"
	)
	_assert(r_upper.head_center.is_finite(), "Upper ragdoll head_center is finite")
	_assert(r_upper.pelvis.is_finite(), "Upper ragdoll pelvis is finite")
	_assert(r_upper.left_hand.is_finite() and r_upper.sword_tip.is_finite(), "Upper ragdoll carries arms and weapon")

	var r_lower := RigSystem.StickmanPoseSolver.generate_ragdoll_pose(
		Vector2(200.0, 100.0), -1.2, 1.0, 1, "enemy_heavy"
	)
	_assert(r_lower.left_foot.is_finite() and r_lower.right_foot.is_finite(), "Lower ragdoll carries feet and hips")

	var helm_xform := RigSystem.StickmanPoseSolver.compute_slot_transform(r_upper, RigSystem.PartSlot.HAT_HELMET, 1.0)
	_assert((helm_xform["center"] as Vector2).is_finite(), "Upper ragdoll hat/helmet transform is finite and tracks tumbling head")
	var foot_xform := RigSystem.StickmanPoseSolver.compute_slot_transform(r_lower, RigSystem.PartSlot.FOOT_L, 1.0)
	_assert((foot_xform["center"] as Vector2).is_finite(), "Lower ragdoll foot transform is finite and tracks tumbling leg")

	# 6. StickmanProcedural runtime API extensions (archetype configuration, aim, hitstun)
	var rig_packed: PackedScene = load(RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH)
	_assert(rig_packed != null, "PROCEDURAL_STICKMAN_SCENE_PATH loads successfully")
	var rig_inst = rig_packed.instantiate()
	var root := get_root()
	root.add_child(rig_inst)
	_assert(rig_inst.has_method("apply_archetype_configuration"), "Rig has apply_archetype_configuration")
	_assert(rig_inst.has_method("apply_aim_offsets"), "Rig has apply_aim_offsets")
	_assert(rig_inst.has_method("apply_hitstun_offsets"), "Rig has apply_hitstun_offsets")

	rig_inst.call("apply_archetype_configuration", "heavy", Color(0.9, 0.2, 0.2, 1.0), 1.35)
	var aim_offsets := {}
	rig_inst.call("apply_aim_offsets", aim_offsets, false)
	_assert(not aim_offsets.is_empty(), "apply_aim_offsets populated IK offsets")

	var hit_offsets := {}
	rig_inst.call("apply_hitstun_offsets", hit_offsets, true)
	_assert(not hit_offsets.is_empty(), "apply_hitstun_offsets populated IK offsets")

	root.remove_child(rig_inst)
	rig_inst.free()



