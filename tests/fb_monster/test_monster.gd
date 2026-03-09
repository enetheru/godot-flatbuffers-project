@tool
extends TestBase

## │ __  __             _              [br]
## │|  \/  |___ _ _  __| |_ ___ _ _    [br]
## │| |\/| / _ \ ' \(_-<  _/ -_) '_|   [br]
## │|_|  |_\___/_||_/__/\__\___|_|     [br]
## ╰────────────────────────────────── [br]
## The Canonical Monster Example
##
## Perform all the functions of the standard monster example
## as described in the documentation[br]
## [br]
## Testing Phases:[br]
## - Schema parsing - Not relevant right now [br]
## - Code generation[br]
## - Encoding[br]
## - Verification[br]
## - Decoding[br]
## - Using[br]

var schema_file:String = "res://tests/fb_monster/Monster.fbs"
var generated_file:String = "res://tests/fb_monster/Monster_generated.gd"
var test_script:String = "res://tests/fb_monster/monster_test_script.gd"
var schema:GDScript

var creating_script:String = "res://tests/fb_monster/monster_creating.gd"
var reading_script:String = "res://tests/fb_monster/monster_reading.gd"

func compile_schema() -> void:
	logd("== Compiling Monster Schema ==")
	var run_dict:Dictionary = await FlatBuffersPlugin.generate(schema_file)
	var run_output:String = run_dict.output
	TEST_EQ(0, run_dict.retcode, run_output)


func load_generated_script() -> void:
	logd("== Loading Generated GDScript ==")
	schema = load(generated_file)
	TEST_TRUE(is_instance_valid(schema), "Loading generated script")


func _run_test() -> int: 
	var efs:EditorFileSystem = EditorInterface.get_resource_filesystem()
	
	#@warning_ignore_start("return_value_discarded")
	#efs.filesystem_changed.connect(
		#func()->void:print("filesystem_changed"),
		#CONNECT_ONE_SHOT)
		#
	#efs.resources_reimported.connect(
		#func(rlist:PackedStringArray)->void:
			#print("resources_reimported")
			#for r:String in rlist: print("\t", r),
		#CONNECT_ONE_SHOT)
		#
	#efs.resources_reimporting.connect(
		#func(rlist:PackedStringArray)->void:
			#print("resources_reimporting")
			#for r:String in rlist: print("\t", r),
		#CONNECT_ONE_SHOT)
		#
	#efs.resources_reload.connect(
		#func(rlist:PackedStringArray)->void:
			#print("resources_reload")
			#for r:String in rlist: print("\t", r),
		#CONNECT_ONE_SHOT)
		#
	#efs.script_classes_updated.connect(
		#func()->void:print("script_classes_updated"),
		#CONNECT_ONE_SHOT)
		#
	#efs.sources_changed.connect(
		#func( exist:bool )->void:
			#print("sources_changed")
			#print("\texist:", exist),
		#CONNECT_ONE_SHOT)
	#@warning_ignore_restore("return_value_discarded")

	compile_schema()
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Schema Compilation"):
		return runcode
	
	load_generated_script()
	if not TEST_EQ_RET(RetCode.TEST_OK, runcode, "Load Generated Script"):
		return runcode
	
	# Must wait for existing scan to complete before we can re-import otherwise
	# we get a bunch of errors.
	if efs.is_scanning():
		await efs.filesystem_changed
		
	# re-import script files. This outputs an error, but still works.
	# Preliminary searching for the error message didnt show up much
	# INTERNAL ERROR: BUG: File queued for import, but can't be imported,
	#     importer for type '' not found.
	efs.reimport_files([generated_file, creating_script, reading_script])

	## Because we cannot pre-load a script that hasnt been generated yet, it
	## means that we have no access to types. But I can load and run a script
	## that does pre-load the generated script, because when it is loaded it will
	## pull in the pre-load but that's after the generated script is created.
	## It's a bit convoluted yes.
	var CreatingTest:GDScript = load(creating_script)
	var cts:Object = CreatingTest.new(self)
	TEST_TRUE(is_instance_valid(cts), "creation instance object")
	
	var ReadingTest:GDScript = load(reading_script)
	var rts:Object = ReadingTest.new(self)
	TEST_TRUE(is_instance_valid(rts), "reading instance object")
	
	var packed:PackedByteArray = cts.call(&"create_orc_flatbuffer")
	TEST_OP(packed.size(), OP_GREATER, 0, "Packed Array size is larger than zero")
	
	rts.call(&"read_orc_flatbuffer", packed)
	
	return runcode
