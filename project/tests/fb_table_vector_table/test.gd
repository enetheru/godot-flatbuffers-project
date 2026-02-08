@tool
extends TestBase

const schema = preload('test_schema_generated.gd')
const Item = schema.Item
const Bag = schema.Bag
const RootTable = schema.RootTable

var id : int
var pos : Vector3

func _run() -> void:
	_verbose = true
	initial_sanity_check()
	var item_bytes : PackedByteArray = item_check()
	bag_check( item_bytes )
	root_table_check( item_bytes )
	retcode = runcode


func initial_sanity_check():
	var test_int : int = u64
	var test_vec : Vector3i = Vector3i(u32,u32,u32)
	var test_bytes : PackedByteArray
	test_bytes.resize(24)
	test_bytes.encode_u64(0, test_int)
	test_bytes.encode_s32(8, test_vec.x )
	test_bytes.encode_s32(12, test_vec.y )
	test_bytes.encode_s32(16, test_vec.z )
	logd(["test_bytes:", bytes_view(test_bytes)] )
	logd()


func item_check() -> PackedByteArray:
	logd( "Item Check" )
	id = u64_;
	pos = Vector3(u32_,u32_,u32_)
	logd("id: %d" % [id] )
	logd("pos: %s" % [pos] )
	logd()

	#Serialise an item
	var fbb := FlatBufferBuilder.create(1)
	var item_ofs = schema.create_Item(fbb,id, pos)
	fbb.finish(item_ofs)

	var item_bytes : PackedByteArray = fbb.to_packed_byte_array()

	# Item is the root of this buffer.
	var item : Item = schema.get_Item(item_bytes, item_bytes.decode_u32(0))

	logd("item.id: %d" % item.id() )
	logd(["item.pos: %s" % item.pos()] )
	logd(["item:", bytes_view(item.bytes)] )
	logd()
	TEST_EQ(id, item.id())
	TEST_EQ(pos, item.pos())

	return item_bytes

func bag_check( item_bytes : PackedByteArray ):
	logd( "Bag Check" )
	# Reset the builder
	var fbb := FlatBufferBuilder.create(1)

	# put the already packed item into the buffer.
	var bag_item_ofs : int = fbb.create_vector_uint8( item_bytes )

	var bag_ofs : int = schema.create_Bag(fbb, id, bag_item_ofs )

	fbb.finish( bag_ofs )

	var bag_bytes : PackedByteArray = fbb.to_packed_byte_array()

	# bag is the root of this buffer.
	var bag : Bag = schema.get_Bag(bag_bytes, bag_bytes.decode_u32(0))

	logd("bag.id: %d" % bag.id() )
	logd(["bag.item_size: %s" % bag.item_size()] )
	TEST_EQ(id, bag.id())
	TEST_EQ(item_bytes.size(), bag.item_size())
	logd()

	var bag_item_bytes : PackedByteArray = bag.item()
	var bag_item : Item = schema.get_Item(bag_item_bytes, bag_item_bytes.decode_u32(0) )
	logd("bag.item.id: %d" % bag_item.id() )
	logd(["bag.item.pos: %s" % bag_item.pos()] )
	logd(["bag.item:", bytes_view(bag_item.bytes)] )
	logd(["bag:", bytes_view(bag.bytes)] )
	TEST_EQ(id, bag_item.id())
	TEST_EQ(pos, bag_item.pos())
	logd()
	return


func root_table_check( item_bytes : PackedByteArray ):
	logd( "RootTable Check" )
	# Reset the builder
	var fbb := FlatBufferBuilder.create(1)

	# Construct the Bag
	var bag_item_ofs : int = fbb.create_vector_uint8( item_bytes )
	var bag_ofs : int = schema.create_Bag(fbb, id, bag_item_ofs )

	# Now add the bag to a list of bags. We can reference the same offset
	# multiple times
	var offsets : PackedInt32Array = [bag_ofs, bag_ofs, bag_ofs]

	# Add the offset array into the builder
	var offsets_ofs : int = fbb.create_vector_offset( offsets )
	var rt_offset : int = schema.create_RootTable(fbb, offsets_ofs)
	fbb.finish( rt_offset )

	var root_table_bytes : PackedByteArray = fbb.to_packed_byte_array()
	fbb.reset()

	# RootTable is the root of this buffer.
	var root_table : RootTable = schema.get_RootTable(
		root_table_bytes, root_table_bytes.decode_u32(0))

	TEST_TRUE( root_table.list_is_present(), "presence of list" )
	logd("rt.list.size(): %d" % root_table.list_size() )
	TEST_EQ(3, root_table.list_size())
	logd()

	for i in root_table.list_size():
		var bag : Bag = root_table.list_at(i)
		logd("bag.id: %d" % bag.id() )
		logd(["bag.item_size: %s" % bag.item_size()] )
		TEST_EQ(id, bag.id())
		TEST_EQ(item_bytes.size(), bag.item_size())
		logd()

		var bag_item_bytes : PackedByteArray = bag.item()
		var bag_item : Item = schema.get_Item(bag_item_bytes, bag_item_bytes.decode_u32(0) )
		logd("bag.item.id: %d" % bag_item.id() )
		logd(["bag.item.pos: %s" % bag_item.pos()] )
		TEST_EQ(id, bag_item.id())
		TEST_EQ(pos, bag_item.pos())
		logd()


	var list : Array = root_table.list()
	TEST_EQ(3, list.size(), "list.size() from root_table.list()")

	for bag : Bag in list:
		logd("bag.id: %d" % bag.id() )
		logd(["bag.item_size: %s" % bag.item_size()] )
		TEST_EQ(id, bag.id())
		TEST_EQ(item_bytes.size(), bag.item_size())
		logd()

		var bag_item_bytes : PackedByteArray = bag.item()
		var bag_item : Item = schema.get_Item(bag_item_bytes, bag_item_bytes.decode_u32(0) )
		logd("bag.item.id: %d" % bag_item.id() )
		logd(["bag.item.pos: %s" % bag_item.pos()] )
		TEST_EQ(id, bag_item.id())
		TEST_EQ(pos, bag_item.pos())
		logd()
