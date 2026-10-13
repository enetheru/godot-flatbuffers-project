@tool
extends FlatBufferTestBase
## Bit flags.
##
## An unsigned enum marked (bit_flags) stores 1 << index.
## Implicit values count from 0. An explicit index resumes at the next bit.
## A combined mask round-trips through the field.


const schema_file:String = "res://tests/flatbuffers/schemas/bit_flags.fbs"
const generated_file:String = "res://tests/flatbuffers/schemas/bit_flags_generated.gd"
const strategy_file:String = "res://tests/flatbuffers/scripts/bit_flags_strategy.gd"


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
