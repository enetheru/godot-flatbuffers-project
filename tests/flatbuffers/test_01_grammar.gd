@tool
extends FlatBufferTestBase
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
	logd("== Compiling Schema ==")
	await compile_schema(schema_file)
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Schema Compilation"):
		return runcode

	logd("== Loading Generated GDScript ==")
	load_generated_script(generated_file)
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Load Generated Script"):
		return runcode

	return runcode
