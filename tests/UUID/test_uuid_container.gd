@tool
extends TestBase

func _run_test() -> int:
	var uuid_obj: UUID = UUID.new()

	var key1: String = UUID.create_v4_stduuid_string()
	var key2: String = UUID.create_v4_stduuid_string()
	var invalid_key: String = "invalid"

	# Testing setters
	TEST_TRUE(uuid_obj.assign_value(key1, 42), "assign_value(key1,42) == true")

	TEST_FALSE(uuid_obj.assign_value(invalid_key, 99), "assign_value(invalid_key, 99) == false")

	# Testing getters.
	TEST_EQ(42, uuid_obj.get_value(key1, null), "uuid_obj.get_value(key1, null)")

	TEST_EQ(0, uuid_obj.get_value(key2, 0), "uuid_obj.get_value(key2, 0)")

	TEST_EQ(null, uuid_obj.get_value(invalid_key, 0), "uuid_obj.get_value(invalid_key, 0)")

	# Testing Has
	TEST_TRUE(uuid_obj.has_key(key1), "has_value(key1) == true")
	TEST_FALSE(uuid_obj.has_key(key2), "has_value(key2) == false")
	TEST_FALSE(uuid_obj.has_key(invalid_key), "has_value(invalid_key) == false")

	# Reporting
	TEST_EQ( 1, uuid_obj.get_map_size(), "uuid_obj.get_map_size()")

	var keys:Array = uuid_obj.get_keys_as_strings()
	TEST_EQ( 1, keys.size(), "uuid_obj.get_value_keys().size()")

	# Erase
	TEST_TRUE(uuid_obj.erase_key(key1), "erase_key(key1) == true")

	TEST_FALSE(uuid_obj.erase_key(key1), "erase_key(key1) == false")

	TEST_FALSE(uuid_obj.erase_key(invalid_key), "erase_key(invalid_key) == false")

	# Reporting after erasure.
	TEST_EQ( 0, uuid_obj.get_map_size(), "uuid_obj.get_map_size()")

	@warning_ignore("return_value_discarded")
	uuid_obj.assign_value(key1, 42)
	@warning_ignore("return_value_discarded")
	uuid_obj.assign_value(key2, "test")
	TEST_EQ( 2, uuid_obj.get_map_size(), "uuid_obj.get_map_size()")

	# adding multiple keys.
	var keys_multi: Array = uuid_obj.get_keys_as_strings()
	TEST_TRUE(
		TEST_EQ_RET(2, keys_multi.size()) \
		and TEST_TRUE_RET(keys_multi.has(key1)) \
		and TEST_TRUE_RET(keys_multi.has(key2)),
		"get_keys_as_strings().size() == 2, and contains both keys")

	# Clearing the set.
	uuid_obj.clear()
	TEST_EQ(0, uuid_obj.get_map_size(), "uuid_obj.get_map_size()")

	TEST_FALSE(uuid_obj.has_key(key1), "has_key(key1), after clear")

	return runcode
