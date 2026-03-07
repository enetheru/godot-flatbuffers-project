@tool
extends TestBase

var schema_file:String = "res://tests/fb_monster/Monster.fbs"

func _run_test() -> int:
	logd("== Compiling Monster Schema ==")
	var run_dict:Dictionary = FlatBuffersPlugin.generate(schema_file)
	TEST_EQ(0, run_dict.retcode, run_dict.output)
	return runcode
