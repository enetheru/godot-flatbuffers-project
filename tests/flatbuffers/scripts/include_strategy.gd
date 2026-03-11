@tool
extends TestStrategy

const Print = preload("uid://cbluyr4ifn8g3")
const Schema = preload("../schemas/include_generated.gd")

const u32 = TestBase.u32
const u32_ = TestBase.u32_
const u64 = TestBase.u64
const u64_ = TestBase.u64_

enum {
	ENCODING = 0,
	VERIFYING,
	DECODING,
	USING
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_a]
		# TODO: I want some way to create dependencies between the strategies
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

var initial_value:int = 42

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

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
	test.logp("[b]== Flow ==[/b]")
	# encode
	var encode:Callable = get_strategy(ENCODING, selection[ENCODING])
	test.logp(" --- %s ---" % encode.get_method().capitalize())
	var packed:PackedByteArray = encode.call()
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
	var offset:int = Schema.minimum_schema.create_Minimum(fbb, initial_value)
	fbb.finish( offset )
	return fbb.to_packed_byte_array()


func verify_a( _buf:PackedByteArray ) -> int:
	#logp("[b]== Verification ==[/b]")
	#var verifier := FlatBufferVerifier.new()
	#verifier.set_buffer(bytes)

	# TODO requires code generation changes
	# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
	return TestBase.RetCode.TEST_OK


func decode_a(buf:PackedByteArray) -> Variant:
	var mininum:Schema.minimum_schema.Minimum = Schema.minimum_schema.get_Minimum(buf)
	return mininum


func use_a( variant:Variant ) -> int:
	var mininum:Schema.minimum_schema.Minimum = variant
	test.TEST_EQ(initial_value, mininum.my_field(),
			"Initial value and decompiled value should be the same")
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
