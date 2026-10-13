@tool
extends TestStrategy

const Schema = preload("../schemas/nested_generated.gd")

var test:TestBase


func _init(initiator:TestBase) -> void:
	test = initiator


func _get_phase_count() -> int: return 1

func _get_phase_name(_idx:int) -> String: return "nested"

func _get_strategy_count(_idx:int) -> int: return 1

func _get_strategy(_idx:int, _idx2:int) -> Callable:
	return null_strategy()


func _flow(_selection:Array[int]) -> void:
	_present()
	_absent()
	_short()


func _present() -> void:
	var inner_fbb := FlatBufferBuilder.new()
	var inner_offset:int = Schema.create_Inner(inner_fbb, 7)
	if not test.TEST_TRUE_RET(inner_offset != 0, "finish inner"):
		return
	inner_fbb.finish(inner_offset)
	var packed:PackedByteArray = inner_fbb.get_buffer()
	var bytes:Array = []
	for b:int in packed:
		bytes.append(b)
	var outer := FlatBufferBuilder.new()
	var vec:int = outer.create_vector_uint8(bytes)
	var root_offset:int = Schema.create_Root(outer, vec)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish nested root"):
		return
	outer.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(outer.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify nested buffer"):
		return
	var nested:Schema.Inner = root.payload_nested_root()
	if test.TEST_TRUE_RET(nested != null, "nested root exists"):
		test.TEST_EQ(7, nested.n(), "nested n")


func _absent() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = Schema.create_Root(fbb, 0)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish absent root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	test.TEST_TRUE(root.verify(verifier), "verify missing nested")
	test.TEST_EQ(null, root.payload_nested_root(), "missing nested root")


func _short() -> void:
	var fbb := FlatBufferBuilder.new()
	var vec:int = fbb.create_vector_uint8([1, 2, 3])
	var root_offset:int = Schema.create_Root(fbb, vec)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish short root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	test.TEST_EQ(null, root.payload_nested_root(), "short nested root")
	var verifier := FlatBufferVerifier.new()
	test.TEST_FALSE(root.verify(verifier), "short nested fails verify")
