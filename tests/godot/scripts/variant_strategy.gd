@tool
extends TestStrategy

const Print = preload("uid://cbluyr4ifn8g3")
const Schema = preload("../schemas/variant_generated.gd")

enum {
	ENCODING = 0,
	DECODING,
}

var phases:Array[Dictionary] = [{
		&"name":"Encoding",
		&"strategies":[encode_builder]
		# TODO: I want some way to create dependencies between the strategies
	},{
		&"name":"Decoding",
		&"strategies":[decode_a]
	}
]

class Initial:
	var boolean        :bool  = true
	var integer        :int   = 37
	var floating_point :float = 73.59
	var string               := String( "This is a String" )
	var vector2              := Vector2( 1.2, 3.4 )
	var vector2i             := Vector2i( 1, 2 )
	var rect2                := Rect2( 1.2, 3.4, 5.6, 7.8, )
	var rect2i               := Rect2i( 1, 2, 3, 4 )
	var vector3              := Vector3( 1.2, 3.4, 5.6 )
	var vector3i             := Vector3i( 1, 2, 3 )
	var transform2d          := Transform2D( 5.6, vector2 )
	var vector4              := Vector4( 1.2, 3.4, 5.6, 7.8 )
	var vector4i             := Vector4i( 1, 2, 3, 4 )
	var plane                := Plane( vector3, 4.5 )
	var quaternion           := Quaternion( 9.8, 7.6, 5.4, 3.2 )
	var aabb                 := AABB( vector3, vector3i)
	var basis                := Basis( quaternion )
	var transform3d          := Transform3D( basis, vector3 )
	var projection           := Projection( transform3d )
	var color                := Color("13579BDF")
	#var string_name:StringName
	#var node_path:NodePath
	#var rid:RID
	#var object:Object
	#var callable:Callable
	#var signal:Signal
	#var dictionary:Dictionary
	#var array:Array
	var packed_byte_array:PackedByteArray = [1,2,3,4,5,6,7,8,9]
	var packed_int32_array:PackedInt32Array = [1,3,5,7,9]
	var packed_int64_array:PackedInt64Array = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
	var packed_float32_array:PackedFloat32Array = [7,14,21,28,35,42,49,56,63,70]
	var packed_float64_array:PackedFloat64Array = [3,6,9,12,15,18,21,24,27,30]
	var packed_string_array:PackedStringArray = ["This", "is an", "array", "of", "Strings"]
	var packed_vector2_array:PackedVector2Array = [
		Vector2(1,1), Vector2(1,-1), Vector2(-1,-1), Vector2(-1,1) ]
	var packed_vector3_array:PackedVector3Array = [
		Vector3(1,1,1), Vector3(1,-1,1), Vector3(-1,-1,1), Vector3(-1,1,1),
		Vector3(1,1,-1), Vector3(1,-1,-1), Vector3(-1,-1,-1), Vector3(-1,1,-1)]
	var packed_color_array:PackedColorArray = [
		Color.RED, Color.GREEN, Color.BLUE ]
	var packed_vector4_array:PackedVector4Array = [
		Vector4(45,135, 225, 315),Vector4( 1, 0, -1, INF),
	]


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

	# decode
	var decode:Callable = get_strategy(DECODING, selection[DECODING])
	test.logp(" --- %s ---" % decode.get_method().capitalize())
	var unpacked:Schema.RootTable = decode.call(packed)
	test.TEST_TRUE(is_instance_valid(unpacked),
		"result of decode should be a valid instance")

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


func encode_builder() -> PackedByteArray:
	# Reset the builder
	var fbb := FlatBufferBuilder.create(1)

	var string_ofs:int = fbb.create_variant(initial.string, TYPE_STRING)
	test.TEST_OP( string_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pbyte_ofs:int = fbb.create_variant( initial.packed_byte_array, TYPE_PACKED_BYTE_ARRAY)
	test.TEST_OP( pbyte_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pint32_ofs:int = fbb.create_variant( initial.packed_int32_array, TYPE_PACKED_INT32_ARRAY)
	test.TEST_OP( pint32_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pint64_ofs:int = fbb.create_variant( initial.packed_int64_array, TYPE_PACKED_INT64_ARRAY)
	test.TEST_OP( pint64_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pfloat32_ofs:int = fbb.create_variant( initial.packed_float32_array, TYPE_PACKED_FLOAT32_ARRAY)
	test.TEST_OP( pfloat32_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pfloat64_ofs:int = fbb.create_variant( initial.packed_float64_array, TYPE_PACKED_FLOAT64_ARRAY)
	test.TEST_OP( pfloat64_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pstring_ofs:int = fbb.create_variant( initial.packed_string_array, TYPE_PACKED_STRING_ARRAY)
	test.TEST_OP( pstring_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pvector2_ofs:int = fbb.create_variant( initial.packed_vector2_array, TYPE_PACKED_VECTOR2_ARRAY)
	test.TEST_OP( pvector2_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pvector3_ofs:int = fbb.create_variant( initial.packed_vector3_array, TYPE_PACKED_VECTOR3_ARRAY)
	test.TEST_OP( pvector3_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pcolor_ofs:int = fbb.create_variant( initial.packed_color_array, TYPE_PACKED_COLOR_ARRAY)
	test.TEST_OP( pcolor_ofs, OP_GREATER, 0, "offset should be larger than zero")

	var pvector4_ofs:int = fbb.create_variant( initial.packed_vector4_array, TYPE_PACKED_VECTOR4_ARRAY)
	test.TEST_OP( pvector4_ofs, OP_GREATER, 0, "offset should be larger than zero")


	var rtb := Schema.RootTableBuilder.new(fbb)
	rtb.add_boolean(initial.boolean)
	rtb.add_integer(initial.integer)
	rtb.add_string( string_ofs )
	rtb.add_vector2(initial.vector2 )
	rtb.add_vector2i(initial.vector2i )
	rtb.add_rect2(initial.rect2 )
	rtb.add_rect2i(initial.rect2i )
	rtb.add_vector3(initial.vector3 )
	rtb.add_vector3i(initial.vector3i )
	rtb.add_transform2d(initial.transform2d )
	rtb.add_vector4(initial.vector4 )
	rtb.add_vector4i(initial.vector4i )
	rtb.add_plane(initial.plane )
	rtb.add_quaternion(initial.quaternion )
	rtb.add_aabb(initial.aabb )
	rtb.add_basis(initial.basis )
	rtb.add_transform3d(initial.transform3d )
	rtb.add_projection(initial.projection )
	rtb.add_color(initial.color )
	rtb.add_packed_byte_array_( pbyte_ofs )
	rtb.add_packed_int32_array_( pint32_ofs )
	rtb.add_packed_int64_array_( pint64_ofs )
	rtb.add_packed_float32_array_( pfloat32_ofs )
	rtb.add_packed_float64_array_( pfloat64_ofs )
	rtb.add_packed_string_array_( pstring_ofs )
	rtb.add_packed_vector2_array_( pvector2_ofs )
	rtb.add_packed_vector3_array_(pvector3_ofs)
	rtb.add_packed_color_array_(pcolor_ofs)
	rtb.add_packed_vector4_array_(pvector4_ofs)

	var rtb_ofs:int = rtb.finish()
	fbb.finish(rtb_ofs)

	return fbb.get_buffer()

func decode_a(buf:PackedByteArray) -> Schema.RootTable:
	var rto := Schema.get_RootTable(buf)

	test.TEST_EQ(initial.boolean, rto.boolean(), "decode and initial data should be identical")
	test.TEST_EQ(initial.integer, rto.integer(), "decode and initial data should be identical")
	test.TEST_EQ(initial.string, rto.string(), "decode and initial data should be identical")
	test.TEST_EQ(initial.vector2, rto.vector2(), "decode and initial data should be identical")
	test.TEST_EQ(initial.vector2i, rto.vector2i(), "decode and initial data should be identical")
	test.TEST_EQ(initial.rect2, rto.rect2(), "decode and initial data should be identical")
	test.TEST_EQ(initial.rect2i, rto.rect2i(), "decode and initial data should be identical")
	test.TEST_EQ(initial.vector3, rto.vector3(), "decode and initial data should be identical")
	test.TEST_EQ(initial.vector3i, rto.vector3i(), "decode and initial data should be identical")
	test.TEST_EQ(initial.transform2d, rto.transform2d(), "decode and initial data should be identical")
	test.TEST_EQ(initial.vector4, rto.vector4(), "decode and initial data should be identical")
	test.TEST_EQ(initial.vector4i, rto.vector4i(), "decode and initial data should be identical")
	test.TEST_EQ(initial.plane, rto.plane(), "decode and initial data should be identical")
	test.TEST_EQ(initial.quaternion, rto.quaternion(), "decode and initial data should be identical")
	test.TEST_EQ(initial.aabb, rto.aabb(), "decode and initial data should be identical")
	test.TEST_EQ(initial.basis, rto.basis(), "decode and initial data should be identical")
	test.TEST_EQ(initial.transform3d, rto.transform3d(), "decode and initial data should be identical")
	test.TEST_EQ(initial.projection, rto.projection(), "decode and initial data should be identical")
	test.TEST_EQ(initial.color, rto.color(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_byte_array, rto.packed_byte_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_int32_array, rto.packed_int32_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_int64_array, rto.packed_int64_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_float32_array, rto.packed_float32_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_float64_array, rto.packed_float64_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_string_array, rto.packed_string_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_vector2_array, rto.packed_vector2_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_vector3_array, rto.packed_vector3_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_color_array, rto.packed_color_array_(), "decode and initial data should be identical")
	test.TEST_EQ(initial.packed_vector4_array, rto.packed_vector4_array_(), "decode and initial data should be identical")

	return rto
