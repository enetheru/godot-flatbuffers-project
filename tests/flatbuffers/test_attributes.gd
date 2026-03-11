@tool
extends "scripts/fb_generic_test.gd"


## │   _  _   _       _ _         _             [br]
## │  /_\| |_| |_ _ _(_) |__ _  _| |_ ___ ___   [br]
## │ / _ \  _|  _| '_| | '_ \ || |  _/ -_|_-<   [br]
## │/_/ \_\__|\__|_| |_|_.__/\_,_|\__\___/__/   [br]
## ╰─────────────────────────────────────────── [br]
## Attributes By-Line
##
## Attributes Description

const schema_file:String = "res://tests/flatbuffers/schemas/attribute.fbs"
const generated_file:String = "res://tests/flatbuffers/schemas/attribute_generated.gd"
const strategy_file:String = "res://tests/flatbuffers/scripts/attribute_strategy.gd"

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

	# Wait for scan to complete or receive errors when we reimport.
	if efs.is_scanning(): await efs.filesystem_changed

	# re-import script files. This outputs an error, but still works.
	# INTERNAL ERROR: BUG: File queued for import, but can't be imported,
	#     importer for type '' not found.
	efs.reimport_files([generated_file, strategy_file])


	## Because we cannot pre-load a script that hasnt been generated yet, it
	## means that we have no access to types. But I can load and run a script
	## that does pre-load the generated script, because when it is loaded it will
	## pull in the pre-load but that's after the generated script is created.
	## It's a bit convoluted yes.
	var StrategyScript:GDScript = load(strategy_file)
	var tso:TestStrategy = StrategyScript.new(self)
	if not TEST_TRUE_RET(is_instance_valid(tso), "StrategyScript.new(self)"):
		return runcode

	# Iterate Over the combinations of strategies for each phase.
	var counter:int = 0
	for combo:Array[int] in tso:
		counter += 1
		tso.flow(combo)
	TEST_EQ(tso.get_max_combos(), counter,
		"The expected number of combinations and the counter should match")

	return runcode
