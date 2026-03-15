@tool
extends TestStrategy


const Schema = preload("../schemas/attribute_generated.gd")

enum {
	ENCODING = 0,
	VERIFYING,
	DECODING,
	USING
}

var simple_tests:Array[Callable] = []

var phases:Array[Dictionary] = [
	#{
		#&"name":"Encoding",
		#&"strategies":[]
	#},{
		#&"name":"Verifying",
		#&"strategies":[]
	#},{
		#&"name":"Decoding",
		#&"strategies":[]
	#},{
		#&"name":"Using",
		#&"strategies":[]
	#}
]


var value:int = TestBase.u32
var want_simple_tests:bool = true


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
func _flow( _selection:Array[int] ) -> void:
	if want_simple_tests:
		for simple:Callable in simple_tests:
			if simple.call(): return
	want_simple_tests = false
	return
	#test.logp("[b]== Flow ==[/b]")
	## encode
	#var encode:Callable = get_strategy(ENCODING, selection[ENCODING])
	#test.logp(" --- %s ---" % encode.get_method().capitalize())
	#var packed:PackedByteArray = encode.call()
	#if not test.TEST_FALSE_RET(packed.is_empty(),
		#"result of encoding should not be empty"): return
	## validate
	#var verify:Callable = get_strategy(VERIFYING, selection[VERIFYING])
	#test.logp(" --- %s ---" % verify.get_method().capitalize())
	#var is_verified:bool = verify.call(packed)
	#if is_verified: pass
	## decode
	#var decode:Callable = get_strategy(DECODING, selection[DECODING])
	#test.logp(" --- %s ---" % decode.get_method().capitalize())
	#var unpacked:Variant = decode.call(packed)
	## use
	#var use:Callable = get_strategy(USING, selection[USING])
	#test.logp(" --- %s ---" % use.get_method().capitalize())
	#var can_use:bool = use.call(unpacked)
	#if can_use: pass


#                ███████ ██ ███    ███ ██████  ██      ███████                 #
#                ██      ██ ████  ████ ██   ██ ██      ██                      #
#                ███████ ██ ██ ████ ██ ██████  ██      █████                   #
#                     ██ ██ ██  ██  ██ ██      ██      ██                      #
#                ███████ ██ ██      ██ ██      ███████ ███████                 #
func                        __________SIMPLE_________              ()->void:pass

## simple tests should return true if they want to halt the testing. and false
## if its OK to continue.
func deprecated_field() -> bool:
	var test_object := Schema.Attribute.new()
	test.TEST_FALSE(test_object.has_method(&"deprecated_field"))
	return false

#               ██████  ██   ██  █████  ███████ ███████ ███████                #
#               ██   ██ ██   ██ ██   ██ ██      ██      ██                     #
#               ██████  ███████ ███████ ███████ █████   ███████                #
#               ██      ██   ██ ██   ██      ██ ██           ██                #
#               ██      ██   ██ ██   ██ ███████ ███████ ███████                #
func                        __________PHASES_________              ()->void:pass

## encoding method a, use the Schema.create_ function
func encode_a() -> PackedByteArray:
	return []


func verify_a( _buf:PackedByteArray ) -> int:
	#logp("[b]== Verification ==[/b]")
	#var verifier := FlatBufferVerifier.new()
	#verifier.set_buffer(bytes)

	# TODO requires code generation changes
	# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
	return TestBase.RetCode.TEST_OK


func decode_a( _buf:PackedByteArray ) -> Variant:
	return null


func use_a( _variant:Variant ) -> int:
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
