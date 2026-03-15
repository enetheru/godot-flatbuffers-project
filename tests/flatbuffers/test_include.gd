@tool
extends FlatBufferTestBase
## │ ___         _         _        [br]
## │|_ _|_ _  __| |_  _ __| |___    [br]
## │ | || ' \/ _| | || / _` / -_)   [br]
## │|___|_||_\__|_|\_,_\__,_\___|   [br]
## ╰─────────────────────────────── [br]
## Testing the 'include' functionality
##
## Considerations: path separators, absolute, and relative paths, project paths[br]
## Test Phases:[br]
## - Schema Parsing[br]
##   - I'm not sure how I can make this happen, perhaps I can [br]
## - Code Generation[br]
## - Encoding[br]
## - Verification[br]
## - Decoding[br]
## - Using[br]

# - [ ] Testing of includes would also involve testing all features from an included file
# - [ ] multiple layers of include
# - Absolute Paths
#     - [ ] `{c} "/path"`
#     - [ ] `{c} "C:/path"`
# - Relative Paths
#     - [ ] `{c} "./relative/path"`
#     - [ ] `{c} "relative/path"`
# - Godot Paths
#     - [ ] `{c} "res://path"`
#     - [ ] `{c} "user://path"`
# - Special Cases
#     - [ ] `{c} "godot.fbs"`
# - [ ] Path separators `"/"` or `"\"`

const GEN_OPTS = preload("uid://ck8of5cb3qlar")

const strategy_file:String = "res://tests/flatbuffers/scripts/include_strategy.gd"

const schema_files:Array[String] = [
	"res://tests/flatbuffers/schemas/include.fbs",
	"res://tests/flatbuffers/schemas/minimum.fbs"
]

const generated_files:Array[String] = [
	"res://tests/flatbuffers/schemas/include_generated.gd",
	"res://tests/flatbuffers/schemas/minimum_generated.gd",
]

func _run_test() -> int:
	var efs:EditorFileSystem = EditorInterface.get_resource_filesystem()

	logd("== Compiling Schemas ==")
	for schema_file:String in schema_files:
		await compile_schema(schema_file, GEN_OPTS)
		if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Schema Compilation must succeed"):
			return runcode

	logd("== Loading Generated GDScripts ==")
	for generated_file:String in generated_files:
		load_generated_script(generated_file)
		if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Load Generated Scripts must succeed"):
			return runcode

	# Wait for scan to complete or receive errors when we reimport.
	if efs.is_scanning(): await efs.filesystem_changed

	# re-import script files.
	# NOTE: This outputs the following error, but still works.
	# INTERNAL ERROR: BUG: File queued for import, but can't be imported,
	#     importer for type '' not found.
	efs.reimport_files( generated_files + [strategy_file])


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
	for combo:Array in tso:
		counter += 1
		tso.flow(combo)
	TEST_EQ(tso.get_max_combos(), counter,
		"The expected number of combinations and the counter should match")

	return runcode
