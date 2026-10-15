@tool
extends TestStrategy

const Schema = preload("../schemas/struct_generated.gd")

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

var value:Dictionary = {
	&'is_true': true,
	&'x': 2,
	&'y': 3.5,
	&'w': Vector3(4,5,6),
}


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
	var unpacked:Schema.CustomStruct = decode.call(packed)

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
	_table_cases()
	_struct_span()

#               ██████  ██   ██  █████  ███████ ███████ ███████                #
#               ██   ██ ██   ██ ██   ██ ██      ██      ██                     #
#               ██████  ███████ ███████ ███████ █████   ███████                #
#               ██      ██   ██ ██   ██      ██ ██           ██                #
#               ██      ██   ██ ██   ██ ███████ ███████ ███████                #
func                        __________PHASES_________              ()->void:pass

func encode_a() -> PackedByteArray:
	# struct
	var cs := Schema.CustomStruct.new()
	cs.is_true = value.is_true
	cs.x = value.x
	cs.y = value.y
	cs.w = value.w
	return cs.get_bytes()


func decode_a(buf:PackedByteArray) -> Schema.CustomStruct:
	# Decode buffer
	var struct:Schema.CustomStruct = Schema.CustomStruct.new(buf)
	print( "decode.is_true: ", struct.is_true )
	print( "decode.x: ", struct.x )
	print( "decode.y: ", struct.y )
	print( "decode.w: ", struct.w )

	test.TEST_EQ(value.is_true, struct.is_true, "is_true")
	test.TEST_EQ(value.x, struct.x, "x")
	test.TEST_EQ(value.y, struct.y, "y")
	test.TEST_EQ(value.w, struct.w, "w")
	return struct


func use_a(decoded:Schema.CustomStruct) -> int:
	test.TEST_EQ(value.is_true, decoded.is_true, "use is_true")
	test.TEST_EQ(value.w, decoded.w, "use w")
	return TestBase.RetCode.TEST_OK


func _table_cases() -> void:
	var cs := Schema.CustomStruct.new()
	cs.is_true = false
	cs.x = -4
	cs.y = 3.5
	cs.w = Vector3(-1, 0, 2)
	var fbb := FlatBufferBuilder.new()
	fbb.finish(Schema.create_RootTable(fbb, cs, 9))
	var root:Schema.RootTable = Schema.get_RootTable(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "table verify"):
		return
	test.TEST_TRUE(root.custom_struct_is_present(), "struct field present")
	test.TEST_TRUE(root.z_is_present(), "z present")
	test.TEST_EQ(9, root.z(), "z")
	var got:Schema.CustomStruct = root.custom_struct()
	if not test.TEST_TRUE_RET(got != null, "struct object"):
		return
	test.TEST_FALSE(got.is_true, "embedded is_true false")
	test.TEST_EQ(-4, got.x, "embedded x")
	test.TEST_EQ(3.5, got.y, "embedded y")
	test.TEST_EQ(Vector3(-1, 0, 2), got.w, "embedded w")
	test.TEST_TRUE(got.verify(verifier), "embedded struct span fits")

	var absent_fbb := FlatBufferBuilder.new()
	var absent_builder := Schema.RootTableBuilder.new(absent_fbb)
	absent_builder.add_z(4)
	absent_fbb.finish(absent_builder.finish())
	var absent:Schema.RootTable = Schema.get_RootTable(absent_fbb.get_buffer())
	if test.TEST_TRUE_RET(absent.verify(FlatBufferVerifier.new()), "absent struct verifies"):
		test.TEST_FALSE(absent.custom_struct_is_present(), "struct absent")
		test.TEST_EQ(null, absent.custom_struct(), "absent struct is null")
		test.TEST_EQ(4, absent.z(), "z beside absent struct")

	var elided_fbb := FlatBufferBuilder.new()
	var elided_builder := Schema.RootTableBuilder.new(elided_fbb)
	elided_builder.add_z(0)
	elided_fbb.finish(elided_builder.finish())
	var elided:Schema.RootTable = Schema.get_RootTable(elided_fbb.get_buffer())
	test.TEST_FALSE(elided.z_is_present(), "z default elided")
	test.TEST_EQ(0, elided.z(), "z default reads 0")
	test.TEST_TRUE(elided.verify(FlatBufferVerifier.new()), "elided z verifies")


func _struct_span() -> void:
	var verifier := FlatBufferVerifier.new()
	var fitted := Schema.CustomStruct.new()
	test.TEST_TRUE(fitted.verify(verifier), "struct span fits")

	var bytes := PackedByteArray()
	bytes.resize(Schema.CustomStruct._fb_struct_size)
	var overrun := Schema.CustomStruct.new()
	overrun.assign_buffer(bytes, 1)
	test.TEST_FALSE(overrun.verify(verifier), "struct offset overruns the buffer")


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



#endregion BoilerPlate
