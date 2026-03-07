@tool
extends TestBase

const binary_schema:String = "res://tests/fb_reflection/Reflection.bfbs"
const schema_file:String = "res://tests/fb_reflection/Reflection.fbs"
const generated_file:String = "res://tests/fb_reflection/Reflection_generated.gd"

func _run_test() -> int:
	logp("[b]== Generate GDScript ==[/b]")
	var run_report:Dictionary = FlatBuffersPlugin.generate(schema_file)
	var run_output:String = run_report.output
	TEST_EQ(0, run_report.retcode, run_output)

	var script:GDScript = load(generated_file)
	#var schema:Object = script.new()
	
	var filename : String = "res://tests/fb_reflection/Reflection.bfbs"

	var bfbs : PackedByteArray = FileAccess.get_file_as_bytes( filename )
	if bfbs.is_empty():
		output.append("Unable to open file: " + filename)
		output.append( error_string( FileAccess.get_open_error() ) )
		return RetCode.TEST_FAILED

	var root_table:FlatBuffer = script.call('get_root', bfbs )
	if not root_table:
		output.append( "Failure to decode bfbs using Reflection.fbs")
		return RetCode.TEST_FAILED

	return runcode
