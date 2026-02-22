@tool
extends TestBase


const other_schema = preload('other_generated.gd')
# == other.fbs ==
#include "godot.fbs";
#table Other {
	#value:Vector3;
#}
#root_type Other;

const schema = preload('include_generated.gd')
# == include.fbs ==
#include "other.fbs";
#table RootTable {
	#external:Other;
	#external_array:[Other];
#}
#root_type RootTable;

func _run_test() -> int:
	logd("== Testing Includes ==")
	var vec : Vector3i = Vector3i(u32,u32,u32)
	logd("Starting Vector3i: %s" % vec)
	logd("\n== Creating 'Other' ==")
	var fbb = FlatBufferBuilder.new()
	var offset = other_schema.create_Other(fbb, vec)
	fbb.finish( offset )
	logd("finished creating flatbuffer object 'Other'")
	var other_bytes = fbb.to_packed_byte_array()
	logd(["bytes: %s" % bytes_view( other_bytes ) ])

	logd("\nDecoding flatbuffer object 'Other'")
	var other := other_schema.get_root(other_bytes)
	var other_vec = other.value()
	logd("decoded vector: %s" % other_vec)

	TEST_EQ(vec.x, other_vec.x)
	TEST_EQ(vec.y, other_vec.y)
	TEST_EQ(vec.z, other_vec.z)
	TEST_EQ(vec, other_vec)

	logd("\n== Creating 'RootTable' ==")
	var vectors : Array = [
		Vector3i(1,2,u32_),
		Vector3i(4,u32_,6),
		Vector3i(u32_,8,9)]

	logd(["Using starting vec: %s" % vec, "And these ones for the array:"])
	for tvec in vectors:
		logd("\t%s" % [tvec])

	fbb.reset()
	var e_offset = other_schema.create_Other(fbb, vec)
	var offsets : PackedInt32Array
	offsets.resize(vectors.size())
	for i in vectors.size():
		offsets[i] = other_schema.create_Other(fbb, vectors[i])

	var ea_offset : int = fbb.create_vector_offset( offsets )
	var root_offset = schema.create_RootTable( fbb, e_offset, ea_offset )
	fbb.finish( root_offset )

	logd("Finished creating flatbuffer object 'RootTable'")
	var root_bytes = fbb.to_packed_byte_array()
	logd(["bytes: %s" % bytes_view( root_bytes ) ])

	logd("\nDecoding flatbuffer object 'RootTable'")
	var rtable := schema.get_root(root_bytes)
	var rtable_ext: = rtable.external()
	var rte_vec = rtable_ext.value()
	logd("decoding rtable.external().value(): %s" % rte_vec )

	TEST_EQ(vec.x, rte_vec.x)
	TEST_EQ(vec.y, rte_vec.y)
	TEST_EQ(vec.z, rte_vec.z)
	TEST_EQ(vec, rte_vec)

	var earray := rtable.external_array()
	logd(["decoding rtable.external_array(): size:%d" % earray.size()])

	logd(["decoding elements using rtable.external_array()"])
	for temp in earray:
		logd("\t%s" % [temp.value()])

	logd(["decoding elements using root_table.external_array_at(idx)"])
	for i in rtable.external_array_size():
		var tother = rtable.external_array_at(i)
		var tvec = tother.value()
		logd("\t%d: %s" % [i, tvec])
		TEST_EQ(vectors[i], tvec )

	return runcode
