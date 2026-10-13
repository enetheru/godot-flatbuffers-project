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
