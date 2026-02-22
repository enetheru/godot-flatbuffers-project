@tool
extends TestBase


func report(test_name: String, passed: bool, details: String = "") -> void:
	if passed:
		logp("[color=lime]PASS[/color]: " + test_name)
	else:
		runcode = RetCode.TEST_FAILED
		logp("[color=salmon]FAIL[/color]: " + test_name + " [color=gray]" + details + "[/color]")


func _run_test() -> int:
	var uuid_obj: UUID = UUID.new()

	var key1: String = UUID.create_v4_stduuid_string()
	var key2: String = UUID.create_v4_stduuid_string()
	var invalid_key: String = "invalid"

	# Testing setters
	var set_valid: bool = uuid_obj.set_variant(key1, 42)
	report("set_variant(key1,42) == true", TEST_TRUE(set_valid))

	var set_invalid: bool = uuid_obj.set_variant(invalid_key, 99)
	report("set_variant(invalid_key, 99) == false", TEST_FALSE(set_invalid))

	# Testing getters.
	var get_found: Variant = uuid_obj.get_variant(key1, null)
	report("get_variant(key1) == 42",  TEST_EQ(42, get_found ))

	var get_default: Variant = uuid_obj.get_variant(key2, 0)
	report("get_variant(key2, 0) == 0 (default)", TEST_EQ(0, get_default ))

	var get_invalid: Variant = uuid_obj.get_variant(invalid_key, 0)
	report("get_variant(invalid_key, 0) == 0 (default)", TEST_EQ(0, get_invalid ))

	# Testing Has
	report("has_variant(key1) == true", TEST_TRUE(uuid_obj.has_variant(key1)))
	report("has_variant(key2) == false", TEST_FALSE(uuid_obj.has_variant(key2)))
	report("has_variant(invalid_key) == false", TEST_FALSE(uuid_obj.has_variant(invalid_key)))

	# Reporting
	var size1: int = uuid_obj.get_variant_map_size()
	report("get_variant_map_size() == 1, after one set", TEST_EQ( 1, size1))

	var keys: Array = uuid_obj.get_variant_keys()
	report("get_variant_keys().size() == 1, contains key1",
		TEST_EQ( 1, keys.size()) && TEST_TRUE(keys.has(key1)))

	# Erase
	var erase_valid: bool = uuid_obj.erase_variant(key1)
	report("erase_variant(key1) == true", TEST_TRUE(erase_valid))

	var erase_missing: bool = uuid_obj.erase_variant(key1)
	report("erase_variant(key1) == false", TEST_FALSE(erase_missing))

	var erase_invalid: bool = uuid_obj.erase_variant(invalid_key)
	report("erase_variant(invalid_key) == false", TEST_FALSE(erase_invalid))

	# Reporting after erasure.
	var size_after_erase: int = uuid_obj.get_variant_map_size()
	report("get_variant_map_size() == 0, after erase",  TEST_EQ( 0, size_after_erase))

	uuid_obj.set_variant(key1, 42)
	uuid_obj.set_variant(key2, "test")
	var size2: int = uuid_obj.get_variant_map_size()
	report("get_variant_map_size() == 2, after two sets",  TEST_EQ( 2, size2))

	# adding multiple keys.
	var keys_multi: Array = uuid_obj.get_variant_keys()
	report("get_variant_keys().size() == 2, and contains both keys",
		TEST_EQ(2, keys_multi.size()) \
		&& TEST_TRUE(keys_multi.has(key1)) \
		&& TEST_TRUE(keys_multi.has(key2)))

	# Clearing the set.
	uuid_obj.clear_variants()
	var size_after_clear: int = uuid_obj.get_variant_map_size()
	report("clear_variants(), get_variant_map_size() == 0", TEST_EQ(0, size_after_clear))

	report("has_variant(key1), after clear", TEST_FALSE(uuid_obj.has_variant(key1)))

	return runcode
