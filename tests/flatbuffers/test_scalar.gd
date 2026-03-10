@tool
extends TestBase

## │ ___          _            ___ _     _    _       [br]
## │/ __| __ __ _| |__ _ _ _  | __(_)___| |__| |___   [br]
## │\__ \/ _/ _` | / _` | '_| | _|| / -_) / _` (_-<   [br]
## │|___/\__\__,_|_\__,_|_|   |_| |_\___|_\__,_/__/   [br]
## ╰───────────────────────────────────────────────── [br]
## Scalar Fields By-Line
##
## Scalar Fields Description

const Strategy = preload("uid://4kv4xyusnsge")

const schema_file:String = "res://tests/flatbuffers/schemas/scalar.fbs"
const generated_file:String = "res://tests/flatbuffers/schemas/scalar_generated.gd"
const test_script:String = "res://tests/flatbuffers/scalar_test_script.gd"

func compile_schema() -> void:
	var run_dict:Dictionary = await FlatBuffersPlugin.generate(schema_file)
	var stdout:String = run_dict.stdout
	TEST_EQ(0, run_dict.retcode, stdout)


func load_generated_script() -> void:
	if TEST_TRUE_RET(FileAccess.file_exists(generated_file),
			"does generated file exist: '%s'" % generated_file ):
		var schema:GDScript = load(generated_file)
		TEST_TRUE(is_instance_valid(schema), "Loading generated script")


func _run_test() -> int:
	var efs:EditorFileSystem = EditorInterface.get_resource_filesystem()

	logd("== Compiling Schema ==")
	await compile_schema()
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Schema Compilation"):
		return runcode

	logd("== Loading Generated GDScript ==")
	load_generated_script()
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Load Generated Script"):
		return runcode

	# Wait for scan to complete or receive errors when we reimport.
	if efs.is_scanning(): await efs.filesystem_changed

	# re-import script files.
	# NOTE: This outputs the following error, but still works.
	# INTERNAL ERROR: BUG: File queued for import, but can't be imported,
	#     importer for type '' not found.
	efs.reimport_files([generated_file, test_script])


	## Because we cannot pre-load a script that hasnt been generated yet, it
	## means that we have no access to types. But I can load and run a script
	## that does pre-load the generated script, because when it is loaded it will
	## pull in the pre-load but that's after the generated script is created.
	## It's a bit convoluted yes.
	var TestScript:GDScript = load(test_script)
	var tso:Strategy = TestScript.new(self)
	TEST_TRUE(is_instance_valid(tso), "TestScript.new(self)")

	var selection:Array[int]
	# fill selection with the strategy sizes.
	TEST_EQ(selection.resize(tso.get_phase_count()), OK, "Resize Failed")
	var pc:int = tso.get_phase_count()
	for p:int in pc:
		for sc:int in tso.get_strategy_count(p):
			selection[p] = sc

	# count down the selection items till they all reach zero.
	while selection.any(func(i:int)->bool: return i > 0):
		tso.flow( selection )
		var break_on_next:bool = false
		for p in pc:
			var sc:int = tso.get_strategy_count(p) -1
			if sc == 0: continue # skip phases with only one strategy.
			var cs:int = selection[p] # Current Strategy.
			if cs == 0:
				selection[p] = sc # reset the strategy to default.
				break_on_next = true
				continue
			selection[p] = cs - 1 # decrement the strategy index
			if break_on_next: break

	# Final flow for all zeroes.
	tso.flow( selection )

	return runcode
