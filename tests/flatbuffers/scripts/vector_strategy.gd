@tool
extends TestStrategy

const Print = preload("uid://cbluyr4ifn8g3")
const Schema = preload("../schemas/vector_generated.gd")

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
	static var items:Array[Dictionary] = [
		{ &'id': 123, &'type':ItemType.DEFAULT},
		{ &'id': 456, &'type':ItemType.WEAPON},
		{ &'id': 789, &'type':ItemType.FOOD},
		]




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
	test.logd( "RootTable Check" )
	# Reset the builder
	var fbb := FlatBufferBuilder.create(1)

	# Use these two arrays to accumulate data
	var item_ids:PackedInt64Array = []
	var item_offsets:PackedInt32Array = []

	# Resize them to the correct dimensions.
	if item_ids.resize(Initial.items.size()) != OK:
		printerr(Print.get_call_site(), "\n\t unable to resize array")

	if item_offsets.resize(Initial.items.size()) != OK:
		printerr(Print.get_call_site(), "\n\t unable to resize array")

	# Fill them with the inforamtion
	for i:int in Initial.items.size():
		var item:Dictionary = Initial.items[i]
		item_ids[i] = item.id
		var type:int = item.type
		item_offsets[i] = Schema.create_Item(fbb, item_ids[i], type)

	# encode them into the buffer.
	var item_ids_offset:int = fbb.create_PackedInt64Array(item_ids)
	var items_offset:int = fbb.create_vector_offset(item_offsets)

	var bag_ofs:int = Schema.create_Bag(fbb, item_ids_offset, items_offset)
	fbb.finish(bag_ofs)

	return fbb.to_packed_byte_array()


func verify_a( _buf:PackedByteArray ) -> int:
	#logp("[b]== Verification ==[/b]")
	#var verifier := FlatBufferVerifier.new()
	#verifier.set_buffer(bytes)

	# TODO requires code generation changes
	# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
	return TestBase.RetCode.TEST_OK


func decode_a(buf:PackedByteArray) -> Variant:
	return Schema.get_Bag(buf)


func use_a( variant:Variant ) -> int:
	# bag is the root of this buffer.
	var bag:Schema.Bag = variant

	test.TEST_EQ(Initial.items.size(), bag.ids_size(),
		"size of ids should match the size of the initial items list.")
	test.TEST_EQ( Initial.items.size(), bag.items_size(),
		"size of items should match the size of the initial items list.")

	var bag_ids:PackedInt64Array = bag.ids()
	var init_ids:PackedInt64Array = Initial.items.map(
		func(d:Dictionary)->int:
			return d.id)

	test.TEST_EQ(init_ids, bag_ids, "id's should match")

	for item:Schema.Item in bag.items():
		test.TEST_TRUE(item.id() in bag_ids,
			"item id should be in the bag's id list")
		test.TEST_TRUE(item.id() in init_ids,
			"item id should be in the initial id list")
		var item_idx:int = Initial.items.find_custom(
			func(i:Dictionary)->bool:
				return i.id == item.id())
		if test.TEST_OP_RET(item_idx, OP_GREATER_EQUAL, 0,
			"index is invalid"):
				continue
		var initial_item:Dictionary = Initial.items[item_idx]

		test.TEST_EQ(initial_item.id, item.id(),
			"item id should match intial item")
		test.TEST_EQ(initial_item.type, item.type(),
			"item type should match initial item")

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
