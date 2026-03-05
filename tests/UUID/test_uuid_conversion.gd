@tool
extends TestBase


func _run_test() -> int:
	var test_str: String = "12345678-1234-1234-1234-123456789abc"
	var bytes: PackedByteArray = UUID.to_bytes(test_str)
	logp("to_bytes hex: " + bytes.hex_encode() )
	TEST_EQ(16, bytes.size(), "to_bytes size == 16")

	var back_str: String = UUID.from_bytes(bytes)
	logp("from_bytes back: " + back_str )
	TEST_EQ(test_str, back_str, "from_bytes roundtrip == original")

	var nil_bytes: PackedByteArray = UUID.to_bytes(UUID.get_nil_uuid())
	TEST_EQ(16, nil_bytes.size(), "to_bytes(nil) size == 16")
	TEST_EQ(16, nil_bytes.count(0), "to_bytes(nil) is all zeros")

	var invalid_str: String = "invalid"
	var invalid_bytes: PackedByteArray = UUID.to_bytes(invalid_str)
	if TEST_TRUE_RET(invalid_bytes.is_empty(), "to_bytes(invalid).is_empty()"):
		logp(bytes_view(invalid_bytes))

	var zero_bytes: PackedByteArray = PackedByteArray()
	TEST_EQ(OK, zero_bytes.resize(16), "resizing")
	zero_bytes.fill(0)
	TEST_EQ(UUID.get_nil_uuid(), UUID.from_bytes(zero_bytes), "from_bytes(zeros) == nil_uuid")

	var short_bytes: PackedByteArray = PackedByteArray([1,2,3])
	var short_back: String = UUID.from_bytes(short_bytes)
	TEST_TRUE(short_back.is_empty(), "from_bytes(invalid short) empty")

	var long_bytes: PackedByteArray = PackedByteArray()
	TEST_EQ(long_bytes.resize(17), OK, "resizing")
	var long_back: String = UUID.from_bytes(long_bytes)
	TEST_TRUE(long_back.is_empty(), "from_bytes(invalid long) empty")

	var v4_bytes: PackedByteArray = UUID.create_v4_stduuid_bytes()
	var v4_str: String = UUID.from_bytes(v4_bytes)
	TEST_EQ(36, v4_str.length(), "from_bytes(v4) length == 36")

	# uuid to vec4i conversion and back.
	var uuid_str: String = "12345678-1234-5678-9abc-def012345678"
	var vec4i: Vector4i = UUID.to_vector4i(uuid_str)
	logp("UUID.to_vector4i('12345678-1234-5678-9abc-def012345678')")
	logp("vec4i: %s" % vec4i)
	logp("vec4i.x: 0x%x" % vec4i.x)
	logp("vec4i.y: 0x%x" % vec4i.y)
	logp("vec4i.z: 0x%x" % vec4i.z)
	logp("vec4i.w: 0x%x" % vec4i.w)

	TEST_EQ("0x12345678", "0x%x"%vec4i.x, "to_vector4i(uuid_str).x == 0x12345678")
	TEST_EQ("0x12345678", "0x%x"%vec4i.y, "to_vector4i(uuid_str).y == 0x12345678")

	# ... similarly for z/w.
	TEST_EQ(uuid_str, UUID.from_vector4i(vec4i), "UUID.from_vector4i(vec4i)")

	return runcode
