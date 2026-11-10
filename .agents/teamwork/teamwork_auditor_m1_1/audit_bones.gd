extends SceneTree

const RigSystem = preload("res://scripts/modular_rig/modular_asset_system.gd")

func _init() -> void:
	print("=== AUDITOR EMPIRICAL INSPECTION OF STICKMAN BONE POSITIONS ===")
	var registry := RigSystem.ModularAssetRegistry.new()
	var rig_node: Node = registry.instantiate_rig("player_procedural_stickman")
	if rig_node == null:
		printerr("FAIL: rig_node is null")
		quit(1)
		return

	root.add_child(rig_node)

	# Initial call
	var bones: Dictionary = rig_node.call("get_bone_positions")
	print("Total bones returned: %d" % bones.size())
	for k in bones.keys():
		print("  %s: %s" % [k, str(bones[k])])

	# Update animation and check again
	rig_node.call("update_procedural_animation", Vector2(250.0, 0.0), true, 1.0, "run", 0.1)
	var bones_run: Dictionary = rig_node.call("get_bone_positions")
	print("\nBones after run gait update:")
	for k in ["pelvis", "head", "left_foot", "right_foot"]:
		print("  %s: %s" % [k, str(bones_run.get(k, "MISSING"))])

	# Check geometry invariants:
	# In 2D screen coordinates, Y points DOWN. So head.y < neck.y < pelvis.y
	var head_pos: Vector2 = bones.get("head", Vector2.ZERO)
	var neck_pos: Vector2 = bones.get("neck", Vector2.ZERO)
	var pelvis_pos: Vector2 = bones.get("pelvis", Vector2.ZERO)

	print("\nVertical ordering in 2D space (Y-down):")
	print("  head.y = %f" % head_pos.y)
	print("  neck.y = %f" % neck_pos.y)
	print("  pelvis.y = %f" % pelvis_pos.y)

	var valid_vertical: bool = (head_pos.y < neck_pos.y) and (neck_pos.y < pelvis_pos.y)
	print("  Valid skeletal vertical hierarchy (head < neck < pelvis): %s" % str(valid_vertical))

	root.remove_child(rig_node)
	rig_node.free()

	if not valid_vertical:
		printerr("FAIL: Skeletal vertical hierarchy inverted!")
		quit(1)
	else:
		print("SUCCESS: Bones are geometrically authentic.")
		quit(0)
