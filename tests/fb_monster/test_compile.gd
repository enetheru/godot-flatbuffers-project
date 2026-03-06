@tool
extends TestBase

var schema_file:String = "res://tests/fb_monster/Monster.fbs"

func _run_test() -> int:
	logd("== Compiling Monster Schema ==")
	var run_dict:Dictionary = FlatBuffersPlugin.generate(schema_file)
	#{
		#'flatc_path':"C:/.../flatc.exe",
		#'args':["--gdscript", ...],
		#'schema': "schema_path.fbs",
		#'retcode': 0 # (int)
		#'output': [""] # stdout + stderr
	#}
	logd("flatc: " + run_dict.flatc_path)
	var args:PackedStringArray = run_dict.args
	logd("Args: " +' '.join(args))
	logd("schema: " + run_dict.schema)
	logd("retcode: %d" % run_dict.retcode)
	var flatc_output:PackedStringArray = run_dict.output
	logd("output: " +' '.join(flatc_output))
	TEST_EQ(0, run_dict.retcode, "Failed to generate GDScript from FlatBuffers schema")
	
	return runcode
