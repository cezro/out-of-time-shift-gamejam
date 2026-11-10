extends SceneTree

## Empirical In-Engine Stress Test Harness for scenes/main.tscn
## Tests rapid reload loops (30 cycles), monitors memory static, object count,
## node count, and verifies that no orphan nodes or memory leaks occur.

const CYCLES: int = 50
const FRAMES_PER_CYCLE: int = 5
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"

func _init() -> void:
	print("=== RUNNING IN-ENGINE RAPID SCENE RELOAD STRESS HARNESS ===")
	print("Scene: %s | Total Cycles: %d | Frames/cycle: %d" % [MAIN_SCENE_PATH, CYCLES, FRAMES_PER_CYCLE])

	var packed: PackedScene = load(MAIN_SCENE_PATH)
	if packed == null:
		printerr("FATAL: Failed to load %s" % MAIN_SCENE_PATH)
		quit(1)
		return

	# Warm-up cycle to allow Godot to load and cache static scene resources (textures, audio streams)
	var warmup: Node = packed.instantiate()
	root.add_child(warmup)
	for f in range(FRAMES_PER_CYCLE):
		if warmup.has_method("step_simulation"):
			warmup.call("step_simulation", 0.016)
	root.remove_child(warmup)
	warmup.free()

	var mem_initial: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var obj_initial: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphan_initial: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	print("Initial baseline: MemoryStatic=%d bytes, Objects=%d, Orphans=%d" % [int(mem_initial), int(obj_initial), int(orphan_initial)])

	for cycle in range(CYCLES):
		var instance: Node = packed.instantiate()
		if instance == null:
			printerr("Cycle %d: Failed to instantiate scene!" % cycle)
			quit(1)
			return

		root.add_child(instance)

		# Step simulation frames
		for f in range(FRAMES_PER_CYCLE):
			if instance.has_method("step_simulation"):
				instance.call("step_simulation", 0.016)

		# Synchronous teardown: remove and immediately free
		root.remove_child(instance)
		instance.free()

		var cur_mem: float = Performance.get_monitor(Performance.MEMORY_STATIC)
		var cur_obj: float = Performance.get_monitor(Performance.OBJECT_COUNT)
		var cur_orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

		if cur_orphans > orphan_initial:
			printerr("Cycle %d: Orphan nodes leaked! Current=%d, Baseline=%d" % [cycle, int(cur_orphans), int(orphan_initial)])
			quit(1)
			return

		if (cycle + 1) % 10 == 0:
			print("  Completed cycle %d/%d: Memory=%d bytes, Objects=%d, Orphans=%d" % [cycle + 1, CYCLES, int(cur_mem), int(cur_obj), int(cur_orphans)])

	var mem_final: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var obj_final: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphan_final: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	var mem_delta: float = mem_final - mem_initial
	var obj_delta: float = obj_final - obj_initial

	print("\n=== IN-ENGINE STRESS TEST SUMMARY ===")
	print("Final: MemoryStatic=%d (delta: %+d bytes)" % [int(mem_final), int(mem_delta)])
	print("Final: Objects=%d (delta: %+d)" % [int(obj_final), int(obj_delta)])
	print("Final: Orphan Nodes=%d (delta: %+d)" % [int(orphan_final), int(orphan_final - orphan_initial)])

	if orphan_final > orphan_initial:
		printerr("FAIL: Leaked %d orphan nodes during rapid scene reload!" % int(orphan_final - orphan_initial))
		quit(1)
		return

	# Memory static check: delta should not exceed 512KB after 30 instantiations
	if mem_delta > 512.0 * 1024.0:
		printerr("FAIL: Excessive memory growth delta: %d bytes!" % int(mem_delta))
		quit(1)
		return

	print("PASS: In-Engine Rapid Scene Reload Stress Test passed with 0 orphan nodes and bounded memory!")
	quit(0)
