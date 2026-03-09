@tool
extends TestBase

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

const schema_include = "res://tests/flatbuffers/schemas/include.fbs"
const schema_minimum = "res://tests/flatbuffers/schemas/minimum.fbs"

# Cant pre-load something that doesnt exist.
const schema_b = preload('schemas/minimum_generated.gd')
const schema = preload('schemas/include_generated.gd')

func _run_test() -> int:
	# Process the schema, should produce no errors.
	
	var run_dict:Dictionary = await FlatBuffersPlugin.generate(schema_include, GEN_OPTS)
	var run_output:String = run_dict.output
	TEST_EQ(0, run_dict.retcode, run_output)
	
	run_dict = await FlatBuffersPlugin.generate(schema_minimum)
	run_output = run_dict.output
	TEST_EQ(0, run_dict.retcode, run_output)
	
	logp( "" )
	logd("== Testing Includes ==")
	logd("\n== Creating Minimum ==")
	var fbb := FlatBufferBuilder.new()
	var offset:int = schema_b.create_Minimum(fbb, 42)
	fbb.finish( offset )
	logd("finished creating flatbuffer object 'Other'")
	var other_bytes:PackedByteArray = fbb.to_packed_byte_array()
	logd(["bytes: %s" % bytes_view( other_bytes ) ])

	logd("\nDecoding flatbuffer object 'Other'")
	var other:schema_b.Minimum = schema_b.get_Minimum(other_bytes)
	var other_value:int = other.my_field()
	logd("decoded other.value: %s" % other_value)

	TEST_EQ(42, other_value)
	return runcode
