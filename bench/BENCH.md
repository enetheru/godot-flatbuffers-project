# Benchmarking

[[lib/flatbuffers/docs/source/benchmarks]]

I went and build some dumb copy paste of the google test code so I could run the tests as they do in the main project.
pls don't hate on me, it was not a good week and it helped with my anxiety to manually process it(No AI).

Anyway, through that experience it drew my attention to the fact that my reproduction test cases weren't apples to apples comparisons, and that more could be achieved.

I also need to respect the existing benchmarks so that I can compare against them.

## Scenarios

I really want to emphasise a more real-world scenario's Which from my limited imagination mostly comes down to usage

Use the serialised data to:
- update
- create
- store
- load

The pipeline should somewhat look like:

For updating objects:
```
pre-existing-object | --(encoding)-> wire-format --(decoding)-> --(updating)-> | pre-existing-object
                   >|__________________________________________________________|<
                          The window we are interested in
```
For Spawning objects:
```
pre-existing-object | --(encoding)-> wire-format --(decoding)-> new-object |
                   >|______________________________________________________|<
                                 The window we are interested in
```
For Storage:
```
 | pre-existing-object | --(encoding)-> Storage |
>|_____________________________________________ |<
          The window we are interested in
```
For Loading:
```
 | wire-format --(decoding)-> new-object |
>|_______________________________________|<
     The window we are interested in
```

## Methods
And I want to be able to benchmark against alternate methods
- Godot Built-In with GDScript
- FlatBuffers with GDScript
- Godot Built-In with GDExtension
- FlatBuffers with GDExtension

> [!QUESTION] What about other languages like C# or Rust?

> [!QUESTION] What about using generated C++ godot class helpers underpinned with FlatBuffers?
> so fbs -> C++ in GDExtension registered classes.
