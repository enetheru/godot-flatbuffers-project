@tool
extends TestBase

func _run_test() -> int:
	var uuid_obj: UUID = UUID.new()

	var key1: String = UUID.create_v4_stduuid_string()
	var key2: String = UUID.create_v4_stduuid_string()
	var invalid_key: String = "invalid"

	# Testing setters
	TEST_TRUE(uuid_obj.set_variant(key1, 42), "set_variant(key1,42) == true")

	TEST_FALSE(uuid_obj.set_variant(invalid_key, 99), "set_variant(invalid_key, 99) == false")

	# Testing getters.
	TEST_EQ(42, uuid_obj.get_variant(key1, null), "uuid_obj.get_variant(key1, null)")

	TEST_EQ(0, uuid_obj.get_variant(key2, 0), "uuid_obj.get_variant(key2, 0)")

	TEST_EQ(0, uuid_obj.get_variant(invalid_key, 0), "uuid_obj.get_variant(invalid_key, 0)")

	# Testing Has
	TEST_TRUE(uuid_obj.has_variant(key1), "has_variant(key1) == true")
	TEST_FALSE(uuid_obj.has_variant(key2), "has_variant(key2) == false")
	TEST_FALSE(uuid_obj.has_variant(invalid_key), "has_variant(invalid_key) == false")

	# Reporting
	TEST_EQ( 1, uuid_obj.get_variant_map_size(), "uuid_obj.get_variant_map_size()")

	TEST_EQ( 1, uuid_obj.get_variant_keys(), "uuid_obj.get_variant_keys()")

	# Erase
	TEST_TRUE(uuid_obj.erase_variant(key1), "erase_variant(key1) == true")

	TEST_FALSE(uuid_obj.erase_variant(key1), "erase_variant(key1) == false")

	TEST_FALSE(uuid_obj.erase_variant(invalid_key), "erase_variant(invalid_key) == false")

	# Reporting after erasure.
	TEST_EQ( 0, uuid_obj.get_variant_map_size(), "uuid_obj.get_variant_map_size()")

	@warning_ignore("return_value_discarded")
	uuid_obj.set_variant(key1, 42)
	@warning_ignore("return_value_discarded")
	uuid_obj.set_variant(key2, "test")
	TEST_EQ( 2, uuid_obj.get_variant_map_size(), "uuid_obj.get_variant_map_size()")

	# adding multiple keys.
	var keys_multi: Array = uuid_obj.get_variant_keys()
	TEST_TRUE(
		TEST_EQ_RET(2, keys_multi.size()) \
		and TEST_TRUE_RET(keys_multi.has(key1)) \
		and TEST_TRUE_RET(keys_multi.has(key2)),
		"get_variant_keys().size() == 2, and contains both keys")

	# Clearing the set.
	uuid_obj.clear_variants()
	TEST_EQ(0, uuid_obj.get_variant_map_size(), "uuid_obj.get_variant_map_size()")

	TEST_FALSE(uuid_obj.has_variant(key1), "has_variant(key1), after clear")

	return runcode
