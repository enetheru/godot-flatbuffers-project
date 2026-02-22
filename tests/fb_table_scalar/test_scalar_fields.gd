@tool
extends TestBase

const schema = preload('scalar_fields_generated.gd')

func _run_test() -> int:
	test_neg_one()
	return runcode

func test_neg_one():
	var fbb = FlatBufferBuilder.new()

	# Setting fields to -1
	var offset : int = schema.create_RootTable(fbb,
		true,	# f_bool	== true
		-1,		# f_byte	== -1
		-1,		# f_ubyte	== 255
		-1,		# f_short	== -1
		-1,		# f_ushort	== 65535
		-1,		# f_int		== -1
		-1,		# f_uint	== 4294967295
		-1,		# f_long	== -1
		-1,		# f_ulong	== -1 ? This one is confusing to me
		-1,		# f_float	== -1: we need better tests
		-1		# f_double	== -1: we need better tests
		)
	fbb.finish(offset)
	var data : PackedByteArray = fbb.to_packed_byte_array()

	# Decode buffer
	var fbo : schema.RootTable = schema.get_root(data)
	TEST_TRUE( fbo.f_bool(), " f_bool()")
	TEST_EQ(fbo.f_byte(), -1, "f_byte()" )
	TEST_EQ(fbo.f_ubyte(), 255, "f_ubyte()" )
	TEST_EQ(fbo.f_short(), -1, "f_short()" )
	TEST_EQ(fbo.f_ushort(), 65_535, "f_ushort()" )
	TEST_EQ(fbo.f_int(), -1, "f_int()" )
	TEST_EQ(fbo.f_uint(), 4_294_967_295, "f_uint()" )
	TEST_EQ(fbo.f_long(), -1, "f_long()" )
	TEST_EQ(fbo.f_ulong(), -1, "f_ulong()" )
	TEST_EQ(fbo.f_float(), -1, "f_float()" )
	TEST_EQ(fbo.f_double(), -1, "f_double()" )

	# provide debug info if an error occurs.
	if runcode:
		output.append_array( ["[color=goldenrod]Debug:[/color]",
			JSON.stringify(fbo.debug(), "  ", false) ])
