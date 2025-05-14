Godot Flatbuffers
=================
Serialise to, and from, flatbuffer objects.

This is a work in progress, and I would appreciate any and all feedback relating to it.
if there are any requests please drop them in an issue and I'll look into it.

The project consists of three main areas:

1. The modifications to the flatc compiler which generates gdscript [here](https://github.com/enetheru/flatbuffers)
  * `flatc --gdscript <schema.fbs>`
1. The gdextension binary plugin - This Github Project
  * FlatbufferBuilder Object
  * Flatbuffer Object
1. The Godot editor addon - `project/addons/gdflatbuffers`
  * Syntax Highlighting of flatbuffer schema files `*.fbs`
  * Context menu's for calling flatc to generate gdscript from flatbuffer schema

### Installation
Due to the work in progress nature, there are no release binaries yet.

I've tried to make compilation as straight forward as possible, dependencies are pulled using CMake's FetchContent.

I do know that at least on windows flatbuffers likes mingw, if you run into trouble please hit me up in issues,
or in godot discord gdextension/c++ channels.

### Basic Usage

First you might want to read up on the [Flatbuffers Documentation](https://flatbuffers.dev/index.html)

#### Step One - Create a schema file
ie.

`my_object.fbs`
```flatbuffers
table MyObject {
    var_name:int32;
}

root_type MyObject;
```

#### Step Two - Generate the gdscript code

Right click on the file in the file explorer, or the script editor and select `flatc --gdscript` to call the flatc compiler on the buffer and generate the code.

A new file `my_object_generated.gd` should appear next to my_object.fbs

#### Step Three - Serialise/De-Serialise some data

If you had read the flatbuffer documentation above, you might see that serialising data is a bit more involved than what might be expected.

Here is an editor script demonstrating serialisation and de-serialiastion of the simple case
```gdscript
@tool
extends EditorScript

# the generated files do not have a class_name so that we dont pollute the global namespace
const MyObjectSchema = preload('res://flatbuffers/my_object_generated.gd')

# Handy trick to get shorter names.
const MyFlatBuf = MyObjectSchema.MyObject
const MyBuilder = MyObjectSchema.MyObjectBuilder

## The value I wish to serialise
var my_value : int = 42


## Construct the flabuffer data in one shot using the create_* function
func serialise() -> PackedByteArray:
	# Make a new builder
	var fbb = FlatBufferBuilder.new()

	# If you want to serialise all the values at once
	var offset = MyObjectSchema.create_MyObject( fbb, my_value )

	# finalise the builder and return the PackedByteArray
	fbb.finish( offset )
	return fbb.to_packed_byte_array()

## Construct the flabuffer data using the builder object, this would be most
## useful in larger objects when you want to only partially construct the buffer.
func serialise_parts() -> PackedByteArray:
	# Create a new builder
	var fbb = FlatBufferBuilder.new()

	# if you want to partially serialise a buffer with many fields
	var my_builder = MyBuilder.new(fbb)
	my_builder.add_var_name(my_value)
	var offset = my_builder.finish()

	# Finalise the fbb
	fbb.finish(offset)

	# return the final buffer
	return fbb.to_packed_byte_array()


## Use the MyObject Flatbuffer specialisation to deserialise the bytes
func deserialise( buffer : PackedByteArray ) -> void:
	var flatbuf : MyFlatBuf = MyObjectSchema.get_root( buffer )

	if flatbuf.var_name_is_present():
		my_value = flatbuf.var_name()


## EditorScripts can be run form the script editor panel by right clicking
## their filename and selecting 'Run'
func _run() -> void:
	print("serialise using create_ function")

	print( "Start Value: %d" % my_value )
	var buffer1 : PackedByteArray = serialise()

	my_value = 9001
	print( "Value changed to: %d" % my_value )

	deserialise( buffer1 )
	print( "Deserialised Value: %d" % my_value )

	print()
	print("serialise fields independently")

	print( "Start Value: %d" % my_value )
	var buffer2 : PackedByteArray = serialise_parts()

	my_value = 37
	print( "Value changed to: %d" % my_value )

	deserialise( buffer2 )
	print( "Deserialised Value: %d" % my_value )

```

### Help me help you

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/P5P61CW89K)

### Discord
I'm frequently available in both the official and the unofficial discord channels for gdextension and C++
as 'Enetheru' during Australian Central Standard Time. GMT+930

* [GodotEngine #cplusplus-discuss](https://discord.com/channels/1235157165589794909/1259879534392774748)
* [Godot Café #gdnative-gdextension](https://discord.com/channels/212250894228652034/342047011778068481)

### Upstream
* https://flatbuffers.dev/index.html
* https://github.com/google/flatbuffers


### Alternative Projects
* https://github.com/V-Sekai-archive/godot-flatbuffers
* https://gitlab.com/JudGenie/flatbuffersgdscript
