@tool
extends TestBase

const schema = preload('simple_generated.gd')

# simple.fbs
#table RootTable {
	#my_field : int;
#}
#root_type RootTable;

func _run() -> void:
	var value : int = u32
	logd("starting value: %X" %value )

	var fbb := FlatBufferBuilder.new()
	var rt_offset = schema.create_RootTable(fbb, value )
	fbb.finish( rt_offset )

	var bytes = fbb.to_packed_byte_array()
	logd("bytes: %s" % bytes_view(bytes) )

	var rt = schema.get_root(bytes)
	print("decoded: %X" %rt.my_field() )
	TEST_EQ(value, rt.my_field())

	retcode = runcode
