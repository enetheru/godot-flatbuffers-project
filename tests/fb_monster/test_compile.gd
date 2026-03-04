@tool
extends TestBase

var schema:String = "res://tests/fb_monster/Monster.fbs"

func _run_test() -> int:
	logd("== Compiling Monster Schema ==")

	# Compile Schema
	var report:Dictionary = FlatBuffersPlugin.generate(schema)
	var stdout:PackedStringArray = report.output
	return TEST_EQ(report.retcode, 0, '\n'.join(stdout))
