@tool
class_name FlatBuffersBench
extends BenchBase

const FB = preload("bench_generated.gd")  # adjust path to your generated file


var fbb:FlatBufferBuilder;

#explicit FlatBufferBench(int64_t initial_size, Allocator* allocator)
	#: fbb(initial_size, allocator, false) {}

func _init( initial_size:int ) -> void:
	fbb = FlatBufferBuilder.create(initial_size)


#uint8_t* Encode(void*, int64_t& len) override {
func Encode( _thing:Variant ) -> PackedByteArray:
	fbb.clear();

	#const int kVectorLength = 3;
	const kVectorLength:int = 3
	#Offset<FooBar> vec[kVectorLength];
	var vec:PackedInt32Array = []
	if vec.resize(kVectorLength) != OK:
		push_error("Failed to resize container.")
		return []

	#for (int i = 0; i < kVectorLength; ++i) {
	for i:int in kVectorLength:

		#Foo foo(0xABADCAFEABADCAFE + i, 10000 + i, '@' + i, 1000000 + i);
		# NOTE: Foo is a struct, godot doesnt have structs, so I am making a class here.
		# FIXME: the value cannot be represented as a signed 64 bit integer, and godot does
		# not provide an alternative.
		var foo:FB.FBFoo = FB.create_FBFoo(0xBADCAFEABADCAFE + i, 10000 + i, ord('@') + i, 1000000 + i)

		#Bar bar(foo, 123456 + i, 3.14159f + i, 10000 + i);
		# NOTE: Bar is a struct, godot doesnt have structs, so I am making a class here.
		var bar:FB.FBBar = FB.create_FBBar(foo, 123456 + i, 3.14159 + i, 10000 + i)

		#auto name = fbb.CreateString("Hello, World!");
		var name_ofs:int = fbb.create_variant("Hello, World!")

		#auto foobar = CreateFooBar(fbb, &bar, name, 3.1415432432445543543 + i, '!' + i);
		#vec[i] = foobar;
		vec[i] = FB.create_FBFooBar(fbb, bar, name_ofs, 3.1415432432445543543 + i, ord('!') + i)

	#auto location = fbb.CreateString("http://google.com/flatbuffers/");
	var loc_ofs:int = fbb.create_variant("http://google.com/flatbuffers/")

	#auto foobarvec = fbb.CreateVector(vec, kVectorLength);
	var foobarvec_ofs:int = fbb.create_vector_offset(vec)
	#auto foobarcontainer =
		#CreateFooBarContainer(fbb, foobarvec, true, Enum_Bananas, location);
	var foobarcontainer_ofs:int = FB.create_FBFooBarContainer(fbb, foobarvec_ofs, true, FB.Enum.BANANAS, loc_ofs )
	fbb.finish(foobarcontainer_ofs);

	#len = fbb.GetSize();
	#NOTE: removed due to it existing in the packedbytearray return value
	#return fbb.GetBufferPointer();
	return fbb.to_packed_byte_array()


#int64_t Use(void* decoded) override {
func Use( decoded:Variant ) -> int:
	var pba:PackedByteArray = decoded
	sum = 0;
	#auto foobarcontainer = GetFooBarContainer(decoded);
	var foobarcontainer:FB.FBFooBarContainer = FB.get_FBFooBarContainer(pba)
	sum = 0;
	Add(foobarcontainer.initialized())
	Add(foobarcontainer.location().length());
	Add(foobarcontainer.fruit());
	#for (unsigned int i = 0; i < foobarcontainer->list()->Length(); i++) {
	for i:int in foobarcontainer.list_size():
		#auto foobar = foobarcontainer->list()->Get(i);
		var foobar:FB.FBFooBar = foobarcontainer.list_at(i)
		#Add(foobar->name()->Length());
		Add( foobar.name().length() )
		#Add(foobar->postfix());
		Add( foobar.postfix() )
		#Add(static_cast<int64_t>(foobar->rating()));
		Add( int(foobar.rating()) )
		#auto bar = foobar->sibling();
		var bar:FB.FBBar = foobar.sibling()
		#Add(static_cast<int64_t>(bar->ratio()));
		Add( int(bar.ratio) )
		#Add(bar->size());
		Add( bar._fb_struct_size )
		#Add(bar->time());
		Add( bar.time )
		#auto& foo = bar->parent();
		var foo:FB.FBFoo = bar.parent
		Add(foo.count)
		Add(foo.id)
		Add(foo.length)
		Add(foo.prefix)

	return sum;


#void* Decode(void* buffer, int64_t) override { return buffer; }
func Decode( buf:PackedByteArray ) -> Variant:
	return buf

#void Dealloc(void*) override {};
func Dealloc( _decoded:Variant ) -> void:
	pass
