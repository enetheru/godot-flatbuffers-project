class_name CompareWork
extends RefCounted

## 64 records of the same fields as the upstream FooBar sample.
## Big enough that a fixed overhead does not hide the per-record cost,
## small enough that one iteration stays well under the 0.5s minimum.
const COUNT := 64
const LOCATION := "http://google.com/flatbuffers/"
const LABEL := "Hello, World!"
const FRUIT := 2

const FB = preload("uid://ddiycsgeokhmv")
const DictCase = preload("uid://dve0r6lgn2kft")


class Record:
	var id:int
	var count:int
	var prefix:int
	var length:int
	var time:int
	var ratio:float
	var ssize:int
	var rating:float
	var postfix:int
	var label:String


## One root, one table, and one of each struct. LoadReuse fills these
## instead of constructing a reader per record. The nested class cannot
## see this file's preload, so make_readers() builds the four objects.
class Readers:
	var root:RefCounted
	var item:RefCounted
	var bar:RefCounted
	var foo:RefCounted


func make_readers() -> Readers:
	var readers := Readers.new()
	readers.root = FB.FBFooBarContainer.new()
	readers.item = FB.FBFooBar.new()
	readers.bar = FB.FBBar.new()
	readers.foo = FB.FBFoo.new()
	return readers


func check_payload() -> String:
	var flat_buf := encode_flat()
	var dict_value := make_dict()
	var object_value := make_objects()
	var flat_total := flat_sum(flat_buf)
	var dict_total := dict_sum(dict_value)
	var object_total := object_sum(object_value)
	var dict_round := dict_sum_bytes(encode_dict(dict_value))
	var object_round := object_sum_bytes(encode_objects(object_value))
	var built_value := dict_from_objects(object_value)
	var built_buf := encode_dict(built_value)
	var built_total := dict_sum(built_value)
	var built_round := dict_sum_bytes(built_buf)
	if flat_total == 0 or flat_total != dict_total or flat_total != object_total \
			or flat_total != dict_round or flat_total != object_round \
			or flat_total != built_total or flat_total != built_round:
		return "scenario payload mismatch flat=%d dict=%d object=%d built=%d dict_bytes=%d object_bytes=%d built_bytes=%d" % [
			flat_total, dict_total, object_total, built_total, dict_round, object_round, built_round,
		]

	var flat_dest := make_dict()
	flat_dest.location = ""
	apply_flat(flat_buf, flat_dest)
	var dict_dest := make_dict()
	dict_dest.location = ""
	apply_dict(encode_dict(dict_value), dict_dest)
	var object_dest := make_objects()
	object_dest.location = ""
	apply_objects(encode_objects(object_value), object_dest)
	var built_dest := dict_from_objects(object_value)
	built_dest.location = ""
	apply_dict(built_buf, built_dest)
	if dict_sum(flat_dest) != flat_total or dict_sum(dict_dest) != flat_total \
			or object_sum(object_dest) != flat_total or dict_sum(built_dest) != flat_total:
		return "scenario update mismatch flat=%d dict=%d object=%d built=%d" % [
			dict_sum(flat_dest), dict_sum(dict_dest), object_sum(object_dest),
			dict_sum(built_dest),
		]
	if dict_sum(spawn_dict(built_buf)) != flat_total:
		return "scenario spawn mismatch built=%d flat=%d" % [
			dict_sum(spawn_dict(built_buf)), flat_total,
		]

	var expect := _expect_rating()
	if peek_flat(flat_buf) != expect or peek_dict(encode_dict(dict_value)) != expect \
			or peek_objects(encode_objects(object_value)) != expect \
			or peek_dict(built_buf) != expect:
		return "scenario peek mismatch flat=%d dict=%d object=%d built=%d expect=%d" % [
			peek_flat(flat_buf), peek_dict(encode_dict(dict_value)),
			peek_objects(encode_objects(object_value)), peek_dict(built_buf), expect,
		]
	return ""


func encode_flat() -> PackedByteArray:
	var fbb := FlatBufferBuilder.create(0)
	var rec := Record.new()
	var offsets := PackedInt32Array()
	if offsets.resize(COUNT) != OK:
		push_error("scenario offset resize failed")
		return PackedByteArray()
	for i in COUNT:
		_apply(i, rec)
		var foo := FB.create_FBFoo(rec.id, rec.count, rec.prefix, rec.length)
		var bar := FB.create_FBBar(foo, rec.time, rec.ratio, rec.ssize)
		var name_ofs:int = fbb.create_variant(rec.label)
		offsets[i] = FB.create_FBFooBar(fbb, bar, name_ofs, rec.rating, rec.postfix)
	var loc_ofs:int = fbb.create_variant(LOCATION)
	var list_ofs:int = fbb.create_vector_offset(offsets)
	var root_ofs:int = FB.create_FBFooBarContainer(
			fbb, list_ofs, true, FB.Enum.BANANAS, loc_ofs)
	fbb.finish(root_ofs)
	return fbb.get_buffer()


func encode_dict(value:Dictionary) -> PackedByteArray:
	return var_to_bytes(value)


func encode_objects(value:FooBarContainer) -> PackedByteArray:
	return var_to_bytes_with_objects(value)


func make_dict() -> Dictionary:
	var rec := Record.new()
	var list:Array = []
	if list.resize(COUNT) != OK:
		push_error("scenario list resize failed")
	for i in COUNT:
		_apply(i, rec)
		var parent:Dictionary = {}
		parent.id = rec.id
		parent.count = rec.count
		parent.prefix = rec.prefix
		parent.length = rec.length
		var sibling:Dictionary = {}
		sibling.parent = parent
		sibling.time = rec.time
		sibling.ratio = rec.ratio
		sibling.size = rec.ssize
		var row:Dictionary = {}
		row.name = rec.label
		row.postfix = rec.postfix
		row.rating = rec.rating
		row.sibling = sibling
		list[i] = row
	var root:Dictionary = {}
	root.location = LOCATION
	root.fruit = FRUIT
	root.initialized = true
	root.list = list
	return root


func make_objects() -> FooBarContainer:
	var rec := Record.new()
	var root := FooBarContainer.new()
	root.location = LOCATION
	root.fruit = FooBarContainer.Enum.Bananas
	root.initialized = true
	if root.list.resize(COUNT) != OK:
		push_error("scenario object list resize failed")
	for i in COUNT:
		_apply(i, rec)
		var foo := Foo.new()
		foo.id = rec.id
		foo.count = rec.count
		foo.prefix = rec.prefix
		foo.length = rec.length
		var bar := Bar.new()
		bar.parent = foo
		bar.time = rec.time
		bar.ratio = rec.ratio
		bar.size = rec.ssize
		var row := FooBar.new()
		row.name = rec.label
		row.postfix = rec.postfix
		row.rating = rec.rating
		row.sibling = bar
		root.list[i] = row
	return root


func dict_from_objects(root:FooBarContainer) -> Dictionary:
	var src_list := _array_from(root.list)
	var list:Array = []
	if list.resize(src_list.size()) != OK:
		push_error("scenario construct resize failed")
		return {}
	for i in src_list.size():
		var item := _foobar_from(src_list[i])
		if item == null or item.sibling == null or item.sibling.parent == null:
			continue
		var bar := item.sibling
		var foo := bar.parent
		var parent:Dictionary = {}
		parent.id = foo.id
		parent.count = foo.count
		parent.prefix = foo.prefix
		parent.length = foo.length
		var sibling:Dictionary = {}
		sibling.parent = parent
		sibling.time = bar.time
		sibling.ratio = bar.ratio
		sibling.size = bar.size
		var row:Dictionary = {}
		row.name = item.name
		row.postfix = item.postfix
		row.rating = item.rating
		row.sibling = sibling
		list[i] = row
	var out:Dictionary = {}
	out.location = root.location
	out.fruit = root.fruit
	out.initialized = root.initialized
	out.list = list
	return out


func flat_sum(buf:PackedByteArray) -> int:
	if buf.is_empty():
		return -1
	var bench := FlatBuffersBench.new()
	return bench.Use(FB.get_FBFooBarContainer(buf))


## Same terms as FlatBuffersBench.Use. list_at, sibling, and parent reuse
## the Readers objects, so those three allocations stay outside the records.
func flat_sum_reuse(buf:PackedByteArray, readers:Readers) -> int:
	if buf.is_empty() or readers == null:
		return -1
	var root := readers.root
	root._interpret_as_root(buf)
	var total := 0
	total += int(root.initialized())
	total += root.location().length()
	total += int(root.fruit())
	for i in root.list_size():
		var item := root.list_at(i, readers.item)
		total += item.name().length()
		total += item.postfix()
		total += int(item.rating())
		var bar := _sibling_into(item, readers.bar)
		if bar == null:
			return -1
		total += int(bar.ratio)
		total += bar.ssize
		total += bar.time
		var foo := _parent_into(bar, readers.foo)
		total += foo.count
		total += foo.id
		total += foo.length
		total += foo.prefix
	return total


func dict_sum(value:Dictionary) -> int:
	var bench:BenchCase = DictCase.new()
	return bench.Use(value)


func dict_sum_bytes(buf:PackedByteArray) -> int:
	return dict_sum(_dict_from(bytes_to_var(buf)))


func object_sum(value:FooBarContainer) -> int:
	if value == null:
		return -1
	var bench := BuiltInBench.new()
	return bench.Use(value)


func object_sum_bytes(buf:PackedByteArray) -> int:
	return object_sum(_object_from(bytes_to_var_with_objects(buf)))


func spawn_flat(buf:PackedByteArray) -> Dictionary:
	var root:FB.FBFooBarContainer = FB.get_FBFooBarContainer(buf)
	var list:Array = []
	if list.resize(root.list_size()) != OK:
		push_error("scenario spawn resize failed")
	for i in root.list_size():
		var item := root.list_at(i)
		var bar := item.sibling()
		var foo := bar.parent
		var parent:Dictionary = {}
		parent.id = foo.id
		parent.count = foo.count
		parent.prefix = foo.prefix
		parent.length = foo.length
		var sibling:Dictionary = {}
		sibling.parent = parent
		sibling.time = bar.time
		sibling.ratio = bar.ratio
		sibling.size = bar.ssize
		var row:Dictionary = {}
		row.name = item.name()
		row.postfix = item.postfix()
		row.rating = item.rating()
		row.sibling = sibling
		list[i] = row
	var out:Dictionary = {}
	out.initialized = root.initialized()
	out.location = root.location()
	out.fruit = int(root.fruit())
	out.list = list
	return out


func spawn_dict(buf:PackedByteArray) -> Dictionary:
	return _dict_from(bytes_to_var(buf))


func spawn_objects(buf:PackedByteArray) -> FooBarContainer:
	return _object_from(bytes_to_var_with_objects(buf))


func apply_flat(buf:PackedByteArray, dest:Dictionary) -> void:
	var root:FB.FBFooBarContainer = FB.get_FBFooBarContainer(buf)
	dest.initialized = root.initialized()
	dest.location = root.location()
	dest.fruit = int(root.fruit())
	var dest_list := _array_from(dest.list)
	var n := mini(root.list_size(), dest_list.size())
	for i in n:
		_fill_row(_dict_from(dest_list[i]), root.list_at(i))


func apply_dict(buf:PackedByteArray, dest:Dictionary) -> void:
	_copy_root(_dict_from(bytes_to_var(buf)), dest)


func apply_objects(buf:PackedByteArray, dest:FooBarContainer) -> void:
	var src := _object_from(bytes_to_var_with_objects(buf))
	if src == null or dest == null:
		return
	dest.initialized = src.initialized
	dest.location = src.location
	dest.fruit = src.fruit
	var src_list := _array_from(src.list)
	var dest_list := _array_from(dest.list)
	var n := mini(src_list.size(), dest_list.size())
	for i in n:
		var incoming := _foobar_from(src_list[i])
		var current := _foobar_from(dest_list[i])
		if incoming == null or current == null:
			continue
		_copy_foobar(current, incoming)


func peek_flat(buf:PackedByteArray) -> int:
	var root:FB.FBFooBarContainer = FB.get_FBFooBarContainer(buf)
	if root.list_size() <= (COUNT >> 1):
		return -1
	return int(root.list_at(COUNT >> 1).rating())


func peek_dict(buf:PackedByteArray) -> int:
	var list := _array_from(_dict_from(bytes_to_var(buf)).list)
	if list.size() <= (COUNT >> 1):
		return -1
	return _int_field(_dict_from(list[COUNT >> 1]).rating)


func peek_objects(buf:PackedByteArray) -> int:
	var root := _object_from(bytes_to_var_with_objects(buf))
	if root == null:
		return -1
	var list := _array_from(root.list)
	if list.size() <= (COUNT >> 1):
		return -1
	var row := _foobar_from(list[COUNT >> 1])
	if row == null:
		return -1
	return int(row.rating)


func _sibling_into(item:FB.FBFooBar, into:FB.FBBar) -> FB.FBBar:
	var field_start := item.get_inline_field_start(FB.FBFooBar.VT_SIBLING)
	if not field_start:
		return null
	into._fb_bytes = item._fb_bytes
	into._fb_start = field_start
	return into


func _parent_into(bar:FB.FBBar, into:FB.FBFoo) -> FB.FBFoo:
	into._fb_bytes = bar._fb_bytes
	into._fb_start = bar._fb_start
	return into


func _apply(i:int, rec:Record) -> void:
	rec.id = 0xBADCAFEABADCAFE + i
	rec.count = 10000 + i
	rec.prefix = ord("@") + i
	rec.length = 1000000 + i
	rec.time = 123456 + i
	rec.ratio = 3.14159 + i
	rec.ssize = 10000 + i
	rec.rating = 3.1415432432445543543 + i
	rec.postfix = ord("!") + i
	rec.label = LABEL


func _expect_rating() -> int:
	var rec := Record.new()
	_apply(COUNT >> 1, rec)
	return int(rec.rating)


func _fill_row(row:Dictionary, item:FB.FBFooBar) -> void:
	var bar := item.sibling()
	var foo := bar.parent
	row.name = item.name()
	row.postfix = item.postfix()
	row.rating = item.rating()
	var sibling := _dict_from(row.sibling)
	sibling.time = bar.time
	sibling.ratio = bar.ratio
	sibling.size = bar.ssize
	var parent := _dict_from(sibling.parent)
	parent.id = foo.id
	parent.count = foo.count
	parent.prefix = foo.prefix
	parent.length = foo.length


func _copy_root(src:Dictionary, dest:Dictionary) -> void:
	dest.initialized = src.initialized
	dest.location = src.location
	dest.fruit = src.fruit
	var src_list := _array_from(src.list)
	var dest_list := _array_from(dest.list)
	var n := mini(src_list.size(), dest_list.size())
	for i in n:
		_copy_row(_dict_from(dest_list[i]), _dict_from(src_list[i]))


func _copy_row(dest:Dictionary, src:Dictionary) -> void:
	dest.name = src.name
	dest.postfix = src.postfix
	dest.rating = src.rating
	var dest_bar := _dict_from(dest.sibling)
	var src_bar := _dict_from(src.sibling)
	dest_bar.time = src_bar.time
	dest_bar.ratio = src_bar.ratio
	dest_bar.size = src_bar.size
	var dest_foo := _dict_from(dest_bar.parent)
	var src_foo := _dict_from(src_bar.parent)
	dest_foo.id = src_foo.id
	dest_foo.count = src_foo.count
	dest_foo.prefix = src_foo.prefix
	dest_foo.length = src_foo.length


func _copy_foobar(dest:FooBar, src:FooBar) -> void:
	dest.name = src.name
	dest.postfix = src.postfix
	dest.rating = src.rating
	var dest_bar := dest.sibling
	var src_bar := src.sibling
	if dest_bar == null or src_bar == null:
		return
	dest_bar.time = src_bar.time
	dest_bar.ratio = src_bar.ratio
	dest_bar.size = src_bar.size
	var dest_foo := dest_bar.parent
	var src_foo := src_bar.parent
	if dest_foo == null or src_foo == null:
		return
	dest_foo.id = src_foo.id
	dest_foo.count = src_foo.count
	dest_foo.prefix = src_foo.prefix
	dest_foo.length = src_foo.length


func _dict_from(value:Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _array_from(value:Variant) -> Array:
	if value is Array:
		return value
	return []


func _object_from(value:Variant) -> FooBarContainer:
	if value is FooBarContainer:
		return value
	return null


func _foobar_from(value:Variant) -> FooBar:
	if value is FooBar:
		return value
	return null


func _int_field(value:Variant) -> int:
	if value is int:
		return value
	if value is float:
		return int(_as_float(value))
	return -1


func _as_float(value:Variant) -> float:
	if value is float:
		return value
	return 0.0
