@tool
extends TestStrategy

const Print = preload("uid://cbluyr4ifn8g3")
const Schema = preload("../schemas/vector_generated.gd")

const TestEnum = Schema.TestEnum
const TestStruct = Schema.TestStruct
const TestTableA = Schema.TestTableA
const TestTableB = Schema.TestTableB
const TestUnion = Schema.TestUnion

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

enum ItemType {
	NONE,
	DEFAULT,
	WEAPON,
	FOOD,
	SPECIAL,
}

class Initial:

	# Vector of Scalars
	var scalars:Array = [0,1,2,3,4,5,6,7,8,9]

	# Vector of Enums
	var enums:Array[TestEnum] = [TestEnum.ZERO, TestEnum.ONE, TestEnum.ZERO ]

	# Vector of Strings
	var strings:Array[String] = ["An", "Array", "Of", "Strings"]

	# Vector of Godot Structs
	var godot_structs:Array[Vector3] = [
		Vector3(1,2,3),
		Vector3(4,5,6),
		Vector3(7,8,9),
		]

	# Vector of Custom Structs
	var custom_structs:Array[TestStruct] = [
		Schema.create_TestStruct(1,2),
		Schema.create_TestStruct(3,4),
		Schema.create_TestStruct(5,6),
		]

	# Vector of Tables
	var tables:Array[TestTableA] = []

	# Vector of Unions
	var unions:Array[TestUnion] = []

static var initial:Initial

func initialise() -> void:
	initial = Initial.new()



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
	# Reset the builder
	var fbb := FlatBufferBuilder.create(1)

	#scalars:[int];
	var scalars_ofs:int = fbb.create_PackedInt32Array(initial.scalars)

	#enums:[TestEnum];
	# FIXME It's not straight forward what data type i need to use when packing
	# enums. I wonder if I can make the builder a little more friendly to use.
	var enums_ofs:int = fbb.create_PackedByteArray(initial.enums)

	#strings:[string];
	var strings_ofs:int = fbb.create_PackedStringArray(initial.strings)

	#godot_structs:[Vector3];
	var godot_structs_ofs:int = fbb.create_PackedVector3Array(initial.godot_structs)

	#custom_structs:[TestStruct];
	var custom_structs_ofs:int = fbb.create_vector_of_custom_struct(
		initial.custom_structs, Schema.TestStruct._fb_struct_size )

	# Vector of Tables
	#tables:[TestTableA];

	# Temporary Union to check the differences between vectors and non vectors
	#single:TestUnion;

	# Vector of Unions
	#unions:[TestUnion];

	var rtb := Schema.RootTableBuilder.new(fbb)
	rtb.add_scalars(scalars_ofs)
	rtb.add_enums(enums_ofs)
	rtb.add_strings(strings_ofs)
	rtb.add_godot_structs(godot_structs_ofs)
	rtb.add_custom_structs(custom_structs_ofs)
	var rtb_ofs:int = rtb.finish()
	fbb.finish(rtb_ofs)

	return fbb.to_packed_byte_array()


func verify_a( _buf:PackedByteArray ) -> int:
	#logp("[b]== Verification ==[/b]")
	#var verifier := FlatBufferVerifier.new()
	#verifier.set_buffer(bytes)

	# TODO requires code generation changes
	# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
	return TestBase.RetCode.TEST_OK


func decode_a(buf:PackedByteArray) -> Variant:
	return Schema.get_RootTable(buf)


func use_a( variant:Variant ) -> int:
	## bag is the root of this buffer.
	var rtb:Schema.RootTable = variant

	# vector of scalars
	#if test.TEST_TRUE_RET(rtb.scalars_is_present()):
	var rtb_scalars:Array = rtb.scalars() # transform to basic array so we can compare
	test.TEST_EQ(initial.scalars, rtb_scalars,
		"contents of initial scalars should match the decoded scalars()")

	# vector of enum
	var rtb_enums:Array = rtb.enums() # transform to basic array so we can compare
	test.TEST_EQ(initial.enums, rtb_enums,
		"contents of initial enums should match the decoded enums()")

	# vector of strings
	if test.TEST_EQ_RET(initial.strings.size(), rtb.strings_size(),
			"size of initial strings should match the decoded strings_size()"):
		for i in initial.strings.size():
			test.TEST_EQ(initial.strings[i], rtb.strings_at(i),
					"strings_at(%d) should match initial.strings[%d]" % [i,i])

	# vector of structs
	if test.TEST_EQ_RET(initial.godot_structs.size(), rtb.godot_structs_size(),
			"size of initial godot_structs should match the decoded godot_structs_size()"):
		for i in initial.godot_structs.size():
			test.TEST_EQ(initial.godot_structs[i], rtb.godot_structs_at(i),
					"godot_structs_at(%d) should match initial.godot_structs[%d]" % [i,i])

	# vector of structs
	if test.TEST_EQ_RET(initial.custom_structs.size(), rtb.custom_structs_size(),
			"size of initial custom_structs should match the decoded custom_structs_size()"):
		pass
		for i in initial.custom_structs.size():
			var initial_custom_struct:Schema.TestStruct = initial.custom_structs[i]
			var decoded_custom_struct:Schema.TestStruct = rtb.custom_structs_at(i)
			test.TEST_EQ(initial_custom_struct.a, decoded_custom_struct.a,
					"custom_structs_at(%d).a should match initial.custom_structs[%d].a" % [i,i])
			test.TEST_EQ(initial_custom_struct.b, decoded_custom_struct.b,
					"custom_structs_at(%d).b should match initial.custom_structs[%d].b" % [i,i])


	return test.runcode


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
	initialise()

#endregion BoilerPlate
