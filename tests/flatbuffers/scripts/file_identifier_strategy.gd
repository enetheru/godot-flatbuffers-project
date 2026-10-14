@tool
extends TestStrategy

const Schema = preload("../schemas/file_identifier_generated.gd")

var test:TestBase


func _init(initiator:TestBase) -> void:
	test = initiator


func _get_phase_count() -> int: return 1

func _get_phase_name(_idx:int) -> String: return "file_identifier"

func _get_strategy_count(_idx:int) -> int: return 1

func _get_strategy(_idx:int, _idx2:int) -> Callable:
	return null_strategy()


func _flow(_selection:Array[int]) -> void:
	_present_round_trip()
	_identifier_mismatch()
	_identifier_absent()


func _build(fbb:FlatBufferBuilder) -> int:
	var label_offset:int = fbb.create_variant("rqid-label")
	var child_offset:int = Schema.create_Child(fbb, 3)
	return Schema.create_Root(fbb, label_offset, child_offset)


func _present_round_trip() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = _build(fbb)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish the root table"):
		return
	fbb.finish(root_offset, "RQID")
	var bytes:PackedByteArray = fbb.get_buffer()
	test.TEST_EQ("RQID", bytes.slice(4, 8).get_string_from_ascii(), "identifier bytes")

	var root:Schema.Root = Schema.get_Root(bytes)
	var verifier := FlatBufferVerifier.new()
	verifier.set_buffer(bytes)
	if not test.TEST_TRUE_RET(verifier.buffer_has_identifier("RQID"), "buffer has RQID"):
		return
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify the table"):
		return
	test.TEST_EQ("rqid-label", root.label(), "label()")
	test.TEST_EQ(3, root.child().n(), "child().n()")
	test.TEST_TRUE(root.child().verify(verifier), "child verifies inside an identified buffer")


func _identifier_mismatch() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = _build(fbb)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish mismatch root"):
		return
	fbb.finish(root_offset, "RQID")
	var bad:PackedByteArray = fbb.get_buffer().duplicate()
	bad[4] = 88
	bad[5] = 88
	bad[6] = 88
	bad[7] = 88
	var verifier := FlatBufferVerifier.new()
	verifier.set_buffer(bad)
	test.TEST_FALSE(verifier.buffer_has_identifier("RQID"), "mismatched identifier")
	test.TEST_EQ("XXXX", bad.slice(4, 8).get_string_from_ascii(), "overwritten identifier")
	var root:Schema.Root = Schema.get_Root(bad)
	test.TEST_TRUE(root.child().verify(verifier), "child verifies after the identifier bytes change")


func _identifier_absent() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = _build(fbb)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish plain root"):
		return
	fbb.finish(root_offset)
	var bytes:PackedByteArray = fbb.get_buffer()
	var verifier := FlatBufferVerifier.new()
	verifier.set_buffer(bytes)
	test.TEST_FALSE(verifier.buffer_has_identifier("RQID"), "plain finish has no identifier")
	test.TEST_FALSE(verifier.buffer_has_identifier("NO"), "short identifier is false")
	var unset := FlatBufferVerifier.new()
	test.TEST_FALSE(unset.buffer_has_identifier("RQID"), "no buffer is not an identifier")
	var root:Schema.Root = Schema.get_Root(bytes)
	test.TEST_EQ("rqid-label", root.label(), "label without an identifier")
