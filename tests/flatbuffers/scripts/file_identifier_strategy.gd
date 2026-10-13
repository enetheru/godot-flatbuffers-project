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
	_verify_mismatch()
	_verify_missing()


func _build(fbb:FlatBufferBuilder) -> int:
	var label_offset:int = fbb.create_variant("rqid-label")
	var child_offset:int = Schema.create_Child(fbb, 3)
	return Schema.create_Root(fbb, label_offset, child_offset)


func _present_round_trip() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = _build(fbb)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish the root table"):
		return
	Schema.finish_Root_buffer(fbb, root_offset)
	var bytes:PackedByteArray = fbb.get_buffer()
	test.TEST_EQ("RQID", bytes.slice(4, 8).get_string_from_ascii(), "identifier bytes")
	test.TEST_EQ(Schema.FILE_IDENTIFIER, "RQID", "FILE_IDENTIFIER")

	var root:Schema.Root = Schema.get_Root(bytes)
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify passes when the identifier matches"):
		return
	test.TEST_EQ("rqid-label", root.label(), "label()")
	test.TEST_EQ(3, root.child().n(), "child().n()")
	test.TEST_TRUE(root.child().verify(verifier), "nested verify ignores the file identifier")


func _verify_mismatch() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = _build(fbb)
	Schema.finish_Root_buffer(fbb, root_offset)
	var bad:PackedByteArray = fbb.get_buffer().duplicate()
	bad[4] = 88
	bad[5] = 88
	bad[6] = 88
	bad[7] = 88
	var root:Schema.Root = Schema.get_Root(bad)
	var verifier := FlatBufferVerifier.new()
	test.TEST_FALSE(root.verify(verifier), "verify rejects a mismatched file identifier")
	test.TEST_TRUE(root.child().verify(verifier), "nested verify still passes on a mismatched identifier")


func _verify_missing() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = _build(fbb)
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	test.TEST_FALSE(root.verify(verifier), "verify rejects a buffer finished without the file identifier")
