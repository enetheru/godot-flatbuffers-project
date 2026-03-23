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
		&"strategies":[encode_a]
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

func encode_a() -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()

	# Setting fields to -1
	var offset:int = Schema.create_RootTable(fbb,
		true,	# f_bool	== true
		-1,		# f_byte	== -1
		-1,		# f_ubyte	== 255
		-1,		# f_short	== -1
		-1,		# f_ushort	== 65535
		-1,		# f_int		== -1
		-1,		# f_uint	== 4294967295
		-1,		# f_long	== -1
		-1,		# f_ulong	== -1 ? This one is confusing to me
		-1,		# f_float	== -1: we need better tests
		-1		# f_double	== -1: we need better tests
		)
	fbb.finish(offset)
	return fbb.get_buffer()

func decode_a(data:PackedByteArray) -> Schema.RootTable:
	# Decode buffer
	var fbo : Schema.RootTable = Schema.get_RootTable(data)
	test.TEST_TRUE( fbo.f_bool(), " f_bool()")
	test.TEST_EQ(fbo.f_byte(), -1, "f_byte()" )
	test.TEST_EQ(fbo.f_ubyte(), 255, "f_ubyte()" )
	test.TEST_EQ(fbo.f_short(), -1, "f_short()" )
	test.TEST_EQ(fbo.f_ushort(), 65_535, "f_ushort()" )
	test.TEST_EQ(fbo.f_int(), -1, "f_int()" )
	test.TEST_EQ(fbo.f_uint(), 4_294_967_295, "f_uint()" )
	test.TEST_EQ(fbo.f_long(), -1, "f_long()" )
	test.TEST_EQ(fbo.f_ulong(), -1, "f_ulong()" )
	test.TEST_EQ(fbo.f_float(), -1, "f_float()" )
	test.TEST_EQ(fbo.f_double(), -1, "f_double()" )
	return fbo


func use_a( decoded:Schema.RootTable ) -> int:
	test.TEST_EQ(-1, decoded.f_double(), "rt.f_double()")
	test.logd("decoded value: %X" % decoded.f_double() )
	return TestBase.RetCode.TEST_OK
