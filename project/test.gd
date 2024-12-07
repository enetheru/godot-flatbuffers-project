class_name CustomMainLoop
extends MainLoop

func _initialize():
	print("_initialize()")
	print( "LoadedExtensions: ", GDExtensionManager.get_loaded_extensions() )

func _process(delta: float) -> bool:
	print("_process()")
	return true

func _finalize():
	print("_finalize()")
