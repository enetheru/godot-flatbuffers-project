@tool
extends TestBase

const schema = preload('res://tests/ScalarFields/scalar_fields_generated.gd')

func _run() -> void:
	var fbb = FlatBufferBuilder.new()

	var offset : int = schema.create_RootTable(fbb,
		true,	# bool
		-1,		# byte
		-1,		# ubyte
		-1,		# short
		-1,		# ushort
		-1,		# int
		-1,		# uint
		-1,		# long
		-1,		# ulong
		-1,		# float
		-1		# double
		)
	fbb.finish(offset)

	var data : PackedByteArray = fbb.to_packed_byte_array()
	output.append_array([
		"data size: %s" % data.size(),
	])

	# Decode buffer
	var fbo : schema.RootTable = schema.get_root(data)

	# Dump dictionary of contents.
	var dict : Dictionary = fbo.debug()

	output.append( JSON.stringify(dict, "  ", false) )
	return TEST_EQ( dict['size'], 81, "checking: size(), wanted 80, got i dunno")




	var builder = schema.RootTableBuilder.new(fbb)
	# finalise flatbuffer builder
	#builder.finish( offset )
	#TEST_EQ( root_table.my_field(), 5, "my_field == 5")

	return
