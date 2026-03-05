I need to define a series of challenges to confirm that a particular feature is viable.

I think if I break it down into broad usage pattern I might be able to do this comprehensively.

- schema parsing
- code generation
- encoding
- verification
- decoding
- using

## Schema Parsing
There are really two parts to this.
- The GDScript based parser
- the flatc compiler

For the first(GDScript highlighter), I never built in any mechanism for using it as a means to validate schema before its used, it was built entirely to support highlighting, and its the first ever parser I've ever written, so its rough.

For the second(flatc compiler) There really shouldn't be any need to "colour outside the lines", I'm not trying to build in custom features in a way that could break things so I don't foresee needing to make tests for this

## Code Generation
This is very important, the flatc compiler needs to be able to generate valid GDScript code.
I think I can trigger a generation, and then test that I can read and instantiate the script.

Usage of the code would fit into the next categories.

## Encoding
There are, to my knowledge, at least two ways to build flatbuffers.
- using the build directly using the lower level functions
- using the generated helper

Then there are additional considerations depending on the feature set, like the object API.