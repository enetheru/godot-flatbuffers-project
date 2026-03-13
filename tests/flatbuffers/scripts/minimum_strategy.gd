@tool
extends TestStrategy


const Schema = preload("../schemas/minimum_generated.gd")


var value:int = TestBase.u32

enum {
	ENCODING = 0,
	VERIFYING,
	DECODING,
	USING
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_function, encode_builder, encode_manual]
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

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

## Because we cannot pre-load a script that hasnt been generated yet, the test
## script must load this script after the generated script has been created so
## that this script can preload and use it properly.
## It's a bit convoluted yes.
var test:TestBase
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

func                        __Encoding_______________              ()->void:pass
#region Encoding
#MARK: Encoding
##                                        [br]
## │ ___                 _ _              [br]
## │| __|_ _  __ ___  __| (_)_ _  __ _    [br]
## │| _|| ' \/ _/ _ \/ _` | | ' \/ _` |   [br]
## │|___|_||_\__\___/\__,_|_|_||_\__, |   [br]
## ╰─────────────────────────────|___/─── [br]
## Encoding By-Line
##
## Encoding Description

## Encode the object without the Generated script
func encode_manual() -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var ts:int = fbb.start_table()
	fbb.add_element_int(4, value)
	var te:int = fbb.end_table(ts)
	fbb.finish(te)
	return fbb.to_packed_byte_array()


## encoding method a, use the Schema.create_ function
func encode_function() -> PackedByteArray:
	test.logd("starting value: %X" % value )
	var fbb := FlatBufferBuilder.new()
	var rt_offset:int = Schema.create_Minimum(fbb, value )
	fbb.finish( rt_offset )

	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	test.logd("bytes: %s" % TestBase.bytes_view(bytes) )
	return bytes


## encoding method a, use the Schema.*Builder helper class
func encode_builder() -> PackedByteArray:
	test.logd("starting value: %X" % value )
	var fbb := FlatBufferBuilder.new()
	var mbb := Schema.MinimumBuilder.new(fbb)
	mbb.add_my_field(value)
	var ofs:int = mbb.finish()
	fbb.finish(ofs)

	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	test.logd("bytes: %s" % TestBase.bytes_view(bytes) )
	return bytes

#endregion encoding


func                        __Verification___________              ()->void:pass
#region Verification
#MARK: Verification
## │__   __       _  __ _         _   _             [br]
## │\ \ / /__ _ _(_)/ _(_)__ __ _| |_(_)___ _ _     [br]
## │ \ V / -_) '_| |  _| / _/ _` |  _| / _ \ ' \    [br]
## │  \_/\___|_| |_|_| |_\__\__,_|\__|_\___/_||_|   [br]
## ╰─────────────────────────────────────────────── [br]
## Verification By-Line
##
## Verification Description

func verify_a( _buf:PackedByteArray ) -> int:
	#logp("[b]== Verification ==[/b]")
	#var verifier := FlatBufferVerifier.new()
	#verifier.set_buffer(bytes)

	# TODO requires code generation changes
	# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
	return TestBase.RetCode.TEST_OK

#endregion Verification


func                        __Decoding_______________              ()->void:pass
#region Decoding
#MARK: Decoding
##                                        [br]
## │ ___                 _ _              [br]
## │|   \ ___ __ ___  __| (_)_ _  __ _    [br]
## │| |) / -_) _/ _ \/ _` | | ' \/ _` |   [br]
## │|___/\___\__\___/\__,_|_|_||_\__, |   [br]
## ╰─────────────────────────────|___/─── [br]
## Decoding By-Line
##
## Decoding Description

func decode_a( buf:PackedByteArray ) -> Variant:
	var decoded:Schema.Minimum = Schema.get_Minimum(buf)
	return decoded

#endregion Decoding


func                        __Usage__________________              ()->void:pass
#region Usage
#MARK: Usage
##                              [br]
## │ _   _                      [br]
## │| | | |___ __ _ __ _ ___    [br]
## │| |_| (_-</ _` / _` / -_)   [br]
## │ \___//__/\__,_\__, \___|   [br]
## ╰───────────────|___/─────── [br]
## Usage By-Line
##
## Usage Description

func use_a( variant:Variant ) -> int:
	var decoded:Schema.Minimum = variant
	test.TEST_EQ(value, decoded.my_field(), "rt.my_field()")
	test.logd("decoded value: %X" % decoded.my_field() )
	return TestBase.RetCode.TEST_OK
#endregion Usage
