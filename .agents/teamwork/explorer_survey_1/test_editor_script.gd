@tool
extends EditorScript

func _run():
	print("Hello from EditorScript!")
	var editor_interface = get_editor_interface()
	print("EditorInterface: ", editor_interface)
