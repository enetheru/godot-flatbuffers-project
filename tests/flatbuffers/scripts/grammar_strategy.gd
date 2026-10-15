@tool
extends TestStrategy

const Schema = preload("../schemas/grammar_generated.gd")

var test:TestBase


func _init( initiator:TestBase ) -> void:
	test = initiator


func _get_phase_count() -> int:
	return 1


func _get_phase_name( _idx:int ) -> String:
	return "defaults"


func _get_strategy_count( _idx:int ) -> int:
	return 1


func _get_strategy( _idx:int, _idx2:int ) -> Callable:
	return null_strategy()


func _flow( _selection:Array[int] ) -> void:
	_enum_values()
	_omitted()
	_explicit_defaults()
	_non_defaults()


func _enum_values() -> void:
	test.TEST_EQ( 0, Schema.Fruit.APPLES, "apples is 0" )
	test.TEST_EQ( 1, Schema.Fruit.BANNAS, "bannas is 1" )
	test.TEST_EQ( 1, Schema.Fruit.ORANGES, "oranges shares 1" )
	test.TEST_EQ( 2, Schema.Fruit.MORE_BANNANAS, "more bannanas is 2" )
	test.TEST_EQ( 4, Schema.Fruit.EVEN_MORE_BANANNAS, "even more is 4" )
	test.TEST_EQ( "", Schema.Fruit.find_key( 3 ), "3 has no name" )
	test.TEST_EQ( 0, Schema.Enum1.NONE, "empty enum is none" )
	test.TEST_EQ( 0, Schema.Enum2.NONE, "empty enum 2 is none" )
	test.TEST_EQ( 0, Schema.Enum3.NONE, "empty enum 3 is none" )
	test.TEST_EQ( 0, Schema.Enum4.NONE, "empty enum 4 is none" )


func _take( fbb:FlatBufferBuilder, offset:int ) -> Schema.TableDecl:
	fbb.finish( offset )
	var bytes:PackedByteArray = fbb.get_buffer()
	return Schema.TableDecl.new( bytes, bytes.decode_u32( 0 ) )


func _omitted() -> void:
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.TableDeclBuilder.new( fbb )
	var table := _take( fbb, builder.finish() )
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET( table.verify( verifier ), "omitted verifies" ):
		return
	test.TEST_FALSE( table.scalar_bool_is_present(), "omitted bool absent" )
	test.TEST_EQ( false, table.scalar_bool(), "omitted bool is false" )
	test.TEST_FALSE( table.scalar_int_is_present(), "omitted int absent" )
	test.TEST_EQ( 32, table.scalar_int(), "omitted int default is 32" )
	test.TEST_FALSE( table.scalar_float_is_present(), "omitted float absent" )
	test.TEST_EQ( 5.3, table.scalar_float(), "omitted float default is 5.3" )
	test.TEST_FALSE( table.ident5_is_present(), "omitted vector absent" )
	test.TEST_EQ( 0, table.ident5_size(), "omitted vector size" )


func _explicit_defaults() -> void:
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.TableDeclBuilder.new( fbb )
	builder.add_scalar_float( 5.3 )
	builder.add_scalar_int( 32 )
	builder.add_scalar_bool( false )
	var table := _take( fbb, builder.finish() )
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET( table.verify( verifier ), "explicit defaults verify" ):
		return
	test.TEST_FALSE( table.scalar_bool_is_present(), "default bool elided" )
	test.TEST_EQ( false, table.scalar_bool(), "default bool reads false" )
	test.TEST_FALSE( table.scalar_int_is_present(), "default int elided" )
	test.TEST_EQ( 32, table.scalar_int(), "default int reads 32" )
	test.TEST_FALSE( table.scalar_float_is_present(), "default float elided" )
	test.TEST_EQ( 5.3, table.scalar_float(), "default float reads 5.3" )


func _non_defaults() -> void:
	var fbb := FlatBufferBuilder.new()
	var builder := Schema.TableDeclBuilder.new( fbb )
	builder.add_scalar_float( 1.0 )
	builder.add_scalar_int( 0 )
	builder.add_scalar_bool( true )
	var table := _take( fbb, builder.finish() )
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET( table.verify( verifier ), "non-defaults verify" ):
		return
	test.TEST_TRUE( table.scalar_bool_is_present(), "bool stored" )
	test.TEST_EQ( true, table.scalar_bool(), "bool true" )
	test.TEST_TRUE( table.scalar_int_is_present(), "int stored" )
	test.TEST_EQ( 0, table.scalar_int(), "int 0 is not the default 32" )
	test.TEST_TRUE( table.scalar_float_is_present(), "float stored" )
	test.TEST_EQ( 1.0, table.scalar_float(), "float 1" )
