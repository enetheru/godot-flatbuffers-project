@tool
extends TestBase

# TODO Audit this test script.

func report(test_name: String, passed: bool, details: String = "") -> void:
	if passed:
		logp("[color=lime]PASS[/color]: " + test_name)
	else:
		runcode = RetCode.TEST_FAILED
		logp("[color=salmon]FAIL[/color]: " + test_name + " [color=gray]" + details + "[/color]")


func _run_test() -> int:
	var test_str: String = "12345678-1234-1234-1234-123456789abc"
	var bytes: PackedByteArray = UUID.to_bytes(test_str)
	print("to_bytes hex: " + bytes.hex_encode() )
	report("to_bytes size == 16", bytes.size() == 16, "(Got size: " + str(bytes.size()) + ")")

	var back_str: String = UUID.from_bytes(bytes)
	print("from_bytes back: " + back_str )
	report("from_bytes roundtrip == original", back_str == test_str, "(Got: '" + back_str + "', Expected: '" + test_str + "')")

	var nil_bytes: PackedByteArray = UUID.to_bytes(UUID.get_nil_uuid())
	report("to_bytes(nil) size == 16", nil_bytes.size() == 16, "(Got: " + str(nil_bytes.size()) + ")")
	report("to_bytes(nil) is all zeros", nil_bytes.count(0) == 16, "")

	var invalid_str: String = "invalid"
	var invalid_bytes: PackedByteArray = UUID.to_bytes(invalid_str)
	report("to_bytes(invalid).is_empty()", invalid_bytes.is_empty(), "(Got size: " + str(invalid_bytes.size()) + ")")

	var zero_bytes: PackedByteArray = PackedByteArray()
	zero_bytes.resize(16)
	zero_bytes.fill(0)
	var from_zero: String = UUID.from_bytes(zero_bytes)
	report("from_bytes(zeros) == nil_uuid", from_zero == UUID.get_nil_uuid(), "(Got: '" + from_zero + "')")

	var short_bytes: PackedByteArray = PackedByteArray([1,2,3])
	var short_back: String = UUID.from_bytes(short_bytes)
	report("from_bytes(invalid short) empty", short_back.is_empty(), "(Got: '" + short_back + "')")

	var long_bytes: PackedByteArray = PackedByteArray()
	long_bytes.resize(17)
	var long_back: String = UUID.from_bytes(long_bytes)
	report("from_bytes(invalid long) empty", long_back.is_empty(), "(Got: '" + long_back + "')")

	var v4_bytes: PackedByteArray = UUID.create_v4_stduuid_bytes()
	var v4_str: String = UUID.from_bytes(v4_bytes)
	report("from_bytes(v4) length == 36", v4_str.length() == 36, "(Got: '" + v4_str + "')")

	# uuid to vec4i conversion and back.
	var uuid_str: String = "12345678-1234-5678-9abc-def012345678"
	var vec4i: Vector4i = UUID.to_vector4i(uuid_str)
	logp("UUID.to_vector4i('12345678-1234-5678-9abc-def012345678')")
	logp("vec4i: %s" % vec4i)
	logp("vec4i.x: 0x%x" % vec4i.x)
	logp("vec4i.y: 0x%x" % vec4i.y)
	logp("vec4i.z: 0x%x" % vec4i.z)
	logp("vec4i.w: 0x%x" % vec4i.w)

	report("to_vector4i(uuid_str).x == 0x12345678",
			TEST_EQ("0x12345678", "0x%x"%vec4i.x, "vec4i.x should match input value"))

	report("to_vector4i(uuid_str).y == 0x12345678",
			TEST_EQ("0x12345678", "0x%x"%vec4i.y, "vec4i.y should match input value"))

	# ... similarly for z/w.
	var return_str: String = UUID.from_vector4i(vec4i)
	report("from_vector4i roundtrip", TEST_EQ(uuid_str, return_str))

	return runcode
