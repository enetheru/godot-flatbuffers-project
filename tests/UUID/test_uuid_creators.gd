@tool
extends TestBase

# FIXME, something in here is giving me a stack underflow.
# ERROR: modules\gdscript\gdscript.h:530 - Stack underflow! (Engine Bug)

func _run_test() -> int:
	var v3_str: String = UUID.create_v3_godot_string("test_seed")
	logp("v3 (test_seed) string: '" + v3_str + "' (length = " + str(v3_str.length()) + ")")
	TEST_EQ(36, v3_str.length(), "create_v3_godot_string length == 36")

	var v3_bytes: PackedByteArray = UUID.create_v3_godot_bytes("test_seed")
	logp("v3 (test_seed) bytes hex: " + v3_bytes.hex_encode() )
	TEST_EQ(16, v3_bytes.size(), "create_v3_godot_bytes size == 16")

	var v3_ns_str: String = UUID.create_v3_godot_string("test_seed", UUID.get_namespace_dns())
	TEST_OP(v3_ns_str, OP_NOT_EQUAL , v3_str, "create_v3_godot_string with namespace differs from default")
	
	# FIXME, this test exhibits the following error.
	# ERROR: core\crypto\hashing_context.cpp:53 - Condition "len == 0" is true. Returning: FAILED
	#var v3_empty_str: String = UUID.create_v3_godot_string("")
	#TEST_EQ(36, v3_empty_str.length(), "create_v3_godot_string(empty seed) length == 36")

	var v3_invalid_ns: String = UUID.create_v3_godot_string("test_seed", "invalid")
	TEST_EQ(v3_invalid_ns, v3_str, "create_v3_godot_string(invalid ns) == default (nil ns)")

	var v4_std_str: String = UUID.create_v4_stduuid_string()
	TEST_EQ(36, v4_std_str.length(), "create_v4_stduuid_string length == 36")

	var v4_std_bytes: PackedByteArray = UUID.create_v4_stduuid_bytes()
	TEST_EQ(16, v4_std_bytes.size(), "create_v4_stduuid_bytes size == 16")

	var v4_v4_str: String = UUID.create_v4_uuidv4_string()
	TEST_EQ(36, v4_v4_str.length(), "create_v4_uuidv4_string length == 36")

	var v4_v4_bytes: PackedByteArray = UUID.create_v4_uuidv4_bytes()
	TEST_EQ(16, v4_v4_bytes.size(), "create_v4_uuidv4_bytes size == 16")

	TEST_OP( v4_std_str, OP_NOT_EQUAL, v4_v4_str, "v4 generators differ")

	var v5_str: String = UUID.create_v5_stduuid_string("test_seed")
	TEST_EQ(36, v5_str.length(), "create_v5_stduuid_string length == 36")

	var v5_bytes: PackedByteArray = UUID.create_v5_stduuid_bytes("test_seed")
	TEST_EQ(16, v5_bytes.size(), "create_v5_stduuid_bytes size == 16")

	var v5_ns_str: String = UUID.create_v5_stduuid_string("test_seed", UUID.get_namespace_url())
	TEST_OP(v5_ns_str, OP_NOT_EQUAL, v5_str, "create_v5_stduuid_string with namespace differs from default")

	var invalid_ns: String = UUID.create_v5_stduuid_string("test_seed", "invalid")
	TEST_TRUE(invalid_ns.is_empty(), "create_v5_stduuid_string(invalid ns) empty")

	var v5_empty_str: String = UUID.create_v5_stduuid_string("")
	TEST_EQ(36, v5_empty_str.length(), "create_v5_stduuid_string(empty seed) length == 36")

	return runcode
