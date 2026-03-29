@tool
extends TestBase


func _run_test() -> int:
	var test_str: String = "12345678-1234-1234-1234-123456789abc"
	logp("test_str: " + test_str )
	var bytes: PackedByteArray = UUID.to_bytes_from_variant(test_str)
	logp("to_bytes_from_variant(test_str).hex_encode(): " + bytes.hex_encode() )
	TEST_EQ(16, bytes.size(), "bytes.size() == 16")

	var back_str: String = UUID.to_string_from_variant(bytes)
	logp("to_string_from_variant(): " + back_str )
	TEST_EQ(test_str, back_str, "roundtrip should equal original")

	var nil_bytes: PackedByteArray = UUID.to_bytes_from_variant(UUID.get_nil_uuid())
	TEST_EQ(16, nil_bytes.size(), "to_bytes_from_variant(nil) size == 16")
	TEST_EQ(16, nil_bytes.count(0), "to_bytes_from_variant(nil) is all zeros")

	var invalid_str: String = "invalid"
	var invalid_bytes: PackedByteArray = UUID.to_bytes_from_variant(invalid_str)
	TEST_EQ(0, invalid_bytes.size(), "to_bytes_from_variant('invalid') size == 0")
	TEST_EQ(0, invalid_bytes.count(0), "to_bytes_from_variant('invalid').count(0) = 0")

	var zero_bytes: PackedByteArray = PackedByteArray()
	TEST_EQ(OK, zero_bytes.resize(16), "resizing")
	zero_bytes.fill(0)
	TEST_EQ(UUID.get_nil_uuid(), UUID.to_string_from_variant(zero_bytes), "to_string_from_variant(zeros) == nil_uuid")

	var short_bytes: PackedByteArray = PackedByteArray([1,2,3])
	TEST_TRUE(UUID.to_string_from_variant(short_bytes).is_empty(), "to_string_from_variant(short_bytes).is_empty()")

	var long_bytes: PackedByteArray = PackedByteArray()
	TEST_EQ(long_bytes.resize(17), OK, "resizing")
	TEST_TRUE(UUID.to_string_from_variant(long_bytes).is_empty(), "to_string_from_variant(long_bytes).is_empty()")

	var v4_bytes: PackedByteArray = UUID.create_v4_stduuid_bytes()
	var v4_str: String = UUID.to_string_from_variant(v4_bytes)
	TEST_EQ(36, v4_str.length(), "to_string_from_variant(v4) length == 36")

	# uuid to vec4i conversion and back.
	var uuid_str: String = "12345678-1234-5678-9abc-def012345678"
	var vec4i: Vector4i = UUID.to_vector4i_from_variant(uuid_str)
	logp("UUID.to_vector4i_from_variant('12345678-1234-5678-9abc-def012345678')")
	logp("vec4i: %s" % vec4i)
	logp("vec4i.x: 0x%x" % vec4i.x)
	logp("vec4i.y: 0x%x" % vec4i.y)
	logp("vec4i.z: 0x%x" % vec4i.z)
	logp("vec4i.w: 0x%x" % vec4i.w)

	TEST_EQ("0x12345678", "0x%x"%vec4i.x, "to_vector4i_from_variant(uuid_str).x == 0x12345678")
	TEST_EQ("0x12345678", "0x%x"%vec4i.y, "to_vector4i_from_variant(uuid_str).y == 0x12345678")

	# ... similarly for z/w.
	TEST_EQ(uuid_str, UUID.to_string_from_variant(vec4i), "UUID.to_string_from_variant(vec4i)")

	return runcode
