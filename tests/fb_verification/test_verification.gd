@tool
extends TestBase

const Schema = preload('uid://bkiq2py2ei7y6')

func _run_test() -> int:
	logd("== Testing Verification ==")

	var fbb := FlatBufferBuilder.new()
	var final_ofs:int = Schema.create_MyTable(fbb, 42)
	fbb.finish(final_ofs)

	var packed:PackedByteArray = fbb.to_packed_byte_array()
	logd(sbytes(packed))

	var fb_table := Schema.get_MyTable(packed, packed.decode_u32(0))

	logd( "first_field: %d" % fb_table.first_field() )
	TEST_EQ(42, fb_table.first_field(), "ensure inputs match outputs")

	logd("[b]== Constructing Verifier ==[/b]")
	var verifier := FlatBufferVerifier.new()
	verifier.set_buffer(packed)

	TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")

	logd("== Messing with packed ==")
	# OK, now we need to mess with the table, break it, and have the verifier
	# report false.
	logd("start: %d" % packed.decode_u32(0) ) # When last checked was 12
	# lets ruin the first 8 bytes
	packed.encode_u32(0, 0x0FFFFFFFFFFFFFFF)
	verifier.set_buffer(packed)
	fb_table.bytes = packed
	fb_table.start = packed.decode_u32(0)

	if not TEST_FALSE(fb_table.verify(verifier), "broken table start.") \
		or _verbose:
			logp("\tfb_table.start: %d" % fb_table.start)
			logp("\tfb_table.bytes: %s" % sbytes(fb_table.bytes))


	return runcode
