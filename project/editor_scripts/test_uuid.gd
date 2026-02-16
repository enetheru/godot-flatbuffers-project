@tool
extends EditorScript

func _run() -> void:
	test_constants()
	test_hashing()
	test_creators()
	test_conversions()
	test_validation()
	test_variant_map()

func report(test_name: String, passed: bool, details: String = "") -> void:
	if passed:
		print_rich("[color=lime]PASS[/color]: " + test_name)
	else:
		print_rich("[color=salmon]FAIL[/color]: " + test_name + " [color=gray]" + details + "[/color]")

func test_constants() -> void:
	var nil_uuid: String = UUID.get_nil_uuid()
	report("get_nil_uuid == '00000000-0000-0000-0000-000000000000'", nil_uuid == "00000000-0000-0000-0000-000000000000", "(Got: '" + nil_uuid + "')")

	var max_uuid: String = UUID.get_max_uuid()
	report("get_max_uuid == 'ffffffff-ffff-ffff-ffff-ffffffffffff'", max_uuid == "ffffffff-ffff-ffff-ffff-ffffffffffff", "(Got: '" + max_uuid + "')")

	var ns_dns: String = UUID.get_namespace_dns()
	report("get_namespace_dns == '6ba7b810-9dad-11d1-80b4-00c04fd430c8'", ns_dns == "6ba7b810-9dad-11d1-80b4-00c04fd430c8", "(Got: '" + ns_dns + "')")

	var ns_url: String = UUID.get_namespace_url()
	report("get_namespace_url == '6ba7b811-9dad-11d1-80b4-00c04fd430c8'", ns_url == "6ba7b811-9dad-11d1-80b4-00c04fd430c8", "(Got: '" + ns_url + "')")

	var ns_oid: String = UUID.get_namespace_oid()
	report("get_namespace_oid == '6ba7b812-9dad-11d1-80b4-00c04fd430c8'", ns_oid == "6ba7b812-9dad-11d1-80b4-00c04fd430c8", "(Got: '" + ns_oid + "')")

	var ns_x500: String = UUID.get_namespace_x500()
	report("get_namespace_x500 == '6ba7b814-9dad-11d1-80b4-00c04fd430c8'", ns_x500 == "6ba7b814-9dad-11d1-80b4-00c04fd430c8", "(Got: '" + ns_x500 + "')")

func test_hashing() -> void:
	var nil_hash: int = UUID.hash_uuid(UUID.get_nil_uuid())
	report("hash_uuid(nil) == 0", nil_hash == 0, "(Got: " + str(nil_hash) + ")")

	var valid_uuid: String = "12345678-1234-1234-1234-123456789abc"
	var valid_hash: int = UUID.hash_uuid(valid_uuid)
	report("hash_uuid(valid) != 0", valid_hash != 0, "(Got: " + str(valid_hash) + ")")

	var hash1: int = UUID.hash_uuid(valid_uuid)
	var hash2: int = UUID.hash_uuid(valid_uuid)
	report("hash_uuid consistent for same input", hash1 == hash2, "(Hash1: " + str(hash1) + ", Hash2: " + str(hash2) + ")")

	var another_uuid: String = "87654321-4321-4321-4321-cba987654321"
	var another_hash: int = UUID.hash_uuid(another_uuid)
	report("hash_uuid differs for different inputs", valid_hash != another_hash, "(Hash1: " + str(valid_hash) + ", Hash2: " + str(another_hash) + ")")

	var invalid_hash: int = UUID.hash_uuid("invalid")
	report("hash_uuid(invalid) == 0", invalid_hash == 0, "(Got: " + str(invalid_hash) + ")")

func test_creators() -> void:
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

func test_conversions() -> void:
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
	# And remove or adjust the from_bytes(empty) test
	# (or keep it but don't expect it to be called with empty in this context)

	var nil_back: String = UUID.from_bytes(nil_bytes)
	report("from_bytes(empty).is_empty()", nil_back.is_empty(), "(Got: '" + nil_back + "')")

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

func test_validation() -> void:
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

func test_variant_map() -> void:
	var uuid_obj: UUID = UUID.new()

	var key1: String = UUID.create_v4_stduuid_string()
	var key2: String = UUID.create_v4_stduuid_string()
	var invalid_key: String = "invalid"

	var set_valid: bool = uuid_obj.set_variant(key1, 42)
	report("set_variant(valid) returns true", set_valid, "")

	var set_invalid: bool = uuid_obj.set_variant(invalid_key, 99)
	report("set_variant(invalid) returns false", !set_invalid, "")

	var get_found: Variant = uuid_obj.get_variant(key1, null)
	report("get_variant(found) == 42", get_found == 42, "(Got: " + str(get_found) + ")")

	var get_default: Variant = uuid_obj.get_variant("missing", 0)
	report("get_variant(missing) returns default (0)", get_default == 0, "(Got: " + str(get_default) + ")")

	report("has_variant(true) for existing", uuid_obj.has_variant(key1), "")
	report("has_variant(false) for missing", !uuid_obj.has_variant("missing"), "")
	report("has_variant(false) for invalid key", !uuid_obj.has_variant(invalid_key), "")

	var size1: int = uuid_obj.get_variant_map_size()
	report("get_variant_map_size == 1 after one set", size1 == 1, "(Got: " + str(size1) + ")")

	var keys: Array = uuid_obj.get_variant_keys()
	report("get_variant_keys size == 1 and contains key1", keys.size() == 1 && keys.has(key1), "(Got: " + str(keys) + ", Expected to contain: '" + key1 + "')")

	var erase_valid: bool = uuid_obj.erase_variant(key1)
	report("erase_variant(existing) returns true", erase_valid, "")

	var erase_missing: bool = uuid_obj.erase_variant("missing")
	report("erase_variant(missing) returns false", !erase_missing, "")

	var size_after_erase: int = uuid_obj.get_variant_map_size()
	report("get_variant_map_size == 0 after erase", size_after_erase == 0, "(Got: " + str(size_after_erase) + ")")

	uuid_obj.set_variant(key1, 42)
	uuid_obj.set_variant(key2, "test")
	var size2: int = uuid_obj.get_variant_map_size()
	report("get_variant_map_size == 2 after two sets", size2 == 2, "(Got: " + str(size2) + ")")

	var keys_multi: Array = uuid_obj.get_variant_keys()
	report("get_variant_keys size == 2 and contains both keys", keys_multi.size() == 2 && keys_multi.has(key1) && keys_multi.has(key2), "(Got: " + str(keys_multi) + ")")

	uuid_obj.clear_variants()
	var size_after_clear: int = uuid_obj.get_variant_map_size()
	report("get_variant_map_size == 0 after clear_variants", size_after_clear == 0, "(Got: " + str(size_after_clear) + ")")

	report("has_variant(false) after clear", !uuid_obj.has_variant(key1), "")
