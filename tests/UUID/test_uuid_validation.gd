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
	report("is_nil(true) for nil_uuid", UUID.is_nil(UUID.get_nil_uuid()), "")
	report("is_nil(false) for valid_uuid", !UUID.is_nil("12345678-1234-1234-1234-123456789abc"), "")
	report("is_nil(false) for invalid", !UUID.is_nil("invalid"), "")

	var nil_version: int = UUID.get_version(UUID.get_nil_uuid())
	report("get_version(nil) == -1", nil_version == -1, "(Got: " + str(nil_version) + ")")

	var invalid_version: int = UUID.get_version("invalid")
	report("get_version(invalid) == -1", invalid_version == -1, "(Got: " + str(invalid_version) + ")")

	var v3_str: String = UUID.create_v3_godot_string("test")
	var v3_version: int = UUID.get_version(v3_str)
	report("get_version(v3) == NAME_BASED_MD5 (3)", v3_version == UUID.Version.NAME_BASED_MD5, "(Got: " + str(v3_version) + ")")

	var v4_str: String = UUID.create_v4_stduuid_string()
	var v4_version: int = UUID.get_version(v4_str)
	report("get_version(v4) == RANDOM_NUMBER_BASED (4)", v4_version == UUID.Version.RANDOM_NUMBER_BASED, "(Got: " + str(v4_version) + ")")

	var v5_str: String = UUID.create_v5_stduuid_string("test")
	var v5_version: int = UUID.get_version(v5_str)
	report("get_version(v5) == NAME_BASED_SHA1 (5)", v5_version == UUID.Version.NAME_BASED_SHA1, "(Got: " + str(v5_version) + ")")

	var v3_variant: int = UUID.get_uuid_variant(v3_str)
	report("get_uuid_variant(v3) == 1", v3_variant == 1, "(Got: " + str(v3_variant) + ")")

	var nil_variant: int = UUID.get_uuid_variant(UUID.get_nil_uuid())
	report("get_uuid_variant(nil) == -1", nil_variant == -1, "(Got: " + str(nil_variant) + ")")

	var invalid_variant: int = UUID.get_uuid_variant("invalid")
	report("get_uuid_variant(invalid) == -1", invalid_variant == -1, "(Got: " + str(invalid_variant) + ")")

	var uuid1: String = "12345678-1234-1234-1234-123456789abc"
	var uuid2: String = "12345678-1234-1234-1234-123456789abc"
	report("equals(true) same strings", UUID.equals(uuid1, uuid2), "")

	report("equals(false) different", !UUID.equals(uuid1, UUID.get_nil_uuid()), "")
	report("equals(false) one invalid", !UUID.equals(uuid1, "invalid"), "")
	report("equals(false) both invalid", !UUID.equals("invalid1", "invalid2"), "")

	report("is_valid(true) valid_uuid", UUID.is_valid(uuid1), "")
	report("is_valid(false) invalid", !UUID.is_valid("invalid"), "")
	report("is_valid(false) nil", !UUID.is_valid(UUID.get_nil_uuid()), "")
	report("is_valid(false) empty string", !UUID.is_valid(""), "")
	report("is_valid(false) wrong format", !UUID.is_valid("12345678-1234-1234-1234-123456789ab"), "")
	report("is_valid(false) non-hex chars", !UUID.is_valid("12345678-1234-1234-1234-123456789abg"), "")

	var zero_bytes := PackedByteArray()
	zero_bytes.resize(16)
	var from_zero: String = UUID.from_bytes(zero_bytes)
	report("is_valid(from_bytes(zeros)) == false", !UUID.is_valid(from_zero), "")
	report("is_nil(from_bytes(zeros)) == true", UUID.is_nil(from_zero), "")

	return runcode
