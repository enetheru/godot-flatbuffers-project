@tool
extends TestStrategy

const Schema = preload("../schemas/string_generated.gd")

enum {
	ENCODING = 0,
	DECODING,
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_function, encode_builder, encode_manual]
		# TODO: I want some way to create dependencies between the strategies
	},{
		&"name":"Decoding",
		&"strategies":[decode_function, decode_manual]
	}
	# TODO implement a use function.
]

var test_string : String = "This is a string that I am adding to te flatbuffer"


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

#               ██████  ██   ██  █████  ███████ ███████ ███████                #
#               ██   ██ ██   ██ ██   ██ ██      ██      ██                     #
#               ██████  ███████ ███████ ███████ █████   ███████                #
#               ██      ██   ██ ██   ██      ██ ██           ██                #
#               ██      ██   ██ ██   ██ ███████ ███████ ███████                #
func                        __________PHASES_________              ()->void:pass
func                        __Encode_________________              ()->void:pass
#region Encode
#MARK: Encode
## │ ___                 _        [br]
## │| __|_ _  __ ___  __| |___    [br]
## │| _|| ' \/ _/ _ \/ _` / -_)   [br]
## │|___|_||_\__\___/\__,_\___|   [br]
## ╰───────────────────────────── [br]
## Encode By-Line
##
## Encode Description

func encode_function() -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()

	var string_ofs:int = fbb.create_variant( test_string )

	var offset:int = Schema.create_RootTable(fbb, string_ofs)
	fbb.finish(offset)
	return fbb.get_buffer()


func encode_builder() -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()

	# Encode the string first to get the offset.
	var string_offset:int = fbb.create_variant( test_string )

	# Construct the builder and add the items.
	var root_builder := Schema.RootTableBuilder.new( fbb )
	root_builder.add_my_string( string_offset )

	# Finishe the buffer and get the bytes
	fbb.finish( root_builder.finish() )
	return fbb.get_buffer()


func encode_manual() -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var string_ofs:int = fbb.create_variant(test_string)
	var sto:int = fbb.start_table()
	fbb.add_offset(4, string_ofs )
	var eto:int = fbb.end_table(sto)
	# Finish the buffer and get the bytes
	fbb.finish( eto )
	return fbb.get_buffer()

#endregion Encode


func                        __Decode_________________              ()->void:pass
#region Decode
#MARK: Decode
## │ ___                 _        [br]
## │|   \ ___ __ ___  __| |___    [br]
## │| |) / -_) _/ _ \/ _` / -_)   [br]
## │|___/\___\__\___/\__,_\___|   [br]
## ╰───────────────────────────── [br]
## Decode By-Line
##
## Decode Description

func decode_manual(buf:PackedByteArray) -> Schema.RootTable:
	var rtl:int = buf.decode_u32(0)
	test.logd("root_table_pos: %d" % rtl)
	var vtl:int = rtl - buf.decode_s32(rtl)
	test.logd("vtable_pos: %d" % rtl)
	var vts:int = buf.decode_s16(vtl)
	test.logd("vtable_size: %d" % vts)
	var rts:int = buf.decode_s16(vtl+2)
	test.logd("root_table_size: %d" % rts)

	var f0o:int = buf.decode_s16(vtl+4)
	test.logd("field0_offset: %d" % f0o)

	# I am going offset from table. but it might be offset from current location.
	# I will only be able to tell on a multi-field object.
	var f0l:int = rtl + f0o
	test.logd("field0_location: %d" % f0l)

	# field0 is a string, so the value at the location is an offset.
	var f0v:int = buf.decode_u32(f0l)
	test.logd("field0_value: %d" % f0v)

	# the location of the string is the field location + the decoded offset.
	var sl:int = f0l + f0v
	test.logd("string_location: %d" % sl)

	# Now we know where the string is, does it look like a flatbuffers string?
	var ss:int = buf.decode_u32(sl)
	test.logd("string_size: %d" % ss)
	# string length in godot does not count the null termination, but getting the size
	# from the flatbuffer is the size in bytes, which includes a null termination.
	test.TEST_EQ(test_string.length() +1, ss, "decoded size, and original size should be the same")

	# get the string directly from the buffer using slice.
	var decoded_string:String = buf.slice(sl+4, sl+4+ss).get_string_from_utf8()
	test.TEST_EQ(test_string, decoded_string, "decoded string, and original string should be the same")

	# This is to pass onto the use function which isnt really necessary for my
	# testing. pehraps I should remove it.
	var fbo : Schema.RootTable = Schema.get_RootTable(buf)
	test.TEST_EQ( fbo.my_string(), test_string, "my_string()" )

	return fbo


func decode_function(buf:PackedByteArray) -> Schema.RootTable:
	var fbo : Schema.RootTable = Schema.get_RootTable(buf)
	test.TEST_EQ( fbo.my_string(), test_string, "my_string()" )
	return fbo

#endregion Decode
