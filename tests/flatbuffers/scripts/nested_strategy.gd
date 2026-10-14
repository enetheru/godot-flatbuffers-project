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
	_elided_default()


func _inner_bytes(n:int) -> PackedByteArray:
	var inner_fbb := FlatBufferBuilder.new()
	var inner_offset:int = Schema.create_Inner(inner_fbb, n)
	if not test.TEST_TRUE_RET(inner_offset != 0, "finish inner"):
		return PackedByteArray()
	inner_fbb.finish(inner_offset)
	return inner_fbb.get_buffer()


func _copy_bytes(packed:PackedByteArray) -> Array:
	var bytes:Array = []
	for b:int in packed:
		bytes.append(b)
	return bytes


func _finish_root(outer:FlatBufferBuilder, vec:int) -> Schema.Root:
	var root_offset:int = Schema.create_Root(outer, vec)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish nested root"):
		return null
	outer.finish(root_offset)
	return Schema.get_Root(outer.get_buffer())


func _read_inner(root:Schema.Root) -> Schema.Inner:
	var packed:PackedByteArray = root.payload()
	if packed.is_empty():
		return null
	return Schema.Inner.new(packed, packed.decode_u32(0))


func _present() -> void:
	var packed:PackedByteArray = _inner_bytes(7)
	if packed.is_empty():
		return
	var outer := FlatBufferBuilder.new()
	var root:Schema.Root = _finish_root(outer, outer.create_vector_uint8(_copy_bytes(packed)))
	if root == null:
		return
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify nested buffer"):
		return
	test.TEST_TRUE(root.payload_is_present(), "payload present")
	test.TEST_EQ(packed.size(), root.payload_size(), "payload size")
	var nested:Schema.Inner = _read_inner(root)
	if test.TEST_TRUE_RET(nested != null, "inner view exists"):
		test.TEST_TRUE(nested.n_is_present(), "n stored")
		test.TEST_EQ(7, nested.n(), "nested n")
		test.TEST_TRUE(nested.verify(verifier), "inner verifies")


func _absent() -> void:
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = Schema.create_Root(fbb, 0)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish absent root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	test.TEST_TRUE(root.verify(verifier), "verify missing nested")
	test.TEST_FALSE(root.payload_is_present(), "payload absent")
	test.TEST_EQ(0, root.payload_size(), "absent payload size")
	test.TEST_EQ(0, root.payload().size(), "absent payload is empty")


func _short() -> void:
	var fbb := FlatBufferBuilder.new()
	var vec:int = fbb.create_vector_uint8([1, 2, 3])
	var root_offset:int = Schema.create_Root(fbb, vec)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish short root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	test.TEST_TRUE(root.payload_is_present(), "short payload is present")
	test.TEST_EQ(3, root.payload_size(), "short payload size")
	var verifier := FlatBufferVerifier.new()
	test.TEST_TRUE(root.verify(verifier), "ubyte vector verifies")


func _elided_default() -> void:
	var packed:PackedByteArray = _inner_bytes(0)
	if packed.is_empty():
		return
	var outer := FlatBufferBuilder.new()
	var root:Schema.Root = _finish_root(outer, outer.create_vector_uint8(_copy_bytes(packed)))
	if root == null:
		return
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify elided inner"):
		return
	test.TEST_TRUE(root.payload_is_present(), "elided inner still has a payload")
	test.TEST_OP(root.payload_size(), OP_GREATER, 0, "elided inner buffer is stored")
	var nested:Schema.Inner = _read_inner(root)
	if not test.TEST_TRUE_RET(nested != null, "elided inner view"):
		return
	test.TEST_FALSE(nested.n_is_present(), "default n is omitted")
	test.TEST_EQ(0, nested.n(), "omitted n reads 0")
	test.TEST_TRUE(nested.verify(verifier), "elided inner verifies")
