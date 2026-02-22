@tool
extends TestBase

const schema = preload('./fixed_array_generated.gd')

# fixed_array.fbs
#include "godot.fbs";
#table RootTable {
	#value:FAE;
#}
#struct FAE {
	#ascalar:[int:32];
	#astruct:[Vector3i:3];
#}
#root_type RootTable;

func _run_test() -> int:
	logd(" == Starting Vars ==")
	var scalar : int = u32
	var vecs = [
		Vector3i(1,2,3),
		Vector3i(4,5,6),
		Vector3i(7,8,9)
	]
	logd("scalar: %X" % scalar )
	for i in vecs.size():
		logd("vecs[%d]: %s" %[i,vecs[i]])

	var fae := schema.FAE.new()
	fae.at_ascalar(0)

	return runcode
