# Testing
I'm going to split the testing into logical chunks.

## flatc
Test the compiler's ability to generate valid code, with a focus on command
line flags.

What test cases do I want?
### File Name Manipulation
- -o PATH
- -I PATH
- --filename-suffix: default:_generated

### Code Generation
- --gen-mutable
- --gen-onefile
- --include-prefix PATH
- --object-api
	- --object-prefix PREFIX
	- --object-suffix SUFFIX
	- --gen-compare

## Schema Features
[SchemaDocs](lib/flatbuffers/docs/source/schema) - upstream documentation for the FlatBuffers schema file.

It would be nice to support as much as possible
### include
[SchemaDocs: Includes](lib/flatbuffers/docs/source/schema#Includes)
- Include other flatbuffer schemas
- Include godot.fbs for built-in objects
### file_identifier
### file_extension

### namespace
[SchemaDocs: Namespaces](lib/flatbuffers/docs/source/schema#Namespaces)
I haven't figured out a way to make this useful in a godot context. Perhaps I
can create a separate file which is used as the namespace, and import all the
sub-objects into it.

something like:
```gdscript
# namespace.gd

const GeneratedClass = preload('fbs_generated.gd').GeneratedClass
```
You would then include the namespace, and it would have a reference to the sub-objects
that are distributed throughout other files. It's a bit messy.

### attribute
[schema #Attributes](lib/flatbuffers/docs/source/schema#Attributes)

#### Respected Attributes

None... Yet.
#### TODO
##### `id: n` (on a table field)

Manually set the field identifier to `n`. If you use this attribute, you must
use it on ALL fields of this table, and the numbers must be a contiguous range
from 0 onwards. Additionally, since a union type effectively adds two fields,
its id must be that of the second field (the first field is the type field and
not explicitly declared in the schema). For example, if the last field before
the union field had id 6, the union field should have id 8, and the unions type
field will implicitly be 7. IDs allow the fields to be placed in any order in
the schema. When a new field is added to the schema it must use the next
available ID.
##### `deprecated` (on a field)

Do not generate accessors for this field anymore, code should stop using this
data. Old data may still contain this field, but it won't be accessible anymore
by newer code. Note that if you deprecate a field that was previous required,
old code may fail to validate new data (when using the optional verifier).

These would be expressed using [GDScript documentation comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html#gdscript-documentation-comments)
```gdscript
## @deprecated
var member_variable

## @deprecated: Use [AnotherClass] instead.
class GeneratedClass:
  pass

```
##### `required` (on a non-scalar table field)

By default, fields do not need to be present in the binary. This is desirable,
as it helps with forwards/backwards compatibility, and flexibility of data
structures. By specifying this attribute, you make non-presence an error
for both reader and writer. The reading code may access the field directly,
without checking for null. If the constructing code does not initialize this
field, they will get an assert, and also the verifier will fail on buffers that
have missing required fields. Both adding and removing this attribute may be
forwards/backwards incompatible as readers will be unable read old or new data,
respectively, unless the data happens to always have the field set.
##### `bit_flags` (on an unsigned enum)

The values of this field indicate bits, meaning that any unsigned value N
specified in the schema will end up representing 1<<N, or if you don't specify
values at all, you'll get the sequence 1, 2, 4, 8, ...
##### `nested_flatbuffer: "table_name"` (on a field)

this indicates that the field (which must be a vector of ubyte) contains
flatbuffer data, for which the root type is given by `table_name`. The
generated code will then produce a convenient accessor for the nested
FlatBuffer.
##### `flexbuffer` (on a field)

this indicates that the field (which must be a vector of ubyte) contains
flexbuffer data. The generated code will then produce a convenient accessor for
the FlexBuffer root.
##### `key` (on a field)

this field is meant to be used as a key when sorting a vector of the type of
table it sits in. Can be used for in-place binary search.
##### 'native*\*'

Several attributes have been added to support the C++ object Based API. All
such attributes are prefixed with the term "native*".

#### Undecided Attributes
##### `hash` (on a field)

This is an (un)signed 32/64 bit integer field, whose value during JSON parsing
is allowed to be a string, which will then be stored as its hash. The value of
attribute is the hashing algorithm to use, one of `fnv1_32` `fnv1_64`
`fnv1a_32` `fnv1a_64`.
#### Ignored Attributes
-  `force_align: size` (on a struct)
-  `force_align: size` (on a vector)
-  `original_order` (on a table)

#### Brainstorming godot specific attributes
- mark a flatbuffer generated script with annotations like @tool
-
### Identifiers
I need rules on how to handle naming collisions.
so far I'm just adding an underscore to the name, but going forward I need to
change the identifiers built-in to the extension such that they are less likely to collide. things like using names like 'start', are too generic.

Testing such things would be to purposefully build a flatbuffer which collides and
document the outcomes.
### enum
Godot has two types of Enums, unnamed and named. FlatBuffers Enums are named.
I don't know if there is some specifics around this I should care about, perhaps
including, or adding an attribute to include from another class or file, perhaps something like to prevent it from being generated.
```fbs
enum Named:uint8 (native:"ExistingClass.ExistingEnum") {
    ENUM_VAL = 0, // enum values can also have individual metadata
}
```

### union
I haven't really spent a lot of time thinking about how to support unions.
The documentation appears to be missing some information too, as the type alias is new to me. I don't really know how to express this in gdscript yet and is something I have to look into.

```fbs
union UnionIdent {
    TypeAlias:Type,
}
```
### struct
Because structs are not supported in godot at this time, it seems to me that
the majority of how this will be expressed is in the flatbuffer side of things, and not so much the godot side of things.
### table
I want to be able to add the object API to tables.

### rpc_service
I will have to look into how the C++ code is generated to know what will make sense
for godot.
#### rpc_method
### root_type

I need to make the root type optional

### Fields

#### Identity
#### Type
Any godot native type that is available as a struct can have built-in accessors
##### Scalars
I think native godot only has \[nil, bool, int, and float\], whereas flatbuffers has the full C++ range.
This means that there is conversion required to and from.
##### Objects
I have no idea how or when these types are represented in the schema file.
##### Strings
String to std::string

##### Vectors
FlatBuffers vectors are C++ vectors which are contiguous containers of elements
not the x,y,z of a geometric nature.

#### Default
#### Metadata/Atrributes

