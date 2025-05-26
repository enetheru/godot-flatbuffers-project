@tool
extends TestBase

const schema = preload('./test_schema_generated.gd')
const Struct = schema.MyStruct
const RootTable = schema.RootTable

var my_array : Array
var builtin_array : Array

func _run() -> void:
	# struct
	var struct = Struct.new()
	struct.x = 35; struct.y = 73

	TEST_EQ(35, struct.x, "struct.x")
	TEST_EQ(73, struct.y, "struct.x")

	# Table
	#var fbb = FlatBufferBuilder.new()
	#var builder = schema.RootTableBuilder.new(fbb)

	# FIXME struct arrays I believe are just contiguous data as we know the size
	# of each element ahead of time. But for custom structs we need a mechanism
	# to set that up.

	# I have to double check how this is done.
	# I dont think we need the vector of offsets, I think the elements are inline

	# FIXME For scalars and builtin structs like Vector3 it works the same,
	# except we can add the builtin methods.

	output.append("Warning: I still have to implement this")
