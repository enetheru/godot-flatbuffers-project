@tool
class_name FlatBuffersBench
extends BenchCase

const FB = preload("bench_generated.gd")  # adjust path to your generated file

var kVectorLength:int = 3
var kPreAllocateSize:int = 0
var kStaticReader:bool = false

#explicit FlatBufferBench(int64_t initial_size, Allocator* allocator)
	#: fbb(initial_size, allocator, false) {}

var default_opts:Dictionary = {
	&'kVectorLength':3,
	&'kPreAllocateSize':false,
	&'kStaticReader':false
}

func _init( opts:Dictionary = default_opts ) -> void:
	kVectorLength = opts.get(&'kVectorLength', kVectorLength)
	kPreAllocateSize = opts.get(&'kPreAllocateSize', kPreAllocateSize)
	kStaticReader = opts.get(&'kStaticReader', kStaticReader)


#uint8_t* Encode(void*, int64_t& len) override {
func Encode( _unused:Variant = null ) -> PackedByteArray:
	var fbb := FlatBufferBuilder.create(kPreAllocateSize)

	#const int kVectorLength = 3;
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
	return fbb.get_buffer()

# static reader so we dont need to allocate.
static var _sbf_foobarcontainer := FB.FBFooBarContainer.new()

#void* Decode(void* buffer, int64_t) override { return buffer; }
func Decode( buf:PackedByteArray ) -> Variant:
	if kStaticReader:
		_sbf_foobarcontainer._interpret_as_root(buf)
	else:
		return FB.get_FBFooBarContainer(buf)

	return _sbf_foobarcontainer


#int64_t Use(void* decoded) override {
func Use( decoded:Variant ) -> int:
	#auto foobarcontainer = GetFooBarContainer(decoded);
	var foobarcontainer:FB.FBFooBarContainer = decoded

	sum = 0;
	Add(int(foobarcontainer.initialized()))
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
		Add( bar.ssize )
		#Add(bar->time());
		Add( bar.time )
		#auto& foo = bar->parent();
		var foo:FB.FBFoo = bar.parent
		Add(foo.count)
		Add(foo.id)
		Add(foo.length)
		Add(foo.prefix)

	return sum;
