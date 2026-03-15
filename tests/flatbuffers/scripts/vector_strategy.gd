@tool
extends TestStrategy

const Print = preload("uid://cbluyr4ifn8g3")
const Schema = preload("../schemas/vector_generated.gd")

const TestEnum = Schema.TestEnum
const TestStruct = Schema.TestStruct
const TestTableA = Schema.TestTableA
const TestTableB = Schema.TestTableB
const TestUnion = Schema.TestUnion

enum {
	ENCODING = 0,
	VERIFYING,
	DECODING,
	USING
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_builder]
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
	var table_data:Array[Dictionary] = [
		{ &'o':3},
		{ &'o':5},
		{ &'o':7}
	]

	func table_creator(fbb:FlatBufferBuilder, O:Dictionary) -> int:
		var value:int = O.o
		var ofs:int = Schema.create_TestTableA(fbb, value)
		return ofs

	# Vector of Unions
	var unions_data:Array[Dictionary] = [
		{ &'type':TestUnion.TEST_TABLE_B, &'b':5},
		{ &'type':TestUnion.TEST_TABLE_A, &'a':3},
		{ &'type':TestUnion.TEST_TABLE_A, &'a':7},
	]

	func unions_creator(fbb:FlatBufferBuilder, O:Dictionary) -> PackedInt32Array:
		var type:int = O.type
		var ofs:int
		match type:
			TestUnion.TEST_TABLE_A:
				var value:int = O.a
				ofs = Schema.create_TestTableA(fbb, value)
			TestUnion.TEST_TABLE_B:
				var value:int = O.b
				ofs = Schema.create_TestTableB(fbb, value)
		print("ud: ", O)
		return [ofs,type]


static var initial:Initial

func initialise() -> void:
	initial = Initial.new()



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
	initialise()

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


func encode_builder() -> PackedByteArray:
	# Reset the builder
	var fbb := FlatBufferBuilder.create(1)

	#scalars:[int];
	var temp:PackedInt32Array = initial.scalars
	var scalars_ofs:int = fbb.create_variant(temp, TYPE_PACKED_INT32_ARRAY)
	test.TEST_OP(scalars_ofs, OP_GREATER, 0,
			"Scalars Offset should be greater than zero")

	#enums:[TestEnum];
	# FIXME It's not straight forward what data type i need to use when packing
	# enums. I wonder if I can make the builder a little more friendly to use.
	var enums_ofs:int = fbb.create_variant(initial.enums, TYPE_PACKED_BYTE_ARRAY)
	test.TEST_OP(enums_ofs, OP_GREATER, 0,
			"Enums Offset should be greater than zero")

	#strings:[string];
	var strings_ofs:int = fbb.create_variant(initial.strings, TYPE_PACKED_STRING_ARRAY)
	test.TEST_OP(strings_ofs, OP_GREATER, 0,
			"Strings Offset should be greater than zero")

	#godot_structs:[Vector3];
	var godot_structs_ofs:int = fbb.create_variant(initial.godot_structs, TYPE_PACKED_VECTOR3_ARRAY)
	test.TEST_OP(godot_structs_ofs, OP_GREATER, 0,
			"Godot Structs Offset should be greater than zero")

	#custom_structs:[TestStruct];
	var custom_structs_ofs:int = fbb.create_vector_of_custom_struct(
			initial.custom_structs, TestStruct._fb_struct_size )
	test.TEST_OP(custom_structs_ofs, OP_GREATER, 0,
			"Custom Structs Offset should be greater than zero")

	#tables:[TestTableA];
	var tables_ofs:int = fbb.create_vector_of_table(initial.table_data, initial.table_creator )
	test.TEST_OP(tables_ofs, OP_GREATER, 0,
			"Tables Offset should be greater than zero")

	# Temporary Union to check the differences between vectors and non vectors
	#single:TestUnion;

	# Vector of Unions
	#unions:[TestUnion];
	var unions_ofs_pair:Array = fbb.create_vector_of_union(
			initial.unions_data, initial.unions_creator )
	var unions_values_ofs:int = unions_ofs_pair[0]
	var unions_types_ofs:int = unions_ofs_pair[1]
	test.TEST_OP(unions_values_ofs, OP_GREATER, 0,
			"union_values_ofs should be greater than zero")
	test.TEST_OP(unions_types_ofs, OP_GREATER, 0,
			"union_types_ofs should be greater than zero")

	var rtb := Schema.RootTableBuilder.new(fbb)
	rtb.add_scalars(scalars_ofs)
	rtb.add_enums(enums_ofs)
	rtb.add_strings(strings_ofs)
	rtb.add_godot_structs(godot_structs_ofs)
	rtb.add_custom_structs(custom_structs_ofs)
	rtb.add_tables(tables_ofs)
	rtb.add_unions(unions_values_ofs)
	rtb.add_unions_type(unions_types_ofs)
	var rtb_ofs:int = rtb.finish()
	fbb.finish(rtb_ofs)

	return fbb.get_buffer()


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
		for i in initial.custom_structs.size():
			var initial_custom_struct:TestStruct = initial.custom_structs[i]
			var decoded_custom_struct:TestStruct = rtb.custom_structs_at(i)
			test.TEST_EQ(initial_custom_struct.a, decoded_custom_struct.a,
					"custom_structs_at(%d).a should match initial.custom_structs[%d].a" % [i,i])
			test.TEST_EQ(initial_custom_struct.b, decoded_custom_struct.b,
					"custom_structs_at(%d).b should match initial.custom_structs[%d].b" % [i,i])

	# vector of tables
	if test.TEST_EQ_RET(initial.table_data.size(), rtb.tables_size(),
			"size of initial table_data should match the decoded tables_size()"):
		for i in initial.table_data.size():
			var O:Dictionary = initial.table_data[i]
			var decoded_table:TestTableA = rtb.tables_at(i)
			test.TEST_EQ(O.o, decoded_table.a(),
				"Decoded table field should match initial data source")


	# vector of union
	if test.TEST_EQ_RET(initial.unions_data.size(), rtb.unions_size(),
			"size of initial unions_data should match the decoded unions_size()"):
		var types:PackedByteArray = rtb.unions_type()
		var unions:Array = rtb.unions()
		print("unions_type()",  types )
		print("unions()",  unions )
		for i in initial.unions_data.size():
			print("i: ", i)
			var ud:Dictionary = initial.unions_data[i]
			print("ud: ", ud)
			var type:TestUnion = types[i] as TestUnion
			var type_at:TestUnion = rtb.unions_type_at(i)

			test.TEST_EQ(ud.get(&'type', 0), type,
				"decoded union_type()[i] should match initial data type")
			test.TEST_EQ(ud.get(&'type', 0), type_at,
				"decoded union_type_at(i) should match initial data type")

			print("UnionType: ", TestUnion.find_key(type), ":", type)
			print("unions[i]: ", unions[i])
			if unions[i] is TestTableA:
				print("unions[i] is TestTableA")

			elif unions[i] is TestTableB:
				print("unions[i] is TestTableB")
			else:
				print("unions[i] is Unknown")

			match type:
				TestUnion.TEST_TABLE_A:
					var table:TestTableA = unions[i]
					var table_at:TestTableA = rtb.unions_at(i)
					test.TEST_EQ(ud.get(&'a',0), table.a(),
							"decoded unions()[i].a should match initia data")
					test.TEST_EQ(ud.get(&'a',0), table_at.a(),
							"decoded unions_at(i).a should match initia data")
				TestUnion.TEST_TABLE_B:
					var table:TestTableB = unions[i]
					var table_at:TestTableB = rtb.unions_at(i)
					test.TEST_EQ(ud.get(&'b',0), table.b(),
							"decoded unions()[i].a should match initia data")
					test.TEST_EQ(ud.get(&'b',0), table_at.b(),
							"decoded unions_at(i).a should match initia data")

	return test.runcode
