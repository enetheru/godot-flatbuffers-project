@tool
extends TestBase

const schema = preload( 'test_schema_generated.gd' )

var test_object = Node3D.new()

func _run() -> void:
	# Setup Persistent data
	test_object.rotate(Vector3(randf(), randf(), randf()).normalized(), randf())
	reconstruct( manual() )
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
	root_builder.add_my_field( test_object.transform )
	# root_builder.add_<field_name>( offset )
	# ...

	# Finish the root builder
	var root_offset = root_builder.finish()

	# Finalise the builder
	builder.finish( root_offset )
#
	# export data
	return builder.to_packed_byte_array()


func reconstruct( buffer : PackedByteArray ):
	var root_table : FlatBuffer = schema.get_root( buffer )

	# Perform testing on the reconstructed flatbuffer.
	TEST_EQ( root_table.my_field(), test_object.transform, "my_field == test_object.transform")
