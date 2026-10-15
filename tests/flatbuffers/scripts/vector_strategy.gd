@tool
extends TestStrategy

const Schema = preload("../schemas/vector_generated.gd")

const TestEnum = Schema.TestEnum
const TestStruct = Schema.TestStruct
const TestTableA = Schema.TestTableA
const TestTableB = Schema.TestTableB
const TestUnion = Schema.TestUnion

enum {
	ENCODING = 0,
	DECODING,
	USING
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_builder]
		# TODO: I want some way to create dependencies between the strategies
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
	var enums:PackedByteArray = [TestEnum.ZERO, TestEnum.ONE, TestEnum.ZERO ]

	# Vector of Strings
	var strings:PackedStringArray = ["An", "café — 日本語", "", "Strings"]

	# Vector of Godot Structs
	var godot_structs:PackedVector3Array = [
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
	_vector_edges()
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
	if not test.TEST_OP_RET(unions_ofs_pair.size(), OP_GREATER, 0,
			"union_offset_pairs.size() should be greater than zero"):
		return []
	var unions_values_ofs:int = unions_ofs_pair[0]
	var unions_types_ofs:int = unions_ofs_pair[1]
	test.TEST_OP(unions_values_ofs, OP_GREATER, 0,
			"union_values_ofs should be greater than zero")
	test.TEST_OP(unions_types_ofs, OP_GREATER, 0,
			"union_types_ofs should be greater than zero")

	print(fbb)
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

	var buf:PackedByteArray = fbb.get_buffer()
	return buf


func decode_a(buf:PackedByteArray) -> Schema.RootTable:
	return Schema.get_RootTable(buf)


func use_a( rtb:Schema.RootTable ) -> int:
	# vector of scalars
	#if test.TEST_TRUE_RET(rtb.scalars_is_present()):
	var rtb_scalars:Array = rtb.scalars() # transform to basic array so we can compare
	test.TEST_EQ(initial.scalars, rtb_scalars,
		"contents of initial scalars should match the decoded scalars()")

	# vector of enum
	var rtb_enums:PackedByteArray = rtb.enums() # transform to basic array so we can compare
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


func _root_from(fbb:FlatBufferBuilder, offset:int) -> Schema.RootTable:
	fbb.finish(offset)
	return Schema.get_RootTable(fbb.get_buffer())


func _vector_edges() -> void:
	_absent_vectors()
	_empty_vectors()
	_union_discriminant()
	_struct_span()


func _absent_vectors() -> void:
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.RootTableBuilder.new(fbb)
	var root:Schema.RootTable = _root_from(fbb, builder.finish())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "absent vectors verify"):
		return
	test.TEST_FALSE(root.scalars_is_present(), "scalars absent")
	test.TEST_EQ(0, root.scalars_size(), "absent scalars size")
	test.TEST_EQ(0, root.scalars().size(), "absent scalars array")
	test.TEST_FALSE(root.enums_is_present(), "enums absent")
	test.TEST_EQ(0, root.enums_size(), "absent enums size")
	test.TEST_FALSE(root.strings_is_present(), "strings absent")
	test.TEST_EQ(0, root.strings_size(), "absent strings size")
	test.TEST_EQ("", root.strings_at(0), "absent strings_at")
	test.TEST_FALSE(root.godot_structs_is_present(), "godot structs absent")
	test.TEST_EQ(0, root.godot_structs_size(), "absent godot structs size")
	test.TEST_FALSE(root.custom_structs_is_present(), "custom structs absent")
	test.TEST_EQ(0, root.custom_structs_size(), "absent custom structs size")
	test.TEST_FALSE(root.tables_is_present(), "tables absent")
	test.TEST_EQ(0, root.tables_size(), "absent tables size")
	test.TEST_FALSE(root.unions_is_present(), "unions absent")
	test.TEST_FALSE(root.unions_type_is_present(), "union types absent")
	test.TEST_EQ(0, root.unions_size(), "absent unions size")
	test.TEST_EQ(0, root.unions_type_size(), "absent union type size")


func _empty_vectors() -> void:
	var fbb := FlatBufferBuilder.new()
	var scalars_ofs:int = fbb.create_variant(PackedInt32Array(), TYPE_PACKED_INT32_ARRAY)
	var enums_ofs:int = fbb.create_variant(PackedByteArray(), TYPE_PACKED_BYTE_ARRAY)
	var strings_ofs:int = fbb.create_variant(PackedStringArray(), TYPE_PACKED_STRING_ARRAY)
	var godot_ofs:int = fbb.create_variant(PackedVector3Array(), TYPE_PACKED_VECTOR3_ARRAY)
	var custom_ofs:int = fbb.create_vector_of_custom_struct([], TestStruct._fb_struct_size)
	var tables_ofs:int = fbb.create_vector_of_table([], initial.table_creator)
	var unions_pair:Array = fbb.create_vector_of_union([], initial.unions_creator)
	if not test.TEST_TRUE_RET(scalars_ofs != 0, "empty scalar vector"):
		return
	if not test.TEST_TRUE_RET(enums_ofs != 0, "empty enum vector"):
		return
	if not test.TEST_TRUE_RET(strings_ofs != 0, "empty string vector"):
		return
	if not test.TEST_TRUE_RET(godot_ofs != 0, "empty godot struct vector"):
		return
	if not test.TEST_TRUE_RET(custom_ofs != 0, "empty custom struct vector"):
		return
	if not test.TEST_TRUE_RET(tables_ofs != 0, "empty table vector"):
		return
	if not test.TEST_EQ_RET(2, unions_pair.size(), "empty union vector pair"):
		return
	var builder := Schema.RootTableBuilder.new(fbb)
	builder.add_unions(unions_pair[0])
	builder.add_unions_type(unions_pair[1])
	builder.add_tables(tables_ofs)
	builder.add_custom_structs(custom_ofs)
	builder.add_godot_structs(godot_ofs)
	builder.add_strings(strings_ofs)
	builder.add_enums(enums_ofs)
	builder.add_scalars(scalars_ofs)
	var root:Schema.RootTable = _root_from(fbb, builder.finish())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "empty vectors verify"):
		return
	test.TEST_TRUE(root.scalars_is_present(), "empty scalars present")
	test.TEST_EQ(0, root.scalars_size(), "empty scalars size")
	test.TEST_TRUE(root.enums_is_present(), "empty enums present")
	test.TEST_EQ(0, root.enums_size(), "empty enums size")
	test.TEST_TRUE(root.strings_is_present(), "empty strings present")
	test.TEST_EQ(0, root.strings_size(), "empty strings size")
	test.TEST_TRUE(root.godot_structs_is_present(), "empty godot structs present")
	test.TEST_EQ(0, root.godot_structs_size(), "empty godot structs size")
	test.TEST_TRUE(root.custom_structs_is_present(), "empty custom structs present")
	test.TEST_EQ(0, root.custom_structs_size(), "empty custom structs size")
	test.TEST_TRUE(root.tables_is_present(), "empty tables present")
	test.TEST_EQ(0, root.tables_size(), "empty tables size")
	test.TEST_TRUE(root.unions_is_present(), "empty unions present")
	test.TEST_TRUE(root.unions_type_is_present(), "empty union types present")
	test.TEST_EQ(0, root.unions_size(), "empty unions size")
	test.TEST_EQ(0, root.unions_type_size(), "empty union type size")


func _union_discriminant() -> void:
	var verifier := FlatBufferVerifier.new()
	test.TEST_TRUE(Schema.test_union_verify(verifier, null, TestUnion.NONE), "none union verifies")
	test.TEST_FALSE(Schema.test_union_verify(verifier, null, 9), "unknown union type fails")


func _struct_span() -> void:
	var verifier := FlatBufferVerifier.new()
	var fitted := TestStruct.new()
	test.TEST_TRUE(fitted.verify(verifier), "test struct span fits")
	var bytes := PackedByteArray()
	bytes.resize(TestStruct._fb_struct_size)
	var overrun := TestStruct.new()
	overrun.assign_buffer(bytes, 1)
	test.TEST_FALSE(overrun.verify(verifier), "test struct offset overruns")
