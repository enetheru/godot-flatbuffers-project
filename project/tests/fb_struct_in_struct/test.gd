@tool
extends TestBase

const schema = preload('test_schema_generated.gd')
const Item = schema.Item
const Bag = schema.Bag
const RootTable = schema.RootTable

func _run() -> void:
	var test_int : int = 32;
	var test_vec : Vector3 = Vector3(1,2,3)
	var test_bytes : PackedByteArray
	test_bytes.resize(20)
	test_bytes.encode_u64(0, test_int)
	test_bytes.encode_float(8, test_vec.x )
	test_bytes.encode_float(12, test_vec.y )
	test_bytes.encode_float(16, test_vec.z )
	print("test_bytes:\n", bytes_view(test_bytes) )
	print()


	_verbose = true
	var id : int = 32;
	var pos = Vector3(1,2,3)
	print("id: %d" % id )
	print("pos: " , pos )
	print()

	var item = Item.new()
	item.id = id
	item.pos = pos
	print("item.id: %d" % item.id )
	print("item.pos: " , item.pos )
	print("item:\n", bytes_view(item.bytes) )
	print()
	TEST_EQ(id, item.id, "struct encoding (id:int)")
	TEST_EQ(pos, item.pos, "struct encoding (pos:vector3)")

	var bag = Bag.new()
	bag.item = item
	print("bag.bytes:\n", bytes_view(bag.bytes) )


	var fbb = FlatBufferBuilder.new()
	var offset = schema.create_RootTable(fbb, bag)
	fbb.finish(offset)

	var bytes : PackedByteArray = fbb.to_packed_byte_array()
	print("bytes:\n", bytes_view(bytes) )

	print("\n== Serialisation Finished ==\n")

	var root_table : RootTable = schema.get_root(bytes)

	var bag_recon : Bag = root_table.container()
	print("bag.bytes:\n", bytes_view(bag_recon.bytes) )

	var item_recon : Item = bag_recon.item
	print("item.bytes:\n", bytes_view(item_recon.bytes) )
	print("item.id: " , item.id )
	print("item.pos: " , item.pos )
	print("item_recon.id: " , item_recon.id )
	print("item_recon.pos: " , item_recon.pos )
	TEST_EQ(item.id, item_recon.id, "Item Recon.id")

	if retcode:
		output.append_array([
			"root_table: ",
			#JSON.stringify( root_table.debug(), '  ', false )
		])
		print_rich( '\n'.join( output ) )
