@tool
extends TestBase

const schema = preload("schemas/minimum_generated.gd")


# simple.fbs
#table Minimum {
	#my_field : int;
#}
#root_type Minimum;

func _run_test() -> int:
	var value : int = u32
	logd("starting value: %X" %value )

	var fbb := FlatBufferBuilder.new()
	var rt_offset:int = schema.create_Minimum(fbb, value )
	fbb.finish( rt_offset )

	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	logd("bytes: %s" % bytes_view(bytes) )

	var rt:schema.Minimum = schema.get_root(bytes)
	print("decoded: %X" %rt.my_field() )
	TEST_EQ(value, rt.my_field())

	return runcode
