@tool
extends TestBase

const fb = preload('./test_schema_generated.gd')

var my_array : Array
var builtin_array : Array

func _run() -> void:
	short_way()
	long_way()
	if not silent:
		print_rich( "\n[b]== Struct ==[/b]\n" )
		for o in output: print( o )


func short_way():
	var builder = FlatBufferBuilder.new()

	var my_array_offset : int
	var array_offset : int

	var offset = fb.create_RootTable( builder, my_array_offset, array_offset )
	builder.finish( offset )

	## This must be called after `Finish()`.
	var buf = builder.to_packed_byte_array()
	reconstruction( buf )


func long_way():
	var builder = FlatBufferBuilder.new()

	var my_array_offset : int
	var array_offset : int

	var root_builder = fb.RootTableBuilder.new( builder )
	root_builder.add_my_array( my_array_offset )
	root_builder.add_builtin_array( array_offset )
	builder.finish( root_builder.finish() )

	## This must be called after `Finish()`.
	var buf = builder.to_packed_byte_array()
	reconstruction( buf )


func reconstruction( buffer : PackedByteArray ):
	var root_table := fb.get_root( buffer )
	output.append( "root_table: " + JSON.stringify( root_table.debug(), '\t', false ) )

	TEST_EQ( 0, 1, "TODO Generate testing" )
