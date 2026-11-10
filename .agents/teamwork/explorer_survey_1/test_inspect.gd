extends SceneTree

func _init():
	var s: GDScript = load("res://scripts/core/player_kinematics.gd")
	print("has_script_signal: ", s.get_script_signal_list())
	print("method_list count: ", s.get_script_method_list().size())
	print("property_list count: ", s.get_script_property_list().size())
	quit(0)
