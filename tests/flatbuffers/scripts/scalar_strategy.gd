@tool
extends TestStrategy

const Schema = preload("../schemas/scalar_generated.gd")

enum {
	ENCODING = 0,
	DECODING,
	USING
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[
			encode_sentinel,
			encode_omitted,
			encode_defaults,
			encode_extremes,
			encode_highs,
		]
	},{
		&"name":"Decoding",
		&"strategies":[decode_a]
	},{
		&"name":"Using",
		&"strategies":[use_a]
	}
]

var value:int = TestBase.u32
var test:TestBase
## True when every field was stored. False when each field is the schema default.
var expect_present:bool = true
var expect:Dictionary = {}

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init(initiator:TestBase) -> void:
	test = initiator

func _get_phase_count() -> int:
	return phases.size()


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
	assert( phase_idx >= 0 and phase_idx < get_phase_count() )
	var phase:Dictionary = phases[phase_idx]
	var strats:Array = phase.get(&'strategies', [])
	if strats.is_empty(): return null_strategy # defined in the Strategy Base
	assert( strategy_idx >= 0 and strategy_idx < strats.size() )
	return strats[strategy_idx]


#                     ███████ ██       ██████  ██     ██                       #
#                     ██      ██      ██    ██ ██     ██                       #
#                     █████   ██      ██    ██ ██  █  ██                       #
#                     ██      ██      ██    ██ ██ ███ ██                       #
#                     ██      ███████  ██████   ███ ███                        #
func                        __________FLOW___________              ()->void:pass

## A selection is an array of strategies, one for each phase.
func _flow( selection:Array[int] ) -> void:
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
	var unpacked:Schema.RootTable = decode.call(packed)

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

func _set_expect(present:bool, values:Dictionary) -> void:
	expect_present = present
	expect = values


func _zeros() -> Dictionary:
	return {
		"f_bool": false,
		"f_byte": 0,
		"f_ubyte": 0,
		"f_short": 0,
		"f_ushort": 0,
		"f_int": 0,
		"f_uint": 0,
		"f_long": 0,
		"f_ulong": 0,
		"f_float": 0.0,
		"f_double": 0.0,
	}


## Godot float is 64-bit. The float field stores float32.
func _float32(value:float) -> float:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	return bytes.decode_float(0)


func _finish_create(
		f_bool:bool,
		f_byte:int,
		f_ubyte:int,
		f_short:int,
		f_ushort:int,
		f_int:int,
		f_uint:int,
		f_long:int,
		f_ulong:int,
		f_float:float,
		f_double:float) -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var offset:int = Schema.create_RootTable(fbb,
		f_bool, f_byte, f_ubyte, f_short, f_ushort,
		f_int, f_uint, f_long, f_ulong, f_float, f_double)
	fbb.finish(offset)
	return fbb.get_buffer()


func encode_sentinel() -> PackedByteArray:
	# -1 sets every bit of each width. Godot has no u64, so ulong reads back as -1.
	_set_expect(true, {
		"f_bool": true,
		"f_byte": -1,
		"f_ubyte": 255,
		"f_short": -1,
		"f_ushort": 65_535,
		"f_int": -1,
		"f_uint": 4_294_967_295,
		"f_long": -1,
		"f_ulong": -1,
		"f_float": -1.0,
		"f_double": -1.0,
	})
	return _finish_create(true, -1, -1, -1, -1, -1, -1, -1, -1, -1.0, -1.0)


func encode_omitted() -> PackedByteArray:
	_set_expect(false, _zeros())
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.RootTableBuilder.new(fbb)
	fbb.finish(builder.finish())
	return fbb.get_buffer()


func encode_defaults() -> PackedByteArray:
	# add_*_default must drop values that equal the schema default.
	_set_expect(false, _zeros())
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.RootTableBuilder.new(fbb)
	builder.add_f_double(0.0)
	builder.add_f_ulong(0)
	builder.add_f_long(0)
	builder.add_f_float(0.0)
	builder.add_f_uint(0)
	builder.add_f_int(0)
	builder.add_f_ushort(0)
	builder.add_f_short(0)
	builder.add_f_ubyte(0)
	builder.add_f_byte(0)
	builder.add_f_bool(false)
	fbb.finish(builder.finish())
	return fbb.get_buffer()


func encode_extremes() -> PackedByteArray:
	# 2^24+1 is not a float32. The float field rounds; the double field does not.
	var over_mantissa := 16_777_217.0
	var long_min:int = -9_223_372_036_854_775_807 - 1
	_set_expect(true, {
		"f_bool": true,
		"f_byte": -128,
		"f_ubyte": 128,
		"f_short": -32_768,
		"f_ushort": 32_768,
		"f_int": -2_147_483_648,
		"f_uint": 2_147_483_648,
		"f_long": long_min,
		"f_ulong": long_min,
		"f_float": _float32(over_mantissa),
		"f_double": over_mantissa,
	})
	return _finish_create(
		true, -128, 128, -32_768, 32_768, -2_147_483_648, 2_147_483_648,
		long_min, long_min, over_mantissa, over_mantissa)


func encode_highs() -> PackedByteArray:
	var frac := -0.1
	_set_expect(true, {
		"f_bool": true,
		"f_byte": 127,
		"f_ubyte": 254,
		"f_short": 32_767,
		"f_ushort": 65_534,
		"f_int": 2_147_483_647,
		"f_uint": 4_294_967_294,
		"f_long": 9_223_372_036_854_775_807,
		"f_ulong": 9_223_372_036_854_775_807,
		"f_float": _float32(frac),
		"f_double": frac,
	})
	return _finish_create(
		true, 127, 254, 32_767, 65_534, 2_147_483_647, 4_294_967_294,
		9_223_372_036_854_775_807, 9_223_372_036_854_775_807, frac, frac)


func _check_field(table:Schema.RootTable, field:String) -> void:
	var present:bool = Callable(table, field + "_is_present").call()
	if expect_present:
		test.TEST_TRUE(present, "%s present" % field)
	else:
		test.TEST_FALSE(present, "%s absent" % field)
	test.TEST_EQ(expect[field], Callable(table, field).call(), "%s()" % field)


func decode_a(data:PackedByteArray) -> Schema.RootTable:
	var fbo:Schema.RootTable = Schema.get_RootTable(data)
	for field:String in expect:
		_check_field(fbo, field)
	return fbo


func use_a(decoded:Schema.RootTable) -> int:
	test.TEST_EQ(expect["f_float"], decoded.f_float(), "rt.f_float()")
	test.TEST_EQ(expect["f_double"], decoded.f_double(), "rt.f_double()")
	test.TEST_EQ(expect["f_ulong"], decoded.f_ulong(), "rt.f_ulong()")
	return TestBase.RetCode.TEST_OK
