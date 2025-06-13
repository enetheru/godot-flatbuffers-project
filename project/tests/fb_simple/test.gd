@tool
extends TestBase

const schema = preload('./FBTest.simple_generated.gd')

#region == Testing Setup ==
# testing variables

var test_object = { 'my_field': 5 }
#endregion

func _run() -> void:
	# Setup Persistent data
	# ...

	# Generate the flatbuffer using the three methods of creation
	reconstruct( manual() )
	reconstruct( create() )
	retcode = runcode

func manual() -> PackedByteArray:
	# create new builder
	var builder = FlatBufferBuilder.new()

	# create all the composite objects here
	# var offset : int = schema.Create<Type>( builder, element, ... )
	# ...

	# Start the root object builder
	var root_builder = schema.RootTableBuilder.new( builder )

	# Add all the root object items
	root_builder.add_my_field( 5 )
	# root_builder.add_<field_name>( offset )
	# ...

	# Finish the root builder
	var root_offset = root_builder.finish()

	# Finalise the builder
	builder.finish( root_offset )
#
	# export data
	return builder.to_packed_byte_array()


func create():
	# create new builder
	var builder = FlatBufferBuilder.new()

	# create all the composite objects here
	# var offset : int = schema.Create<Type>( builder, element, ... )
	# ...

	var offset : int = schema.create_RootTable( builder, 5 )


	# finalise flatbuffer builder
	builder.finish( offset )

	# export data
	return builder.to_packed_byte_array()


func reconstruct( buffer : PackedByteArray ):
	var root_table : FlatBuffer = schema.get_root( buffer )
	output.append( "root_table: " + JSON.stringify( root_table.debug(), '\t', false ) )

	# Perform testing on the reconstructed flatbuffer.
	TEST_EQ( root_table.my_field(), 5, "my_field == 5")
