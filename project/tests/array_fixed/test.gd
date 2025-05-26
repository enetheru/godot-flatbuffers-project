@tool
extends TestBase

const schema = preload('./test_schema_generated.gd')
const FixedArrayExample = schema.FixedArrayExample

func _run() -> void:
	reconstruction( [] )

func reconstruction( buffer : PackedByteArray ):
	if TEST_TRUE( buffer.size(), "buffer.size()"): return
	var root_table := schema.get_root( buffer )
	output.append( "root_table: " + JSON.stringify( root_table.debug(), '\t', false ) )

	TEST_EQ( 0, 1, "TODO Generate testing" )
