@tool
extends BenchCase

var kVectorLength:int = 3

func _init(vlen:int = 3) -> void:
	kVectorLength = vlen

func Encode( _unused:Variant = null ) -> PackedByteArray:
	var dict:Dictionary = {}
	dict.location = "http://google.com/flatbuffers/"
	dict.fruit = FooBarContainer.Enum.Bananas
	dict.initialized = true
	var list:Array
	if list.resize(kVectorLength) != OK:
		push_error( "resizing fbc.list failed" )

	for i:int in kVectorLength:
		# We add + i to not make these identical copies for a more realistic
		# compression test.
		var foo: Dictionary = {}
		foo.id = 0xBADCAFEABADCAFE + i
		foo.count = 10000 + i
		foo.length = 1000000 + i
		foo.prefix = ord('@') + i

		var bar:Dictionary = {}
		bar.parent = foo
		bar.ratio = 3.14159 + i
		bar.size = 10000 + i
		bar.time = 123456 + i

		var foobar:Dictionary = {}
		list[i] = foobar
		foobar.rating = 3.1415432432445543543 + i
		foobar.postfix = ord('!') + i
		foobar.name = "Hello, World!"
		foobar.sibling = bar

	dict.list = list
	return var_to_bytes_with_objects(dict)


func Decode( buf:PackedByteArray ) -> Variant:
	var foobarcontainer:Dictionary = bytes_to_var_with_objects(buf)
	return foobarcontainer


func Use( decoded:Variant ) -> int:
	var fbc:Dictionary = decoded
	sum = 0
	var temp:int = 0
	temp = fbc.initialized
	Add(temp)
	var location:String = fbc.location
	Add(location.length())
	temp = fbc.fruit
	Add(temp)
	var list:Array = fbc.list
	for i:int in list.size():
		var foobar:Dictionary = list[i]
		var fbname:String = foobar.name
		Add(fbname.length())
		temp = foobar.postfix
		Add(temp)
		temp = foobar.rating
		Add(temp)
		var bar:Dictionary = foobar.sibling
		temp = bar.ratio
		Add(temp)
		temp = bar.size
		Add(temp)
		temp = bar.time
		Add(temp)
		var foo:Dictionary = bar.parent
		temp = foo.count
		Add(temp)
		temp = foo.id
		Add(temp)
		temp = foo.length
		Add(temp)
		temp = foo.prefix
		Add(temp)

	return sum
