extends SceneTree

func _init() -> void:
	print("--- Scanning all scripts via ResourceLoader with CACHE_MODE_IGNORE ---")
	var scripts = [
		"res://scripts/chrono_shift/chrono_shift_model.gd",
		"res://scripts/core/combat_math.gd",
		"res://scripts/core/enemy_ai.gd",
		"res://scripts/core/player_kinematics.gd",
		"res://scripts/core/ragdoll_physics.gd",
		"res://scripts/core/time_control.gd",
		"res://scripts/game/audio_manager.gd",
		"res://scripts/game/game_controller.gd",
		"res://scripts/modular_rig/modular_asset_system.gd",
		"res://scripts/timeline/timeline_system.gd",
		"res://scripts/tools/asset_mcp_bridge.gd",
		"res://tests/test_adversarial_disprover.gd",
		"res://tests/test_chrono_and_timeline.gd",
		"res://tests/test_core.gd",
		"res://tests/test_game_integration.gd",
		"res://tests/test_modular_rig.gd",
	]
	for s_path in scripts:
		var scr = ResourceLoader.load(s_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if scr == null:
			printerr("FAILED TO LOAD: ", s_path)
	print("--- Scan complete ---")
	quit(0)
