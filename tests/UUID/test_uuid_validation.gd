@tool
extends TestBase

# TODO Audit this test script.

func _run_test() -> int:
	TEST_TRUE(UUID.is_nil(UUID.get_nil_uuid()), "is_nil(true) for nil_uuid")
	TEST_FALSE(UUID.is_nil("12345678-1234-1234-1234-123456789abc"), "is_nil(false) for valid_uuid")
	TEST_FALSE(UUID.is_nil("invalid"), "is_nil(false) for invalid")

	var nil_version: int = UUID.get_uuid_version(UUID.get_nil_uuid())
	TEST_EQ(0, nil_version,  "get_uuid_version(nil) == 0")

	var invalid_version: int = UUID.get_uuid_version("invalid")
	TEST_EQ(-1, invalid_version,  "get_uuid_version(invalid) == -1")

	var v3_str: String = UUID.create_v3_godot_string("test")
	var v3_version: int = UUID.get_uuid_version(v3_str)
	TEST_EQ(v3_version, UUID.Version.NAME_BASED_MD5,"get_uuid_version(v3) == NAME_BASED_MD5 (3)")

	var v4_str: String = UUID.create_v4_stduuid_string()
	var v4_version: int = UUID.get_uuid_version(v4_str)
	TEST_EQ(v4_version, UUID.Version.RANDOM_NUMBER_BASED, "get_uuid_version(v4) == RANDOM_NUMBER_BASED (4)")

	var v5_str: String = UUID.create_v5_stduuid_string("test")
	var v5_version: int = UUID.get_uuid_version(v5_str)
	TEST_EQ(v5_version, UUID.Version.NAME_BASED_SHA1, "get_uuid_version(v5) == NAME_BASED_SHA1 (5)")

	var v3_variant: int = UUID.get_uuid_variant(v3_str)
	TEST_EQ(v3_variant, 1,"get_uuid_variant(v3) == 1")

	var nil_variant: int = UUID.get_uuid_variant(UUID.get_nil_uuid())
	TEST_EQ(0, nil_variant, "get_uuid_variant(nil) == 0")

	var invalid_variant: int = UUID.get_uuid_variant("invalid")
	TEST_EQ(-1, invalid_variant, "get_uuid_variant(invalid) == -1")

	var uuid1: String = "12345678-1234-1234-1234-123456789abc"
	var uuid2: String = "12345678-1234-1234-1234-123456789abc"
	TEST_TRUE(UUID.equals(uuid1, uuid2), "equals(true) same strings")

	TEST_FALSE(UUID.equals(uuid1, UUID.get_nil_uuid()), "equals(false) different")
	TEST_FALSE(UUID.equals(uuid1, "invalid"), "equals(false) one invalid")
	TEST_FALSE(UUID.equals("invalid1", "invalid2"), "equals(false) both invalid")

	TEST_TRUE(UUID.is_valid(uuid1), "is_valid(uuid1) == true")
	TEST_FALSE(UUID.is_valid("invalid"), "is_valid('invaid') == false")
	TEST_TRUE(UUID.is_valid(UUID.get_nil_uuid()), "is_valid(nil-uuid) == true")
	TEST_FALSE(UUID.is_valid(""), "is_valid(false) empty string")
	TEST_FALSE(UUID.is_valid("12345678-1234-1234-1234-123456789ab"), "is_valid(false) wrong format")
	TEST_FALSE(UUID.is_valid("12345678-1234-1234-1234-123456789abg"), "is_valid(false) non-hex chars")

	var zero_bytes := PackedByteArray()
	TEST_EQ(OK, zero_bytes.resize(16), "Resize" )
	var from_zero: String = UUID.to_string_from_variant(zero_bytes)
	TEST_TRUE(UUID.is_valid(from_zero), "is_valid(from_bytes(zeros)) == true")
	TEST_TRUE(UUID.is_nil(from_zero), "is_nil(from_bytes(zeros)) == true")

	return runcode
