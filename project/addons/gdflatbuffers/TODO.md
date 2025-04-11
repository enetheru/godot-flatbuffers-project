# TODO List

Because the root of the git tree isnt available when using in a godot project
I have this file so that I can add things to a TODO list while working on
other things inside godot.

If the field is an array of bytes, then we should be able to use slice rather than decode.

If the field is in a form that is equivalent to a Packed*Array then use that
	- `PackedByteArray		== fieldname:[byte|int|ubyte|uint8]`
	- `PackedColorArray		== fieldname:[Color]`
	- `PackedFloat32Array	== fieldname:[float|float32]`
	- `PackedFloat64Array	== fieldname:[double|float64]`
	- `PackedInt32Array		== fieldname:[int|int32|uint|uint32]`
	- `PackedInt64Array		== fieldname:[long|int64|ulong|uint64]`
	- `PackedStringArray	== fieldname:[string]` ? I'll need to look at this more.
	- `PackedVector2Array	== fieldname:[Vector2]`
	- `PackedVector3Array	== fieldname:[Vector3]`
	- `PackedVector4Array	== fieldname:[Vector4]`

Because I have specified the structs in the godot file, and have appropriate
encoding and decoding functions I think I can use them directly.

2025-04-11
I'd like a simpler way to get a subtable as the root table.
at the moment I am using the static functions like so

```gdscript
var change = script.GetChange( bytes, bytes.decode_u32(0) )
```
This is tedious, I'd rather give -1 or something so that it performs the decode

I'd also like a _to_string() method that prints out the schema like a
dictionary with values, or even just a to dictionary function I can then
pretty print.

I'd like a way to tag a schema as a sort of interface version which we can then
ignore the creation functions for, rather than have to delete them after the fact.

I might perform another re-design of the code gen as it is pretty messy right now

I'd like to add figlet headings between objects or better comments between
objects to visually separate them.

I'd like to add features and fix up the syntax highlighter, and add features to
the code gen too. anyway, lots to do, but its being written here because i am
working on other things.
