@tool
extends TestStrategy

const Schema = preload("../schemas/key_generated.gd")

var test:TestBase


func _init(initiator:TestBase) -> void:
	test = initiator


func _get_phase_count() -> int: return 1

func _get_phase_name(_idx:int) -> String: return "key"

func _get_strategy_count(_idx:int) -> int: return 1

func _get_strategy(_idx:int, _idx2:int) -> Callable:
	return null_strategy()


func _flow(_selection:Array[int]) -> void:
	_unsorted_string_vector()
	_sorted_string_and_long()
	_missing_name()
	_default_fields()


func _named(fbb:FlatBufferBuilder, name:String, n:int) -> int:
	var name_offset:int = fbb.create_variant(name)
	return Schema.create_Named(fbb, name_offset, n)


func _numbered(fbb:FlatBufferBuilder, n:int, label:String) -> int:
	var label_offset:int = fbb.create_variant(label)
	return Schema.create_Numbered(fbb, n, label_offset)


func _unsorted_string_vector() -> void:
	var fbb := FlatBufferBuilder.new()
	var c:int = _named(fbb, "c", 3)
	var a:int = _named(fbb, "a", 1)
	var ab:int = _named(fbb, "ab", 2)
	var offsets:PackedInt32Array = [c, a, ab]
	var named_offset:int = fbb.create_vector_offset(offsets)
	var root_offset:int = Schema.create_Root(fbb, named_offset, 0)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish unsorted root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	test.TEST_EQ("c", root.named_at(0).name(), "unsorted name 0")
	test.TEST_EQ("a", root.named_at(1).name(), "unsorted name 1")
	test.TEST_EQ("ab", root.named_at(2).name(), "unsorted name 2")


func _sorted_string_and_long() -> void:
	var fbb := FlatBufferBuilder.new()
	var c:int = _named(fbb, "c", 3)
	var a:int = _named(fbb, "a", 1)
	var ab:int = _named(fbb, "ab", 2)
	var named_offsets:PackedInt32Array = [c, a, ab]
	var pos:int = _numbered(fbb, 4, "pos")
	var neg:int = _numbered(fbb, -3, "neg")
	var zero:int = _numbered(fbb, 0, "zero")
	var numbered_offsets:PackedInt32Array = [pos, neg, zero]
	var named_offset:int = Schema.create_sorted_Named_vector(fbb, named_offsets)
	var numbered_offset:int = Schema.create_sorted_Numbered_vector(fbb, numbered_offsets)
	var root_offset:int = Schema.create_Root(fbb, named_offset, numbered_offset)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish sorted root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "verify sorted buffer"):
		return
	test.TEST_EQ("a", root.named_at(0).name(), "sorted name 0")
	test.TEST_EQ("ab", root.named_at(1).name(), "sorted name 1")
	test.TEST_EQ("c", root.named_at(2).name(), "sorted name 2")
	test.TEST_EQ(-1, root.named_at(0).key_compare_with_value("ab"), "cmp a vs ab")
	test.TEST_EQ(0, root.named_at(1).key_compare_with_value("ab"), "cmp ab vs ab")
	test.TEST_EQ(1, root.named_at(2).key_compare_with_value("ab"), "cmp c vs ab")
	test.TEST_EQ(0, root.named_at(1).key_compare_with_value(root.named_at(1).name()), "cmp ab vs its name")
	var string_hit:Schema.Named = root.named_lookup("ab")
	if test.TEST_TRUE_RET(string_hit != null, "string hit exists"):
		test.TEST_EQ("ab", string_hit.name(), "string hit")
	test.TEST_EQ(null, root.named_lookup("b"), "string miss")
	test.TEST_EQ("neg", root.numbered_at(0).label(), "sorted long 0")
	test.TEST_EQ("zero", root.numbered_at(1).label(), "sorted long 1")
	test.TEST_EQ("pos", root.numbered_at(2).label(), "sorted long 2")
	test.TEST_EQ(-1, root.numbered_at(0).key_compare_with_value(0), "cmp neg vs 0")
	test.TEST_EQ(0, root.numbered_at(1).key_compare_with_value(0), "cmp zero vs 0")
	test.TEST_EQ(1, root.numbered_at(2).key_compare_with_value(0), "cmp pos vs 0")
	var long_hit:Schema.Numbered = root.numbered_lookup(0)
	if test.TEST_TRUE_RET(long_hit != null, "long hit exists"):
		test.TEST_EQ("zero", long_hit.label(), "long hit uses the default")
		test.TEST_FALSE(long_hit.n_is_present(), "zero key is omitted")
		test.TEST_EQ(0, long_hit.n(), "omitted key reads 0")
	test.TEST_EQ(null, root.numbered_lookup(1), "long miss")


func _missing_name() -> void:
	var fbb := FlatBufferBuilder.new()
	test.TEST_EQ(0, Schema.create_Named(fbb, 0, 4), "named without a name fails")


func _default_fields() -> void:
	var fbb := FlatBufferBuilder.new()
	var name_offset:int = fbb.create_variant("café")
	var named:int = Schema.create_Named(fbb, name_offset, 0)
	if not test.TEST_TRUE_RET(named != 0, "finish named with default n"):
		return
	var named_offset:int = fbb.create_vector_offset(PackedInt32Array([named]))
	var root_offset:int = Schema.create_Root(fbb, named_offset, 0)
	if not test.TEST_TRUE_RET(root_offset != 0, "finish key root"):
		return
	fbb.finish(root_offset)
	var root:Schema.Root = Schema.get_Root(fbb.get_buffer())
	var verifier := FlatBufferVerifier.new()
	if not test.TEST_TRUE_RET(root.verify(verifier), "default key fields verify"):
		return
	var row:Schema.Named = root.named_at(0)
	test.TEST_EQ("café", row.name(), "name")
	test.TEST_TRUE(row.name_is_present(), "name stored")
	test.TEST_FALSE(row.n_is_present(), "default n omitted")
	test.TEST_EQ(0, row.n(), "omitted n reads 0")
	var hit:Schema.Named = root.named_lookup("café")
	if test.TEST_TRUE_RET(hit != null, "lookup café"):
		test.TEST_EQ(0, hit.n(), "lookup reads omitted n")
	test.TEST_EQ(null, root.named_lookup("cafe"), "lookup miss")
	test.TEST_FALSE(root.numbered_is_present(), "numbered absent")
	test.TEST_EQ(0, root.numbered_size(), "absent numbered size")
	test.TEST_EQ(null, root.numbered_lookup(0), "lookup in an absent vector")
