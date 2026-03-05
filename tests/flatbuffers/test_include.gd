@tool
extends TestBase


const schema_include = "res://tests/flatbuffers/schemas/include.fbs"
const schema_minimum = "res://tests/flatbuffers/schemas/minimum.fbs"

# Cant pre-load something that doesnt exist.
const schema_b = preload('schemas/minimum_generated.gd')
const schema = preload('schemas/include_generated.gd')

func _run_test() -> int:
	# Process the schema, should produce no errors.
	var run_dict:Dictionary = FlatBuffersPlugin.generate(schema_include)
	TEST_EQ(0, run_dict.retcode, str(run_dict.output))
	
	run_dict = FlatBuffersPlugin.generate(schema_minimum)
	TEST_EQ(0, run_dict.retcode, str(run_dict.output))
	
	
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
	var other:schema_b.Minimum = schema_b.get_root(other_bytes)
	var other_value:int = other.my_field()
	logd("decoded other.value: %s" % other_value)

	TEST_EQ(42, other_value)
	return runcode
