@tool
extends TestBase

func report(test_name: String, passed: bool, details: String = "") -> void:
	if passed:
		logp("[color=lime]PASS[/color]: " + test_name)
	else:
		runcode = RetCode.TEST_FAILED
		logp("[color=salmon]FAIL[/color]: " + test_name + " [color=gray]" + details + "[/color]")


func _run_test() -> int:
	var nil_uuid: String = UUID.get_nil_uuid()
	report("get_nil_uuid() == '00000000-0000-0000-0000-000000000000'",
		TEST_EQ("00000000-0000-0000-0000-000000000000", nil_uuid))

	var max_uuid: String = UUID.get_max_uuid()
	report( "get_max_uuid() == 'ffffffff-ffff-ffff-ffff-ffffffffffff'",
		TEST_EQ("ffffffff-ffff-ffff-ffff-ffffffffffff", max_uuid))

	var ns_dns: String = UUID.get_namespace_dns()
	report("get_namespace_dns() == '6ba7b810-9dad-11d1-80b4-00c04fd430c8'",
		TEST_EQ("6ba7b810-9dad-11d1-80b4-00c04fd430c8", ns_dns))

	var ns_url: String = UUID.get_namespace_url()
	report("get_namespace_url() == '6ba7b811-9dad-11d1-80b4-00c04fd430c8'",
		TEST_EQ("6ba7b811-9dad-11d1-80b4-00c04fd430c8", ns_url))

	var ns_oid: String = UUID.get_namespace_oid()
	report("get_namespace_oid() == '6ba7b812-9dad-11d1-80b4-00c04fd430c8'",
		TEST_EQ("6ba7b812-9dad-11d1-80b4-00c04fd430c8", ns_oid))

	var ns_x500: String = UUID.get_namespace_x500()
	report("get_namespace_x500() == '6ba7b814-9dad-11d1-80b4-00c04fd430c8'",
		TEST_EQ("6ba7b814-9dad-11d1-80b4-00c04fd430c8", ns_x500))

	return runcode
