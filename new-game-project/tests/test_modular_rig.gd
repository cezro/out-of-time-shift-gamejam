extends SceneTree

## Unit Test Suite for ModularAssetSystem & AssetMcpBridge
## Run via:
## godot --headless --path "<workspace>/new-game-project" --script res://tests/test_modular_rig.gd

const RigSystem = preload("res://scripts/modular_rig/modular_asset_system.gd")
const McpBridge = preload("res://scripts/tools/asset_mcp_bridge.gd")

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

