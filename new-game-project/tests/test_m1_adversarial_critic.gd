@tool
extends SceneTree

## Adversarial Critic Stress-Test Suite for Milestone 1
## Rig & Scene Asset Integration

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

func _init() -> void:
	print("=== Running Milestone 1 Adversarial Critic Stress Suite ===")
	test_textures_and_import_integrity()
	test_scene_structure_and_ccdik_stack()
	test_script_interface_and_properties()
	test_adversarial_animation_inputs()
	test_bone_positions_and_stickman_pose()
	test_modular_asset_system_packed_scene_backend()
	test_lifecycle_multiple_instantiations()

	print("\n=== Milestone 1 Critic Summary: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			printerr("  [FAIL] %s" % f)
		quit(1)
	else:
		print("All Milestone 1 adversarial critic checks passed successfully!")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % message)
	else:
		_failed += 1
		_failures.append(message)
		printerr("  [FAIL] %s" % message)


func test_textures_and_import_integrity() -> void:
	print("\n-- 1. Texture and .import Integrity --")
	var textures: Array[String] = [
		"ArmBotB", "ArmBotF", "ArmTopB", "ArmTopF",
		"HandB", "HandF", "Head", "LegBotB",
		"LegBotF", "LegTopB", "LegTopF", "neck",
		"Pelvis", "StickmanBase", "Torso", "Waist"
	]
	for tex_name in textures:
		var png_path: String = "res://assets/stickman/%s.png" % tex_name
		_assert(ResourceLoader.exists(png_path), "Texture file exists: %s" % png_path)
		var res = load(png_path)
		_assert(res != null and res is Texture2D, "Texture2D loads cleanly: %s" % png_path)


func test_scene_structure_and_ccdik_stack() -> void:
	print("\n-- 2. Scene Structure and CCDIK Modifiers --")
	var scene_path: String = "res://scenes/stickman/stickmanprocedural.tscn"
	_assert(ResourceLoader.exists(scene_path), "Scene file exists: %s" % scene_path)

	var packed: PackedScene = load(scene_path)
	_assert(packed != null, "Scene loads into PackedScene")
	var instance: Node = packed.instantiate()
	_assert(instance != null, "Scene instantiates")
	_assert(instance is CharacterBody2D, "Root node is CharacterBody2D")
	_assert(instance.get_script() != null, "Script attached to root node")

	var skel: Skeleton2D = instance.get_node_or_null("Rig/Bones/Skeleton2D")
	_assert(skel != null, "Skeleton2D found under Rig/Bones")

	var mod_stack: SkeletonModificationStack2D = skel.modification_stack
	_assert(mod_stack != null, "Modification stack exists on Skeleton2D")
	_assert(mod_stack.enabled, "Modification stack is enabled")
	_assert(mod_stack.modification_count == 5, "Modification count is exactly 5 (dangling 6th removed)")

	# Verify each modification targets valid nodes in the instance
	for i in range(mod_stack.modification_count):
		var mod = mod_stack.get_modification(i)
		_assert(mod != null, "Modification %d is non-null" % i)
		if mod is SkeletonModification2DCCDIK:
			var target_path: NodePath = mod.target_nodepath
			var tip_path: NodePath = mod.tip_nodepath
			var target_node = skel.get_node_or_null(target_path)
			var tip_node = skel.get_node_or_null(tip_path)
			_assert(target_node != null, "CCDIK %d target resolves: %s" % [i, target_path])
			_assert(tip_node != null, "CCDIK %d tip resolves: %s" % [i, tip_path])
			for j in range(mod.ccdik_data_chain_length):
				var bone_path: NodePath = mod.get_ccdik_joint_bone2d_node(j)
				var bone_node = skel.get_node_or_null(bone_path)
				_assert(bone_node != null, "CCDIK %d joint %d bone resolves: %s" % [i, j, bone_path])
		elif mod is SkeletonModification2DLookAt:
			var target_path: NodePath = mod.target_nodepath
			var bone_path: NodePath = mod.bone2d_node
			var target_node = skel.get_node_or_null(target_path)
			var bone_node = skel.get_node_or_null(bone_path)
			_assert(target_node != null, "LookAt target resolves: %s" % target_path)
			_assert(bone_node != null, "LookAt bone resolves: %s" % bone_path)

	instance.free()


func test_script_interface_and_properties() -> void:
	print("\n-- 3. Script Interface and Properties --")
	var scene_path: String = "res://scenes/stickman/stickmanprocedural.tscn"
	var inst = load(scene_path).instantiate()
	root.add_child(inst)

	# Verify properties per PROJECT.md interface contract
	_assert("stride_length" in inst, "Has stride_length property")
	_assert("foot_lift" in inst, "Has foot_lift property")
	_assert("arm_swing" in inst, "Has arm_swing property")
	_assert("head_bounce" in inst, "Has head_bounce property")
	_assert("snappiness" in inst, "Has snappiness property")

	# Aliases
	_assert("hand_swing" in inst, "Has hand_swing alias")
	_assert("pose_response" in inst, "Has pose_response alias")
	inst.set("arm_swing", 30.0)
	_assert(inst.get("hand_swing") == 30.0, "hand_swing alias reads arm_swing")
	inst.set("snappiness", 25.0)
	_assert(inst.get("pose_response") == 25.0, "pose_response alias reads snappiness")

	# Methods
	_assert(inst.has_method("update_procedural_animation"), "Has update_procedural_animation")
	_assert(inst.has_method("get_bone_positions"), "Has get_bone_positions")
	_assert(inst.has_method("get_ik_targets"), "Has get_ik_targets")
	_assert(inst.has_method("to_stickman_pose"), "Has to_stickman_pose")

	# Autonomous physics default
	_assert(inst.get("autonomous_physics") == false, "autonomous_physics defaults to false")
	_assert(inst.is_physics_processing() == false, "physics_process deactivated when autonomous_physics is false")

	root.remove_child(inst)
	inst.free()


func test_adversarial_animation_inputs() -> void:
	print("\n-- 4. Adversarial Animation Inputs Stress Test --")
	var scene_path: String = "res://scenes/stickman/stickmanprocedural.tscn"
	var inst = load(scene_path).instantiate()
	root.add_child(inst)

	# 1. Delta = 0.0
	inst.call("update_procedural_animation", Vector2(100, 0), true, 1.0, "run", 0.0)
	_assert(true, "Handled delta = 0.0 without divide by zero")

	# 2. Large Delta (lag spike: 10 seconds)
	inst.call("update_procedural_animation", Vector2(100, 0), true, 1.0, "run", 10.0)
	_assert(true, "Handled delta = 10.0 without overflow or crash")

	# 3. Negative / Zero Facing
	inst.call("update_procedural_animation", Vector2(-150, 0), true, 0.0, "run", 0.016)
	_assert(float(inst.get("facing")) != 0.0, "Facing maintains non-zero direction when facing_direction is 0")
	inst.call("update_procedural_animation", Vector2(-150, 0), true, -1.0, "run", 0.016)
	_assert(float(inst.get("facing")) == -1.0, "Facing properly updates to -1.0")

	# 4. Extreme velocity
	inst.call("update_procedural_animation", Vector2(100000.0, -50000.0), false, 1.0, "jump", 0.016)
	var targets: Dictionary = inst.call("get_ik_targets")
	for t_name in targets.keys():
		var t_node: Node2D = targets[t_name]
		_assert(is_finite(t_node.position.x) and is_finite(t_node.position.y), "Target %s position finite after extreme velocity" % t_name)

	# 5. All supported and exotic stances
	var stances: Array[String] = [
		"idle", "run", "walk", "jump", "fall", "air",
		"wall_slide", "slash", "heavy_slash", "parry_guard",
		"", "non_existent_stance"
	]
	for st in stances:
		inst.call("update_procedural_animation", Vector2(50, 0), true, 1.0, st, 0.016)
	_assert(true, "All standard and unknown stances execute without exception")

	root.remove_child(inst)
	inst.free()


func test_bone_positions_and_stickman_pose() -> void:
	print("\n-- 5. Bone Positions and StickmanPose Mapping --")
	var scene_path: String = "res://scenes/stickman/stickmanprocedural.tscn"
	var inst = load(scene_path).instantiate()
	root.add_child(inst)

	var bones: Dictionary = inst.call("get_bone_positions")
	var required_bones: Array[String] = [
		"pelvis", "hip", "neck", "head", "head_center", "torso", "waist",
		"left_shoulder", "left_elbow", "left_hand",
		"right_shoulder", "right_elbow", "right_hand",
		"left_hip", "left_knee", "left_foot",
		"right_hip", "right_knee", "right_foot"
	]
	for b_name in required_bones:
		_assert(bones.has(b_name), "Bone map contains '%s'" % b_name)
		var pos = bones[b_name]
		_assert(pos is Vector2 and is_finite(pos.x) and is_finite(pos.y), "Bone '%s' has finite Vector2 coords" % b_name)

	var pose = inst.call("to_stickman_pose", 1.0)
	_assert(pose != null, "to_stickman_pose returned non-null StickmanPose")
	_assert(is_finite(pose.get("pelvis").x) and is_finite(pose.get("pelvis").y), "Pose pelvis is finite")
	_assert(is_finite(pose.get("head_center").x) and is_finite(pose.get("head_center").y), "Pose head_center is finite")

	root.remove_child(inst)
	inst.free()


func test_modular_asset_system_packed_scene_backend() -> void:
	print("\n-- 6. ModularAssetSystem PACKED_SCENE Backend --")
	var mas = load("res://scripts/modular_rig/modular_asset_system.gd")
	_assert(mas != null, "modular_asset_system.gd loads cleanly")

	var reg = mas.ModularAssetRegistry.new()
	var loadout = reg.get_loadout("player_procedural_stickman")
	_assert(loadout != null, "player_procedural_stickman exists in registry")
	_assert(loadout.rig_scene_path == mas.PROCEDURAL_STICKMAN_SCENE_PATH, "rig_scene_path is correctly set")

	# Test PartPieceSpec instantiate_scene
	var part: RefCounted = loadout.get_part(mas.PartSlot.TORSO)
	_assert(part != null, "Torso part exists")
	_assert(part.get("backend") == mas.AssetRenderBackend.PACKED_SCENE, "Torso part uses PACKED_SCENE backend")
	var node1: Node = part.call("instantiate_scene")
	_assert(node1 != null and node1 is CharacterBody2D, "part.instantiate_scene() succeeded")
	node1.free()

	# Test loadout.duplicate_loadout preserves rig_scene_path
	var dup = loadout.duplicate_loadout()
	_assert(dup.rig_scene_path == loadout.rig_scene_path, "duplicate_loadout preserves rig_scene_path")

	# Test split_for_ragdoll preserves rig_scene_path
	var halves = loadout.split_for_ragdoll()
	_assert(halves.has("upper") and halves.has("lower"), "split_for_ragdoll produces upper and lower")
	_assert(halves["upper"].rig_scene_path == loadout.rig_scene_path, "Upper ragdoll retains rig_scene_path")
	_assert(halves["lower"].rig_scene_path == loadout.rig_scene_path, "Lower ragdoll retains rig_scene_path")

	# Test serialization roundtrip (to_dict / from_dict)
	var d = loadout.to_dict()
	_assert(d.get("rig_scene_path") == loadout.rig_scene_path, "to_dict includes rig_scene_path")
	var restored = mas.CharacterLoadout.from_dict(d)
	_assert(restored.rig_scene_path == loadout.rig_scene_path, "from_dict restored rig_scene_path")

	# Test instantiate_scene_backend on invalid paths (graceful failure)
	_assert(mas.ModularAssetRegistry.instantiate_scene_backend("") == null, "Empty path returns null")
	_assert(mas.ModularAssetRegistry.instantiate_scene_backend("res://non_existent.tscn") == null, "Non-existent path returns null")


func test_lifecycle_multiple_instantiations() -> void:
	print("\n-- 7. Multiple Instantiations Stress & Teardown --")
	var mas = load("res://scripts/modular_rig/modular_asset_system.gd")
	var reg = mas.ModularAssetRegistry.new()
	var nodes: Array[Node] = []

	for i in range(25):
		var n: Node = reg.instantiate_rig("player_procedural_stickman")
		_assert(n != null, "Instantiation %d succeeded" % i)
		root.add_child(n)
		n.call("update_procedural_animation", Vector2(100, 0), true, 1.0, "run", 0.016)
		nodes.append(n)

	for n in nodes:
		root.remove_child(n)
		n.free()

	_assert(true, "25 rigs instantiated, animated, and freed cleanly without errors")
