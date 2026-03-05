@tool
extends TestBase

# TODO Audit this test script.

func _run_test() -> int:
	var nil_hash: int = UUID.hash_uuid(UUID.get_nil_uuid())
	TEST_EQ(0, nil_hash, "hash_uuid(nil) == 0")

	var valid_uuid: String = "12345678-1234-1234-1234-123456789abc"
	var valid_hash: int = UUID.hash_uuid(valid_uuid)
	TEST_OP(valid_hash, OP_NOT_EQUAL, 0, "hash_uuid(valid) != 0")

	var hash1: int = UUID.hash_uuid(valid_uuid)
	var hash2: int = UUID.hash_uuid(valid_uuid)
	TEST_EQ(hash1, hash2, "hash_uuid consistent for same input")

	var another_uuid: String = "87654321-4321-4321-4321-cba987654321"
	var another_hash: int = UUID.hash_uuid(another_uuid)
	TEST_OP( valid_hash, OP_NOT_EQUAL, another_hash, "hash_uuid differs for different inputs")

	var invalid_hash: int = UUID.hash_uuid("invalid")
	TEST_EQ(0, invalid_hash, "hash_uuid(invalid) == 0")

	return runcode
