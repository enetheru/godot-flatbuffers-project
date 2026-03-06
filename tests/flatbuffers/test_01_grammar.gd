@tool
extends TestBase

## │  ___                                  [br]
## │ / __|_ _ __ _ _ __  _ __  __ _ _ _    [br]
## │| (_ | '_/ _` | '  \| '  \/ _` | '_|   [br]
## │ \___|_| \__,_|_|_|_|_|_|_\__,_|_|     [br]
## ╰────────────────────────────────────── [br]
## Use a Schema file that contains all the grammar that is supported
##
## This test is to verify valid GDScript output for a comprehensive use of the
## FlatBuffers schema grammar

const schema_file = "res://tests/flatbuffers/schemas/grammar.fbs"
const generated_file = "res://tests/flatbuffers/schemas/grammar_generated.gd"

func _run_test() -> int:
	
	if generate_gdscript():
		logp("Failed to generate GDScript from FlatBuffers schema")
		return runcode
	
	var script:GDScript = load( generated_file )
	if TEST_TRUE_RET( (script is GDScript), "Load script file" ) == RetCode.TEST_OK:
		var object:Object = script.new()
		TEST_TRUE( is_instance_valid(object), "instantiate object")
	
	return runcode


func generate_gdscript() -> bool:
	var run_dict:Dictionary = FlatBuffersPlugin.generate(schema_file)
	if TEST_EQ_RET(0, run_dict.retcode, str(run_dict.output)) == RetCode.TEST_FAILED:
		var gen_output:PackedStringArray = run_dict.output
		logp("[color=salmon]" + '\n'.join(gen_output) + "[/color]")
		return RetCode.TEST_FAILED
	return RetCode.TEST_OK
