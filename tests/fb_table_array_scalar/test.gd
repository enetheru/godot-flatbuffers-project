@tool
extends TestBase

const INT8_MIN  = -128
const INT8_MAX = 127
const UINT8_MAX = 255 # (0xff)
const INT16_MIN = -32768
const INT16_MAX = 32767
const UINT16_MAX = 65535 #(0xffff)
const INT32_MIN = -2147483648
const INT32_MAX = 2147483647
const UINT32_MAX = 4294967295 #(0xffffffff)
const INT64_MIN = -2147483648
const INT64_MAX = 2147483647
const UINT64_MAX = 4294967295 #(0xffffffff)
const INT128_MIN = -9223372036854775808
#const INT128_MAX = 9223372036854775807
#const UINT128_MAX = 18446744073709551615 #(0xffffffffffffffff)

const FLT_EPSILON = 1.192092896e-07
const DBL_EPSILON = 2.2204460492503131e-016
#const FLT_MAX = 3.402823466e+38
const FLT_MAX = 3.402823466e+38
const DBL_MAX = 1.7976931348623158e+308
const FLT_MIN = 1.175494351e-38
const DBL_MIN = 2.2250738585072014e-308

const schema = preload('./FBTestScalarArrays_generated.gd')
const RootTable = schema.RootTable

func _run_test() -> int:
	var bytes : PackedByteArray = short_way()
	print( bytes )
	var root_table : RootTable = schema.get_root(bytes)
	print( JSON.stringify( root_table.debug(), '  ', false ) )
	check( root_table )

	bytes = long_way()
	root_table = schema.get_root(bytes)
	check( root_table )

	if runcode:
		output.append_array([
			"root_table: ",
			JSON.stringify( root_table.debug(), '  ', false )
		])
	return runcode


func short_way() -> PackedByteArray:
	var builder = FlatBufferBuilder.new()

	var bytes_offset = builder.create_vector_int8( [INT8_MIN, INT8_MAX] )
	var ubytes_offset = builder.create_vector_uint8( [0, UINT8_MAX] )
	var shorts_offset = builder.create_vector_int16( [INT16_MIN, INT16_MAX] )
	var ushorts_offset = builder.create_vector_uint16( [0, UINT16_MAX] )
	var ints_offset = builder.create_vector_int32( [INT32_MIN, INT32_MAX] )
	var uints_offset = builder.create_vector_uint32( [0, UINT32_MAX] )
	var int64s_offset = builder.create_vector_int64( [INT64_MIN, INT64_MAX] )
	var uint64s_offset = builder.create_vector_uint64( [0, UINT64_MAX] )
	var floats_offset = builder.create_vector_float32( [FLT_MIN, FLT_MAX] )
	var doubles_offset = builder.create_vector_float64( [DBL_MIN, DBL_MAX] )

	var offset = schema.create_RootTable(builder,
		bytes_offset, ubytes_offset,
		shorts_offset, ushorts_offset,
		ints_offset, uints_offset,
		int64s_offset, uint64s_offset,
		floats_offset, doubles_offset )
	builder.finish( offset )

	return builder.to_packed_byte_array()


func long_way() -> PackedByteArray:
	var builder = FlatBufferBuilder.new()

	var bytes_offset = builder.create_vector_int8( [INT8_MIN, INT8_MAX] )
	var ubytes_offset = builder.create_vector_uint8( [0, UINT8_MAX] )
	var shorts_offset = builder.create_vector_int16( [INT16_MIN, INT16_MAX] )
	var ushorts_offset = builder.create_vector_uint16( [0, UINT16_MAX] )
	var ints_offset = builder.create_vector_int32( [INT32_MIN, INT32_MAX] )
	var uints_offset = builder.create_vector_uint32( [0, UINT32_MAX] )
	var int64s_offset = builder.create_vector_int64( [INT64_MIN, INT64_MAX] )
	var uint64s_offset = builder.create_vector_uint64( [0, UINT64_MAX] )
	var floats_offset = builder.create_vector_float32( [FLT_MIN, FLT_MAX] )
	var doubles_offset = builder.create_vector_float64( [DBL_MIN, DBL_MAX] )


	var root_builder = schema.RootTableBuilder.new( builder )
	root_builder.add_bytes_( bytes_offset )
	root_builder.add_ubytes( ubytes_offset )
	root_builder.add_shorts( shorts_offset )
	root_builder.add_ushorts( ushorts_offset )
	root_builder.add_ints( ints_offset )
	root_builder.add_uints( uints_offset )
	root_builder.add_int64s( int64s_offset )
	root_builder.add_uint64s( uint64s_offset )
	root_builder.add_floats( floats_offset )
	root_builder.add_doubles( doubles_offset )

	builder.finish( root_builder.finish() )

	## This must be called after `Finish()`.
	return builder.to_packed_byte_array()


func check( root_table : RootTable ):

	# bytes
	TEST_EQ( 2, root_table.bytes__size(), "bytes__size()")
	TEST_EQ( INT8_MIN, root_table.bytes__at(0),  "bytes__at(0)")
	TEST_EQ( INT8_MAX, root_table.bytes__at(1),  "bytes__at(1)")
	var bytes = root_table.bytes_()
	TEST_EQ( 2, bytes.size(),  "bytes.size()" )
	TEST_EQ( INT8_MIN, bytes[0],  "bytes[0]" )
	TEST_EQ( INT8_MAX, bytes[1],  "bytes[1]" )

	# ubytes
	TEST_EQ( 2, root_table.ubytes_size(), "ubytes_size()" )
	TEST_EQ( 0, root_table.ubytes_at(0), "ubytes_at(0)" )
	TEST_EQ( UINT8_MAX, root_table.ubytes_at(1), "ubytes_at(1)" )
	var ubytes = root_table.ubytes()
	TEST_EQ( 2, ubytes.size(), "ubytes.size()" )
	TEST_EQ( 0, ubytes[0], "ubytes[0]" )
	TEST_EQ( UINT8_MAX, ubytes[1], "ubytes[1]" )

	# shorts
	TEST_EQ( 2, root_table.shorts_size(), "shorts_size()")
	TEST_EQ( INT16_MIN, root_table.shorts_at(0), "shorts_at(0)")
	TEST_EQ( INT16_MAX, root_table.shorts_at(1), "shorts_at(1)")
	var shorts = root_table.shorts()
	TEST_EQ( 2, shorts.size(), "shorts.size()" )
	TEST_EQ( INT16_MIN, shorts[0], "shorts[0]" )
	TEST_EQ( INT16_MAX, shorts[1], "shorts[1]" )

	# ushorts
	TEST_EQ( 2, root_table.ushorts_size(), "ushorts_size()" )
	TEST_EQ( 0, root_table.ushorts_at(0), "ushorts_at(0)" )
	TEST_EQ( UINT16_MAX, root_table.ushorts_at(1), "ushorts_at(1)" )
	var ushorts = root_table.ushorts()
	TEST_EQ( 2, ushorts.size(), "ushorts.size()" )
	TEST_EQ( 0, ushorts[0], "ushorts[0]" )
	TEST_EQ( UINT16_MAX, ushorts[1], "ushorts[1]" )

	# ints
	TEST_EQ( 2, root_table.ints_size(), "ints_size()")
	TEST_EQ( INT32_MIN, root_table.ints_at(0), "ints_at(0)")
	TEST_EQ( INT32_MAX, root_table.ints_at(1), "ints_at(1)")
	var ints = root_table.ints()
	TEST_EQ( 2, ints.size(), "ints.size()" )
	TEST_EQ( INT32_MIN, ints[0], "ints[0]" )
	TEST_EQ( INT32_MAX, ints[1], "ints[1]" )

	# uints
	TEST_EQ( 2, root_table.uints_size(), "uints_size()" )
	TEST_EQ( 0, root_table.uints_at(0), "uints_at(0)" )
	TEST_EQ( UINT32_MAX, root_table.uints_at(1), "uints_at(1)" )
	var uints = root_table.uints()
	TEST_EQ( 2, uints.size(), "uints.size()" )
	TEST_EQ( 0, uints[0], "uints[0]" )
	TEST_EQ( UINT32_MAX, uints[1], "uints[1]" )

	# int64s
	TEST_EQ( 2, root_table.int64s_size(), "int64s_size()")
	TEST_EQ( INT64_MIN, root_table.int64s_at(0), "int64s_at(0)")
	TEST_EQ( INT64_MAX, root_table.int64s_at(1), "int64s_at(1)")
	var int64s = root_table.int64s()
	TEST_EQ( 2, int64s.size(), "int64s.size()" )
	TEST_EQ( INT64_MIN, int64s[0], "int64s[0]" )
	TEST_EQ( INT64_MAX, int64s[1], "int64s[1]" )

	# uint64s
	TEST_EQ( 2, root_table.uint64s_size(), "uint64s_size()" )
	TEST_EQ( 0, root_table.uint64s_at(0), "uint64s_at(0)" )
	TEST_EQ( UINT64_MAX, root_table.uint64s_at(1), "uint64s_at(1)" )
	var uint64s = root_table.uint64s()
	TEST_EQ( 2, uint64s.size(), "uint64s.size()" )
	TEST_EQ( 0, uint64s[0], "uint64s[0]" )
	TEST_EQ( UINT64_MAX, uint64s[1], "uint64s[1]" )

	# floats
	TEST_EQ( 2, root_table.floats_size(), "floats_size()")
	TEST_APPROX( FLT_MIN, root_table.floats_at(0), "floats_at(0)")
	TEST_APPROX( FLT_MAX, root_table.floats_at(1), "floats_at(1)")
	var floats = root_table.floats()
	TEST_EQ( 2, floats.size(), "floats.size()" )
	TEST_APPROX( FLT_MIN, floats[0], "floats[0]" )
	TEST_APPROX( FLT_MAX, floats[1], "floats[1]" )

	# doubles
	TEST_EQ( 2, root_table.doubles_size(), "doubles_size()")
	TEST_EQ( DBL_MIN, root_table.doubles_at(0), "doubles_at(0)")
	TEST_EQ( DBL_MAX, root_table.doubles_at(1), "doubles_at(1)")
	var doubles = root_table.doubles()
	TEST_EQ( 2, doubles.size(), "doubles.size()" )
	TEST_EQ( DBL_MIN, doubles[0], "doubles[0]" )
	TEST_EQ( DBL_MAX, doubles[1], "doubles[1]" )
