const keywords:Dictionary = {


	&'include':"You can include other schemas files in your current one, e.g.:

include \"mydefinitions.fbs\";

This makes it easier to refer to types defined elsewhere. include automatically
ensures each file is parsed just once, even when referred to more than once.

When using the flatc compiler to generate code for schema definitions, only
definitions in the current file will be generated, not those from the included
files (those you still generate separately).",


	&'namespace':"These will generate the corresponding namespace in C++ for
all helper code, and packages in Java. You can use . to specify nested
namespaces / packages.",


	&'table':"Tables are the main way of defining objects in FlatBuffers.
Example Table

table Monster {
  pos:Vec3;
  mana:short = 150;
  hp:short = 100;
  name:string;
  friendly:bool = false (deprecated, priority: 1);
  inventory:[ubyte];
  color:Color = Blue;
  test:Any;
}

They consist of a name (here Monster) and a list of fields. This field list can
be appended to (and deprecated from) while still maintaining compatibility.",


	&'struct':"Similar to a table, structs consist of fields are required
(so no defaults either), and fields may not be added or be deprecated.
Example Struct

struct Vec3 {
  x:float;
  y:float;
  z:float;
}

Structs may only contain scalars or other structs. Use this for simple objects
where you are very sure no changes will ever be made (as quite clear in the
example Vec3). Structs use less memory than tables and are even faster to
access (they are always stored in-line in their parent object, and use no
virtual table).",


	&'enum':"Define a sequence of named constants, each with a given value,
or increasing by one from the previous one. The default first value is 0. As
you can see in the enum declaration, you specify the underlying integral type
of the enum with:(in this case byte), which then determines the type of any
fields declared with this enum type.

Only integer types are allowed, i.e. byte, ubyte, short ushort, int, uint, long
and ulong.

Typically, enum values should only ever be added, never removed (there is no
deprecation for enums). This requires code to handle forwards compatibility
itself, by handling unknown enum values.",


	&'union':"Unions share a lot of properties with enums, but instead of new
names for constants, you use names of tables. You can then declare a union
field, which can hold a reference to any of those types, and additionally a
field with the suffix _type is generated that holds the corresponding enum
value, allowing you to know which type to cast to at runtime.

It's possible to give an alias name to a type union. This way a type can even
be used to mean different things depending on the name used:

table PointPosition { x:uint; y:uint; }
table MarkerPosition {}
union Position {
  Start:MarkerPosition,
  Point:PointPosition,
  Finish:MarkerPosition
}

Unions contain a special NONE marker to denote that no value is stored so that
name cannot be used as an alias.

Unions are a good way to be able to send multiple message types as a
FlatBuffer. Note that because a union field is really two fields, it must
always be part of a table, it cannot be the root of a FlatBuffer by itself.

If you have a need to distinguish between different FlatBuffers in a more
open-ended way, for example for use as files, see the file identification
feature below.

There is an experimental support only in C++ for a vector of unions (and
types). In the example IDL file above, use [Any] to add a vector of Any to
Monster table. There is also experimental support for other types besides
tables in unions, in particular structs and strings. There's no direct support
for scalars in unions, but they can be wrapped in a struct at no space cost.",


	&'root_type':"This declares what you consider to be the root table of the
serialized data. This is particularly important for parsing JSON data, which
doesn't include object type information.",


	&'file_extension':"by default flatc will output binary files as .bin. This
declaration in the schema will change that to whatever you want:",


	&'file_identifier':"Typically, a FlatBuffer binary buffer is not
self-describing, i.e. it needs you to know its schema to parse it correctly.
But if you want to use a FlatBuffer as a file format, it would be convenient to
be able to have a \"magic number\" in there, like most file formats have, to be
able to do a sanity check to see if you're reading the kind of file you're
expecting.

Now, you can always prefix a FlatBuffer with your own file header, but
FlatBuffers has a built-in way to add an identifier to a FlatBuffer that takes
up minimal space, and keeps the buffer compatible with buffers that don't have
such an identifier.

You can specify in a schema, similar to root_type, that you intend for this
type of FlatBuffer to be used as a file format:

file_identifier \"MYFI\";

Identifiers must always be exactly 4 characters long. These 4 characters will
end up as bytes at offsets 4-7 (inclusive) in the buffer.

For any schema that has such an identifier, flatc will automatically add the
identifier to any binaries it generates (with -b), and generated calls like
FinishMonsterBuffer also add the identifier. If you have specified an
identifier and wish to generate a buffer without one, you can always still do
so by calling FlatBufferBuilder::Finish explicitly.

After loading a buffer, you can use a call like MonsterBufferHasIdentifier to
check if the identifier is present.

Note that this is best for open-ended uses such as files. If you simply wanted
to send one of a set of possible messages over a network for example, you'd be
better off with a union.",


	&'attribute':"Attributes may be attached to a declaration, behind a
field/enum value, or after the name of a table/struct/enum/union. These may
either have a value or not. Some attributes like deprecated are understood by
the compiler; user defined ones need to be declared with the attribute
declaration (like priority in the example above), and are available to query if
you parse the schema at runtime. This is useful if you write your own code
generators/editors etc., and you wish to add additional information specific to
your tool (such as a help text).

Current understood attributes:

	id: n (on a table field): manually set the field identifier to n. If you
		use this attribute, you must use it on ALL fields of this table, and
		the numbers must be a contiguous range from 0 onwards. Additionally,
		since a union type effectively adds two fields, its id must be that of
		the second field (the first field is the type field and not explicitly
		declared in the schema). For example, if the last field before the
		union field had id 6, the union field should have id 8, and the unions
		type field will implicitly be 7. IDs allow the fields to be placed in
		any order in the schema. When a new field is added to the schema it
		must use the next available ID.

	deprecated (on a field): do not generate accessors for this field anymore,
		code should stop using this data. Old data may still contain this
		field, but it won't be accessible anymore by newer code. Note that if
		you deprecate a field that was previous required, old code may fail to
		validate new data (when using the optional verifier).

	required (on a non-scalar table field): this field must always be set. By
		default, fields do not need to be present in the binary. This is
		desirable, as it helps with forwards/backwards compatibility, and
		flexibility of data structures. By specifying this attribute, you make
		non- presence in an error for both reader and writer. The reading code
		may access the field directly, without checking for null. If the
		constructing code does not initialize this field, they will get an
		assert, and also the verifier will fail on buffers that have missing
		required fields. Both adding and removing this attribute may be
		forwards/backwards incompatible as readers will be unable read old or
		new data, respectively, unless the data happens to always have the
		field set.

	force_align: size (on a struct): force the alignment of this struct to be
		something higher than what it is naturally aligned to. Causes these
		structs to be aligned to that amount inside a buffer, IF that buffer is
		allocated with that alignment (which is not necessarily the case for
		buffers accessed directly inside a FlatBufferBuilder). Note: currently
		not guaranteed to have an effect when used with --object-api, since
		that may allocate objects at alignments less than what you specify with
		force_align.

	force_align: size (on a vector): force the alignment of this vector to be
		something different than what the element size would normally dictate.
		Note: Now only work for generated C++ code.

	bit_flags (on an unsigned enum): the values of this field indicate bits,
		meaning that any unsigned value N specified in the schema will end up
		representing 1<<N, or if you don't specify values at all, you'll get
		the sequence 1, 2, 4, 8, ...

	nested_flatbuffer: \"table_name\" (on a field): this indicates that the
		field (which must be a vector of ubyte) contains flatbuffer data, for
		which the root type is given by table_name. The generated code will
		then produce a convenient accessor for the nested FlatBuffer.

	flexbuffer (on a field): this indicates that the field (which must be a
		vector of ubyte) contains flexbuffer data. The generated code will then
		produce a convenient accessor for the FlexBuffer root.

	key (on a field): this field is meant to be used as a key when sorting a
		vector of the type of table it sits in. Can be used for in-place binary
		search.

	hash (on a field). This is an (un)signed 32/64 bit integer field, whose
		value during JSON parsing is allowed to be a string, which will then be
		stored as its hash. The value of attribute is the hashing algorithm to
		use, one of fnv1_32 fnv1_64 fnv1a_32 fnv1a_64.

	original_order (on a table): since elements in a table do not need to be
		stored in any particular order, they are often optimized for space by
		sorting them to size. This attribute stops that from happening. There
		should generally not be any reason to use this flag.

'native*'. Several attributes have been added to support the C++ object Based
API. All such attributes are prefixed with the term \"native\".",


	&'rpc_service':"You can declare RPC calls in a schema, that define a set of
functions that take a FlatBuffer as an argument (the request) and return a
FlatBuffer as the response (both of which must be table types):

rpc_service MonsterStorage {
	Store(Monster):StoreResponse;
	Retrieve(MonsterId):Monster;
}

What code this produces and how it is used depends on language and RPC system
used, there is preliminary support for GRPC through the --grpc code generator,
see grpc/tests for an example."
}
