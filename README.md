This repository is the integration testing for the flatbuffers gdextension.
https://github.com/enetheru/godot-flatbuffers

## Folders

Layout of the project.
### /addons
#### flatbuffers-addon
Folder: addons/enetheru.flatbuffers-addon
URL: https://github.com/enetheru/godot-flatbuffers-addon

This Addon is the helpers addon which adds changes to the Editor Interface to ease the use of the flatbuffers extension.
#### flatbuffers-extension
Folder: addons/enetheru.flatbuffers-extension

The folder that I put the flatbuffers extension shared library and .gdexension files into.
https://github.com/enetheru/godot-flatbuffers
#### test-runner
Folder: addons/enetheru.test-runner
URL: https://github.com/enetheru/godot-test-runner

This grew organically out of bespoke testing scripts, and then got split off.
I did try to migrate to the more mainstream testing libraries like [GUT](https://github.com/bitwes/Gut) and [GdUnit4](https://godot-gdunit-labs.github.io/gdUnit4/latest/) but ended up having more trouble trying to get the specifics of what I needed working, so cleaned up my testing code.

#### Other unimportant, or optional addons that I typically have in the project
- enetheru.utils - helper functions I tend to re-write often enough, limited utility.
- enetheru.editor-tweaks - modifications to the editor user interface to make my editor experience nicer.

### /bench
I needed to benchmark, and in either a stroke of genius or madness ported as much as I needed from the google benchmark library directly to GDScript to perform rudimentary testing. This was all done manually, in a weeklong rush, without the use of AI, and yet somehow I got it working enough for my needs. I very much had my doubts that this project was worth the time, but after rudimentary benchmarking that showed 3x slower, but also 3x smaller, I decided that it was still worth the effort.
- /bench/
    - /BenchLib/ - The somewhat messy straight port of Google/[Benchmark](https://github.com/google/benchmark) to GDScript.
    - /editor_run.gd - right click and run, and wait. it will eventually spit out results.
    - /BenchScene.tscn - used to run the benchmarks in a template_release context, open the scene and press f6 to run.
The rest of the items in the folder support the running of the benchmarks

The benchmark cases themselves, are very rudimentary right now, and could use some polish, but the general gist is to match the test cases used in the official flatbuffers documents. The variations of the benchmarking are:
- using godot's `Dictionaries` and `var_to_bytes`
- using godot's Objects and `var_to_bytes`
- using godot-flatbuffers
    - manual construction
    - using the generated FlatbufferBuilders
    - using the generated create functions

There are also some experimental things in there too.

### /scripts
is for miscelaneous scripts supporting the project, of which there is only one right now.
- /scripts/FlatBufferTestBase.gd 
is used as the base class for some testing scripts.

### /tests
The folder designated to hold test cases.
the test-runner addon scans this folder for scripts deriving from `TestBase` to populate its list.

The tests are separated out into categories
- tests/
    - README.md, TEST_CASE.md, TESTING.md - documents to help me organise and think through testing
    - fb_monster/ - using documentation from the flatbuffers project to create and read the monster example
    - fb_reflection/ - generate the reflection code, read a bfbs created from the reflection fbs
    - flatbuffers/ - test cases focusing on generating different parts of the fbs grammar.
    - flatc/ - future work on providing different options to the flatc compiler
    - godot/ - test cases focusing on godot's Variant types

### Help me help you

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/P5P61CW89K)

### Discord
I'm frequently available in both the official and the unofficial discord channels for gdextension and C++
as 'Enetheru' during Australian Central Standard Time GMT+930. Keep in mind that these channels are for gdextension development discussion, if your question is directly about this project then its best to either @ me with a very short message, or private message me. I am very responsive.

* [GodotEngine #cplusplus-discuss](https://discord.com/channels/1235157165589794909/1259879534392774748)
* [Godot Café #gdnative-gdextension](https://discord.com/channels/212250894228652034/342047011778068481)
