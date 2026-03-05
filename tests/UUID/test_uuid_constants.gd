@tool
extends TestBase

func _run_test() -> int:
	TEST_EQ("00000000-0000-0000-0000-000000000000", UUID.get_nil_uuid(), "UUID.get_nil_uuid()")

	TEST_EQ("ffffffff-ffff-ffff-ffff-ffffffffffff", UUID.get_max_uuid(), "UUID.get_max_uuid()")

	TEST_EQ("6ba7b810-9dad-11d1-80b4-00c04fd430c8", UUID.get_namespace_dns(), "UUID.get_namespace_dns()")

	TEST_EQ("6ba7b811-9dad-11d1-80b4-00c04fd430c8", UUID.get_namespace_url(), "UUID.get_namespace_url()")

	TEST_EQ("6ba7b812-9dad-11d1-80b4-00c04fd430c8", UUID.get_namespace_oid(), "UUID.get_namespace_oid()")

	TEST_EQ("6ba7b814-9dad-11d1-80b4-00c04fd430c8", UUID.get_namespace_x500(), "UUID.get_namespace_x500()")

	return runcode
