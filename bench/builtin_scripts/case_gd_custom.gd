@tool
class_name BuiltInBench
extends BenchCase

var kVectorLength:int = 3

func _init(vlen:int = 3) -> void:
	kVectorLength = vlen

func Encode( _unused:Variant = null ) -> PackedByteArray:
	var fbc := FooBarContainer.new()
	fbc.location = "http://google.com/flatbuffers/"
	fbc.fruit = FooBarContainer.Enum.Bananas
	fbc.initialized = true
	if fbc.list.resize(kVectorLength) != OK:
		push_error( "resizing fbc.list failed" )

	for i:int in kVectorLength:
		# We add + i to not make these identical copies for a more realistic
		# compression test.
		var foo := Foo.new()
		foo.id = 0xBADCAFEABADCAFE + i
		foo.count = 10000 + i
		foo.length = 1000000 + i
		foo.prefix = ord('@') + i

		var bar := Bar.new()
		bar.parent = foo
		bar.ratio = 3.14159 + i
		bar.size = 10000 + i
		bar.time = 123456 + i

		var foobar := FooBar.new()
		fbc.list[i] = foobar
		foobar.rating = 3.1415432432445543543 + i
		foobar.postfix = ord('!') + i
		foobar.name = "Hello, World!"
		foobar.sibling = bar

	return var_to_bytes_with_objects(fbc)


func Decode( buf:PackedByteArray ) -> Variant:
	var foobarcontainer:FooBarContainer = bytes_to_var_with_objects(buf)
	return foobarcontainer


func Use( decoded:Variant ) -> int:
	var foobarcontainer:FooBarContainer = decoded
	sum = 0
	Add(int(foobarcontainer.initialized))
	Add(foobarcontainer.location.length())
	Add(foobarcontainer.fruit)
	for i:int in foobarcontainer.list.size():
		var foobar:FooBar = foobarcontainer.list[i]
		Add(foobar.name.length())
		Add(foobar.postfix)
		Add(int(foobar.rating))
		var bar:Bar = foobar.sibling
		Add(int(bar.ratio))
		Add(bar.size)
		Add(bar.time)
		var foo:Foo = bar.parent
		Add(foo.count)
		Add(foo.id)
		Add(foo.length)
		Add(foo.prefix)

	return sum
