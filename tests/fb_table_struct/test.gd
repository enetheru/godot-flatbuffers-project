@tool
extends TestBase

const schema = preload('./test_schema_generated.gd')
const CustomStruct = schema.CustomStruct
const RootTable = schema.RootTable

var my_array : Array
var builtin_array : Array

func _run_test() -> int:
	_verbose = true
	var x : int = 35;
	var y : float = 73;
	var z : int = 102;
	print("x: ", x)
	print("y: ", y)
	print("z: ", z)

	# struct
	var struct = CustomStruct.new()
	struct.x = x; struct.y = y
	print( "encode.x: ", struct.x )
	print( "encode.y: ", struct.y )
	TEST_EQ(35, struct.x, "struct.x")
	TEST_EQ(73, struct.y, "struct.x")

	# construct Table
	var fbb = FlatBufferBuilder.new()
	var offset = schema.create_RootTable( fbb, struct, z )
	fbb.finish(offset)

	# get packed bytes
	var bytes : PackedByteArray = fbb.to_packed_byte_array()

	var table : RootTable = schema.get_root(bytes)

	var output_struct : CustomStruct =  table.custom_struct()
	print( "decode.x: ", output_struct.x )
	print( "decode.y: ", output_struct.y )
	print( "decode.z: ", table.z() )

	TEST_EQ( struct.x, output_struct.x )
	TEST_EQ( struct.y, output_struct.y )
	return runcode
