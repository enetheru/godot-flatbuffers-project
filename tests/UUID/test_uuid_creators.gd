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
	var v3_str: String = UUID.create_v3_godot_string("test_seed")
	print("v3 (test_seed) string: '" + v3_str + "' (length = " + str(v3_str.length()) + ")")
	report("create_v3_godot_string length == 36", v3_str.length() == 36,
	 "(Got length: " + str(v3_str.length()) + ")")

	var v3_bytes: PackedByteArray = UUID.create_v3_godot_bytes("test_seed")
	print("v3 (test_seed) bytes hex: " + v3_bytes.hex_encode() )
	report("create_v3_godot_bytes size == 16", v3_bytes.size() == 16, "(Got size: " + str(v3_bytes.size()) + ")")

	var v3_ns_str: String = UUID.create_v3_godot_string("test_seed", UUID.get_namespace_dns())
	report("create_v3_godot_string with namespace differs from default", v3_ns_str != v3_str, "(Default: '" + v3_str + "', With NS: '" + v3_ns_str + "')")

	var v3_empty_str: String = UUID.create_v3_godot_string("")
	report("create_v3_godot_string(empty seed) length == 36", v3_empty_str.length() == 36, "(Got: '" + v3_empty_str + "')")

	var v3_invalid_ns: String = UUID.create_v3_godot_string("test_seed", "invalid")
	report("create_v3_godot_string(invalid ns) == default (nil ns)", v3_invalid_ns == v3_str, "(Got: '" + v3_invalid_ns + "', Expected: '" + v3_str + "')")

	var v4_std_str: String = UUID.create_v4_stduuid_string()
	report("create_v4_stduuid_string length == 36", v4_std_str.length() == 36, "(Got length: " + str(v4_std_str.length()) + ")")

	var v4_std_bytes: PackedByteArray = UUID.create_v4_stduuid_bytes()
	report("create_v4_stduuid_bytes size == 16", v4_std_bytes.size() == 16, "(Got size: " + str(v4_std_bytes.size()) + ")")

	var v4_v4_str: String = UUID.create_v4_uuidv4_string()
	report("create_v4_uuidv4_string length == 36", v4_v4_str.length() == 36, "(Got length: " + str(v4_v4_str.length()) + ")")

	var v4_v4_bytes: PackedByteArray = UUID.create_v4_uuidv4_bytes()
	report("create_v4_uuidv4_bytes size == 16", v4_v4_bytes.size() == 16, "(Got size: " + str(v4_v4_bytes.size()) + ")")

	report("v4 generators differ", v4_std_str != v4_v4_str, "(stduuid: '" + v4_std_str + "', uuidv4: '" + v4_v4_str + "')")

	var v5_str: String = UUID.create_v5_stduuid_string("test_seed")
	report("create_v5_stduuid_string length == 36", v5_str.length() == 36, "(Got length: " + str(v5_str.length()) + ")")

	var v5_bytes: PackedByteArray = UUID.create_v5_stduuid_bytes("test_seed")
	report("create_v5_stduuid_bytes size == 16", v5_bytes.size() == 16, "(Got size: " + str(v5_bytes.size()) + ")")

	var v5_ns_str: String = UUID.create_v5_stduuid_string("test_seed", UUID.get_namespace_url())
	report("create_v5_stduuid_string with namespace differs from default", v5_ns_str != v5_str, "(Default: '" + v5_str + "', With NS: '" + v5_ns_str + "')")

	var invalid_ns: String = UUID.create_v5_stduuid_string("test_seed", "invalid")
	report("create_v5_stduuid_string(invalid ns) empty", invalid_ns.is_empty(), "(Got: '" + invalid_ns + "')")

	var v5_empty_str: String = UUID.create_v5_stduuid_string("")
	report("create_v5_stduuid_string(empty seed) length == 36", v5_empty_str.length() == 36, "(Got: '" + v5_empty_str + "')")

	return runcode
