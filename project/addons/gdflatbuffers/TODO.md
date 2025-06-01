# TODO List

Because the root of the git tree isnt available when using in a godot project
I have this file so that I can add things to a TODO list while working on
other things inside godot.

# TODO Items

>I'd like a simpler way to get a subtable as the root table.
at the moment I am using the static functions like the below snippet.
This is tedious, I'd rather give -1 or something so that it performs the decode
```gdscript
var change = script.GetChange( bytes, bytes.decode_u32(0) )
```

>I'd also like a _to_string() method that prints out the schema like a
dictionary with values, or even just a to dictionary function I can then
pretty print.

>I'd like a way to tag a schema as a sort of interface version which we can then
ignore the creation functions for, rather than have to delete them after the fact.

>I'd like to add figlet headings between objects or better comments between
objects to visually separate them.

---

>Today I wanted a single function that does all the work, sort of like a create_root( blah )
just like the shorthand except for the root object.

---

>Optional methods to transform a flatbuffer into a dictionary,
or to print the flatbuffer in its schema form with the values replaced by real ones.

>I also really badly need to perform performance testing.

---

>Today I want to be able to test packedbyte array size against the minimum for
any particular buffer. so having a function in the schema file to return that
value would be handy
>>So  after thinking about this one, there is only one useful circumstance where
> the minimum size of the buffer would be useful, and thats for the root buffer.
> all else wouldnt care about it, and so its usefulness is a lot less.

>I found that I might be able to change the function that creates the buffer
object to test against the minimum before being allowed to be created.
It strikes me that its likely that I can perform other tests, that the offsets
are within the buffer object. or not zero

---

> Today I saw that i had no implementaion of getting an item from an array using an index
it looks something like this:

```gdscript
class TableName:
	const parent = preload("schema_generated.gd")
	const Other = parent.Other

	func others_at( idx : int ) -> Other:
		var field_start = get_field_start( vtable.VT_OTHERS )
		var array_size = bytes.decode_u32( field_start )
		var array_start = field_start + 4
		assert(field_start, "Field is not present in buffer" )
		assert( idx < array_size, "index is out of bounds")
		var relative_offset = array_start + idx * 4
		var offset = relative_offset + bytes.decode_u32( relative_offset )
		return parent.get_Other( bytes, offset )
```

>it would be nice to be able to get an array of the final type, rather than
the type of flatbuffer. but that would require more inforamation than
I currently have.

---

>A discussion in the discord piqued my interest, and is something i need to look into:
```
I remember you could go through variant and affect the original array.
Found the example here https://github.com/godotengine/godot-proposals/issues/10830 .
Also looks like 4.4 has https://github.com/godotengine/godot/pull/99201

Yeah it is in 4.4, in variant_internal.cpp it is loading that added function, so it should work.
https://github.com/godotengine/godot-cpp/blob/4.4/include/godot_cpp/variant/variant_internal.hpp

From the PR:
One example of a use-case for this function is mostly explained in GOP 10830: It allows for in-place modification of (wrapped ref-counted) COW variant arguments, i.e. arrays.

And from the closed issue:
With godotengine/godot#99201 merged, i no longer have a personal use-case for this feature. Instead of storing PackedArrayRefs, one can store a Variant and access its internal value using VariantInternal. If a new use-case emerges, please comment on this proposal, or open a new one linking to this one.
I'll note that godotengine/godot#98373 should be functional and can be salvaged in this case.

If you are on a lower version, then call on Variant is the best you have for in-place modification
```
---

For the Syntax highlighter:
>When editing a file and adding a field that refers to a builtin type without
including the godot.fbs at the start, adding it afterwards doesnt clear the
error until a document is saved triggering the quickscan method.
Either I can check after each error for a keyword and refresh, or I should quick
scan after a successful include parse.

>The names of fields arent tracked, so adding duplicates isnt an error.

>The type names in arrays if they are structs or keywords of tables arent green.

For the Generator:
>create variables to store cached copies of the decoded values.
I thought of how when accessing an array of structs piecemeal,
decoding the whole lot would already create the array anyway, so keeping a
reference to the decoded slice of data around could be very useful.

>it might be possible to create generic c++ code for most of the accessors
this would make the generator only need to provide shims.

>The conversion in gdscript for some of the builtin types isnt the best.
for instance, from the bytes to any of the other packed array types.
Taking a slice first, and then converting still performs mutiple copies.

>warnings are showing up in the output as salmon red for error.
