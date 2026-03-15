@tool
extends TestStrategy

const Schema = preload("../schemas/scalar_generated.gd")

enum {
	ENCODING = 0,
	VERIFYING,
	DECODING,
	USING
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_a]
	},{
		&"name":"Verifying",
		&"strategies":[verify_a]
	},{
		&"name":"Decoding",
		&"strategies":[decode_a]
	},{
		&"name":"Using",
		&"strategies":[use_a]
	}
]

var value:int = TestBase.u32

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

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
	# validate
	var verify:Callable = get_strategy(VERIFYING, selection[VERIFYING])
	test.logp(" --- %s ---" % verify.get_method().capitalize())
	var is_verified:bool = verify.call(packed)
	if is_verified: pass
	# decode
	var decode:Callable = get_strategy(DECODING, selection[DECODING])
	test.logp(" --- %s ---" % decode.get_method().capitalize())
	var unpacked:Variant = decode.call(packed)
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


func verify_a( _buf:PackedByteArray ) -> int:
	#logp("[b]== Verification ==[/b]")
	#var verifier := FlatBufferVerifier.new()
	#verifier.set_buffer(bytes)

	# TODO requires code generation changes
	# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
	return TestBase.RetCode.TEST_OK


func decode_a(data:PackedByteArray) -> Variant:
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


func use_a( variant:Variant ) -> int:
	var decoded:Schema.RootTable = variant
	test.TEST_EQ(-1, decoded.f_double(), "rt.f_double()")
	test.logd("decoded value: %X" % decoded.f_double() )
	return TestBase.RetCode.TEST_OK



func                        __BoilerPlate____________              ()->void:pass
#region BoilerPlate
#MARK: BoilerPlate
## │ ___      _ _         ___ _      _          [br]
## │| _ ) ___(_) |___ _ _| _ \ |__ _| |_ ___    [br]
## │| _ \/ _ \ | / -_) '_|  _/ / _` |  _/ -_)   [br]
## │|___/\___/_|_\___|_| |_| |_\__,_|\__\___|   [br]
## ╰─────────────────────────────────────────── [br]
## Because we cannot pre-load a script that hasnt been generated yet, the test
## script must load this script after the generated script has been created so
## that this script can preload and use it properly.
## It's a bit convoluted yes.

var test:TestBase
func _init(initiator:TestBase) -> void:
	test = initiator

#endregion BoilerPlate
