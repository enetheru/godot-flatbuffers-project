@tool
extends TestStrategy

const Schema = preload("../schemas/include_generated.gd")
const MinimumSchema = preload("../schemas/minimum_generated.gd")

const u32 = TestBase.u32
const u32_ = TestBase.u32_
const u64 = TestBase.u64
const u64_ = TestBase.u64_

enum {
	ENCODING = 0,
	DECODING,
	USING
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_a]
		# TODO: I want some way to create dependencies between the strategies
	},{
		&"name":"Decoding",
		&"strategies":[decode_a]
	},{
		&"name":"Using",
		&"strategies":[use_a]
	}
]

var initial_value:int = 42

var test:TestBase

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass


func _init(initiator:TestBase) -> void:
	test = initiator


func _get_phase_count() -> int: return phases.size()

func _get_phase_name(phase_idx:int) -> String:
	assert( phase_idx >= 0 and phase_idx < get_phase_count() )
	var phase:Dictionary = phases[phase_idx]
	return phase.get(&'name', 'unnamed')


func _get_strategy_count(phase_idx:int) -> int:
	assert( phase_idx >= 0 and phase_idx < get_phase_count() )
	var phase:Dictionary = phases[phase_idx]
	var strats:Array = phase.get(&'strategies', [])
	return strats.size()


func _get_strategy(phase_idx:int, strategy_idx:int) -> Callable:
	var phase:Dictionary = phases[phase_idx]
	var strats:Array = phase.get(&'strategies', [])
	if strats.is_empty(): return null_strategy # defined in the Strategy Base
	return strats[strategy_idx]


#                     ███████ ██       ██████  ██     ██                       #
#                     ██      ██      ██    ██ ██     ██                       #
#                     █████   ██      ██    ██ ██  █  ██                       #
#                     ██      ██      ██    ██ ██ ███ ██                       #
#                     ██      ███████  ██████   ███ ███                        #
func                        __________FLOW___________              ()->void:pass

## A selection is an array of strategies, one for each phase.
func _flow( selection:Array[int] ) -> void:
	_included_tables()
	test.logp("[b]== Flow ==[/b]")

	# encode
	var encode:Callable = get_strategy(ENCODING, selection[ENCODING])
	test.logp(" --- %s ---" % encode.get_method().capitalize())
	var packed:PackedByteArray = encode.call()
	if not test.TEST_FALSE_RET(packed.is_empty(),
		"result of encoding should not be empty"): return
	test.logd("bytes: %s" % TestBase.bytes_view(packed) )

	# decode
	var decode:Callable = get_strategy(DECODING, selection[DECODING])
	test.logp(" --- %s ---" % decode.get_method().capitalize())
	var unpacked:Schema.minimum_schema.Minimum = decode.call(packed)

	# Verify
	test.logp(" --- %s ---" % "verify".capitalize())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(unpacked.verify(verifier),
			"verifying decoded table must pass"):
		return

	# use
	var use:Callable = get_strategy(USING, selection[USING])
	test.logp(" --- %s ---" % use.get_method().capitalize())
	var can_use:bool = use.call(unpacked)
	if can_use: pass


#               ██████  ██   ██  █████  ███████ ███████ ███████                #
#               ██   ██ ██   ██ ██   ██ ██      ██      ██                     #
#               ██████  ███████ ███████ ███████ █████   ███████                #
#               ██      ██   ██ ██   ██      ██ ██           ██                #
#               ██      ██   ██ ██   ██ ███████ ███████ ███████                #
func                        __________PHASES_________              ()->void:pass

func encode_a() -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var offset:int = Schema.minimum_schema.create_Minimum(fbb, initial_value)
	fbb.finish( offset )
	return fbb.get_buffer()


func decode_a(buf:PackedByteArray) -> Variant:
	var mininum:Schema.minimum_schema.Minimum = Schema.minimum_schema.get_Minimum(buf)
	return mininum


func use_a( minimum:Schema.minimum_schema.Minimum ) -> int:
	test.TEST_EQ(initial_value, minimum.my_field(),
			"Initial value and decompiled value should be the same")
	return TestBase.RetCode.TEST_OK


func _included_tables() -> void:
	_included_present()
	_included_absent()
	_included_empty_array()


func _included_present() -> void:
	var fbb := FlatBufferBuilder.new()
	var kept:int = Schema.minimum_schema.create_Minimum(fbb, 42)
	var zeroed:int = Schema.minimum_schema.create_Minimum(fbb, 0)
	if not test.TEST_TRUE_RET(kept != 0 and zeroed != 0, "included tables"):
		return
	var array_offset:int = fbb.create_vector_offset(PackedInt32Array([zeroed, kept]))
	if not test.TEST_TRUE_RET(array_offset != 0, "included array"):
		return
	var root_offset:int = Schema.create_RootTable(fbb, kept, array_offset)
	if not test.TEST_TRUE_RET(root_offset != 0, "included root"):
		return
	fbb.finish(root_offset)
	var root:Schema.RootTable = Schema.get_RootTable(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "included root verifies"):
		return
	test.TEST_TRUE(root.external_is_present(), "external present")
	var external:Schema.minimum_schema.Minimum = root.external()
	test.TEST_EQ(42, external.my_field(), "external field")
	test.TEST_TRUE(external.my_field_is_present(), "non-default included field stored")
	test.TEST_EQ(2, root.external_array_size(), "array size")
	var zero_row:Schema.minimum_schema.Minimum = root.external_array_at(0)
	test.TEST_FALSE(zero_row.my_field_is_present(), "included default elided")
	test.TEST_EQ(0, zero_row.my_field(), "included default reads 0")
	test.TEST_EQ(42, root.external_array_at(1).my_field(), "shared included row")


func _included_absent() -> void:
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.RootTableBuilder.new(fbb)
	fbb.finish(builder.finish())
	var root:Schema.RootTable = Schema.get_RootTable(fbb.get_buffer())
	test.TEST_FALSE(root.external_is_present(), "external absent")
	test.TEST_EQ(null, root.external(), "absent external")
	test.TEST_FALSE(root.external_array_is_present(), "array absent")
	test.TEST_EQ(0, root.external_array_size(), "absent array size")


func _included_empty_array() -> void:
	var fbb := FlatBufferBuilder.new()
	var kept:int = Schema.minimum_schema.create_Minimum(fbb, 3)
	var array_offset:int = fbb.create_vector_offset(PackedInt32Array())
	if not test.TEST_TRUE_RET(array_offset != 0, "empty included array"):
		return
	var root_offset:int = Schema.create_RootTable(fbb, kept, array_offset)
	if not test.TEST_TRUE_RET(root_offset != 0, "root beside empty array"):
		return
	fbb.finish(root_offset)
	var root:Schema.RootTable = Schema.get_RootTable(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "empty included array verifies"):
		return
	test.TEST_TRUE(root.external_array_is_present(), "empty array present")
	test.TEST_EQ(0, root.external_array_size(), "empty array size")
	test.TEST_EQ(3, root.external().my_field(), "external beside empty array")
