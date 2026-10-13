@tool
extends FlatBufferTestBase
## Required fields.
##
## A string and a table field marked (required). Finishing a table without
## one of them fails, and verify() fails when that field is absent.

const schema_file:String = "res://tests/flatbuffers/schemas/required.fbs"
const generated_file:String = "res://tests/flatbuffers/schemas/required_generated.gd"
const strategy_file:String = "res://tests/flatbuffers/scripts/required_strategy.gd"


func _run_test() -> int:
	var efs:EditorFileSystem = EditorInterface.get_resource_filesystem()

	logd("== Compiling Schema ==")
	await compile_schema(schema_file)
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Schema Compilation"):
		return runcode

	logd("== Loading Generated GDScript ==")
	load_generated_script(generated_file)
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Load Generated Script"):
		return runcode

	if efs.is_scanning(): await efs.filesystem_changed

	efs.reimport_files([generated_file, strategy_file])

	var StrategyScript:GDScript = load(strategy_file)
	var tso:TestStrategy = StrategyScript.new(self)
	if not TEST_TRUE_RET(is_instance_valid(tso), "StrategyScript.new(self)"):
		return runcode

	tso.flow([])

	return runcode
