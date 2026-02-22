@tool
extends TestBase

const Schema = preload('uid://dh4x0a1mfn4v6')

func _run_test() -> int:
	logd("== Testing FlatBuffer Class ==")

#region
	# This test proves that the packed byte array inside the FlatBuffer class is
	# a reference, and does not copy the bytes.
	var fbb := FlatBufferBuilder.new()
	var final_ofs:int = Schema.create_MyTable(fbb, 42)
	fbb.finish(final_ofs)

	var packed:PackedByteArray = fbb.to_packed_byte_array()
	logd("packed: " + sbytes(packed))

	logd("Created FlatBuffer using 'packed'")
	var fbuffer:FlatBuffer = Schema.get_MyTable(packed, packed.decode_u32(0))
	logd("fbuffer.bytes: " + sbytes(fbuffer.bytes))

	TEST_EQ(packed, fbuffer.bytes, "packed and fbuffer should have the same data")

	logd("Messed with packed data")
	packed.encode_u64( 0,0x7FFFFFFFFFFFFFFF )

	TEST_EQ(packed, fbuffer.bytes, "packed and fbuffer should still have the same data")
#region

	return runcode
