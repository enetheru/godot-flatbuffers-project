@tool
extends TestStrategy

const Schema = preload("../schemas/bit_flags_generated.gd")

var test:TestBase


func _init(initiator:TestBase) -> void:
	test = initiator


func _get_phase_count() -> int: return 1

func _get_phase_name(_idx:int) -> String: return "bit_flags"

func _get_strategy_count(_idx:int) -> int: return 1

func _get_strategy(_idx:int, _idx2:int) -> Callable:
	return null_strategy()


func _flow(_selection:Array[int]) -> void:
	_values()
	_round_trip()
	_omitted()
	_masks()
	_written_zero()


func _values() -> void:
	test.TEST_EQ(1, Schema.Flags.A, "A is 1 << 0")
	test.TEST_EQ(2, Schema.Flags.B, "B is 1 << 1")
	test.TEST_EQ(4, Schema.Flags.C, "C is 1 << 2")
	test.TEST_EQ(1, Schema.Sparse.F_0, "F0 is 1 << 0")
	test.TEST_EQ(128, Schema.Sparse.F_07, "F07 is 1 << 7")
	test.TEST_EQ(256, Schema.Sparse.F_08, "F08 is 1 << 8")
	test.TEST_EQ(16384, Schema.Sparse.F_14, "F14 is 1 << 14")
	test.TEST_EQ(32768, Schema.Sparse.F_15, "F15 is 1 << 15")


func _round_trip() -> void:
	var combined:int = Schema.Flags.A | Schema.Flags.B
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = Schema.create_Root(fbb, combined, Schema.Sparse.F_15)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish bit_flags root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify bit_flags buffer"):
		return
	test.TEST_EQ(combined, root.flag(), "combined flags")
	test.TEST_EQ(Schema.Sparse.F_15, root.sparse(), "sparse flag")


func _finish(fbb:FlatBufferBuilder, offset:int) -> Schema.Root:
	fbb.finish(offset)
	return Schema.get_Root(fbb.get_buffer())


func _omitted() -> void:
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.RootBuilder.new(fbb)
	var root:Schema.Root = _finish(fbb, builder.finish())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "omitted flags verify"):
		return
	test.TEST_FALSE(root.flag_is_present(), "flag absent")
	test.TEST_EQ(0, root.flag(), "omitted flag reads 0")
	test.TEST_FALSE(root.sparse_is_present(), "sparse absent")
	test.TEST_EQ(0, root.sparse(), "omitted sparse reads 0")


func _masks() -> void:
	var flag:int = Schema.Flags.A | Schema.Flags.B | Schema.Flags.C
	var sparse:int = Schema.Sparse.F_0 | Schema.Sparse.F_08 | Schema.Sparse.F_15
	var fbb := FlatBufferBuilder.new()
	var root_offset:int = Schema.create_Root(fbb, flag, sparse)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish flag masks"):
		return
	var root:Schema.Root = _finish(fbb, root_offset)
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "flag masks verify"):
		return
	test.TEST_TRUE(root.flag_is_present(), "full flag mask stored")
	test.TEST_EQ(flag, root.flag(), "A|B|C")
	test.TEST_TRUE(root.sparse_is_present(), "sparse mask stored")
	test.TEST_EQ(sparse, root.sparse(), "F0|F08|F15")


func _written_zero() -> void:
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.RootBuilder.new(fbb)
	builder.add_sparse(0)
	builder.add_flag(0)
	var root:Schema.Root = _finish(fbb, builder.finish())
	test.TEST_TRUE(root.flag_is_present(), "zero flag is stored")
	test.TEST_EQ(0, root.flag(), "written zero flag")
	test.TEST_TRUE(root.sparse_is_present(), "zero sparse is stored")
	test.TEST_EQ(0, root.sparse(), "written zero sparse")
