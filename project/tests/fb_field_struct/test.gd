@tool
extends TestBase

const schema = preload('./test_schema_generated.gd')
const Struct = schema.CustomStruct
const RootTable = schema.RootTable

var my_array : Array
var builtin_array : Array

func _run() -> void:
	# struct
	var struct = Struct.new()
	struct.x = 35; struct.y = 73

	TEST_EQ(35, struct.x, "struct.x")
	TEST_EQ(73, struct.y, "struct.x")

	# construct Table
	var fbb = FlatBufferBuilder.new()
	var offset = schema.create_RootTable( fbb, struct )
	fbb.finish(offset)

	# get packed bytes
	var bytes := fbb.to_packed_byte_array()

	var table : RootTable = schema.get_root(bytes)

	var output_struct : Struct =  table.custom_struct()

	TEST_EQ( struct.x, output_struct.x )
	TEST_EQ( struct.y, output_struct.y )
