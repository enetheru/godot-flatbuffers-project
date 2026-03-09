@tool
extends TestBase

const schema = preload('schemas/array_fixed_generated.gd')
const Item = schema.Item
const Bag = schema.Bag

func _run_test() -> int:
	var test_int : int = u64
	var test_bytes : PackedByteArray
	test_bytes.resize(24)
	test_bytes.encode_u64(0, test_int)
	logd(["test_bytes:", bytes_view(test_bytes)] )
	logd()

	var id : int = u64_;
	logd("id: %d" % [id] )
	logd()

	var item:Item = schema.create_Item(id)
	logd("item.id: %d" % item.id )
	logd(["item:", bytes_view(item._fb_bytes)] )
	logd()
	TEST_EQ(id, item.id, "struct encoding (id:int)")

	var bag = schema.create_Bag( item, [] )
	logd(["bag.bytes:", bytes_view(bag._fb_bytes)] )
#
	#var fbb = FlatBufferBuilder.new()
	#var offset = schema.create_RootTable(fbb, bag)
	#fbb.finish(offset)
#
	#var bytes : PackedByteArray = fbb.to_packed_byte_array()
	#logd(["bytes:", bytes_view(bytes)] )
#
	#logd("\n== Serialisation Finished ==\n")
#
	#var root_table : RootTable = schema.get_root(bytes)
	#logd(["root_table.bytes: ", bytes_view(root_table.bytes)] )
	#logd("last thing seen.")
	#logd([ "root_table: " + JSON.stringify( root_table.debug(), "  ", false ) ])
#
	#var bag_recon : Bag = root_table.container()
	#var bytes2 : PackedByteArray = bag_recon.bytes
	#logd(["bag.bytes:", bytes_view(bytes2)] )
#
	#var item_recon : Item = bag_recon.item
	#logd(["item.bytes:", bytes_view(item_recon.bytes) ])
	#logd(["item.id: %s" % item.id] )
	#logd(["item.pos: %s" % item.pos] )
	#logd(["item_recon.id: %s" % item_recon.id ])
	#logd(["item_recon.pos: %s" % item_recon.pos] )
	#TEST_EQ(item.id, item_recon.id, "Item Recon.id")
	#TEST_EQ(item.pos, item_recon.pos, "Item Recon.pos")
#
	return runcode
