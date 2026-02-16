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

	return runcode
