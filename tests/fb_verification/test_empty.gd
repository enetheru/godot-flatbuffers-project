@tool
extends TestBase

const Schema = preload('uid://bkiq2py2ei7y6')

func _run_test() -> int:
	logd("== Verify ~Empty Buffer (single byte) ==")

	var packed:PackedByteArray = [0]
	logd(sbytes(packed))

	var fb_table := Schema.get_MyTable(packed, 0)

	logd("== Constructing Verifier ==")
	var verifier := FlatBufferVerifier.new()
	verifier.set_buffer(packed)

	TEST_FALSE(fb_table.verify(verifier), "smol buffer should not return true")

	return runcode
