@tool
extends EditorScript

func _run() -> void:
	test_constants()
	test_hashing()
	test_creators()
	test_conversions()
	test_validation()
	test_variant_map()

func report(result: bool, msg: String) -> void:
	if result:
		print_rich("PASS: " + msg)
	else:
		print_rich("[color=salmon]FAIL: " + msg)

func test_constants() -> void:
	report(UUID.get_nil_uuid() == "00000000-0000-0000-0000-000000000000", "get_nil_uuid")
	report(UUID.get_max_uuid() == "ffffffff-ffff-ffff-ffff-ffffffffffff", "get_max_uuid")
	report(UUID.get_namespace_dns() == "6ba7b810-9dad-11d1-80b4-00c04fd430c8", "get_namespace_dns")
	report(UUID.get_namespace_url() == "6ba7b811-9dad-11d1-80b4-00c04fd430c8", "get_namespace_url")
	report(UUID.get_namespace_oid() == "6ba7b812-9dad-11d1-80b4-00c04fd430c8", "get_namespace_oid")
	report(UUID.get_namespace_x500() == "6ba7b814-9dad-11d1-80b4-00c04fd430c8", "get_namespace_x500")

func test_hashing() -> void:
	var nil_hash: int = UUID.hash_uuid(UUID.get_nil_uuid())
	report(nil_hash == 0, "hash_uuid nil returns 0")
	var valid_hash: int = UUID.hash_uuid("12345678-1234-1234-1234-123456789abc")
	report(valid_hash != 0, "hash_uuid valid != 0")

func test_creators() -> void:
	# v3 Godot (MD5)
	var v3_str: String = UUID.create_v3_godot_string("test_seed")
	print("v3 hex raw: ", UUID.create_v3_godot_bytes("test_seed").hex_encode())
	print("Actual v3 string: '", v3_str, "' (length = ", v3_str.length(), ")")
	report(v3_str.length() == 36, "create_v3_godot_string length")
	var v3_bytes: PackedByteArray = UUID.create_v3_godot_bytes("test_seed")
	report(v3_bytes.size() == 16, "create_v3_godot_bytes size")
	var v3_ns_str: String = UUID.create_v3_godot_string("test_seed", UUID.get_namespace_dns())
	report(v3_ns_str != v3_str, "create_v3_godot_string with namespace differs")

	# v4 stduuid
	var v4_std_str: String = UUID.create_v4_stduuid_string()
	report(v4_std_str.length() == 36, "create_v4_stduuid_string length")
	var v4_std_bytes: PackedByteArray = UUID.create_v4_stduuid_bytes()
	report(v4_std_bytes.size() == 16, "create_v4_stduuid_bytes size")

	# v4 uuidv4
	var v4_v4_str: String = UUID.create_v4_uuidv4_string()
	report(v4_v4_str.length() == 36, "create_v4_uuidv4_string length")
	var v4_v4_bytes: PackedByteArray = UUID.create_v4_uuidv4_bytes()
	report(v4_v4_bytes.size() == 16, "create_v4_uuidv4_bytes size")
	report(v4_std_str != v4_v4_str, "v4 generators differ")

	# v5 stduuid
	var v5_str: String = UUID.create_v5_stduuid_string("test_seed")
	report(v5_str.length() == 36, "create_v5_stduuid_string length")
	var v5_bytes: PackedByteArray = UUID.create_v5_stduuid_bytes("test_seed")
	report(v5_bytes.size() == 16, "create_v5_stduuid_bytes size")
	var v5_ns_str: String = UUID.create_v5_stduuid_string("test_seed", UUID.get_namespace_url())
	report(v5_ns_str != v5_str, "create_v5_stduuid_string with namespace differs")
	var invalid_ns: String = UUID.create_v5_stduuid_string("test_seed", "invalid")
	report(invalid_ns.is_empty(), "create_v5_stduuid_string invalid ns empty")

func test_conversions() -> void:
	var test_str: String = "12345678-1234-1234-1234-123456789abc"
	var bytes: PackedByteArray = UUID.to_bytes(test_str)
	report(bytes.size() == 16, "to_bytes size")
	var back_str: String = UUID.from_bytes(bytes)
	report(back_str == test_str, "from_bytes roundtrip")
	# After roundtrip fail
	var test_bytes = UUID.to_bytes(test_str)
	print("to_bytes hex: ", test_bytes.hex_encode())
	print("from_bytes back: ", UUID.from_bytes(test_bytes))

	var invalid_bytes: PackedByteArray = PackedByteArray([1,2,3])
	report(UUID.from_bytes(invalid_bytes).is_empty(), "from_bytes invalid empty")

func test_validation() -> void:
	report(UUID.is_nil(UUID.get_nil_uuid()), "is_nil true")
	report(!UUID.is_nil("12345678-1234-1234-1234-123456789abc"), "is_nil false")
	report(UUID.get_version(UUID.get_nil_uuid()) == -1, "get_version nil -1")

	var v3_bytes = UUID.create_v3_godot_bytes("test_seed")
	print("v3 bytes hex: ", v3_bytes.hex_encode())
	var v3_from_bytes = UUID.from_bytes(v3_bytes)
	print("v3 from bytes: ", v3_from_bytes)
	print("version from bytes: ", UUID.get_version(v3_from_bytes))

	var v3: String = UUID.create_v3_godot_string("test")
	report(UUID.get_version(v3) == UUID.Version.NAME_BASED_MD5, "get_version v3")

	var v4: String = UUID.create_v4_stduuid_string()
	report(UUID.get_version(v4) == UUID.Version.RANDOM_NUMBER_BASED, "get_version v4")

	var v5: String = UUID.create_v5_stduuid_string("test")
	report(UUID.get_version(v5) == UUID.Version.NAME_BASED_SHA1, "get_version v5")


	# Variants
	report(UUID.get_uuid_variant(v3) == 1, "get_uuid_variant v3 (assumes variant 1)")
	report(UUID.get_uuid_variant(UUID.get_nil_uuid()) == -1, "get_uuid_variant nil -1")

	var uuid1: String = "12345678-1234-1234-1234-123456789abc"
	var uuid2: String = "12345678-1234-1234-1234-123456789abc"
	report(UUID.equals(uuid1, uuid2), "equals true")
	report(!UUID.equals(uuid1, UUID.get_nil_uuid()), "equals false")

	report(UUID.is_valid(uuid1), "is_valid true")
	report(!UUID.is_valid("invalid"), "is_valid false")
	report(!UUID.is_valid(UUID.get_nil_uuid()), "is_valid nil false")  # Based on code: to_stduuid returns nil_stduuid if invalid

func test_variant_map() -> void:
	var uuid_obj: UUID = UUID.new()
	var key1: String = UUID.create_v4_stduuid_string()
	var key2: String = UUID.create_v4_stduuid_string()
	var invalid_key: String = "invalid"

	report(uuid_obj.set_variant(key1, 42), "set_variant valid true")
	report(!uuid_obj.set_variant(invalid_key, 99), "set_variant invalid false")

	report(uuid_obj.get_variant(key1, null) == 42, "get_variant found")
	report(uuid_obj.get_variant("missing", 0) == 0, "get_variant default")

	report(uuid_obj.has_variant(key1), "has_variant true")
	report(!uuid_obj.has_variant("missing"), "has_variant false")

	report(uuid_obj.get_variant_map_size() == 1, "get_variant_map_size 1")

	var keys: Array = uuid_obj.get_variant_keys()
	report(keys.size() == 1 && keys[0] == key1, "get_variant_keys")

	report(uuid_obj.erase_variant(key1), "erase_variant true")
	report(!uuid_obj.erase_variant("missing"), "erase_variant false")

	report(uuid_obj.get_variant_map_size() == 0, "get_variant_map_size 0 after erase")

	uuid_obj.set_variant(key1, 42)
	uuid_obj.set_variant(key2, "test")
	uuid_obj.clear_variants()
	report(uuid_obj.get_variant_map_size() == 0, "clear_variants")
