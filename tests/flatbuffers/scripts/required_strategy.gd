@tool
extends TestStrategy

const Schema = preload("../schemas/required_generated.gd")

var test:TestBase


func _init(initiator:TestBase) -> void:
	test = initiator


func _get_phase_count() -> int: return 1

func _get_phase_name(_idx:int) -> String: return "required"

func _get_strategy_count(_idx:int) -> int: return 1

func _get_strategy(_idx:int, _idx2:int) -> Callable:
	return null_strategy()


func _flow(_selection:Array[int]) -> void:
	_present_round_trip()
	_builder_missing_string()
	_builder_missing_table()
	_verify_missing_string()
	_verify_missing_table()


func _present_round_trip() -> void:
	var fbb := FlatBufferBuilder.new()
	var label_offset:int = fbb.create_variant("required-label")
	var child_offset:int = Schema.create_Child(fbb, 7)
	var root_offset:int = Schema.create_RootTable(fbb, label_offset, child_offset)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish with both required fields"):
		return
	fbb.finish(root_offset)
	var root:Schema.RootTable = Schema.get_RootTable(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify passes when required fields are set"):
		return
	test.TEST_EQ("required-label", root.label(), "label()")
	test.TEST_EQ(7, root.child().my_field(), "child().my_field()")


func _builder_missing_string() -> void:
	var fbb := FlatBufferBuilder.new()
	var child_offset:int = Schema.create_Child(fbb, 7)
	var root_offset:int = Schema.create_RootTable(fbb, 0, child_offset)
	test.TEST_EQ(0, root_offset, "building without the required string fails")


func _builder_missing_table() -> void:
	var fbb := FlatBufferBuilder.new()
	var label_offset:int = fbb.create_variant("required-label")
	var root_offset:int = Schema.create_RootTable(fbb, label_offset, 0)
	test.TEST_EQ(0, root_offset, "building without the required table fails")


func _verify_missing_string() -> void:
	var fbb := FlatBufferBuilder.new()
	var child_offset:int = Schema.create_Child(fbb, 7)
	var start:int = fbb.start_table()
	fbb.add_offset(Schema.RootTable.VT_CHILD, child_offset)
	var end:int = fbb.end_table(start)
	fbb.finish(end)
	var root:Schema.RootTable = Schema.get_RootTable(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	test.TEST_FALSE(root.verify(verifier), "verify fails when the required string is absent")


func _verify_missing_table() -> void:
	var fbb := FlatBufferBuilder.new()
	var label_offset:int = fbb.create_variant("required-label")
	var start:int = fbb.start_table()
	fbb.add_offset(Schema.RootTable.VT_LABEL, label_offset)
	var end:int = fbb.end_table(start)
	fbb.finish(end)
	var root:Schema.RootTable = Schema.get_RootTable(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	test.TEST_FALSE(root.verify(verifier), "verify fails when the required table is absent")
