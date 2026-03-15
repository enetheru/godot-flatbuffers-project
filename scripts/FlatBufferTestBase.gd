@tool
@abstract
extends TestBase
class_name FlatBufferTestBase

var default_generator_opts:FlatBuffersGeneratorOpts = load("uid://b8vn3e2cuhqy3")

func compile_schema(
			schema_file:String,
			opts:FlatBuffersGeneratorOpts = default_generator_opts) -> void:
	var run_dict:Dictionary = await FlatBuffersPlugin.generate(schema_file, opts)
	var stdout:String = run_dict.stdout
	TEST_EQ(0, run_dict.retcode, stdout)


func load_generated_script(generated_file:String) -> void:
	if TEST_TRUE_RET(FileAccess.file_exists(generated_file),
			"does generated file exist: '%s'" % generated_file ):
		var schema:GDScript = load(generated_file)
		TEST_TRUE(is_instance_valid(schema), "Loading generated script")


# TODO add a function to delete the generated files in the schema folder.
