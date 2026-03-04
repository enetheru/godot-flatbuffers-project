@tool
extends TestBase

const schema = preload('schemas/string_generated.gd')

func _run_test() -> int:
	short_way()
	long_way()
	return runcode

var test_string : String = "This is a string that I am adding to te flatbuffer"

func short_way() -> void:
	var builder := FlatBufferBuilder.new()
	var string_offset:int = builder.create_String( test_string )
	var offset:int = schema.create_RootTable( builder, string_offset )
	builder.finish( offset )

	## This must be called after `Finish()`.
	var buf:PackedByteArray = builder.to_packed_byte_array()
	reconstruction( buf )


func long_way() -> void:
	var builder := FlatBufferBuilder.new()

	var string_offset:int = builder.create_String( test_string )

	var root_builder := schema.RootTableBuilder.new( builder )
	root_builder.add_my_string( string_offset )
	builder.finish( root_builder.finish() )

	## This must be called after `Finish()`.
	var buf:PackedByteArray = builder.to_packed_byte_array()
	reconstruction( buf )


func reconstruction( buffer : PackedByteArray ) -> void:
	var root_table := schema.get_root( buffer )

	TEST_EQ( root_table.my_string(), test_string, "my_string()" )
