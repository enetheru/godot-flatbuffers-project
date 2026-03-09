@tool
extends "strategy.gd"

const TB = preload("uid://ldu0vpkadrjd")


const schema_file = "res://tests/flatbuffers/schemas/minimum.fbs"
const Schema = preload("schemas/minimum_generated.gd")


var value:int = TB.u32

enum {
	ENCODING = 0,
	VERIFYING,
	DECODING,
	USING
}

func get_phase_count() -> int:
	return 4

func get_phase_name(phase:int) -> String:
	assert( phase >= 0 and phase < get_phase_count() )
	match phase:
		0: return "Encoding"
		1: return "Verifying"
		2: return "Decoding"
		3: return "Using"
	return ""

func get_strategy_count(phase:int) -> int:
	assert( phase >= 0 and phase < get_phase_count() )
	match phase:
		0: return 2
		1: return 1
		2: return 1
		3: return 1
	return 0

func get_strategy(phase:int, strategy:int) -> Callable:
	assert( phase >= 0 and phase < get_phase_count() )
	assert( strategy >= 0 and strategy < get_strategy_count(phase) )
	match phase:
		#0: return encoding_strategies[strategy]
		0: return [encode_a, encode_b][strategy]
		1: return verifying
		2: return decoding
		3: return using
	return func()->void: pass

## A selection is an array of strategies, one for each phase.
func flow( selection:Array[int] ) -> void:
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


var encoding_strategies:Array[Callable] = [
	encode_a,
	encode_b
]

## encoding method a, use the Schema.create_ function
func encode_a() -> PackedByteArray:
	test.logd("starting value: %X" % value )
	var fbb := FlatBufferBuilder.new()
	var rt_offset:int = Schema.create_Minimum(fbb, value )
	fbb.finish( rt_offset )

	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	test.logd("bytes: %s" % TB.bytes_view(bytes) )
	return bytes


## encoding method a, use the Schema.*Builder helper class
func encode_b() -> PackedByteArray:
	test.logd("starting value: %X" % value )
	var fbb := FlatBufferBuilder.new()
	var mbb := Schema.MinimumBuilder.new(fbb)
	mbb.add_my_field(value)
	var ofs:int = mbb.finish()
	fbb.finish(ofs)

	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	test.logd("bytes: %s" % TB.bytes_view(bytes) )
	return bytes


func verifying( _buf:PackedByteArray ) -> int:
	#logp("[b]== Verification ==[/b]")
	#var verifier := FlatBufferVerifier.new()
	#verifier.set_buffer(bytes)

	# TODO requires code generation changes
	# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
	return TB.RetCode.TEST_OK


func decoding( buf:PackedByteArray ) -> Variant:
	var decoded:Schema.Minimum = Schema.get_Minimum(buf)
	return decoded


func using( variant:Variant ) -> int:
	var decoded:Schema.Minimum = variant
	test.TEST_EQ(value, decoded.my_field(), "rt.my_field()")
	test.logd("decoded value: %X" % decoded.my_field() )
	return TB.RetCode.TEST_OK





## Because we cannot pre-load a script that hasnt been generated yet, the test
## script must load this script after the generated script has been created so
## that this script can preload and use it properly.
## It's a bit convoluted yes.

var test:TestBase
func _init(initiator:TestBase) -> void:
	test = initiator
