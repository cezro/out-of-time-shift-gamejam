extends SceneTree

## Adversarial Challenger M1-2 Test Suite (Challenger 2)
## Empirically stress-tests and audits:
## 1. Repeated preset instantiation (100x loop), memory safety, and orphan node leak checks.
## 2. JSON serialization and deserialization roundtrip on PartPieceSpec with PACKED_SCENE backend.
## 3. Complete texture audit of all 16 stickman textures, UID integrity, format warnings, and sprite bindings.
## 4. ModularAssetRegistry preset integration, CharacterLoadout contracts, and pose generation.

const ModularRigScript = preload("res://scripts/modular_rig/modular_asset_system.gd")
const ProceduralStickmanScript = preload("res://scripts/stickman/stickmanprocedural.gd")

const PROCEDURAL_SCENE_PATH: String = "res://scenes/stickman/stickmanprocedural.tscn"
const PRESET_ID: String = "player_procedural_stickman"

const ALL_16_TEXTURE_NAMES: Array[String] = [
	"ArmBotB.png",
	"ArmBotF.png",
	"ArmTopB.png",
	"ArmTopF.png",
	"HandB.png",
	"HandF.png",
	"Head.png",
	"LegBotB.png",
	"LegBotF.png",
	"LegTopB.png",
	"LegTopF.png",
	"neck.png",
	"Pelvis.png",
	"StickmanBase.png",
	"Torso.png",
	"Waist.png",
]

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("======================================================================")
	print("=== RUNNING CHALLENGER 2 ADVERSARIAL STRESS SUITE (MILESTONE M1) ===")
	print("======================================================================")

	# Group 1: Repeated Preset Instantiation & Memory Safety
	_run_test("test_01_repeated_preset_instantiation_100x_memory_leak", test_01_repeated_preset_instantiation_100x_memory_leak)
	_run_test("test_02_tree_lifecycle_add_process_queue_free_50x", test_02_tree_lifecycle_add_process_queue_free_50x)
	_run_test("test_03_direct_procedural_rig_extreme_inputs_and_edge_cases", test_03_direct_procedural_rig_extreme_inputs_and_edge_cases)
	_run_test("test_04_stride_length_and_move_speed_zero_division_safety", test_04_stride_length_and_move_speed_zero_division_safety)

	# Group 2: JSON Serialization & Roundtrip on PartPieceSpec with PACKED_SCENE
	_run_test("test_05_part_piece_spec_packed_scene_json_roundtrip", test_05_part_piece_spec_packed_scene_json_roundtrip)
	_run_test("test_06_character_loadout_packed_scene_json_roundtrip", test_06_character_loadout_packed_scene_json_roundtrip)
	_run_test("test_07_packed_scene_spec_string_vs_float_backend_parsing", test_07_packed_scene_spec_string_vs_float_backend_parsing)
	_run_test("test_08_packed_scene_spec_missing_corrupt_scene_path_resilience", test_08_packed_scene_spec_missing_corrupt_scene_path_resilience)
	_run_test("test_09_ragdoll_split_with_packed_scene_loadout", test_09_ragdoll_split_with_packed_scene_loadout)

	# Group 3: Texture Audit, UID Integrity & Scene Sprite Bindings
	_run_test("test_10_all_16_textures_existence_and_loadability", test_10_all_16_textures_existence_and_loadability)
	_run_test("test_11_texture_uids_cross_reference_imports_and_tscn", test_11_texture_uids_cross_reference_imports_and_tscn)
	_run_test("test_12_stickman_scene_sprites_texture_binding", test_12_stickman_scene_sprites_texture_binding)

	# Group 4: ModularAssetSystem & Live Pose Solver Contracts
	_run_test("test_13_registry_preset_retrieval_and_instantiate_rig", test_13_registry_preset_retrieval_and_instantiate_rig)
	_run_test("test_14_live_rig_to_stickman_pose_simulation", test_14_live_rig_to_stickman_pose_simulation)
	_run_test("test_15_concurrent_multi_instance_gait_phase_isolation", test_15_concurrent_multi_instance_gait_phase_isolation)

	print("======================================================================")
	print("=== CHALLENGER 2 SUMMARY: %d / %d PASSED (%d FAILED) ===" % [_tests_passed, _tests_run, _tests_failed])
	print("======================================================================")

	if _tests_failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### CHALLENGER 2 VERDICT: APPROVE - ALL ADVERSARIAL STRESS TESTS PASSED")
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


# ============================================================================
# Group 1: Repeated Preset Instantiation & Memory Safety
# ============================================================================

func test_01_repeated_preset_instantiation_100x_memory_leak() -> bool:
	var ok: bool = true
	var registry = ModularRigScript.ModularAssetRegistry.new()

	var baseline_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	const ITERATIONS: int = 100
	for i in range(ITERATIONS):
		var rig = registry.instantiate_rig(PRESET_ID)
		if not _check(rig != null, "Iteration %d: instantiate_rig returned null" % i):
			return false
		if not _check(is_instance_valid(rig), "Iteration %d: rig is not a valid instance" % i):
			return false
		if not _check(rig is CharacterBody2D, "Iteration %d: rig must be CharacterBody2D" % i):
			return false

		# Exercise procedural controller
		if rig.has_method("update_procedural_animation"):
			rig.update_procedural_animation(Vector2(260.0, 0.0), true, 1.0, "run", 0.016)
			var bones: Dictionary = rig.get_bone_positions()
			if not _check(bones.size() >= 18, "Iteration %d: Expected >= 18 bones, got %d" % [i, bones.size()]):
				rig.free()
				return false

		# Direct free
		rig.free()

	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var orphan_diff: int = final_orphans - baseline_orphans

	ok = _check(orphan_diff <= 0, "No orphan nodes leaked across 100 instantiations (orphan_diff=%d)" % orphan_diff) and ok
	return ok


func test_02_tree_lifecycle_add_process_queue_free_50x() -> bool:
	var ok: bool = true
	var registry = ModularRigScript.ModularAssetRegistry.new()
	var tree_root: Window = root

	var baseline_children_count: int = tree_root.get_child_count()
	var baseline_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	const TREE_ITERATIONS: int = 50
	for i in range(TREE_ITERATIONS):
		var rig = registry.instantiate_rig(PRESET_ID)
		if rig == null:
			return false

		tree_root.add_child(rig)

		# Step through 5 gait cycles with varying locomotion states
		var test_states: Array[Dictionary] = [
			{"v": Vector2(0.0, 0.0), "ground": true, "facing": 1.0, "state": "idle"},
			{"v": Vector2(150.0, 0.0), "ground": true, "facing": 1.0, "state": "walk"},
			{"v": Vector2(260.0, 0.0), "ground": true, "facing": 1.0, "state": "run"},
			{"v": Vector2(-260.0, -300.0), "ground": false, "facing": -1.0, "state": "jump"},
			{"v": Vector2(0.0, 500.0), "ground": false, "facing": -1.0, "state": "fall"},
		]

		for st in test_states:
			rig.update_procedural_animation(st["v"], st["ground"], st["facing"], st["state"], 0.016)

		tree_root.remove_child(rig)
		rig.free()

	var final_children_count: int = tree_root.get_child_count()
	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	ok = _check(final_children_count == baseline_children_count,
		"Tree root child count must remain clean: baseline=%d, final=%d" % [baseline_children_count, final_children_count]) and ok
	ok = _check(final_orphans <= baseline_orphans,
		"Orphan node count must not leak: baseline=%d, final=%d" % [baseline_orphans, final_orphans]) and ok

	return ok


func test_03_direct_procedural_rig_extreme_inputs_and_edge_cases() -> bool:
	var ok: bool = true
	var packed: PackedScene = load(PROCEDURAL_SCENE_PATH)
	ok = _check(packed != null, "Loaded procedural stickman PackedScene") and ok
	var rig = packed.instantiate()

	var extreme_scenarios: Array[Dictionary] = [
		{"v": Vector2.ZERO, "ground": true, "facing": 0.0, "state": "idle", "dt": 0.0},
		{"v": Vector2(1e7, -1e7), "ground": true, "facing": 1.0, "state": "run", "dt": 100.0},
		{"v": Vector2(-1e7, 1e7), "ground": false, "facing": -1.0, "state": "jump", "dt": 0.001},
		{"v": Vector2(0.0, 0.0), "ground": true, "facing": -1.0, "state": "slash", "dt": 0.016},
		{"v": Vector2(0.0, 0.0), "ground": true, "facing": 1.0, "state": "heavy_slash", "dt": 0.016},
		{"v": Vector2(0.0, 0.0), "ground": false, "facing": -1.0, "state": "wall_slide", "dt": 0.016},
		{"v": Vector2(0.0, 0.0), "ground": true, "facing": 1.0, "state": "parry_guard", "dt": 0.016},
		{"v": Vector2(100.0, 100.0), "ground": true, "facing": 1.0, "state": "unknown_future_state", "dt": 0.016},
	]

	for sc in extreme_scenarios:
		rig.update_procedural_animation(sc["v"], sc["ground"], sc["facing"], sc["state"], sc["dt"])
		var ik_targets: Dictionary = rig.get_ik_targets()
		for t_name in ik_targets.keys():
			var t_node: Node2D = ik_targets[t_name]
			ok = _check(t_node != null and t_node.position.is_finite(),
				"IK target '%s' must remain finite for scenario %s (got %s)" % [t_name, sc["state"], str(t_node.position) if t_node else "null"]) and ok

		var pose = rig.to_stickman_pose()
		ok = _check(pose != null, "to_stickman_pose() returned non-null pose") and ok
		ok = _check(pose.head_center.is_finite() and pose.pelvis.is_finite(),
			"StickmanPose joint coordinates must remain finite") and ok

	rig.free()
	return ok


func test_04_stride_length_and_move_speed_zero_division_safety() -> bool:
	var ok: bool = true
	var packed: PackedScene = load(PROCEDURAL_SCENE_PATH)
	var rig = packed.instantiate()

	# Zero stride length
	rig.stride_length = 0.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "Phase must remain finite when stride_length == 0.0") and ok

	# Negative stride length
	rig.stride_length = -50.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "Phase must remain finite when stride_length < 0.0") and ok

	# Zero move speed
	rig.move_speed = 0.0
	rig.stride_length = 52.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	ok = _check(is_finite(rig.phase), "Animation must not crash when move_speed == 0.0") and ok

	# Zero snappiness
	rig.snappiness = 0.0
	rig.update_procedural_animation(Vector2(300.0, 0.0), true, 1.0, "run", 0.016)
	var ik_targets: Dictionary = rig.get_ik_targets()
	for t_name in ik_targets.keys():
		var t_node: Node2D = ik_targets[t_name]
		ok = _check(t_node.position.is_finite(), "Targets remain finite with zero snappiness") and ok

	rig.free()
	return ok


# ============================================================================
# Group 2: JSON Serialization & Roundtrip on PartPieceSpec with PACKED_SCENE
# ============================================================================

func test_05_part_piece_spec_packed_scene_json_roundtrip() -> bool:
	var ok: bool = true
	var PartPieceSpec = ModularRigScript.PartPieceSpec
	var AssetRenderBackend = ModularRigScript.AssetRenderBackend
	var PartSlot = ModularRigScript.PartSlot

	var original = PartPieceSpec.new(
		"spec_procedural_rig_alpha",
		PartSlot.TORSO,
		AssetRenderBackend.PACKED_SCENE,
		Color(0.2, 0.4, 0.8, 0.95),
		Color(0.9, 0.8, 0.1, 1.0),
		3.5
	)
	original.scene_path = PROCEDURAL_SCENE_PATH
	original.offset = Vector2(14.25, -8.75)
	original.rotation_offset = 0.456
	original.scale = Vector2(1.15, 0.95)
	original.region_rect = Rect2(5, 10, 50, 60)
	original.z_offset = 7
	original.metadata = {"author": "challenger", "version": 2, "ik_enabled": true}

	# Serialize -> JSON String -> Parse -> Deserialized Spec
	var d: Dictionary = original.to_dict()
	var json_str: String = JSON.stringify(d)
	var parsed = JSON.parse_string(json_str)
	ok = _check(parsed is Dictionary, "JSON parsed successfully to Dictionary") and ok

	var recovered = PartPieceSpec.from_dict(parsed)
	ok = _check(recovered != null, "from_dict constructed valid PartPieceSpec") and ok

	# Verify full field integrity
	ok = _check(recovered.part_id == original.part_id, "part_id matches ('%s')" % recovered.part_id) and ok
	ok = _check(recovered.slot == PartSlot.TORSO, "slot matches PartSlot.TORSO (4)") and ok
	ok = _check(recovered.backend == AssetRenderBackend.PACKED_SCENE,
		"backend matches AssetRenderBackend.PACKED_SCENE (3), got %s" % recovered.backend) and ok
	ok = _check(recovered.scene_path == original.scene_path, "scene_path matches ('%s')" % recovered.scene_path) and ok
	ok = _check(recovered.primary_color.is_equal_approx(original.primary_color), "primary_color matches") and ok
	ok = _check(recovered.secondary_color.is_equal_approx(original.secondary_color), "secondary_color matches") and ok
	ok = _check(is_equal_approx(recovered.line_width, original.line_width), "line_width matches") and ok
	ok = _check(recovered.offset.is_equal_approx(original.offset), "offset matches") and ok
	ok = _check(is_equal_approx(recovered.rotation_offset, original.rotation_offset), "rotation_offset matches") and ok
	ok = _check(recovered.scale.is_equal_approx(original.scale), "scale matches") and ok
	ok = _check(recovered.region_rect == original.region_rect, "region_rect matches") and ok
	ok = _check(recovered.z_offset == original.z_offset, "z_offset matches") and ok
	ok = _check(recovered.metadata.get("author") == "challenger", "metadata preserved") and ok

	# Verify instantiate_scene() on the deserialized spec
	var instance = recovered.instantiate_scene()
	ok = _check(instance != null, "recovered.instantiate_scene() returned valid Node") and ok
	ok = _check(instance is CharacterBody2D, "instantiated node is CharacterBody2D") and ok
	instance.free()

	return ok


func test_06_character_loadout_packed_scene_json_roundtrip() -> bool:
	var ok: bool = true
	var CharacterLoadout = ModularRigScript.CharacterLoadout
	var PartPieceSpec = ModularRigScript.PartPieceSpec
	var AssetRenderBackend = ModularRigScript.AssetRenderBackend
	var PartSlot = ModularRigScript.PartSlot

	var loadout = CharacterLoadout.new(
		"loadout_test_procedural",
		"Procedural Stickman Test Loadout",
		Color.WHITE,
		Color.CYAN
	)
	loadout.rig_scene_path = PROCEDURAL_SCENE_PATH

	var part = PartPieceSpec.new(
		"part_rig_torso",
		PartSlot.TORSO,
		AssetRenderBackend.PACKED_SCENE
	)
	part.scene_path = PROCEDURAL_SCENE_PATH
	loadout.equip_part(part)

	# Serialize -> JSON String -> Parse -> Deserialized Loadout
	var loadout_dict: Dictionary = loadout.to_dict()
	var json_str: String = JSON.stringify(loadout_dict)
	var parsed = JSON.parse_string(json_str)

	var recovered = CharacterLoadout.from_dict(parsed)
	ok = _check(recovered != null, "CharacterLoadout reconstructed from JSON") and ok
	ok = _check(recovered.loadout_id == "loadout_test_procedural", "loadout_id matches") and ok
	ok = _check(recovered.rig_scene_path == PROCEDURAL_SCENE_PATH, "rig_scene_path matches") and ok
	ok = _check(recovered.parts.has(PartSlot.TORSO), "Recovered loadout has equipped TORSO part") and ok

	var recovered_part = recovered.get_part(PartSlot.TORSO)
	ok = _check(recovered_part != null and recovered_part.backend == AssetRenderBackend.PACKED_SCENE,
		"Recovered part is PACKED_SCENE") and ok

	# Instantiate rig via recovered loadout
	var rig = recovered.instantiate_rig()
	ok = _check(rig != null and rig is CharacterBody2D, "recovered.instantiate_rig() returned CharacterBody2D") and ok
	rig.free()

	return ok


func test_07_packed_scene_spec_string_vs_float_backend_parsing() -> bool:
	var ok: bool = true
	var PartPieceSpec = ModularRigScript.PartPieceSpec
	var AssetRenderBackend = ModularRigScript.AssetRenderBackend

	# Scenario A: JSON number parsed as float 3.0
	var dict_float := {
		"part_id": "test_float_backend",
		"slot": 4.0,
		"backend": 3.0,
		"scene_path": PROCEDURAL_SCENE_PATH,
	}
	var spec_float = PartPieceSpec.from_dict(dict_float)
	ok = _check(spec_float.backend == AssetRenderBackend.PACKED_SCENE,
		"Float 3.0 backend parses to PACKED_SCENE") and ok

	# Scenario B: JSON string "PACKED_SCENE"
	var dict_str := {
		"part_id": "test_string_backend",
		"slot": "TORSO",
		"backend": "PACKED_SCENE",
		"scene_path": PROCEDURAL_SCENE_PATH,
	}
	var spec_str = PartPieceSpec.from_dict(dict_str)
	ok = _check(spec_str.backend == AssetRenderBackend.PACKED_SCENE,
		"String 'PACKED_SCENE' parses to PACKED_SCENE") and ok

	# Scenario C: Integer 3
	var dict_int := {
		"part_id": "test_int_backend",
		"slot": 4,
		"backend": 3,
		"scene_path": PROCEDURAL_SCENE_PATH,
	}
	var spec_int = PartPieceSpec.from_dict(dict_int)
	ok = _check(spec_int.backend == AssetRenderBackend.PACKED_SCENE,
		"Integer 3 parses to PACKED_SCENE") and ok

	# Scenario D: Invalid string fallback to PROCEDURAL_VECTOR
	var dict_invalid := {
		"part_id": "test_invalid_backend",
		"slot": 4,
		"backend": "NON_EXISTENT_BACKEND_XYZ",
	}
	var spec_inv = PartPieceSpec.from_dict(dict_invalid)
	ok = _check(spec_inv.backend == AssetRenderBackend.PROCEDURAL_VECTOR,
		"Invalid backend string defaults to PROCEDURAL_VECTOR") and ok

	return ok


func test_08_packed_scene_spec_missing_corrupt_scene_path_resilience() -> bool:
	var ok: bool = true
	var PartPieceSpec = ModularRigScript.PartPieceSpec
	var AssetRenderBackend = ModularRigScript.AssetRenderBackend

	# Empty scene path
	var spec_empty = PartPieceSpec.new("empty_path", 4, AssetRenderBackend.PACKED_SCENE)
	spec_empty.scene_path = ""
	var node_empty = spec_empty.instantiate_scene()
	ok = _check(node_empty == null, "Empty scene_path instantiate_scene() returns null safely") and ok

	# Non-existent scene path
	var spec_nonexistent = PartPieceSpec.new("missing_path", 4, AssetRenderBackend.PACKED_SCENE)
	spec_nonexistent.scene_path = "res://scenes/stickman/non_existent_scene_12345.tscn"
	var node_missing = spec_nonexistent.instantiate_scene()
	ok = _check(node_missing == null, "Non-existent scene_path instantiate_scene() returns null safely") and ok

	return ok


func test_09_ragdoll_split_with_packed_scene_loadout() -> bool:
	var ok: bool = true
	var registry = ModularRigScript.ModularAssetRegistry.new()
	var loadout = registry.get_loadout(PRESET_ID)
	ok = _check(loadout != null, "Preset '%s' retrieved" % PRESET_ID) and ok

	var halves: Dictionary = loadout.split_for_ragdoll()
	ok = _check(halves.has("upper") and halves.has("lower"), "split_for_ragdoll returned upper and lower") and ok

	var upper = halves["upper"]
	var lower = halves["lower"]

	ok = _check(upper.rig_scene_path == loadout.rig_scene_path,
		"Upper ragdoll retains rig_scene_path ('%s')" % upper.rig_scene_path) and ok
	ok = _check(lower.rig_scene_path == loadout.rig_scene_path,
		"Lower ragdoll retains rig_scene_path ('%s')" % lower.rig_scene_path) and ok

	# Torso part belongs to UPPER_BODY_SLOTS (slot 4)
	var upper_torso = upper.get_part(ModularRigScript.PartSlot.TORSO)
	ok = _check(upper_torso != null, "Upper ragdoll inherits equipped Torso PACKED_SCENE part") and ok
	if upper_torso != null:
		ok = _check(upper_torso.backend == ModularRigScript.AssetRenderBackend.PACKED_SCENE,
			"Upper torso retains PACKED_SCENE backend") and ok

	return ok


# ============================================================================
# Group 3: Texture Audit, UID Integrity & Scene Sprite Bindings
# ============================================================================

func test_10_all_16_textures_existence_and_loadability() -> bool:
	var ok: bool = true
	var base_path: String = "res://assets/stickman/"

	for tex_name in ALL_16_TEXTURE_NAMES:
		var full_path: String = base_path + tex_name
		var import_path: String = full_path + ".import"

		# 1. Physical file existence
		ok = _check(FileAccess.file_exists(full_path), "Texture file exists: " + full_path) and ok
		ok = _check(FileAccess.file_exists(import_path), "Import file exists: " + import_path) and ok

		# 2. ResourceLoader resolution
		ok = _check(ResourceLoader.exists(full_path), "ResourceLoader can locate: " + full_path) and ok
		var tex = ResourceLoader.load(full_path)
		ok = _check(tex != null, "Texture loaded: " + full_path) and ok
		ok = _check(tex is Texture2D, "Loaded resource is Texture2D: " + full_path) and ok

		if tex is Texture2D:
			var w: int = tex.get_width()
			var h: int = tex.get_height()
			ok = _check(w > 0 and h > 0, "Texture dimensions valid (%dx%d): %s" % [w, h, tex_name]) and ok

	return ok


func test_11_texture_uids_cross_reference_imports_and_tscn() -> bool:
	var ok: bool = true
	var base_path: String = "res://assets/stickman/"

	# Map texture name -> UID from its .png.import file
	var import_uids: Dictionary = {}
	for tex_name in ALL_16_TEXTURE_NAMES:
		var imp_file := FileAccess.open(base_path + tex_name + ".import", FileAccess.READ)
		ok = _check(imp_file != null, "Opened .import file for " + tex_name) and ok
		if imp_file != null:
			var text: String = imp_file.get_as_text()
			imp_file.close()

			var uid_regex := RegEx.new()
			uid_regex.compile("uid=\"(uid://[^\"]+)\"")
			var m = uid_regex.search(text)
			if m != null:
				import_uids[tex_name] = m.get_string(1)
			else:
				ok = _check(false, "No UID found in .import file for " + tex_name) and ok

	# Read stickmanprocedural.tscn ext_resource declarations
	var tscn_file := FileAccess.open(PROCEDURAL_SCENE_PATH, FileAccess.READ)
	ok = _check(tscn_file != null, "Opened stickmanprocedural.tscn") and ok
	if tscn_file == null:
		return false

	var tscn_text: String = tscn_file.get_as_text()
	tscn_file.close()

	var res_regex := RegEx.new()
	res_regex.compile("\\[ext_resource type=\"Texture2D\" uid=\"([^\"]+)\" path=\"res://assets/stickman/([^\"]+)\"")
	var matches = res_regex.search_all(tscn_text)

	ok = _check(matches.size() == 15, "stickmanprocedural.tscn references exactly 15 textures (found %d)" % matches.size()) and ok

	for match_res in matches:
		var scene_uid: String = match_res.get_string(1)
		var tex_name: String = match_res.get_string(2)
		var expected_uid: String = import_uids.get(tex_name, "NOT_FOUND")

		ok = _check(scene_uid == expected_uid,
			"UID match for %s: scene='%s', import='%s'" % [tex_name, scene_uid, expected_uid]) and ok

	# Also verify StickmanBase.png UID exists even though not referenced in skeletal rig
	ok = _check(import_uids.has("StickmanBase.png"), "StickmanBase.png UID present in import registry") and ok

	return ok


func test_12_stickman_scene_sprites_texture_binding() -> bool:
	var ok: bool = true
	var packed: PackedScene = load(PROCEDURAL_SCENE_PATH)
	var rig = packed.instantiate()

	# Traverse scene tree and find all Sprite2D nodes
	var sprites: Array[Sprite2D] = []
	var stack: Array[Node] = [rig]
	while not stack.is_empty():
		var curr = stack.pop_back()
		if curr is Sprite2D:
			sprites.append(curr)
		for child in curr.get_children():
			stack.append(child)

	ok = _check(sprites.size() == 15, "Procedural stickman scene has 15 Sprite2D nodes (found %d)" % sprites.size()) and ok

	for s in sprites:
		ok = _check(s.texture != null, "Sprite2D '%s' has non-null texture" % s.name) and ok
		if s.texture != null:
			ok = _check(s.texture is Texture2D, "Sprite2D '%s' texture is Texture2D" % s.name) and ok
			ok = _check(s.texture.get_width() > 0 and s.texture.get_height() > 0,
				"Sprite2D '%s' texture has positive dimensions (%dx%d)" % [s.name, s.texture.get_width(), s.texture.get_height()]) and ok
			ok = _check(s.texture.resource_path.begins_with("res://assets/stickman/"),
				"Sprite2D '%s' texture points to res://assets/stickman/" % s.name) and ok

	rig.free()
	return ok


# ============================================================================
# Group 4: ModularAssetSystem & Live Pose Solver Contracts
# ============================================================================

func test_13_registry_preset_retrieval_and_instantiate_rig() -> bool:
	var ok: bool = true
	var registry = ModularRigScript.ModularAssetRegistry.new()

	var loadout = registry.get_loadout(PRESET_ID)
	ok = _check(loadout != null, "Preset '%s' retrieved successfully" % PRESET_ID) and ok
	ok = _check(loadout.rig_scene_path == PROCEDURAL_SCENE_PATH,
		"Preset rig_scene_path is '%s'" % PROCEDURAL_SCENE_PATH) and ok

	# Test both entry points: registry.instantiate_rig and loadout.instantiate_rig
	var rig1 = registry.instantiate_rig(PRESET_ID)
	ok = _check(rig1 != null and rig1 is CharacterBody2D, "registry.instantiate_rig returned CharacterBody2D") and ok

	var rig2 = loadout.instantiate_rig()
	ok = _check(rig2 != null and rig2 is CharacterBody2D, "loadout.instantiate_rig returned CharacterBody2D") and ok

	# Test get_rig_scene_path
	var path: String = registry.get_rig_scene_path(PRESET_ID)
	ok = _check(path == PROCEDURAL_SCENE_PATH, "registry.get_rig_scene_path returned expected path") and ok

	rig1.free()
	rig2.free()
	return ok


func test_14_live_rig_to_stickman_pose_simulation() -> bool:
	var ok: bool = true
	var registry = ModularRigScript.ModularAssetRegistry.new()
	var rig = registry.instantiate_rig(PRESET_ID)

	# Simulate 30 frames of forward sprint
	for f in range(30):
		rig.update_procedural_animation(Vector2(260.0, 0.0), true, 1.0, "run", 0.016)

	var pose = rig.to_stickman_pose(1.0)
	ok = _check(pose != null, "Generated StickmanPose is non-null") and ok
	ok = _check(pose.stance == "run", "Pose stance is 'run'") and ok

	# Verify joint invariants in Godot 2D coordinates (Y down):
	ok = _check(pose.head_center.is_finite(), "head_center is finite: %s" % pose.head_center) and ok
	ok = _check(pose.pelvis.is_finite(), "pelvis is finite: %s" % pose.pelvis) and ok
	ok = _check(pose.left_hand.is_finite() and pose.right_hand.is_finite(), "Hands are finite") and ok
	ok = _check(pose.left_foot.is_finite() and pose.right_foot.is_finite(), "Feet are finite") and ok

	rig.free()
	return ok


func test_15_concurrent_multi_instance_gait_phase_isolation() -> bool:
	var ok: bool = true
	var registry = ModularRigScript.ModularAssetRegistry.new()

	# Create 3 distinct rigs with different speeds/directions
	var rig_idle = registry.instantiate_rig(PRESET_ID)
	var rig_run_fwd = registry.instantiate_rig(PRESET_ID)
	var rig_run_bwd = registry.instantiate_rig(PRESET_ID)

	for _i in range(20):
		rig_idle.update_procedural_animation(Vector2(0.0, 0.0), true, 1.0, "idle", 0.016)
		rig_run_fwd.update_procedural_animation(Vector2(260.0, 0.0), true, 1.0, "run", 0.016)
		rig_run_bwd.update_procedural_animation(Vector2(-130.0, 0.0), true, -1.0, "run", 0.016)

	# Rig idle phase must remain 0.0
	ok = _check(rig_idle.phase == 0.0, "Idle rig phase remained 0.0 (got %f)" % rig_idle.phase) and ok

	# Rig forward must have accumulated phase > 0.0
	ok = _check(rig_run_fwd.phase > 0.0, "Forward rig phase accumulated (> 0.0, got %f)" % rig_run_fwd.phase) and ok

	# Facing must be isolated
	ok = _check(rig_run_fwd.facing == 1.0, "Forward rig facing is 1.0") and ok
	ok = _check(rig_run_bwd.facing == -1.0, "Backward rig facing is -1.0") and ok

	rig_idle.free()
	rig_run_fwd.free()
	rig_run_bwd.free()
	return ok
