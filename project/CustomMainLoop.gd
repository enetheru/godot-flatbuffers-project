class_name CustomMainLoop
extends MainLoop

func _initialize():
	print("_initialize()")
	print( "LoadedExtensions: ", GDExtensionManager.get_loaded_extensions() )

func _process(_delta: float) -> bool:
	print("_process()")
	# Return true to end the main loop.
	return Input.get_mouse_button_mask() != 0 || Input.is_key_pressed(KEY_ESCAPE)

func _finalize():
	print("_finalize()")
